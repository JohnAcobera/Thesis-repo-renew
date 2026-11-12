import fs from 'node:fs';

export const GEMINI_ENDPOINT =
  'https://generativelanguage.googleapis.com/v1beta/models';
export const GROQ_ENDPOINT = 'https://api.groq.com/openai/v1/chat/completions';

export const GEMINI_KEY_COUNT = 5;
export const GROQ_KEY_COUNT = 3;

function isObject(value) {
  return typeof value === 'object' && value !== null && !Array.isArray(value);
}

function numberOrNull(value) {
  return typeof value === 'number' && Number.isFinite(value) ? value : null;
}

export function loadEnvFile(filePath) {
  if (!filePath || !fs.existsSync(filePath)) {
    return { loaded: false, path: filePath ?? null };
  }
  const content = fs.readFileSync(filePath, 'utf8');
  for (const rawLine of content.split(/\r?\n/)) {
    const line = rawLine.trim();
    if (!line || line.startsWith('#')) continue;
    const separator = line.indexOf('=');
    if (separator < 1) continue;
    const key = line.slice(0, separator).trim();
    let value = line.slice(separator + 1).trim();
    if (
      (value.startsWith('"') && value.endsWith('"')) ||
      (value.startsWith("'") && value.endsWith("'"))
    ) {
      value = value.slice(1, -1);
    }
    if (key && process.env[key] === undefined) {
      process.env[key] = value;
    }
  }
  return { loaded: true, path: filePath };
}

function addKey(pool, provider, secret, id) {
  if (typeof secret !== 'string') return;
  const trimmed = secret.trim();
  if (!trimmed) return;
  pool[provider].push({ id, secret: trimmed, disabledUntil: 0 });
}

// Production uses 3 Groq keys and 5 Gemini keys. Single-key names are accepted
// as a fallback so the harness is usable with a minimal setup.
export function createKeyPool(env = process.env) {
  const pool = {
    groq: [],
    gemini: [],
    cursor: { groq: 0, gemini: 0 },
  };
  for (let index = 1; index <= GROQ_KEY_COUNT; index++) {
    addKey(pool, 'groq', env[`GROQ_API_KEY_${index}`], `GROQ_API_KEY_${index}`);
  }
  for (let index = 1; index <= GEMINI_KEY_COUNT; index++) {
    addKey(
      pool,
      'gemini',
      env[`GEMINI_API_KEY_${index}`],
      `GEMINI_API_KEY_${index}`,
    );
  }
  if (pool.groq.length === 0) {
    addKey(pool, 'groq', env.GROQ_API_KEY, 'GROQ_API_KEY');
  }
  if (pool.gemini.length === 0) {
    addKey(pool, 'gemini', env.GEMINI_API_KEY, 'GEMINI_API_KEY');
  }
  return pool;
}

export function keySummary(pool) {
  return {
    groq: pool.groq.map((key) => key.id),
    gemini: pool.gemini.map((key) => key.id),
  };
}

export function takeKey(pool, provider, now = Date.now()) {
  const keys = pool[provider] ?? [];
  if (keys.length === 0) {
    return { key: null, waitMs: 0, reason: 'missing' };
  }
  const available = keys.filter((key) => key.disabledUntil <= now);
  if (available.length === 0) {
    const earliest = Math.min(...keys.map((key) => key.disabledUntil));
    return {
      key: null,
      waitMs: Math.max(1, earliest - now),
      reason: 'cooldown',
    };
  }
  const cursor = pool.cursor[provider] ?? 0;
  const key = available[cursor % available.length];
  pool.cursor[provider] = cursor + 1;
  return { key, waitMs: 0, reason: null };
}

export function coolDownKey(key, durationMs) {
  if (!key || !Number.isFinite(durationMs) || durationMs <= 0) return;
  key.disabledUntil = Math.max(key.disabledUntil, Date.now() + durationMs);
}

