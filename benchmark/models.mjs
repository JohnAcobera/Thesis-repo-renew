// Mirrors MODEL_ROUTES in supabase/functions/generate-quiz/index.ts.
// Keep this list in sync with the Edge Functions if the production order changes.

export const MODEL_ROUTES = [
  {
    provider: 'groq',
    model: 'openai/gpt-oss-120b',
    priority: 1,
    reasoningEffort: 'low',
  },
  {
    provider: 'groq',
    model: 'openai/gpt-oss-20b',
    priority: 2,
    reasoningEffort: 'low',
  },
  { provider: 'groq', model: 'qwen/qwen3.8-27b', priority: 3 },
  { provider: 'gemini', model: 'gemini-3.5-flash-lite', priority: 4 },
  { provider: 'gemini', model: 'gemini-3.1-flash-lite', priority: 5 },
];

const ALIASES = new Map([
  ['gpt-oss-120b', 'openai/gpt-oss-120b'],
  ['gpt-120b', 'openai/gpt-oss-120b'],
  ['120b', 'openai/gpt-oss-120b'],
  ['gpt-oss-20b', 'openai/gpt-oss-20b'],
  ['gpt-20b', 'openai/gpt-oss-20b'],
  ['20b', 'openai/gpt-oss-20b'],
  ['qwen', 'qwen/qwen3.8-27b'],
  ['qwen3.8', 'qwen/qwen3.8-27b'],
  ['gemini-3.5', 'gemini-3.5-flash-lite'],
  ['gemini-35', 'gemini-3.5-flash-lite'],
  ['gemini-3.1', 'gemini-3.1-flash-lite'],
  ['gemini-31', 'gemini-3.1-flash-lite'],
]);

export function routeForModel(modelId) {
  const normalized = ALIASES.get(modelId.toLowerCase()) ?? modelId;
  return (
    MODEL_ROUTES.find(
      (route) => route.model.toLowerCase() === normalized.toLowerCase(),
    ) ?? null
  );
}

export function resolveModels(selection = 'all') {
  const tokens = selection
    .split(',')
    .map((token) => token.trim())
    .filter(Boolean);
  if (tokens.length === 1 && tokens[0].toLowerCase() === 'all') {
    return [...MODEL_ROUTES];
  }
  if (tokens.length === 0) {
    throw new Error('No models selected. Use --models all or a comma-separated list.');
  }

  const selected = [];
  for (const token of tokens) {
    const route = routeForModel(token);
    if (!route) {
      throw new Error(`Unknown model "${token}". Run with --list-models.`);
    }
    if (!selected.some((item) => item.model === route.model)) {
      selected.push(route);
    }
  }
  return selected;
}

// Judge models may be one of the five routes or an explicit provider:model
// pair, e.g. gemini:gemini-3.1-pro-preview or groq:openai/gpt-oss-120b.
export function parseJudgeModel(value) {
  if (!value) return null;
  const known = routeForModel(value);
  if (known) return { ...known, priority: 99, isJudge: true };

  const separator = value.indexOf(':');
  if (separator < 1) {
    throw new Error(
      `Unknown judge model "${value}". Use provider:model, e.g. gemini:gemini-3.1-pro-preview.`,
    );
  }
  const provider = value.slice(0, separator).trim().toLowerCase();
  const model = value.slice(separator + 1).trim();
  if (provider !== 'groq' && provider !== 'gemini') {
    throw new Error(`Judge provider must be "groq" or "gemini", got "${provider}".`);
  }
  if (!model) {
    throw new Error('The judge model name is empty.');
  }
  return {
    provider,
    model,
    priority: 99,
    isJudge: true,
    reasoningEffort:
      provider === 'groq' && model.toLowerCase().includes('gpt-oss')
        ? 'low'
        : undefined,
  };
}

export function modelSlug(route) {
  return `${route.provider}-${route.model.replace(/[^a-zA-Z0-9]+/g, '-')}`.replace(
    /-+$/,
    '',
  );
}
