#!/usr/bin/env node
/**
 * Mock-mode fault injection for the QuizForge routing cascade.
 *
 * This file does NOT call any provider. It replays the routing policy from
 * supabase/functions/generate-quiz/index.ts on a virtual clock against a
 * simulated provider, so fallback, cooldowns, and hedging can be observed
 * without keys, network access, or rate-limit luck.
 *
 * It mirrors, line for line where practical:
 *   - MODEL_ROUTES, key counts, budget/timeouts (index.ts:43-77,159-175)
 *   - per-key-per-model health table and exponential cooldowns (216-292)
 *   - planner with MAX_KEYS_PER_MODEL and MAX_ATTEMPTS (300-341)
 *   - hedged racing loop, global in-flight gate (867-977)
 *
 * Inputs that are ASSUMED, not measured:
 *   1. Provider latencies (DEFAULT_LATENCY). Replace with measured values
 *      before reporting any latency number.
 *   2. Fault durations. They only affect when an attempt resolves.
 *   3. The fault model: per-attempt faults are independent draws, while
 *      --bad-keys marks a key that fails on every attempt and every model it
 *      serves. Cooldowns only show their benefit against the second kind,
 *      because an i.i.d. fault can always be retried on a statistically
 *      identical key.
 *
 * Latency percentiles are computed over successful requests only.
 *
 * Everything here is synthetic. Results must be labelled as a simulation and
 * must never be presented as provider measurements.
 */

import fs from 'node:fs';
import path from 'node:path';
import { fileURLToPath } from 'node:url';

const __dirname = path.dirname(fileURLToPath(import.meta.url));

// ---------------------------------------------------------------------------
// Mirrored production constants
// ---------------------------------------------------------------------------

export const MODEL_ROUTES = [
  { provider: 'groq', model: 'openai/gpt-oss-120b', priority: 1 },
  { provider: 'groq', model: 'openai/gpt-oss-20b', priority: 2 },
  { provider: 'groq', model: 'qwen/qwen3.8-27b', priority: 3 },
  { provider: 'gemini', model: 'gemini-3.5-flash-lite', priority: 4 },
  { provider: 'gemini', model: 'gemini-3.1-flash-lite', priority: 5 },
];

const KEY_COUNTS = { groq: 3, gemini: 5 };

const CONST = {
  TOTAL_REQUEST_BUDGET_MS: 55_000,
  MIN_ATTEMPT_MS: 4_000,
  MAX_ATTEMPTS: 25,
  MAX_KEYS_PER_MODEL: 5,
  MAX_PARALLEL: 2,
  MAX_HEDGES: 2,
  HEDGE_MAX_GLOBAL_INFLIGHT: 20,
  COOLDOWN_RATE_LIMIT_BASE: 20_000,
  COOLDOWN_OVERLOAD_BASE: 5_000,
  COOLDOWN_NETWORK_BASE: 8_000,
  COOLDOWN_BAD_REQUEST: 60_000,
  COOLDOWN_NOT_FOUND: 10 * 60_000,
  COOLDOWN_KEY_AUTH: 10 * 60_000,
  COOLDOWN_MAX: 5 * 60_000,
};

export { CONST as CASCADE_CONSTANTS };

function hedgeDelayMs(questionCount) {
  if (questionCount <= 10) return 7_000;
  if (questionCount <= 20) return 10_000;
  return 14_000;
}

function attemptTimeoutMs(questionCount) {
  if (questionCount <= 10) return 15_000;
  if (questionCount <= 20) return 22_000;
  return 30_000;
}

// ---------------------------------------------------------------------------
// Assumed latency model
// ---------------------------------------------------------------------------

export const DEFAULT_LATENCY = {
  groq: { medianMs: 6_000, p95Ms: 13_000 },
  gemini: { medianMs: 8_000, p95Ms: 17_000 },
};

export const DEFAULT_FAULT_MIX = {
  rate_limit: 0.45,
  overload: 0.25,
  timeout: 0.2,
  invalid_output: 0.1,
};

const SCENARIOS = ['full', 'no-hedge', 'no-cooldown', 'single-route', 'single-provider'];

// ---------------------------------------------------------------------------
// Deterministic randomness
// ---------------------------------------------------------------------------

function hashSeed(...parts) {
  let h = 2166136261 >>> 0;
  const text = parts.join('|');
  for (let i = 0; i < text.length; i++) {
    h ^= text.charCodeAt(i);
    h = Math.imul(h, 16777619);
  }
  return h >>> 0;
}