export function buildProviderRequest({
  route,
  prompt,
  systemMessage,
  responseSchema,
  maxOutputTokens,
  temperature,
  apiKey,
}) {
  if (route.provider === 'gemini') {
    return {
      url: `${GEMINI_ENDPOINT}/${encodeURIComponent(route.model)}:generateContent`,
      headers: {
        'Content-Type': 'application/json',
        'x-goog-api-key': apiKey,
      },
      body: JSON.stringify({
        contents: [{ role: 'user', parts: [{ text: prompt }] }],
        generationConfig: {
          responseMimeType: 'application/json',
          ...(responseSchema ? { responseSchema } : {}),
          maxOutputTokens,
          temperature,
        },
      }),
    };
  }

  const body = {
    model: route.model,
    messages: [
      { role: 'system', content: systemMessage },
      { role: 'user', content: prompt },
    ],
    response_format: { type: 'json_object' },
    max_completion_tokens: maxOutputTokens,
    temperature,
  };
  if (route.reasoningEffort) {
    body.reasoning_effort = route.reasoningEffort;
  }

  return {
    url: GROQ_ENDPOINT,
    headers: {
      'Content-Type': 'application/json',
      Authorization: `Bearer ${apiKey}`,
    },
    body: JSON.stringify(body),
  };
}

function textFromParts(parts) {
  if (!Array.isArray(parts)) return '';
  return parts
    .filter(
      (part) =>
        isObject(part) &&
        typeof part.text === 'string' &&
        part.thought !== true,
    )
    .map((part) => part.text)
    .join('\n')
    .trim();
}

// Same extraction rules as the production Edge Functions.
export function extractResponseText(provider, payload) {
  if (!isObject(payload)) return '';

  if (provider === 'gemini') {
    const candidate =
      Array.isArray(payload.candidates) && isObject(payload.candidates[0])
        ? payload.candidates[0]
        : {};
    const content = isObject(candidate.content) ? candidate.content : {};
    return textFromParts(content.parts);
  }

  const choice =
    Array.isArray(payload.choices) && isObject(payload.choices[0])
      ? payload.choices[0]
      : {};
  const message = isObject(choice.message) ? choice.message : {};

  if (typeof message.content === 'string') {
    return message.content.replace(/<think>[\s\S]*?<\/think>/gi, '').trim();
  }
  if (Array.isArray(message.content)) {
    return textFromParts(message.content);
  }
  return '';
}

export function extractUsage(provider, payload) {
  if (!isObject(payload)) {
    return { prompt: null, completion: null, total: null, reasoning: null };
  }

  if (provider === 'gemini') {
    const usage = isObject(payload.usageMetadata) ? payload.usageMetadata : {};
    const prompt = numberOrNull(usage.promptTokenCount);
    const candidates = numberOrNull(usage.candidatesTokenCount);
    const thoughts = numberOrNull(usage.thoughtsTokenCount);
    const completion =
      candidates === null && thoughts === null
        ? null
        : (candidates ?? 0) + (thoughts ?? 0);
    const total =
      numberOrNull(usage.totalTokenCount) ??
      (prompt !== null && completion !== null ? prompt + completion : null);
    return { prompt, completion, total, reasoning: thoughts };
  }

  const usage = isObject(payload.usage) ? payload.usage : {};
  const details = isObject(usage.completion_tokens_details)
    ? usage.completion_tokens_details
    : {};
  return {
    prompt: numberOrNull(usage.prompt_tokens),
    completion: numberOrNull(usage.completion_tokens),
    total: numberOrNull(usage.total_tokens),
    reasoning: numberOrNull(details.reasoning_tokens),
  };
}

