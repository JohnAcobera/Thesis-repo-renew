#!/usr/bin/env node
import fs from 'node:fs';
import path from 'node:path';
import { fileURLToPath } from 'node:url';
import { execFileSync } from 'node:child_process';

import {
  MODEL_ROUTES,
  modelSlug,
  parseJudgeModel,
  resolveModels,
} from './models.mjs';
import {
  JUDGE_RESPONSE_SCHEMA,
  MAX_OUTPUT_TOKENS,
  PROMPT_VERSION,
  QUIZ_RESPONSE_SCHEMA,
  TASKS,
  TEMPERATURE,
  buildJudgePrompt,
  buildQuizPrompt,
  promptFingerprint,
  systemMessageFor,
  trueFalseCount,
} from './prompts.mjs';
import {
  computeQualityMetrics,
  emptyQualityMetrics,
  judgeAgreement,
  validateJudgeResponse,
  validateQuiz,
} from './metrics.mjs';
import {
  buildProviderRequest,
  coolDownKey,
  createKeyPool,
  invokeModel,
  isRetryableKind,
  keySummary,
  loadEnvFile,
  productionTimeoutMs,
  takeKey,
} from './providers.mjs';

const __dirname = path.dirname(fileURLToPath(import.meta.url));
const HARNESS_VERSION = 1;
const DEFAULT_SEED = 20261102;
const MAX_SOURCE_TEXT_CHARS = 100_000;

const RATING_RUBRIC = `QuizForge human rating rubric

Use the source document listed for each row. Rate every question independently
on four 1-5 scales. Do not open review_key.csv until all ratings are complete,
so the ratings stay blinded to the model.

Correctness
1 = the marked answer is wrong, contradicts the source, or no option is defensible.
2 = the marked answer is questionable; another option is at least as plausible.
3 = the marked answer is acceptable, but the question is ambiguous or partly unsupported.
4 = the marked answer is correct and defensible from the source.
5 = the marked answer is unambiguously correct and exactly one answer is defensible.

Grounding
1 = the question or answer introduces facts that are not in the source.
2 = mostly unsupported; significant invented detail.
3 = partly supported; some details are not in the source.
4 = supported by the source with minor paraphrase.
5 = directly and fully supported by the source.

Clarity
1 = confusing, ungrammatical, or unanswerable as written.
2 = hard to follow; ambiguous wording.
3 = understandable but could be clearer.
4 = clear and well written.
5 = precise, concise, and unambiguous.

Distractor quality (for True/False, rate the plausibility of the false statement)
1 = trivially wrong, duplicated, or unrelated options.
2 = weak distractors; the answer is obvious by elimination.
3 = acceptable but uneven.
4 = plausible, distinct, and in the same category.
5 = strong plausible distractors that test the same concept without trick wording.

Notes: record any factual error, ambiguity, or source mismatch. Use at least two
independent raters and report mean scores plus inter-rater agreement (for example,
ICC or Krippendorff's alpha).`;

let stopping = false;

function isPlainObject(value) {
  return typeof value === 'object' && value !== null && !Array.isArray(value);
}

function round(value, digits = 4) {
  if (typeof value !== 'number' || !Number.isFinite(value)) return null;
  const factor = 10 ** digits;
  return Math.round(value * factor) / factor;
}

function mean(values) {
  const numbers = values.filter(
    (value) => typeof value === 'number' && Number.isFinite(value),
  );
  if (numbers.length === 0) return null;
  return numbers.reduce((sum, value) => sum + value, 0) / numbers.length;
}

function meanOf(records, key, digits = 4) {
  return round(mean(records.map((record) => record[key])), digits);
}

function percentile(values, quantile) {
  const numbers = values
    .filter((value) => typeof value === 'number' && Number.isFinite(value))
    .sort((left, right) => left - right);
  if (numbers.length === 0) return null;
  const position = (numbers.length - 1) * quantile;
  const lower = Math.floor(position);
  const upper = Math.ceil(position);
  if (lower === upper) return round(numbers[lower], 1);
  const weight = position - lower;
  return round(
    numbers[lower] * (1 - weight) + numbers[upper] * weight,
    1,
  );
}

function percent(numerator, denominator) {
  return denominator === 0 ? null : round((numerator / denominator) * 100, 2);
}

function sum(values) {
  return values.reduce((total, value) => total + value, 0);
}

function sleep(ms) {
  return new Promise((resolve) => setTimeout(resolve, ms));
}

function hashString(text) {
  let hash = 2166136261;
  for (let index = 0; index < text.length; index++) {
    hash ^= text.charCodeAt(index);
    hash = Math.imul(hash, 16777619);
  }
  return hash >>> 0;
}

function mulberry32(seed) {
  let state = seed >>> 0;
  return () => {
    state |= 0;
    state = (state + 0x6d2b79f5) | 0;
    let value = Math.imul(state ^ (state >>> 15), 1 | state);
    value = (value + Math.imul(value ^ (value >>> 7), 61 | value)) ^ value;
    return ((value ^ (value >>> 14)) >>> 0) / 4294967296;
  };
}

function shuffleInPlace(items, seed) {
  const random = mulberry32(seed);
  for (let index = items.length - 1; index > 0; index--) {
    const swapIndex = Math.floor(random() * (index + 1));
    [items[index], items[swapIndex]] = [items[swapIndex], items[index]];
  }
  return items;
}

function timestampForPath() {
  return new Date().toISOString().replace(/[:.]/g, '-');
}

function gitCommit() {
  try {
    return execFileSync('git', ['rev-parse', 'HEAD'], {
      cwd: path.join(__dirname, '..'),
      encoding: 'utf8',
      stdio: ['ignore', 'pipe', 'ignore'],
    }).trim();
  } catch {
    return null;
  }
}

// ---------------------------------------------------------------------------
// CLI
// ---------------------------------------------------------------------------

function defaultArgs() {
  return {
    dataset: path.join(__dirname, 'dataset', 'manifest.json'),
    task: 'mcq',
    models: 'all',
    runs: 3,
    questionCount: 10,
    out: null,
    seed: DEFAULT_SEED,
    timeoutMs: 60_000,
    maxRetries: 3,
    envFile: path.join(__dirname, '.env'),
    pricing: path.join(__dirname, 'pricing.json'),
    judgeModel: null,
    reviewSamples: 2,
    humanReview: true,
    maxRequests: 0,
    maxSourceChars: MAX_SOURCE_TEXT_CHARS,
    mock: false,
    dryRun: false,
    yes: false,
    resume: false,
    force: false,
    help: false,
    listModels: false,
  };
}

const VALUE_FLAGS = new Map([
  ['--dataset', 'dataset'],
  ['--task', 'task'],
  ['--models', 'models'],
  ['--runs', 'runs'],
  ['--question-count', 'questionCount'],
  ['--out', 'out'],
  ['--seed', 'seed'],
  ['--timeout-ms', 'timeoutMs'],
  ['--max-retries', 'maxRetries'],
  ['--env-file', 'envFile'],
  ['--pricing', 'pricing'],
  ['--judge-model', 'judgeModel'],
  ['--review-samples', 'reviewSamples'],
  ['--max-requests', 'maxRequests'],
  ['--max-source-chars', 'maxSourceChars'],
]);