function mulberry32(seed) {
  let a = seed >>> 0;
  return function next() {
    a = (a + 0x6d2b79f5) | 0;
    let t = Math.imul(a ^ (a >>> 15), 1 | a);
    t = (t + Math.imul(t ^ (t >>> 7), 61 | t)) ^ t;
    return ((t ^ (t >>> 14)) >>> 0) / 4294967296;
  };
}

function gaussian(rng) {
  let u = 0;
  let v = 0;
  while (u === 0) u = rng();
  while (v === 0) v = rng();
  return Math.sqrt(-2 * Math.log(u)) * Math.cos(2 * Math.PI * v);
}

function sampleLatency(rng, profile, questionCount) {
  const median = profile.medianMs;
  const p95 = Math.max(profile.p95Ms ?? median * 2, median * 1.05);
  const sigma = Math.log(p95 / median) / 1.6448536269514722;
  const factor = Math.max(0.5, questionCount / 10);
  return Math.exp(Math.log(median) + sigma * gaussian(rng)) * factor;
}

function pickWeighted(rng, mix) {
  const entries = Object.entries(mix).filter(([, weight]) => weight > 0);
  const total = entries.reduce((sum, [, weight]) => sum + weight, 0);
  if (total <= 0) return 'overload';

  let roll = rng() * total;
  for (const [kind, weight] of entries) {
    roll -= weight;
    if (roll <= 0) return kind;
  }
  return entries[entries.length - 1][0];
}

// ---------------------------------------------------------------------------
// Virtual clock
// ---------------------------------------------------------------------------

class Scheduler {
  constructor() {
    this.now = 0;
    this.events = [];
    this.sequence = 0;
  }

  at(time, fn) {
    const event = { time: Math.max(time, this.now), sequence: this.sequence++, fn };
    let lo = 0;
    let hi = this.events.length;
    while (lo < hi) {
      const mid = (lo + hi) >> 1;
      const other = this.events[mid];
      const before =
        other.time < event.time ||
        (other.time === event.time && other.sequence < event.sequence);
      if (before) lo = mid + 1;
      else hi = mid;
    }
    this.events.splice(lo, 0, event);
  }

  run() {
    while (this.events.length > 0) {
      const event = this.events.shift();
      if (event.time > this.now) this.now = event.time;
      event.fn();
    }
  }
}

// ---------------------------------------------------------------------------
// Simulation
// ---------------------------------------------------------------------------

class Simulation {
  constructor(config) {
    this.config = config;
    this.scheduler = new Scheduler();
    this.keys = this.#buildKeys();
    this.health = new Map();
    this.keyFaults = this.#buildKeyFaults();
    this.activeRoutes = resolveRoutes(config.scenario);
    this.requests = [];
    this.issued = 0;
    this.completed = 0;
    this.stats = {
      attempts: 0,
      hedgesLaunched: 0,
      successes: 0,
      failedAttempts: 0,
      cancelledAttempts: 0,
      winnerCounts: {},
      failureKinds: {},
    };
    this.peakInflight = 0;
  }

  get now() {
    return this.scheduler.now;
  }