export function extractProviderError(payload) {
  if (!isObject(payload)) return null;
  if (
    isObject(payload.error) &&
    typeof payload.error.message === 'string' &&
    payload.error.message.trim()
  ) {
    return payload.error.message.replace(/\s+/g, ' ').trim().slice(0, 500);
  }
  if (typeof payload.message === 'string' && payload.message.trim()) {
    return payload.message.replace(/\s+/g, ' ').trim().slice(0, 500);
  }
  return null;
}

export function classifyStatus(status) {
  if (status === 429) return 'rate_limit';
  if (status === 401 || status === 403) return 'auth';
  if (status === 404) return 'not_found';
  if (status === 408 || status === 409 || status >= 500) return 'overload';
  return 'bad_request';
}

export function isRetryableKind(kind) {
  return (
    kind === 'rate_limit' ||
    kind === 'overload' ||
    kind === 'network' ||
    kind === 'timeout'
  );
}

export function retryAfterMs(response) {
  const raw = response?.headers?.get?.('retry-after')?.trim();
  if (!raw) return null;
  const seconds = Number(raw);
  if (Number.isFinite(seconds) && seconds >= 0) {
    return Math.ceil(seconds * 1000);
  }
  const timestamp = Date.parse(raw);
  if (!Number.isNaN(timestamp)) {
    return Math.max(0, timestamp - Date.now());
  }
  return null;
}

// Mirrors attemptTimeoutMs() in the Edge Functions.
export function productionTimeoutMs(questionCount) {
  if (questionCount <= 10) return 15_000;
  if (questionCount <= 20) return 22_000;
  return 30_000;
}

export async function invokeModel({
  route,
  request,
  timeoutMs,
  fetchImpl = fetch,
}) {
  if (!Number.isFinite(timeoutMs) || timeoutMs <= 0) {
    throw new Error('timeoutMs must be a positive number.');
  }

  const startedAt = Date.now();
  let response;
  try {
    response = await fetchImpl(request.url, {
      method: 'POST',
      headers: request.headers,
      body: request.body,
      signal: AbortSignal.timeout(timeoutMs),
    });
  } catch (error) {
    const latencyMs = Date.now() - startedAt;
    const isTimeout =
      error?.name === 'TimeoutError' || error?.name === 'AbortError';
    return {
      ok: false,
      kind: isTimeout ? 'timeout' : 'network',
      status: null,
      latencyMs,
      error: error instanceof Error ? error.message : String(error),
      retryAfterMs: null,
      usage: { prompt: null, completion: null, total: null, reasoning: null },
      text: '',
      payload: null,
    };
  }

  let rawBody = '';
  try {
    rawBody = await response.text();
  } catch (error) {
    return {
      ok: false,
      kind: 'network',
      status: response.status,
      latencyMs: Date.now() - startedAt,
      error: error instanceof Error ? error.message : String(error),
      retryAfterMs: null,
      usage: { prompt: null, completion: null, total: null, reasoning: null },
      text: '',
      payload: null,
    };
  }

  const latencyMs = Date.now() - startedAt;
  let payload = null;
  try {
    payload = rawBody ? JSON.parse(rawBody) : null;
  } catch {
    payload = null;
  }

  if (!response.ok) {
    return {
      ok: false,
      kind: classifyStatus(response.status),
      status: response.status,
      latencyMs,
      error:
        extractProviderError(payload) ??
        (rawBody.trim().slice(0, 500) || `HTTP ${response.status}`),
      retryAfterMs: retryAfterMs(response),
      usage: null,
      text: '',
      payload,
    };
  }

  const text = extractResponseText(route.provider, payload);
  const usage = extractUsage(route.provider, payload);
  if (!text) {
    return {
      ok: false,
      kind: 'invalid_output',
      status: response.status,
      latencyMs,
      error: 'The provider returned no generated text.',
      retryAfterMs: null,
      usage,
      text: '',
      payload,
    };
  }

  return {
    ok: true,
    kind: null,
    status: response.status,
    latencyMs,
    error: null,
    retryAfterMs: null,
    usage,
    text,
    payload,
  };
}