const INTEGER_FLAGS = new Set([
  'runs',
  'questionCount',
  'seed',
  'timeoutMs',
  'maxRetries',
  'reviewSamples',
  'maxRequests',
  'maxSourceChars',
]);

function parseArgs(argv) {
  const args = defaultArgs();
  for (let index = 0; index < argv.length; index++) {
    const argument = argv[index];
    if (argument === '--help' || argument === '-h') {
      args.help = true;
      continue;
    }
    if (argument === '--dry-run') {
      args.dryRun = true;
      continue;
    }
    if (argument === '--yes') {
      args.yes = true;
      continue;
    }
    if (argument === '--mock') {
      args.mock = true;
      continue;
    }
    if (argument === '--resume') {
      args.resume = true;
      continue;
    }
    if (argument === '--force') {
      args.force = true;
      continue;
    }
    if (argument === '--no-human-review') {
      args.humanReview = false;
      continue;
    }
    if (argument === '--list-models') {
      args.listModels = true;
      continue;
    }
    if (VALUE_FLAGS.has(argument)) {
      const value = argv[++index];
      if (value === undefined) {
        throw new Error(`${argument} needs a value.`);
      }
      const key = VALUE_FLAGS.get(argument);
      if (INTEGER_FLAGS.has(key)) {
        const parsed = Number(value);
        if (!Number.isInteger(parsed)) {
          throw new Error(`${argument} must be an integer, got "${value}".`);
        }
        args[key] = parsed;
      } else {
        args[key] = value;
      }
      continue;
    }
    throw new Error(`Unknown argument "${argument}". Use --help.`);
  }
  validateArgs(args);
  return args;
}

function validateArgs(args) {
  if (args.help || args.listModels) return;
  if (args.task !== 'all' && !TASKS.includes(args.task)) {
    throw new Error(`--task must be one of ${TASKS.join(', ')}, or all.`);
  }
  if (args.runs < 1) throw new Error('--runs must be at least 1.');
  if (args.questionCount < 1 || args.questionCount > 30) {
    throw new Error('--question-count must be between 1 and 30.');
  }
  if (args.timeoutMs < 1_000) {
    throw new Error('--timeout-ms must be at least 1000.');
  }
  if (args.maxRetries < 0 || args.maxRetries > 10) {
    throw new Error('--max-retries must be between 0 and 10.');
  }
  if (args.seed < 0) throw new Error('--seed must not be negative.');
  if (args.reviewSamples < 0) {
    throw new Error('--review-samples must not be negative.');
  }
  if (args.maxRequests < 0) {
    throw new Error('--max-requests must not be negative.');
  }
  if (args.maxSourceChars < 1 || args.maxSourceChars > MAX_SOURCE_TEXT_CHARS) {
    throw new Error(
      `--max-source-chars must be between 1 and ${MAX_SOURCE_TEXT_CHARS}.`,
    );
  }
}

function printHelp() {
  console.log(`QuizForge quiz-generation benchmark

Usage:
  node benchmark/run_quiz_benchmark.mjs [options]

Required safety flag:
  --yes                  Confirm live API calls. Live runs may incur provider charges.
                         Without --yes the harness prints the plan and exits.

Selection:
  --dataset <path>       Dataset manifest (default: benchmark/dataset/manifest.json)
  --task <name>          mcq | true_false | mixed | all (default: mcq)
  --models <list>        all, or comma-separated model aliases/IDs (default: all)
  --runs <n>             Repetitions per model × document × task (default: 3)
  --question-count <n>   Questions per quiz, 1-30 (default: 10)
  --judge-model <m>      Optional answerability judge. Use a routed model alias, or
                         provider:model (e.g. gemini:gemini-3.1-pro-preview).
  --seed <n>             Seed for the interleaved job order and review sampling.

Runtime:
  --timeout-ms <n>       Per-attempt timeout (default: 60000)
  --max-retries <n>      Retries for transport, rate-limit, and server errors (default: 3)
  --max-requests <n>     Abort if the worst-case request count, including retries,
                         exceeds n (0 = unlimited)
  --env-file <path>      Key file (default: benchmark/.env; see benchmark/.env.example)
  --pricing <path>       Cost table (default: benchmark/pricing.json)
  --out <dir>            Output directory (default: benchmark/results/<timestamp>)
  --resume               Skip job IDs already present in runs.jsonl
  --force                Allow writing into a non-empty output directory
  --no-human-review      Skip the blinded review sheet and key export

Other:
  --mock                 Validate the pipeline without network calls. Results are fake.
  --dry-run              Validate inputs and print the plan without calling APIs.
  --list-models          Print the five routed models and exit.
  -h, --help             Print this help.

What is measured:
  Per model and task: HTTP success, production-eligible success, first-attempt
  success, retried runs, schema validity, exact question count, p50/p95 latency,
  production timeout pass rate, tokens, cost (when pricing is configured),
  duplicate/near-duplicate rate, answer-position balance, lexical grounding to the
  source, source vocabulary coverage, and optional judge answerability agreement.

  Grounding is a lexical proxy, not factual verification. The harness also writes
  human_review.csv (blinded, one row per question), review_key.csv (do not open
  while rating), and rating_rubric.txt for the pedagogical quality ratings.

Experimental controls:
  * Calls the five production model routes directly, not through the Edge Function
    router, so fallback/hedging do not confound model quality.
  * Uses the exact production prompt, JSON schema, temperature 0.4, and 16,384
    max output tokens.
  * Runs sequentially and interleaves models over time using the seed.
  * Retries transport/rate-limit/server errors, but records invalid JSON/schema as
    a model failure rather than retrying it.
  * A separate fault-injection/load test is needed to validate router fallback and
    hedging behavior.

Examples:
  node benchmark/run_quiz_benchmark.mjs --dry-run
  node benchmark/run_quiz_benchmark.mjs --mock --yes --task all --runs 1 --question-count 5
  node benchmark/run_quiz_benchmark.mjs --task mcq --runs 3 --yes
  node benchmark/run_quiz_benchmark.mjs --task all --runs 5 --judge-model gemini:gemini-3.1-pro-preview --yes

Dataset manifest:
  {
    "name": "my-corpus",
    "documents": [
      {
        "id": "photosynthesis",
        "title": "Photosynthesis",
        "file": "sources/photosynthesis.txt",
        "sourceFileName": "photosynthesis.txt",
        "questionCount": 10
      }
    ]
  }
  Paths are relative to the manifest. questionCount is optional and defaults to
  --question-count. Each source must be 100,000 characters or less, matching the
  production Edge Function limit.`);
}

function printModels() {
  console.log('Routed models (priority order):\n');
  for (const route of MODEL_ROUTES) {
    const effort = route.reasoningEffort
      ? ` reasoning_effort=${route.reasoningEffort}`
      : '';
    console.log(
      `  ${route.priority}. ${route.provider.padEnd(6)} ${route.model}${effort}`,
    );
  }
  console.log('\nAliases: gpt-120b, gpt-20b, qwen, gemini-3.5, gemini-3.1');
}

// ---------------------------------------------------------------------------
// Inputs
// ---------------------------------------------------------------------------