  #buildKeys() {
    const keys = { groq: [], gemini: [] };
    for (const provider of ['groq', 'gemini']) {
      for (let i = 1; i <= KEY_COUNTS[provider]; i++) {
        keys[provider].push({
          id: `${provider.toUpperCase()}_API_KEY_${i}`,
          provider,
          inflight: 0,
          lastUsed: 0,
          disabledUntil: 0,
        });
      }
    }
    return keys;
  }

  // A persistent fault models a key that stays throttled or revoked for the
  // whole run. Cooldowns exist to stop requests from retrying exactly this
  // kind of failure; an i.i.d. fault per attempt cannot show that benefit,
  // because the router can always substitute a statistically identical key.
  #buildKeyFaults() {
    const faults = new Map();
    for (const provider of ['groq', 'gemini']) {
      const count = this.config.badKeys[provider] ?? 0;
      for (let i = 0; i < Math.min(count, this.keys[provider].length); i++) {
        faults.set(this.keys[provider][i].id, this.config.badKeyKind);
      }
    }
    return faults;
  }

  cooldownUntil(key, model) {
    return Math.max(
      key.disabledUntil,
      this.health.get(`${key.id}|${model}`)?.until ?? 0,
    );
  }

  coolDown(key, model, baseMs, explicitMs) {
    if (this.config.cooldowns === false) return;

    const healthKey = `${key.id}|${model}`;
    const entry = this.health.get(healthKey) ?? { until: 0, failures: 0 };
    const ms = Math.min(
      explicitMs ?? baseMs * 2 ** entry.failures,
      CONST.COOLDOWN_MAX,
    );
    entry.failures = Math.min(entry.failures + 1, 6);
    entry.until = this.now + ms;
    this.health.set(healthKey, entry);
  }

  markHealthy(key, model) {
    this.health.delete(`${key.id}|${model}`);
    key.disabledUntil = 0;
  }

  totalInflight() {
    let total = 0;
    for (const provider of Object.values(this.keys)) {
      for (const key of provider) total += key.inflight;
    }
    return total;
  }

  pickKey(route, tried) {
    const candidates = this.keys[route.provider].filter(
      (key) =>
        !tried.has(key.id) && this.cooldownUntil(key, route.model) <= this.now,
    );
    if (candidates.length === 0) return null;

    candidates.sort(
      (a, b) => a.inflight - b.inflight || a.lastUsed - b.lastUsed,
    );
    return candidates[0];
  }

  createPlanner() {
    const tried = new Map();
    let attempts = 0;
    const sim = this;

    return {
      get attempts() {
        return attempts;
      },

      next() {
        if (attempts >= CONST.MAX_ATTEMPTS) return null;

        for (const route of sim.activeRoutes) {
          let set = tried.get(route.model);
          if (!set) {
            set = new Set();
            tried.set(route.model, set);
          }
          if (set.size >= CONST.MAX_KEYS_PER_MODEL) continue;

          const key = sim.pickKey(route, set);
          if (!key) continue;

          set.add(key.id);
          attempts++;
          return { route, key };
        }
        return null;
      },

      skipModel(route) {
        const set = tried.get(route.model) ?? new Set();
        for (const key of sim.keys[route.provider]) set.add(key.id);
        tried.set(route.model, set);
      },
    };
  }

  sampleAttempt(rng, route, key, timeoutMs) {
    const cfg = this.config;
    const persistentFault = this.keyFaults.get(key.id);

    if (persistentFault) {
      return {
        ok: false,
        kind: persistentFault,
        reason: 'persistent',
        durationMs: 200 + rng() * 300,
      };
    }

    const faultRate = cfg.modelFaultRates[route.model] ?? cfg.faultRate;
    const profile = {
      ...cfg.latency[route.provider],
      ...(cfg.modelLatency[route.model] ?? {}),
    };
    const latency = sampleLatency(rng, profile, cfg.questionCount);

    if (faultRate <= 0 || rng() >= faultRate) {
      if (latency >= timeoutMs) {
        return { ok: false, kind: 'network', reason: 'timeout', durationMs: timeoutMs };
      }
      return { ok: true, durationMs: latency };
    }

    const kind = pickWeighted(rng, cfg.faultMix);
    const durationMs = faultDuration(rng, kind, timeoutMs, latency);

    if (durationMs >= timeoutMs) {
      return { ok: false, kind: 'network', reason: 'timeout', durationMs: timeoutMs };
    }
    return { ok: false, kind, reason: kind, durationMs };
  }

  launch(request) {
    const remaining = request.deadline - this.now;
    if (remaining < CONST.MIN_ATTEMPT_MS) return false;

    const candidate = request.planner.next();
    if (!candidate) return false;

    const { route, key } = candidate;
    const timeoutMs = Math.min(
      attemptTimeoutMs(this.config.questionCount),
      remaining - 250,
    );
    const outcome = this.sampleAttempt(request.rng, route, key, timeoutMs);

    const attempt = {
      id: request.nextAttemptId++,
      route,
      key,
      outcome,
      startedAt: this.now,
      endAt: this.now + outcome.durationMs,
      settled: false,
      cancelled: false,
    };

    key.inflight++;
    key.lastUsed = this.now;
    request.attempts++;
    this.stats.attempts++;
    request.pending.set(attempt.id, attempt);

    this.scheduler.at(attempt.endAt, () => this.onAttemptDone(request, attempt));
    this.peakInflight = Math.max(this.peakInflight, this.totalInflight());
    return true;
  }

  applyFailure(attempt) {
    const { key, route } = attempt;
    const kind = attempt.outcome.kind;
    if (kind === 'invalid_output') return;

    switch (kind) {
      case 'rate_limit':
        this.coolDown(key, route.model, CONST.COOLDOWN_RATE_LIMIT_BASE);
        break;
      case 'overload':
        this.coolDown(key, route.model, CONST.COOLDOWN_OVERLOAD_BASE);
        break;
      case 'network':
        this.coolDown(key, route.model, CONST.COOLDOWN_NETWORK_BASE);
        break;
      case 'bad_request':
        this.coolDown(
          key,
          route.model,
          CONST.COOLDOWN_BAD_REQUEST,
          CONST.COOLDOWN_BAD_REQUEST,
        );
        break;
      case 'not_found':
        this.coolDown(
          key,
          route.model,
          CONST.COOLDOWN_NOT_FOUND,
          CONST.COOLDOWN_NOT_FOUND,
        );
        break;
      case 'auth':
        if (this.config.cooldowns !== false) {
          key.disabledUntil = this.now + CONST.COOLDOWN_KEY_AUTH;
        }
        break;
      default:
        break;
    }
  }

  cancelPending(request) {
    for (const attempt of request.pending.values()) {
      if (attempt.settled || attempt.cancelled) continue;
      attempt.cancelled = true;
      attempt.key.inflight--;
      this.stats.cancelledAttempts++;
    }
    request.pending.clear();
    request.timerAt = Infinity;
  }

  finish(request) {
    if (request.finished) return;
    request.finished = true;
    request.endAt = this.now;
    request.timerAt = Infinity;

    if (request.success) {
      this.stats.successes++;
      this.stats.winnerCounts[request.winner] =
        (this.stats.winnerCounts[request.winner] ?? 0) + 1;
    }

    this.completed++;
    request.onFinish?.();
  }

  onAttemptDone(request, attempt) {
    if (request.finished || attempt.settled || attempt.cancelled) return;
    attempt.settled = true;
    attempt.key.inflight--;

    const { outcome, route, key } = attempt;

    if (outcome.ok) {
      this.markHealthy(key, route.model);
      request.success = true;
      request.winner = route.model;
      this.cancelPending(request);
      this.finish(request);
      return;
    }

    this.applyFailure(attempt);
    this.stats.failedAttempts++;
    request.failureKinds.push(outcome.kind);
    this.stats.failureKinds[outcome.kind] =
      (this.stats.failureKinds[outcome.kind] ?? 0) + 1;
    request.pending.delete(attempt.id);

    if (outcome.kind === 'not_found') request.planner.skipModel(route);

    if (request.pending.size === 0 && !this.launch(request)) {
      this.finish(request);
      return;
    }
    this.pump(request);
  }

  // Arms the hedge timer relative to the oldest in-flight attempt, exactly as
  // the production loop does after every race. A new generation invalidates
  // any timer scheduled by a previous state.
  pump(request) {
    if (request.finished || request.pending.size === 0) return;

    const eligible =
      this.config.hedging !== false &&
      request.pending.size < CONST.MAX_PARALLEL &&
      request.hedges < CONST.MAX_HEDGES &&
      this.totalInflight() < CONST.HEDGE_MAX_GLOBAL_INFLIGHT;

    if (!eligible) {
      request.timerAt = Infinity;
      return;
    }

    const generation = ++request.timerGeneration;
    const oldestStart = Math.min(
      ...[...request.pending.values()].map((attempt) => attempt.startedAt),
    );
    const fireAt = oldestStart + hedgeDelayMs(this.config.questionCount);
    request.timerAt = fireAt;

    this.scheduler.at(fireAt, () => {
      if (request.finished) return;
      if (request.timerGeneration !== generation || request.timerAt !== fireAt) return;

      request.timerAt = Infinity;

      if (this.launch(request)) {
        request.hedges++;
        request.hedgesLaunched++;
        this.stats.hedgesLaunched++;
      } else {
        request.hedges = CONST.MAX_HEDGES;
      }
      this.pump(request);
    });
  }

  createRequest(id) {
    return {
      id,
      rng: mulberry32(hashSeed(this.config.seed, id)),
      startedAt: this.now,
      deadline: this.now + CONST.TOTAL_REQUEST_BUDGET_MS,
      pending: new Map(),
      nextAttemptId: 0,
      planner: this.createPlanner(),
      hedges: 0,
      hedgesLaunched: 0,
      timerAt: Infinity,
      timerGeneration: 0,
      finished: false,
      success: false,
      winner: null,
      attempts: 0,
      endAt: null,
      failureKinds: [],
      onFinish: null,
    };
  }

  // Closed-loop load: each worker holds at most one request in flight, so
  // --concurrency behaves like N simultaneous users rather than a burst.
  issueNext() {
    if (this.issued >= this.config.requests) return;

    const request = this.createRequest(this.issued++);
    // Without think time, a burst of instant failures drains every queued
    // request inside one cooldown window and reports an artificial collapse.
    request.onFinish = () => {
      if (this.config.thinkTimeMs > 0) {
        this.scheduler.at(this.now + this.config.thinkTimeMs, () => this.issueNext());
      } else {
        this.issueNext();
      }
    };
    this.requests.push(request);

    if (!this.launch(request)) {
      this.finish(request);
      return;
    }
    this.pump(request);
  }

  run() {
    const workers = Math.max(
      1,
      Math.min(this.config.concurrency, this.config.requests),
    );
    for (let worker = 0; worker < workers; worker++) this.issueNext();
    this.scheduler.run();
    return this.summarize();
  }

  summarize() {
    // Latency describes time to a usable quiz, so failed requests are excluded
    // rather than counted as zero-second successes.
    const latencies = this.requests
      .filter((request) => request.success)
      .map((request) => request.endAt - request.startedAt)
      .sort((a, b) => a - b);
    const total = this.requests.length;
    const successes = this.stats.successes;
    const attempts = this.stats.attempts;

    const winners = Object.entries(this.stats.winnerCounts).sort(
      (a, b) => b[1] - a[1] || a[0].localeCompare(b[0]),
    );

    return {
      scenario: this.config.scenario,
      fault_rate: this.config.faultRate,
      concurrency: this.config.concurrency,
      question_count: this.config.questionCount,
      requests: total,
      attempts,
      successes,
      success_rate: total === 0 ? 0 : successes / total,
      p50_ms: percentile(latencies, 0.5),
      p95_ms: percentile(latencies, 0.95),
      mean_attempts: total === 0 ? 0 : attempts / total,
      attempts_per_success: successes === 0 ? null : attempts / successes,
      failed_attempts: this.stats.failedAttempts,
      cancelled_attempts: this.stats.cancelledAttempts,
      excess_attempts: attempts - successes,
      mean_hedges: total === 0 ? 0 : this.stats.hedgesLaunched / total,
      peak_inflight: this.peakInflight,
      winner_distribution: Object.fromEntries(winners),
      failure_kinds: { ...this.stats.failureKinds },
    };
  }
}

