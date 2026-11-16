#!/usr/bin/env node
import assert from 'node:assert/strict';
import fs from 'node:fs';
import path from 'node:path';
import { fileURLToPath } from 'node:url';

import {
  CASCADE_CONSTANTS,
  MODEL_ROUTES,
  simulate,
} from './fault_injection.mjs';

const benchmarkDir = path.dirname(fileURLToPath(import.meta.url));

const tests = [];
function test(name, fn) {
  tests.push({ name, fn });
}

function readProductionSource() {
  const file = path.join(
    benchmarkDir,
    '..',
    'supabase',
    'functions',
    'generate-quiz',
    'index.ts',
  );
  return fs.readFileSync(file, 'utf8');
}

function productionNumber(source, name) {
  const match = source.match(
    new RegExp(`const\\s+${name}\\s*=\\s*([^;]+);`),
  );
  assert.ok(match, `production constant ${name} not found`);
  return Number(new Function(`return (${match[1].replaceAll('_', '')})`)());
}

function shareOf(cell, model) {
  return (cell.winner_distribution[model] ?? 0) / Math.max(1, cell.successes);
}

// Mirrored constants ---------------------------------------------------------

test('cascade constants mirror the production Edge Function', () => {
  const source = readProductionSource();
  const names = Object.keys(CASCADE_CONSTANTS);

  for (const name of names) {
    assert.equal(
      CASCADE_CONSTANTS[name],
      productionNumber(source, name),
      `${name} drifted from production`,
    );
  }
});

test('routes mirror the five production priorities', () => {
  assert.equal(MODEL_ROUTES.length, 5);
  assert.deepEqual(
    MODEL_ROUTES.map((route) => route.priority),
    [1, 2, 3, 4, 5],
  );
  assert.equal(MODEL_ROUTES[0].model, 'openai/gpt-oss-120b');
  assert.equal(MODEL_ROUTES[4].provider, 'gemini');
});

// Behaviour ------------------------------------------------------------------

test('without faults the primary route serves almost every request', () => {
  const cell = simulate({ requests: 200, faultRate: 0 });

  assert.equal(cell.success_rate, 1);
  assert.ok(shareOf(cell, 'openai/gpt-oss-120b') > 0.9, 'primary share too low');
  assert.ok(cell.mean_hedges < 0.6, 'hedging should be occasional at 6s median');
});

test('a total provider outage yields no quiz', () => {
  const cell = simulate({ requests: 100, faultRate: 1 });

  assert.equal(cell.success_rate, 0);
  assert.equal(cell.successes, 0);
  assert.equal(cell.attempts_per_success, null);
});

test('losing the primary route still produces quizzes', () => {
  const cell = simulate({
    requests: 150,
    faultRate: 0,
    modelFaultRates: { 'openai/gpt-oss-120b': 1 },
  });

  assert.equal(cell.success_rate, 1);
  assert.equal(shareOf(cell, 'openai/gpt-oss-120b'), 0);
  assert.ok(shareOf(cell, 'openai/gpt-oss-20b') > 0.5);
});

test('a single-route deployment cannot fail over', () => {
  const cell = simulate({
    scenario: 'single-route',
    requests: 150,
    faultRate: 0,
    modelFaultRates: { 'openai/gpt-oss-120b': 1 },
  });

  assert.equal(cell.success_rate, 0);
  assert.equal(cell.mean_hedges, 0);
});

test('attempt accounting adds up', () => {
  const cell = simulate({ requests: 150, faultRate: 0.3 });

  assert.equal(
    cell.successes + cell.failed_attempts + cell.cancelled_attempts,
    cell.attempts,
  );
  assert.equal(cell.excess_attempts, cell.attempts - cell.successes);
});

test('closed-loop load never exceeds two attempts per user', () => {
  for (const concurrency of [1, 10, 30]) {
    const cell = simulate({ requests: 200, concurrency, faultRate: 0.2 });
    assert.ok(
      cell.peak_inflight <= concurrency * 2,
      `peak ${cell.peak_inflight} exceeded 2 x ${concurrency}`,
    );
  }
});

test('the in-flight gate suppresses hedging under load', () => {
  const idle = simulate({ requests: 200, concurrency: 1, faultRate: 0.2 });
  const busy = simulate({ requests: 200, concurrency: 30, faultRate: 0.2 });

  assert.ok(
    busy.mean_hedges < idle.mean_hedges,
    `expected fewer hedges under load (${busy.mean_hedges} vs ${idle.mean_hedges})`,
  );
});

// Documents an actual property of the production planner: while the primary
// model still has an untried key, the hedge goes to that key, not to a
// different (possibly faster) model. Hedging therefore absorbs a bad key or
// spreads quota, but cannot rescue a uniformly slow model.
test('hedging races a second key of the same model', () => {
  const latency = {
    'openai/gpt-oss-120b': { medianMs: 12_000, p95Ms: 14_000 },
    'openai/gpt-oss-20b': { medianMs: 3_000, p95Ms: 5_000 },
    'qwen/qwen3.8-27b': { medianMs: 3_000, p95Ms: 5_000 },
  };

  const full = simulate({ requests: 200, faultRate: 0, modelLatency: latency });
  const noHedge = simulate({
    scenario: 'no-hedge',
    requests: 200,
    faultRate: 0,
    modelLatency: latency,
  });

  assert.equal(full.success_rate, 1);
  assert.ok(full.mean_hedges > 0.3, 'slow primary should trigger hedges');
  assert.ok(
    Math.abs(full.p50_ms - noHedge.p50_ms) < 50,
    `hedged p50 ${full.p50_ms}ms should match unhedged ${noHedge.p50_ms}ms`,
  );
  assert.ok(
    full.excess_attempts > noHedge.excess_attempts,
    'hedging should duplicate work',
  );
});

// Cooldowns only pay off when a failure is persistent per key, which is how
// real quota and revoked-key failures behave.
test('cooldowns avoid retrying a permanently throttled key', () => {
  const options = {
    requests: 300,
    faultRate: 0,
    badKeys: { groq: 1 },
    badKeyKind: 'rate_limit',
  };

  const full = simulate(options);
  const noCooldown = simulate({ ...options, scenario: 'no-cooldown' });

  assert.equal(full.success_rate, 1);
  assert.equal(noCooldown.success_rate, 1);
  assert.ok(
    full.attempts_per_success < noCooldown.attempts_per_success,
    `cooldowns should save attempts (${full.attempts_per_success} vs ${noCooldown.attempts_per_success})`,
  );
});

test('runs are reproducible for a fixed seed', () => {
  const options = { requests: 120, faultRate: 0.25, concurrency: 4 };
  const first = simulate({ ...options, seed: 7 });
  const second = simulate({ ...options, seed: 7 });
  const different = simulate({ ...options, seed: 8 });

  assert.deepEqual(first, second);
  assert.notDeepEqual(first, different);
});

test('per-model fault rates override the global rate', () => {
  const cell = simulate({
    requests: 120,
    faultRate: 0,
    modelFaultRates: { 'gemini-3.1-flash-lite': 1 },
  });

  assert.equal(cell.success_rate, 1);
  assert.equal(shareOf(cell, 'gemini-3.1-flash-lite'), 0);
});

// Runner ---------------------------------------------------------------------

let failed = 0;
for (const { name, fn } of tests) {
  try {
    fn();
    console.log(`ok   ${name}`);
  } catch (error) {
    failed++;
    console.error(`FAIL ${name}`);
    console.error(error instanceof Error ? error.stack : error);
  }
}

console.log(`\n${tests.length - failed}/${tests.length} tests passed.`);
if (failed > 0) process.exitCode = 1;