function loadDataset(manifestPath, maxSourceChars, defaultQuestionCount) {
  const absolutePath = path.resolve(manifestPath);
  if (!fs.existsSync(absolutePath)) {
    throw new Error(`Dataset manifest not found: ${absolutePath}`);
  }
  let manifest;
  try {
    manifest = JSON.parse(fs.readFileSync(absolutePath, 'utf8'));
  } catch (error) {
    throw new Error(
      `Dataset manifest is not valid JSON: ${error instanceof Error ? error.message : error}`,
    );
  }
  if (
    !isPlainObject(manifest) ||
    !Array.isArray(manifest.documents) ||
    manifest.documents.length === 0
  ) {
    throw new Error(
      'Dataset manifest must contain a non-empty "documents" array.',
    );
  }

  const baseDirectory = path.dirname(absolutePath);
  const seenIds = new Set();
  const documents = manifest.documents.map((document, index) => {
    if (!isPlainObject(document)) {
      throw new Error(`Document ${index} must be an object.`);
    }
    const id = typeof document.id === 'string' ? document.id.trim() : '';
    if (!id) throw new Error(`Document ${index} needs a non-empty "id".`);
    if (seenIds.has(id)) throw new Error(`Duplicate document id "${id}".`);
    seenIds.add(id);

    const file = typeof document.file === 'string' ? document.file.trim() : '';
    if (!file) throw new Error(`Document "${id}" needs a "file".`);
    const sourcePath = path.resolve(baseDirectory, file);
    if (!fs.existsSync(sourcePath)) {
      throw new Error(`Source file not found for "${id}": ${sourcePath}`);
    }
    const sourceText = fs.readFileSync(sourcePath, 'utf8');
    if (!sourceText.trim()) {
      throw new Error(`Source file for "${id}" is empty.`);
    }
    if (sourceText.length > maxSourceChars) {
      throw new Error(
        `Source file for "${id}" is ${sourceText.length} characters; the limit is ${maxSourceChars}.`,
      );
    }

    const questionCount = document.questionCount ?? defaultQuestionCount;
    if (
      !Number.isInteger(questionCount) ||
      questionCount < 1 ||
      questionCount > 30
    ) {
      throw new Error(
        `Document "${id}" questionCount must be an integer from 1 to 30.`,
      );
    }

    const sourceFileName =
      typeof document.sourceFileName === 'string' &&
      document.sourceFileName.trim()
        ? document.sourceFileName.trim()
        : path.basename(sourcePath);
    if (sourceFileName.length > 200) {
      throw new Error(`Document "${id}" sourceFileName exceeds 200 characters.`);
    }

    return {
      id,
      title:
        typeof document.title === 'string' && document.title.trim()
          ? document.title.trim()
          : id,
      sourcePath,
      sourceFileName,
      sourceText,
      questionCount,
    };
  });

  return { manifest, manifestPath: absolutePath, documents };
}

function loadPricing(filePath) {
  if (!filePath || !fs.existsSync(filePath)) return null;
  try {
    const parsed = JSON.parse(fs.readFileSync(filePath, 'utf8'));
    if (!isPlainObject(parsed) || !isPlainObject(parsed.models)) return null;
    return parsed;
  } catch {
    return null;
  }
}

function pricingConfigured(pricing) {
  if (!pricing) return false;
  return Object.values(pricing.models).some(
    (price) =>
      isPlainObject(price) &&
      typeof price.inputPerMillionUsd === 'number' &&
      typeof price.outputPerMillionUsd === 'number',
  );
}

export function computeCost(usage, pricing, modelId) {
  if (!usage || !pricing?.models?.[modelId]) return null;
  const price = pricing.models[modelId];
  if (
    typeof price.inputPerMillionUsd !== 'number' ||
    typeof price.outputPerMillionUsd !== 'number'
  ) {
    return null;
  }
  if (
    typeof usage.prompt !== 'number' ||
    typeof usage.completion !== 'number'
  ) {
    return null;
  }
  return (
    (usage.prompt * price.inputPerMillionUsd +
      usage.completion * price.outputPerMillionUsd) /
    1_000_000
  );
}

function buildJobs({ tasks, documents, routes, runs, seed }) {
  const jobs = [];
  for (const task of tasks) {
    for (const document of documents) {
      for (const route of routes) {
        for (let runIndex = 0; runIndex < runs; runIndex++) {
          jobs.push({
            id: `${task}__${document.id}__q${document.questionCount}__${modelSlug(route)}__r${runIndex}`,
            task,
            document,
            route,
            runIndex,
          });
        }
      }
    }
  }
  return shuffleInPlace(jobs, seed);
}

function prepareOutputDir(args, outputDirectory) {
  if (fs.existsSync(outputDirectory)) {
    const entries = fs.readdirSync(outputDirectory);
    if (entries.length > 0 && !args.resume && !args.force) {
      throw new Error(
        `Output directory is not empty: ${outputDirectory}. Use --resume or --force.`,
      );
    }
  }
  fs.mkdirSync(outputDirectory, { recursive: true });
  return outputDirectory;
}

function readExistingRecords(runsPath) {
  if (!fs.existsSync(runsPath)) return [];
  const records = [];
  const lines = fs.readFileSync(runsPath, 'utf8').split(/\r?\n/);
  for (const line of lines) {
    if (!line.trim()) continue;
    try {
      records.push(JSON.parse(line));
    } catch {
      console.warn('Warning: skipping a malformed line in runs.jsonl.');
    }
  }
  return records;
}

// ---------------------------------------------------------------------------
// Mock mode
// ---------------------------------------------------------------------------

function mockInvoke({ job, prompt }) {
  const { task, document, runIndex } = job;
  const { questionCount } = document;
  const trueFalse = task === 'mixed' ? trueFalseCount(questionCount) : 0;
  const sourceWords = document.sourceText
    .replace(/\s+/g, ' ')
    .trim()
    .split(' ');
  const questions = [];

  for (let index = 0; index < questionCount; index++) {
    const isTrueFalse =
      task === 'true_false' || (task === 'mixed' && index < trueFalse);
    const anchor =
      sourceWords[
        (index * 7 + runIndex * 3 + hashString(job.id)) %
          Math.max(1, sourceWords.length)
      ] ?? 'material';
    const options = isTrueFalse
      ? ['True', 'False']
      : ['Option A', 'Option B', 'Option C', 'Option D'];
    const answerIndex = isTrueFalse ? index % 2 : index % 4;
    questions.push({
      question: `Mock ${isTrueFalse ? 'true-or-false' : 'multiple-choice'} question ${index + 1} about ${anchor}?`,
      options,
      answerIndex,
      explanation: `Mock explanation grounded in the source text for ${anchor}.`,
    });
  }

  if (task === 'mixed') {
    shuffleInPlace(questions, hashString(job.id));
  }

  const text = JSON.stringify({ questions });
  const promptTokens = Math.max(1, Math.round(prompt.length / 4));
  const completionTokens = Math.max(1, Math.round(text.length / 4));
  return {
    ok: true,
    kind: null,
    status: 200,
    latencyMs: 300 + (hashString(job.id) % 1_200),
    error: null,
    retryAfterMs: null,
    usage: {
      prompt: promptTokens,
      completion: completionTokens,
      total: promptTokens + completionTokens,
      reasoning: null,
    },
    text,
    payload: null,
  };
}

// ---------------------------------------------------------------------------
// One job
// ---------------------------------------------------------------------------