function faultDuration(rng, kind, timeoutMs, sampledLatency) {
  switch (kind) {
    case 'rate_limit':
      return 200 + rng() * 400;
    case 'overload':
      return 800 + rng() * 1_200;
    case 'network':
      return 500 + rng() * 1_500;
    case 'timeout':
      return timeoutMs;
    case 'invalid_output':
      return sampledLatency;
    case 'auth':
      return 150 + rng() * 250;
    case 'not_found':
      return 150 + rng() * 250;
    case 'bad_request':
      return 300 + rng() * 500;
    default:
      return 500;
  }
}

function resolveRoutes(scenario) {
  if (scenario === 'single-route') return [MODEL_ROUTES[0]];
  if (scenario === 'single-provider') {
    return MODEL_ROUTES.filter((route) => route.provider === MODEL_ROUTES[0].provider);
  }
  return MODEL_ROUTES;
}

function percentile(sortedValues, fraction) {
  if (sortedValues.length === 0) return 0;
  const index = Math.min(
    sortedValues.length - 1,
    Math.ceil(fraction * sortedValues.length) - 1,
  );
  return sortedValues[index];
}

// ---------------------------------------------------------------------------
// Matrix runner
// ---------------------------------------------------------------------------

export function simulate(overrides = {}) {
  const config = {
    scenario: 'full',
    faultRate: 0,
    modelFaultRates: {},
    faultMix: { ...DEFAULT_FAULT_MIX },
    latency: DEFAULT_LATENCY,
    modelLatency: {},
    badKeys: {},
    badKeyKind: 'rate_limit',
    hedging: true,
    cooldowns: true,
    requests: 200,
    concurrency: 1,
    thinkTimeMs: 2_000,
    questionCount: 10,
    seed: 20261102,
    ...overrides,
  };

  if (!SCENARIOS.includes(config.scenario)) {
    throw new Error(`Unknown scenario "${config.scenario}".`);
  }

  config.hedging =
    config.hedging !== false &&
    config.scenario !== 'no-hedge' &&
    config.scenario !== 'single-route';
  config.cooldowns = config.cooldowns !== false && config.scenario !== 'no-cooldown';

  return new Simulation(config).run();
}

export function runMatrix(options) {
  const cells = [];

  for (const scenario of options.scenarios) {
    for (const faultRate of options.faultRates) {
      for (const concurrency of options.concurrencies) {
        cells.push(
          simulate({
            scenario,
            faultRate,
            concurrency,
            requests: options.requests,
            thinkTimeMs: options.thinkTimeMs,
            questionCount: options.questionCount,
            seed: options.seed,
            modelFaultRates: options.modelFaultRates,
            faultMix: options.faultMix,
            latency: options.latency,
            modelLatency: options.modelLatency,
            badKeys: options.badKeys,
            badKeyKind: options.badKeyKind,
          }),
        );
      }
    }
  }

  return cells;
}

// ---------------------------------------------------------------------------
// CLI
// ---------------------------------------------------------------------------

function parseList(value) {
  return value
    .split(',')
    .map((token) => token.trim())
    .filter(Boolean);
}

function parseFaultMix(value) {
  const mix = {};
  for (const token of parseList(value)) {
    const [kind, weight] = token.split(':');
    const numeric = Number(weight);
    if (!kind || !Number.isFinite(numeric) || numeric < 0) {
      throw new Error(`Invalid fault mix entry "${token}". Use kind:weight.`);
    }
    mix[kind] = numeric;
  }
  if (Object.keys(mix).length === 0) throw new Error('Fault mix is empty.');
  return mix;
}