async function runJob({
  job,
  args,
  pool,
  judgePool,
  judgeRoute,
  pricing,
}) {
  const { route, document, task, runIndex } = job;
  const startedAt = new Date().toISOString();
  const jobStarted = Date.now();
  const prompt = buildQuizPrompt({
    task,
    questionCount: document.questionCount,
    sourceFileName: document.sourceFileName,
    sourceText: document.sourceText,
  });
  const fingerprint = promptFingerprint();

  let final = null;
  let attempts = 0;
  let providerRequests = 0;
  let keyId = '';
  let retries = 0;

  if (args.mock) {
    final = mockInvoke({ job, prompt });
    providerRequests = 1;
  } else {
    const maxAttempts = args.maxRetries + 1;
    let retryDelay = 1_000;

    while (attempts < maxAttempts) {
      if (stopping) {
        final = {
          ok: false,
          kind: 'cancelled',
          status: null,
          latencyMs: 0,
          error: 'Interrupted before this attempt completed.',
          usage: null,
          text: '',
        };
        break;
      }

      if (attempts > 0) {
        await sleep(retryDelay);
        retryDelay = Math.min(retryDelay * 2, 30_000);
      }
      attempts++;

      const keyResult = takeKey(pool, route.provider);
      if (!keyResult.key) {
        if (keyResult.reason === 'missing') {
          final = {
            ok: false,
            kind: 'auth',
            status: null,
            latencyMs: 0,
            error: `No ${route.provider} API key is configured.`,
            usage: null,
            text: '',
          };
          break;
        }
        if (attempts >= maxAttempts) {
          final = {
            ok: false,
            kind: 'rate_limit',
            status: null,
            latencyMs: 0,
            error: 'All configured keys are cooling down.',
            usage: null,
            text: '',
          };
          break;
        }
        await sleep(Math.min(keyResult.waitMs, 30_000));
        continue;
      }

      keyId = keyResult.key.id;
      const request = buildProviderRequest({
        route,
        prompt,
        systemMessage: systemMessageFor(task),
        responseSchema: QUIZ_RESPONSE_SCHEMA,
        maxOutputTokens: MAX_OUTPUT_TOKENS,
        temperature: TEMPERATURE,
        apiKey: keyResult.key.secret,
      });
      providerRequests++;
      const result = await invokeModel({
        route,
        request,
        timeoutMs: args.timeoutMs,
      });
      final = result;

      if (result.ok) break;
      if (result.kind === 'rate_limit') {
        coolDownKey(
          keyResult.key,
          Math.max(result.retryAfterMs ?? 0, 20_000),
        );
      } else if (result.kind === 'overload') {
        coolDownKey(
          keyResult.key,
          Math.max(result.retryAfterMs ?? 0, 5_000),
        );
      } else if (result.kind === 'auth') {
        coolDownKey(keyResult.key, 10 * 60_000);
      }

      if (!isRetryableKind(result.kind)) break;
      if (result.retryAfterMs) {
        retryDelay = Math.max(
          retryDelay,
          Math.min(result.retryAfterMs, 60_000),
        );
      }
    }
    retries = Math.max(0, providerRequests - 1);
  }

  if (!final) {
    final = {
      ok: false,
      kind: 'cancelled',
      status: null,
      latencyMs: 0,
      error: 'No attempt was made.',
      usage: null,
      text: '',
    };
  }

  const wallMs = Date.now() - jobStarted;
  let validation = null;
  let quality = emptyQualityMetrics();

  if (final.ok) {
    validation = validateQuiz({
      task,
      rawText: final.text,
      expectedCount: document.questionCount,
      expectedTrueFalseCount: trueFalseCount(document.questionCount),
    });
    if (validation.schemaValid) {
      quality = computeQualityMetrics({
        questions: validation.questions,
        sourceText: document.sourceText,
      });
    }
  }

  let judge = {
    model: null,
    provider: null,
    answered: null,
    agreement: null,
    agreementAll: null,
    error: null,
    usage: null,
    costUsd: null,
  };

  if (judgeRoute && validation?.schemaValid) {
    if (args.mock) {
      const total = validation.questions.length;
      const agreement = total ? Math.round(total * 0.8) / total : null;
      judge = {
        model: judgeRoute.model,
        provider: judgeRoute.provider,
        answered: total,
        agreement,
        agreementAll: agreement,
        error: null,
        usage: null,
        costUsd: null,
      };
    } else {
      try {
        const judgePrompt = buildJudgePrompt({
          sourceFileName: document.sourceFileName,
          sourceText: document.sourceText,
          questions: validation.questions,
        });
        const judgeKey = takeKey(judgePool, judgeRoute.provider);
        if (!judgeKey.key) {
          throw new Error(
            `No ${judgeRoute.provider} judge key is available.`,
          );
        }
        const judgeRequest = buildProviderRequest({
          route: judgeRoute,
          prompt: judgePrompt,
          systemMessage: systemMessageFor('judge'),
          responseSchema: JUDGE_RESPONSE_SCHEMA,
          maxOutputTokens: 4_096,
          temperature: 0,
          apiKey: judgeKey.key.secret,
        });
        const judgeResult = await invokeModel({
          route: judgeRoute,
          request: judgeRequest,
          timeoutMs: args.timeoutMs,
        });
        if (!judgeResult.ok) {
          throw new Error(
            `Judge ${judgeResult.kind ?? 'error'}: ${judgeResult.error ?? 'unknown'}`,
          );
        }
        const parsed = validateJudgeResponse(
          judgeResult.text,
          validation.questions,
        );
        const agreement = judgeAgreement(
          parsed.answers,
          validation.questions,
        );
        judge = {
          model: judgeRoute.model,
          provider: judgeRoute.provider,
          answered: parsed.answered,
          agreement: agreement.agreement,
          agreementAll: agreement.agreementAll,
          error: parsed.issues.length ? parsed.issues.join(',') : null,
          usage: judgeResult.usage,
          costUsd: computeCost(
            judgeResult.usage,
            pricing,
            judgeRoute.model,
          ),
        };
      } catch (error) {
        judge.error =
          error instanceof Error ? error.message : String(error);
      }
    }
  }

  const costUsd = args.mock
    ? null
    : computeCost(final.usage, pricing, route.model);

  return {
    run_id: job.id,
    harness_version: HARNESS_VERSION,
    timestamp: startedAt,
    task,
    model: route.model,
    provider: route.provider,
    document_id: document.id,
    source_file_name: document.sourceFileName,
    run_index: runIndex,
    question_count: document.questionCount,
    status: final.ok ? 'ok' : final.kind,
    http_status: final.status ?? null,
    error_kind: final.ok ? null : final.kind,
    error_message: final.ok ? null : (final.error ?? null),
    attempts: providerRequests,
    retries,
    latency_ms: Math.round(final.latencyMs),
    wall_ms: wallMs,
    within_production_timeout: final.ok
      ? final.latencyMs <= productionTimeoutMs(document.questionCount)
      : false,
    prompt_tokens: final.usage?.prompt ?? null,
    completion_tokens: final.usage?.completion ?? null,
    reasoning_tokens: final.usage?.reasoning ?? null,
    total_tokens: final.usage?.total ?? null,
    schema_valid: Boolean(validation?.schemaValid),
    count_exact: Boolean(validation?.countExact),
    returned_questions: validation?.returnedQuestions ?? 0,
    accepted_questions: validation?.questions.length ?? 0,
    validation_issues: validation?.issues ?? [],
    ...quality,
    judge_requested: Boolean(judgeRoute),
    judge_model: judge.model,
    judge_provider: judge.provider,
    judge_answered: judge.answered,
    judge_agreement: round(judge.agreement),
    judge_agreement_all: round(judge.agreementAll),
    judge_error: judge.error,
    cost_usd: round(costUsd, 6),
    judge_cost_usd: round(judge.costUsd, 6),
    key_id: keyId,
    mock: args.mock,
    prompt_fingerprint: fingerprint,
    temperature: TEMPERATURE,
    max_output_tokens: MAX_OUTPUT_TOKENS,
    source_chars: document.sourceText.length,
    raw_text: final.text ?? '',
    questions: validation?.questions ?? [],
  };
}