function parseOverrides(values) {
  const overrides = {};
  for (const value of values) {
    for (const token of parseList(value)) {
      const separator = token.lastIndexOf('=');
      if (separator < 1) {
        throw new Error(`Invalid override "${token}". Use model=rate.`);
      }
      const model = token.slice(0, separator).trim();
      const rate = Number(token.slice(separator + 1));
      if (!Number.isFinite(rate) || rate < 0 || rate > 1) {
        throw new Error(`Fault rate for "${model}" must be between 0 and 1.`);
      }
      overrides[model] = rate;
    }
  }
  return overrides;
}

function parseBadKeys(value) {
  const counts = {};
  for (const token of parseList(value)) {
    const [provider, rawCount] = token.split('=');
    const count = Number(rawCount);
    if (!['groq', 'gemini'].includes(provider)) {
      throw new Error(`Unknown provider "${provider}" in --bad-keys.`);
    }
    if (!Number.isInteger(count) || count < 0) {
      throw new Error(`Bad key count for "${provider}" must be a non-negative integer.`);
    }
    counts[provider] = count;
  }
  return counts;
}

function parseLatencyOverrides(values) {
  const overrides = {};
  for (const value of values) {
    for (const token of parseList(value)) {
      const separator = token.lastIndexOf('=');
      if (separator < 1) {
        throw new Error(`Invalid latency override "${token}". Use model=medianMs.`);
      }
      const model = token.slice(0, separator).trim();
      const [medianMs, p95Ms] = token
        .slice(separator + 1)
        .split('/')
        .map(Number);

      if (!Number.isFinite(medianMs) || medianMs <= 0) {
        throw new Error(`Latency for "${model}" must be a positive number of ms.`);
      }
      overrides[model] = Number.isFinite(p95Ms)
        ? { medianMs, p95Ms: Math.max(p95Ms, medianMs * 1.05) }
        : { medianMs, p95Ms: medianMs * 2 };
    }
  }
  return overrides;
}

function parseArgs(argv) {
  const args = {
    scenarios: ['full', 'no-hedge', 'no-cooldown', 'single-route'],
    faultRates: [0, 0.05, 0.2, 0.4],
    concurrencies: [1],
    requests: 300,
    thinkTimeMs: 2_000,
    questionCount: 10,
    seed: 20261102,
    faultMix: { ...DEFAULT_FAULT_MIX },
    modelFaultRates: {},
    latency: DEFAULT_LATENCY,
    modelLatency: {},
    badKeys: {},
    badKeyKind: 'rate_limit',
    out: null,
    json: false,
  };

  for (let index = 0; index < argv.length; index++) {
    const arg = argv[index];
    const next = () => argv[++index];

    switch (arg) {
      case '--scenarios':
        args.scenarios = parseList(next());
        break;
      case '--fault-rates':
        args.faultRates = parseList(next()).map((value) => {
          const rate = Number(value);
          if (!Number.isFinite(rate) || rate < 0 || rate > 1) {
            throw new Error(`Fault rate "${value}" must be between 0 and 1.`);
          }
          return rate;
        });
        break;
      case '--concurrency':
        args.concurrencies = parseList(next()).map((value) => {
          const count = Number(value);
          if (!Number.isInteger(count) || count < 1) {
            throw new Error(`Concurrency "${value}" must be a positive integer.`);
          }
          return count;
        });
        break;
      case '--requests':
        args.requests = Number(next());
        break;
      case '--think-time-ms':
        args.thinkTimeMs = Number(next());
        break;
      case '--questions':
        args.questionCount = Number(next());
        break;
      case '--seed':
        args.seed = Number(next());
        break;
      case '--fault-mix':
        args.faultMix = parseFaultMix(next());
        break;
      case '--fault-model':
        Object.assign(args.modelFaultRates, parseOverrides([next()]));
        break;
      case '--latency-file': {
        const file = next();
        const parsed = JSON.parse(fs.readFileSync(file, 'utf8'));
        args.latency = { ...args.latency, ...parsed };
        break;
      }
      case '--model-latency':
        Object.assign(args.modelLatency, parseLatencyOverrides([next()]));
        break;
      case '--bad-keys':
        Object.assign(args.badKeys, parseBadKeys(next()));
        break;
      case '--bad-key-kind': {
        const kind = next();
        const allowed = ['rate_limit', 'auth', 'overload', 'network', 'not_found', 'bad_request'];
        if (!allowed.includes(kind)) {
          throw new Error(`--bad-key-kind must be one of: ${allowed.join(', ')}.`);
        }
        args.badKeyKind = kind;
        break;
      }
      case '--out':
        args.out = next();
        break;
      case '--json':
        args.json = true;
        break;
      case '-h':
      case '--help':
        printUsage();
        process.exit(0);
        break;
      default:
        throw new Error(`Unknown option "${arg}". Use --help.`);
    }
  }

  if (!Number.isInteger(args.requests) || args.requests < 1) {
    throw new Error('--requests must be a positive integer.');
  }
  if (!Number.isInteger(args.questionCount) || args.questionCount < 1 || args.questionCount > 30) {
    throw new Error('--questions must be an integer between 1 and 30.');
  }
  if (!Number.isFinite(args.thinkTimeMs) || args.thinkTimeMs < 0) {
    throw new Error('--think-time-ms must be a non-negative number.');
  }

  return args;
}

function printUsage() {
  console.log(`Usage:
  node benchmark/fault_injection.mjs [options]

Mock mode only. No provider is called; every number is simulated.

  --scenarios <list>     full,no-hedge,no-cooldown,single-route,single-provider
  --fault-rates <list>   Per-attempt fault probability, e.g. 0,0.05,0.2,0.4
  --concurrency <list>   Simultaneous users, e.g. 1,10,30
  --requests <n>         Total simulated requests per cell (default: 300)
  --think-time-ms <n>    Pause per user between requests (default: 2000)
  --questions <n>        Questions per quiz, 1-30 (default: 10)
  --fault-mix <list>     kind:weight pairs (default: 429 .45, 5xx .25, timeout .2, invalid .1)
  --fault-model <list>   Per-model fault rate, e.g. openai/gpt-oss-120b=1
  --bad-keys <list>      Permanently faulty keys, e.g. groq=1,gemini=2
  --bad-key-kind <kind>  rate_limit (default) or auth
  --model-latency <list> Per-model latency override, e.g. openai/gpt-oss-120b=14000
  --latency-file <path>  JSON: { "groq": { "medianMs": 6000, "p95Ms": 13000 } }
  --seed <n>             Seed for faults, latencies, and request order
  --out <dir>            Output directory
  --json                 Print JSON instead of tables

What is measured per cell: success rate, p50/p95 time to a successful quiz
(modeled), attempts per success, failed and cancelled attempts, hedge launches,
peak in-flight, winner distribution, and failure kinds.

Latency percentiles exclude failed requests. Simulated latency is not a
provider measurement.`);
}

function formatMs(ms) {
  if (ms === null || ms === undefined) return '-';
  return `${(ms / 1000).toFixed(1)}s`;
}

function pad(value, width) {
  return String(value).padEnd(width);
}