// ---------------------------------------------------------------------------
// Output
// ---------------------------------------------------------------------------

const RUN_COLUMNS = [
  'run_id',
  'harness_version',
  'timestamp',
  'task',
  'model',
  'provider',
  'document_id',
  'source_file_name',
  'run_index',
  'question_count',
  'status',
  'http_status',
  'error_kind',
  'error_message',
  'attempts',
  'retries',
  'latency_ms',
  'wall_ms',
  'within_production_timeout',
  'prompt_tokens',
  'completion_tokens',
  'reasoning_tokens',
  'total_tokens',
  'schema_valid',
  'count_exact',
  'returned_questions',
  'accepted_questions',
  'validation_issues',
  'duplicate_rate',
  'near_duplicate_rate',
  'option_duplicate_rate',
  'answer_entropy',
  'answer_entropy_mcq',
  'answer_entropy_tf',
  'max_answer_share',
  'max_answer_share_mcq',
  'max_answer_share_tf',
  'grounding_unigram_mean',
  'grounding_unigram_min',
  'grounding_bigram_mean',
  'grounding_bigram_min',
  'explanation_bigram_mean',
  'source_token_coverage',
  'lexical_diversity',
  'avg_question_words',
  'avg_explanation_words',
  'avg_option_words',
  'tf_count',
  'mcq_count',
  'judge_requested',
  'judge_model',
  'judge_provider',
  'judge_answered',
  'judge_agreement',
  'judge_agreement_all',
  'judge_error',
  'cost_usd',
  'judge_cost_usd',
  'key_id',
  'mock',
  'prompt_fingerprint',
  'source_chars',
];

const SUMMARY_COLUMNS = [
  'scope',
  'model',
  'provider',
  'mock',
  'runs',
  'ok_runs',
  'quality_runs',
  'ok_pct',
  'schema_valid_pct',
  'count_exact_pct',
  'production_eligible_pct',
  'first_attempt_ok_pct',
  'retried_runs',
  'latency_mean_ok_ms',
  'latency_p50_ok_ms',
  'latency_p95_ok_ms',
  'latency_p50_all_ms',
  'latency_p95_all_ms',
  'wall_p50_ms',
  'wall_p95_ms',
  'mean_prompt_tokens',
  'mean_completion_tokens',
  'mean_total_tokens',
  'total_cost_usd',
  'mean_cost_per_run_usd',
  'cost_coverage_pct',
  'mean_duplicate_rate',
  'mean_near_duplicate_rate',
  'mean_option_duplicate_rate',
  'mean_answer_entropy',
  'mean_max_answer_share',
  'mean_grounding_unigram',
  'mean_grounding_bigram',
  'mean_explanation_bigram',
  'mean_source_token_coverage',
  'mean_lexical_diversity',
  'mean_avg_question_words',
  'mean_avg_explanation_words',
  'mean_judge_agreement_all',
  'judge_runs',
  'error_rate_limit',
  'error_auth',
  'error_not_found',
  'error_overload',
  'error_bad_request',
  'error_network',
  'error_timeout',
  'error_invalid_output',
  'error_cancelled',
  'pricing_as_of',
];