function printTable(cells) {
  const header = [
    pad('scenario', 16),
    pad('fault', 7),
    pad('conc', 5),
    pad('success', 8),
    pad('p50', 7),
    pad('p95', 7),
    pad('att/succ', 9),
    pad('fail', 6),
    pad('cancel', 7),
    pad('hedge', 7),
    pad('top route', 28),
    'share',
  ].join(' ');

  console.log(header);
  console.log('-'.repeat(header.length));

  for (const cell of cells) {
    const winners = Object.entries(cell.winner_distribution);
    const top = winners[0];
    console.log(
      [
        pad(cell.scenario, 16),
        pad(`${Math.round(cell.fault_rate * 100)}%`, 7),
        pad(cell.concurrency, 5),
        pad(`${(cell.success_rate * 100).toFixed(1)}%`, 8),
        pad(formatMs(cell.p50_ms), 7),
        pad(formatMs(cell.p95_ms), 7),
        pad(
          cell.attempts_per_success === null
            ? '-'
            : cell.attempts_per_success.toFixed(2),
          9,
        ),
        pad(cell.failed_attempts, 6),
        pad(cell.cancelled_attempts, 7),
        pad(cell.mean_hedges.toFixed(2), 7),
        pad(top ? top[0] : '-', 28),
        top ? `${((top[1] / Math.max(1, cell.successes)) * 100).toFixed(0)}%` : '-',
      ].join(' '),
    );
  }
}

function printWinners(cells) {
  console.log('\nWinner distribution (route that produced the accepted quiz)');
  for (const cell of cells) {
    if (cell.successes === 0) continue;
    const parts = Object.entries(cell.winner_distribution).map(
      ([model, count]) =>
        `${model} ${((count / cell.successes) * 100).toFixed(0)}%`,
    );
    console.log(
      `  ${cell.scenario} @ ${Math.round(cell.fault_rate * 100)}% / c=${cell.concurrency}: ${parts.join(', ')}`,
    );
  }
}

function writeCsv(filePath, rows, columns) {
  const lines = [columns.join(',')];
  for (const row of rows) lines.push(columns.map((key) => row[key] ?? '').join(','));
  fs.writeFileSync(filePath, `${lines.join('\n')}\n`);
}

function main() {
  let args;
  try {
    args = parseArgs(process.argv.slice(2));
  } catch (error) {
    console.error(`Error: ${error.message}`);
    process.exit(1);
  }

  const cells = runMatrix(args);

  const metadata = {
    mode: 'mock',
    synthetic: true,
    warning:
      'Simulated results. No provider was called. Faults are injected and latency is modeled. Do not report these numbers as empirical findings.',
    mirrors: 'supabase/functions/generate-quiz/index.ts',
    seed: args.seed,
    question_count: args.questionCount,
    requests_per_cell: args.requests,
    think_time_ms: args.thinkTimeMs,
    fault_mix: args.faultMix,
    model_fault_rates: args.modelFaultRates,
    bad_keys: args.badKeys,
    bad_key_kind: args.badKeyKind,
    latency_model: args.latency,
    model_latency_overrides: args.modelLatency,
    generated_at: new Date().toISOString(),
  };

  if (args.json) {
    console.log(JSON.stringify({ metadata, cells }, null, 2));
    return;
  }

  const stamp = new Date().toISOString().replace(/[:.]/g, '-');
  const outputDirectory =
    args.out ?? path.join(__dirname, 'results', 'fault_injection', stamp);
  fs.mkdirSync(outputDirectory, { recursive: true });

  const summaryPath = path.join(outputDirectory, 'summary.json');
  fs.writeFileSync(summaryPath, `${JSON.stringify({ metadata, cells }, null, 2)}\n`);
  writeCsv(path.join(outputDirectory, 'summary.csv'), cells, [
    'scenario',
    'fault_rate',
    'concurrency',
    'question_count',
    'requests',
    'successes',
    'success_rate',
    'p50_ms',
    'p95_ms',
    'mean_attempts',
    'attempts_per_success',
    'failed_attempts',
    'cancelled_attempts',
    'excess_attempts',
    'mean_hedges',
    'peak_inflight',
  ]);

  console.log('QuizForge routing fault injection (MOCK MODE)');
  console.log('Synthetic faults and modeled latency. Not provider measurements.\n');
  printTable(cells);
  printWinners(cells);
  console.log(`\nSummary: ${summaryPath}`);
  console.log(`CSV:     ${path.join(outputDirectory, 'summary.csv')}`);
}

const invokedDirectly =
  process.argv[1] && path.resolve(process.argv[1]) === path.resolve(fileURLToPath(import.meta.url));

if (invokedDirectly) {
  main();
}