export function csvCell(value) {
  if (value === null || value === undefined) return '';
  if (Array.isArray(value) || isPlainObject(value)) {
    value = JSON.stringify(value);
  }
  const text = String(value);
  return /[",\r\n]/.test(text)
    ? `"${text.replace(/"/g, '""')}"`
    : text;
}

function writeCsv(filePath, rows, columns) {
  const lines = [
    columns.join(','),
    ...rows.map((row) => columns.map((column) => csvCell(row[column])).join(',')),
  ];
  fs.writeFileSync(filePath, `${lines.join('\r\n')}\r\n`);
}

function buildSummaryRow(scope, route, records, pricing) {
  const okRecords = records.filter((record) => record.status === 'ok');
  const validRecords = records.filter((record) => record.schema_valid);
  const eligibleRecords = records.filter(
    (record) =>
      record.status === 'ok' &&
      record.schema_valid &&
      record.within_production_timeout,
  );
  const costRecords = records.filter(
    (record) => typeof record.cost_usd === 'number',
  );
  const judgeRecords = validRecords.filter(
    (record) => typeof record.judge_agreement_all === 'number',
  );
  const errorCounts = {};
  for (const record of records) {
    if (record.error_kind) {
      errorCounts[record.error_kind] =
        (errorCounts[record.error_kind] ?? 0) + 1;
    }
  }

  const costs = costRecords.map((record) => record.cost_usd);
  const totalCost = costs.length ? round(sum(costs), 6) : null;

  return {
    scope,
    model: route.model,
    provider: route.provider,
    mock: records.every((record) => record.mock === true),
    runs: records.length,
    ok_runs: okRecords.length,
    quality_runs: validRecords.length,
    ok_pct: percent(okRecords.length, records.length),
    schema_valid_pct: percent(validRecords.length, records.length),
    count_exact_pct: percent(
      validRecords.filter((record) => record.count_exact).length,
      records.length,
    ),
    production_eligible_pct: percent(
      eligibleRecords.length,
      records.length,
    ),
    first_attempt_ok_pct: percent(
      records.filter(
        (record) => record.status === 'ok' && (record.attempts ?? 1) === 1,
      ).length,
      records.length,
    ),
    retried_runs: records.filter((record) => (record.attempts ?? 1) > 1).length,
    latency_mean_ok_ms: meanOf(okRecords, 'latency_ms', 1),
    latency_p50_ok_ms: percentile(
      okRecords.map((record) => record.latency_ms),
      0.5,
    ),
    latency_p95_ok_ms: percentile(
      okRecords.map((record) => record.latency_ms),
      0.95,
    ),
    latency_p50_all_ms: percentile(
      records.map((record) => record.latency_ms),
      0.5,
    ),
    latency_p95_all_ms: percentile(
      records.map((record) => record.latency_ms),
      0.95,
    ),
    wall_p50_ms: percentile(
      records.map((record) => record.wall_ms),
      0.5,
    ),
    wall_p95_ms: percentile(
      records.map((record) => record.wall_ms),
      0.95,
    ),
    mean_prompt_tokens: meanOf(okRecords, 'prompt_tokens', 1),
    mean_completion_tokens: meanOf(okRecords, 'completion_tokens', 1),
    mean_total_tokens: meanOf(okRecords, 'total_tokens', 1),
    total_cost_usd: totalCost,
    mean_cost_per_run_usd:
      costs.length === 0 ? null : round(totalCost / costs.length, 6),
    cost_coverage_pct: percent(costRecords.length, records.length),
    mean_duplicate_rate: meanOf(validRecords, 'duplicate_rate'),
    mean_near_duplicate_rate: meanOf(validRecords, 'near_duplicate_rate'),
    mean_option_duplicate_rate: meanOf(
      validRecords,
      'option_duplicate_rate',
    ),
    mean_answer_entropy: meanOf(validRecords, 'answer_entropy'),
    mean_max_answer_share: meanOf(validRecords, 'max_answer_share'),
    mean_grounding_unigram: meanOf(validRecords, 'grounding_unigram_mean'),
    mean_grounding_bigram: meanOf(validRecords, 'grounding_bigram_mean'),
    mean_explanation_bigram: meanOf(
      validRecords,
      'explanation_bigram_mean',
    ),
    mean_source_token_coverage: meanOf(
      validRecords,
      'source_token_coverage',
    ),
    mean_lexical_diversity: meanOf(validRecords, 'lexical_diversity'),
    mean_avg_question_words: meanOf(
      validRecords,
      'avg_question_words',
      2,
    ),
    mean_avg_explanation_words: meanOf(
      validRecords,
      'avg_explanation_words',
      2,
    ),
    mean_judge_agreement_all: meanOf(
      judgeRecords,
      'judge_agreement_all',
    ),
    judge_runs: judgeRecords.length,
    error_rate_limit: errorCounts.rate_limit ?? 0,
    error_auth: errorCounts.auth ?? 0,
    error_not_found: errorCounts.not_found ?? 0,
    error_overload: errorCounts.overload ?? 0,
    error_bad_request: errorCounts.bad_request ?? 0,
    error_network: errorCounts.network ?? 0,
    error_timeout: errorCounts.timeout ?? 0,
    error_invalid_output: errorCounts.invalid_output ?? 0,
    error_cancelled: errorCounts.cancelled ?? 0,
    pricing_as_of: pricing?.asOf ?? null,
  };
}

function summarize({ records, routes, tasks, pricing }) {
  const rows = [];
  for (const route of routes) {
    for (const scope of [...tasks, 'ALL']) {
      const subset = records.filter(
        (record) =>
          record.model === route.model &&
          (scope === 'ALL' || record.task === scope),
      );
      if (subset.length === 0) continue;
      rows.push(buildSummaryRow(scope, route, subset, pricing));
    }
  }
  return rows;
}

function writeHumanReview({
  outputDirectory,
  records,
  routes,
  tasks,
  reviewSamples,
  seed,
}) {
  if (reviewSamples === 0) {
    return { reviews: 0, questions: 0 };
  }

  const validRecords = records.filter(
    (record) =>
      record.status === 'ok' &&
      record.schema_valid &&
      Array.isArray(record.questions) &&
      record.questions.length > 0,
  );
  const selected = [];
  for (const route of routes) {
    for (const task of tasks) {
      const candidates = validRecords.filter(
        (record) => record.model === route.model && record.task === task,
      );
      shuffleInPlace(
        candidates,
        (seed ^ hashString(`${route.model}:${task}`)) >>> 0,
      );
      selected.push(...candidates.slice(0, reviewSamples));
    }
  }
  shuffleInPlace(selected, (seed ^ 0x9e3779b9) >>> 0);

  const reviewRows = [];
  const keyRows = [];
  selected.forEach((record, index) => {
    const reviewId = `R${String(index + 1).padStart(3, '0')}`;
    keyRows.push({
      review_id: reviewId,
      model: record.model,
      provider: record.provider,
      task: record.task,
      document_id: record.document_id,
      source_file_name: record.source_file_name,
      run_index: record.run_index,
      run_id: record.run_id,
    });
    record.questions.forEach((question, questionIndex) => {
      reviewRows.push({
        review_id: reviewId,
        task: record.task,
        document_id: record.document_id,
        source_file_name: record.source_file_name,
        question_no: questionIndex + 1,
        question: question.question,
        option_1: question.options[0] ?? '',
        option_2: question.options[1] ?? '',
        option_3: question.options[2] ?? '',
        option_4: question.options[3] ?? '',
        answer_text: question.options[question.answerIndex] ?? '',
        explanation: question.explanation,
        correctness_1to5: '',
        grounding_1to5: '',
        clarity_1to5: '',
        distractor_quality_1to5: '',
        notes: '',
      });
    });
  });

  if (reviewRows.length === 0) {
    return { reviews: 0, questions: 0 };
  }

  writeCsv(path.join(outputDirectory, 'human_review.csv'), reviewRows, [
    'review_id',
    'task',
    'document_id',
    'source_file_name',
    'question_no',
    'question',
    'option_1',
    'option_2',
    'option_3',
    'option_4',
    'answer_text',
    'explanation',
    'correctness_1to5',
    'grounding_1to5',
    'clarity_1to5',
    'distractor_quality_1to5',
    'notes',
  ]);
  writeCsv(path.join(outputDirectory, 'review_key.csv'), keyRows, [
    'review_id',
    'model',
    'provider',
    'task',
    'document_id',
    'source_file_name',
    'run_index',
    'run_id',
  ]);
  fs.writeFileSync(
    path.join(outputDirectory, 'rating_rubric.txt'),
    `${RATING_RUBRIC}\n`,
  );

  return { reviews: selected.length, questions: reviewRows.length };
}

function buildMetadata({
  args,
  dataset,
  tasks,
  routes,
  judgeRoute,
  envInfo,
  keyInfo,
  pricing,
  plannedRequests,
  maxPossibleRequests,
  status,
  interrupted,
  completedRequests,
  outputDirectory,
  durationMs,
  failure,
}) {
  return {
    harness: 'quizforge-quiz-benchmark',
    harness_version: HARNESS_VERSION,
    generated_at: new Date().toISOString(),
    status,
    interrupted,
    failure: failure ?? null,
    duration_ms: durationMs ?? null,
    node_version: process.version,
    platform: `${process.platform} ${process.arch}`,
    git_commit: gitCommit(),
    output_directory: outputDirectory,
    dataset: {
      name: dataset.manifest.name ?? null,
      path: dataset.manifestPath,
      documents: dataset.documents.map((document) => ({
        id: document.id,
        title: document.title,
        source_path: document.sourcePath,
        source_file_name: document.sourceFileName,
        source_chars: document.sourceText.length,
        question_count: document.questionCount,
      })),
    },
    tasks,
    models: routes.map((route) => ({
      provider: route.provider,
      model: route.model,
      priority: route.priority,
      reasoning_effort: route.reasoningEffort ?? null,
    })),
    judge_model: judgeRoute
      ? {
          provider: judgeRoute.provider,
          model: judgeRoute.model,
          temperature: 0,
          max_output_tokens: 4_096,
        }
      : null,
    runs_per_job: args.runs,
    question_count_default: args.questionCount,
    mock: args.mock,
    seed: args.seed,
    timeout_ms: args.timeoutMs,
    max_retries: args.maxRetries,
    max_source_chars: args.maxSourceChars,
    temperature: TEMPERATURE,
    max_output_tokens: MAX_OUTPUT_TOKENS,
    prompt_version: PROMPT_VERSION,
    prompt_fingerprint: promptFingerprint(),
    production_timeout_policy:
      '15s for <=10 questions, 22s for <=20, 30s for >20 (mirrors attemptTimeoutMs in the Edge Functions)',
    env_file: envInfo,
    keys_configured: keyInfo,
    pricing: {
      path: args.pricing,
      as_of: pricing?.asOf ?? null,
      source: pricing?.source ?? null,
      currency: pricing?.currency ?? null,
      configured: pricingConfigured(pricing),
    },
    planned_requests: plannedRequests,
    max_possible_requests: maxPossibleRequests,
    completed_requests: completedRequests,
    methodology_notes: [
      'Calls the five production model routes directly, not through the Edge Function router, so model quality is not confounded by fallback or hedging.',
      'Uses the exact production prompt, JSON schema, temperature (0.4), and max output tokens (16384).',
      'Runs sequentially and interleaves models over time with a seeded order.',
      'Retries transport, rate-limit, and server errors; invalid JSON/schema is recorded as a model failure and is not retried.',
      'attempts counts provider HTTP requests; retries counts provider requests after the first. Key-cooldown waits that make no request are excluded.',
      'Schema validation mirrors the Edge Functions: MCQ accepts at least N valid questions and slices to N; True/False requires ["True","False"]; mixed requires the production 30% split and four distinct MCQ options.',
      'count_exact means the number of schema-valid questions equals the requested count; production accepts at least N and trims extras, so returning extra valid questions still passes production validation.',
      'Mixed questions are regrouped by type after validation because metrics are order-invariant; the harness does not score the requested question-type ordering.',
      'Grounding metrics are lexical proxies (unigram/bigram overlap with the source), not factual verification. Use the blinded human review sheet for pedagogy ratings.',
      'Judge agreement is an optional answerability proxy: the judge sees only the source, questions, and options, never the claimed key or explanation.',
      'If the judge is one of the five benchmarked models, agreement may be inflated by self-preference; prefer an outside judge or treat the result as a secondary check.',
      'Cost is reported only when benchmark/pricing.json contains current per-million-token prices; the harness does not assume prices.',
      'A model-level benchmark does not validate router fallback or hedging behavior. Use a separate fault-injection/load test for that claim.',
    ],
  };
}

// ---------------------------------------------------------------------------
// Plan + execution
// ---------------------------------------------------------------------------

function printPlan({
  args,
  dataset,
  tasks,
  routes,
  judgeRoute,
  keyInfo,
  pricing,
  jobs,
  plannedRequests,
  maxPossibleRequests,
  outputDirectory,
}) {
  console.log('QuizForge quiz-generation benchmark\n');
  console.log(`Dataset:      ${dataset.manifestPath}`);
  console.log(
    `Documents:    ${dataset.documents.length} (${dataset.documents.map((document) => `${document.id}: ${document.questionCount}q/${document.sourceText.length} chars`).join(', ')})`,
  );
  console.log(`Tasks:        ${tasks.join(', ')}`);
  console.log(`Models:       ${routes.length}`);
  console.log(`Runs/job:     ${args.runs}`);
  console.log(`Jobs:         ${jobs.length}`);
  console.log(
    `Judge:        ${judgeRoute ? `${judgeRoute.provider}:${judgeRoute.model} (adds up to ${jobs.length} requests)` : 'off'}`,
  );
  console.log(`Requests:     ${plannedRequests} planned (${maxPossibleRequests} worst case with retries)`);
  console.log(
    `Keys:         groq=${keyInfo.groq.length}${keyInfo.groq.length ? '' : ' (missing)'}, gemini=${keyInfo.gemini.length}${keyInfo.gemini.length ? '' : ' (missing)'}`,
  );
  console.log(
    `Pricing:      ${pricingConfigured(pricing) ? `configured (${pricing.asOf ?? 'date not set'})` : 'not configured; cost columns will be blank'}`,
  );
  console.log(`Timeout:      ${args.timeoutMs} ms per attempt`);
  console.log(`Retries:      ${args.maxRetries} (transport/rate-limit/server only)`);
  console.log(`Mock mode:    ${args.mock ? 'YES (results are synthetic)' : 'no'}`);
  console.log(`Output:       ${outputDirectory}`);
  console.log('\nModels:');
  for (const route of routes) {
    console.log(
      `  ${route.priority}. ${route.provider.padEnd(6)} ${route.model}`,
    );
  }
}

async function executeJobs({
  jobs,
  records,
  completedIds,
  runsPath,
  args,
  pool,
  judgePool,
  judgeRoute,
  pricing,
}) {
  let interrupted = false;
  for (let index = 0; index < jobs.length; index++) {
    if (stopping) {
      interrupted = true;
      break;
    }
    const job = jobs[index];
    if (completedIds.has(job.id)) {
      console.log(
        `[${index + 1}/${jobs.length}] skip ${job.id} (already in runs.jsonl)`,
      );
      continue;
    }

    const record = await runJob({
      job,
      args,
      pool,
      judgePool,
      judgeRoute,
      pricing,
    });
    records.push(record);
    completedIds.add(record.run_id);
    fs.appendFileSync(runsPath, `${JSON.stringify(record)}\n`);

    const status = record.status === 'ok'
      ? record.schema_valid
        ? 'ok'
        : 'invalid-schema'
      : record.status;
    const judge =
      typeof record.judge_agreement_all === 'number'
        ? ` judge=${record.judge_agreement_all.toFixed(2)}`
        : '';
    console.log(
      `[${index + 1}/${jobs.length}] ${record.task} ${record.document_id} ${record.model} r${record.run_index} -> ${status} ${record.latency_ms}ms${judge}`,
    );
  }
  if (stopping) interrupted = true;
  return { interrupted };
}

async function main() {
  let args;
  try {
    args = parseArgs(process.argv.slice(2));
  } catch (error) {
    console.error(`Error: ${error instanceof Error ? error.message : error}`);
    process.exitCode = 1;
    return;
  }

  if (args.help) {
    printHelp();
    return;
  }
  if (args.listModels) {
    printModels();
    return;
  }

  const envFileInfo = loadEnvFile(args.envFile);
  if (!envFileInfo.loaded) {
    console.warn(
      `Warning: key file not found at ${args.envFile}. Falling back to process environment variables.`,
    );
  } else {
    console.log(`Loaded keys from ${args.envFile}`);
  }

  const pool = createKeyPool(process.env);
  const keyInfo = keySummary(pool);
  const dataset = loadDataset(
    args.dataset,
    args.maxSourceChars,
    args.questionCount,
  );
  const tasks = args.task === 'all' ? [...TASKS] : [args.task];
  const routes = resolveModels(args.models);
  const judgeRoute = parseJudgeModel(args.judgeModel);
  const pricing = loadPricing(args.pricing);
  if (!pricing) {
    console.warn(
      `Warning: pricing table not found at ${args.pricing}. Cost columns will be blank.`,
    );
  } else if (!pricingConfigured(pricing)) {
    console.warn(
      'Warning: no current per-million-token prices are configured. Cost columns will be blank. Fill benchmark/pricing.json from provider pricing pages.',
    );
  }

  const jobs = buildJobs({
    tasks,
    documents: dataset.documents,
    routes,
    runs: args.runs,
    seed: args.seed,
  });
  const plannedRequests = jobs.length + (judgeRoute ? jobs.length : 0);
  const maxPossibleRequests =
    jobs.length * (args.mock ? 1 : args.maxRetries + 1) +
    (judgeRoute ? jobs.length : 0);

  const outputDirectory = args.out
    ? path.resolve(args.out)
    : path.join(
        __dirname,
        'results',
        args.dryRun ? '<timestamp>' : timestampForPath(),
      );

  printPlan({
    args,
    dataset,
    tasks,
    routes,
    judgeRoute,
    keyInfo,
    pricing,
    jobs,
    plannedRequests,
    maxPossibleRequests,
    outputDirectory,
  });

  if (args.dryRun) {
    console.log('\nDry run complete. No API calls were made and no files were written.');
    return;
  }

  if (!args.yes) {
    console.log(
      '\nRefusing to make live API calls without --yes. Add --yes to confirm (live calls may incur provider charges).',
    );
    process.exitCode = 2;
    return;
  }

  if (args.maxRequests > 0 && maxPossibleRequests > args.maxRequests) {
    throw new Error(
      `Worst-case request count ${maxPossibleRequests} (including retries) exceeds --max-requests ${args.maxRequests}. Raise the cap or reduce the matrix.`,
    );
  }

  if (!args.mock) {
    const missing = new Set();
    for (const route of routes) {
      if ((pool[route.provider] ?? []).length === 0) {
        missing.add(route.provider);
      }
    }
    if (judgeRoute && (pool[judgeRoute.provider] ?? []).length === 0) {
      missing.add(judgeRoute.provider);
    }
    if (missing.size > 0) {
      throw new Error(
        `Missing API keys for: ${[...missing].join(', ')}. Add them to ${args.envFile} (see benchmark/.env.example).`,
      );
    }
  }

  process.on('SIGINT', () => {
    if (stopping) {
      console.error('\nForced exit before results could be written.');
      process.exit(130);
    }
    stopping = true;
    console.warn(
      '\nInterrupt received. Finishing the current request, then writing results...',
    );
  });

  prepareOutputDir(args, outputDirectory);

  const runsPath = path.join(outputDirectory, 'runs.jsonl');
  let records = [];
  if (args.resume) {
    records = readExistingRecords(runsPath);
    const currentFingerprint = promptFingerprint();
    const incompatible = records.find(
      (record) =>
        (record.harness_version &&
          record.harness_version !== HARNESS_VERSION) ||
        (record.prompt_fingerprint &&
          record.prompt_fingerprint !== currentFingerprint) ||
        (typeof record.mock === 'boolean' && record.mock !== args.mock) ||
        (typeof record.judge_requested === 'boolean' &&
          record.judge_requested !== Boolean(judgeRoute)) ||
        (record.judge_model &&
          judgeRoute &&
          record.judge_model !== judgeRoute.model),
    );
    if (incompatible) {
      throw new Error(
        'Existing runs use different prompts/settings or a different mock mode. ' +
          'Use a new --out directory, or omit --resume (with --force) to start over.',
      );
    }
    console.log(`Resuming with ${records.length} existing run(s).`);
  } else {
    fs.writeFileSync(runsPath, '');
  }
  const completedIds = new Set(
    records.map((record) => record.run_id).filter(Boolean),
  );

  fs.writeFileSync(
    path.join(outputDirectory, 'run_metadata.json'),
    `${JSON.stringify(
      buildMetadata({
        args,
        dataset,
        tasks,
        routes,
        judgeRoute,
        envInfo: envFileInfo,
        keyInfo,
        pricing,
        plannedRequests,
        maxPossibleRequests,
        status: 'running',
        interrupted: false,
        completedRequests: records.length,
        outputDirectory,
        durationMs: null,
        failure: null,
      }),
      null,
      2,
    )}\n`,
  );

  const startedAt = Date.now();
  let interrupted = false;
  let failure = null;

  try {
    const result = await executeJobs({
      jobs,
      records,
      completedIds,
      runsPath,
      args,
      pool,
      judgePool: pool,
      judgeRoute,
      pricing,
    });
    interrupted = result.interrupted;
  } catch (error) {
    failure = error;
  }

  const durationMs = Date.now() - startedAt;
  const summaryRows = summarize({
    records,
    routes,
    tasks,
    pricing,
  });
  writeCsv(
    path.join(outputDirectory, 'runs.csv'),
    records,
    RUN_COLUMNS,
  );
  writeCsv(
    path.join(outputDirectory, 'summary.csv'),
    summaryRows,
    SUMMARY_COLUMNS,
  );

  const reviewInfo = args.humanReview
    ? writeHumanReview({
        outputDirectory,
        records,
        routes,
        tasks,
        reviewSamples: args.reviewSamples,
        seed: args.seed,
      })
    : { reviews: 0, questions: 0 };

  const metadata = buildMetadata({
    args,
    dataset,
    tasks,
    routes,
    judgeRoute,
    envInfo: envFileInfo,
    keyInfo,
    pricing,
    plannedRequests,
    maxPossibleRequests,
    status: failure
      ? 'failed'
      : interrupted
        ? 'interrupted'
        : 'completed',
    interrupted,
    completedRequests: records.length,
    outputDirectory,
    durationMs,
    failure: failure instanceof Error ? failure.message : failure,
  });

  fs.writeFileSync(
    path.join(outputDirectory, 'run_metadata.json'),
    `${JSON.stringify(metadata, null, 2)}\n`,
  );
  fs.writeFileSync(
    path.join(outputDirectory, 'summary.json'),
    `${JSON.stringify({ metadata, rows: summaryRows }, null, 2)}\n`,
  );

  console.log('\nResults');
  console.log(`  Raw runs:       ${path.join(outputDirectory, 'runs.jsonl')}`);
  console.log(`  Runs table:     ${path.join(outputDirectory, 'runs.csv')}`);
  console.log(`  Summary table:  ${path.join(outputDirectory, 'summary.csv')}`);
  console.log(`  Summary JSON:   ${path.join(outputDirectory, 'summary.json')}`);
  console.log(`  Metadata:       ${path.join(outputDirectory, 'run_metadata.json')}`);
  if (args.humanReview && reviewInfo.questions > 0) {
    console.log(
      `  Human review:   ${path.join(outputDirectory, 'human_review.csv')} (${reviewInfo.reviews} quizzes, ${reviewInfo.questions} questions)`,
    );
    console.log(
      `  Blind key:      ${path.join(outputDirectory, 'review_key.csv')} (do not open while rating)`,
    );
  }
  console.log(`  Completed runs: ${records.length}/${jobs.length}`);
  if (args.mock) {
    console.log(
      '\nWARNING: mock mode was enabled. Every number above is synthetic and must not be reported as a benchmark result.',
    );
  }
  if (interrupted) {
    console.log('\nInterrupted: partial results were written.');
  }

  if (failure) {
    throw failure;
  }
}

function isMainModule() {
  if (!process.argv[1]) return false;
  const entry = path.resolve(process.argv[1]);
  const modulePath = fileURLToPath(import.meta.url);
  return process.platform === 'win32'
    ? entry.toLowerCase() === modulePath.toLowerCase()
    : entry === modulePath;
}

if (isMainModule()) {
  main().catch((error) => {
    console.error(
      `\nBenchmark failed: ${error instanceof Error ? error.stack ?? error.message : error}`,
    );
    process.exitCode = 1;
  });
}
