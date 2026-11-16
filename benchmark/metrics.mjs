const STOPWORDS = new Set(
  (
    'a an the and or but if then than that this these those there here ' +
    'is are was were be been being am i you he she it we they me him her us them ' +
    'my your his its our their mine yours hers ours theirs ' +
    'of in on at by for with from to into onto over under about above below ' +
    'as not no nor so such only own same very can will just should now ' +
    'do does did done doing have has had having ' +
    'what which who whom whose when where why how all any both each few more most ' +
    'other some many much several between during before after while because ' +
    'through against without within upon also may might must shall would could ' +
    'one two three four five six seven eight nine ten ' +
    'following given using used use based according true false'
  ).split(/\s+/),
);

export function isObject(value) {
  return typeof value === 'object' && value !== null && !Array.isArray(value);
}

export function parseGeneratedJson(text) {
  const trimmed = String(text ?? '').trim();
  try {
    return JSON.parse(trimmed);
  } catch {
    return JSON.parse(
      trimmed.replace(/^```(?:json)?\s*/i, '').replace(/\s*```$/, '').trim(),
    );
  }
}

export function isValidMcq(item) {
  if (!isObject(item)) return false;
  const { question, options, answerIndex, explanation } = item;
  if (
    typeof question !== 'string' ||
    question.trim().length === 0 ||
    !Array.isArray(options) ||
    options.length !== 4 ||
    !options.every(
      (option) => typeof option === 'string' && option.trim().length > 0,
    ) ||
    typeof answerIndex !== 'number' ||
    !Number.isInteger(answerIndex) ||
    answerIndex < 0 ||
    answerIndex > 3 ||
    typeof explanation !== 'string' ||
    explanation.trim().length === 0
  ) {
    return false;
  }
  const normalized = options.map((option) => option.trim().toLowerCase());
  return new Set(normalized).size === 4;
}

export function isValidTrueFalse(item) {
  if (!isObject(item)) return false;
  const { question, options, answerIndex, explanation } = item;
  if (
    typeof question !== 'string' ||
    question.trim().length === 0 ||
    !Array.isArray(options) ||
    options.length !== 2 ||
    !options.every(
      (option) => typeof option === 'string' && option.trim().length > 0,
    ) ||
    typeof answerIndex !== 'number' ||
    !Number.isInteger(answerIndex) ||
    answerIndex < 0 ||
    answerIndex > 1 ||
    typeof explanation !== 'string' ||
    explanation.trim().length === 0
  ) {
    return false;
  }
  const normalized = options.map((option) => option.trim().toLowerCase());
  return normalized[0] === 'true' && normalized[1] === 'false';
}

export function isValidMixed(item) {
  if (!isObject(item)) return false;
  if (!Array.isArray(item.options)) return false;
  if (item.options.length === 2) return isValidTrueFalse(item);
  if (item.options.length === 4) {
    if (!isValidMcq(item)) return false;
    const normalized = item.options.map((option) =>
      option.trim().toLowerCase(),
    );
    return new Set(normalized).size === 4;
  }
  return false;
}

export function validateQuiz({
  task,
  rawText,
  expectedCount,
  expectedTrueFalseCount,
}) {
  const result = {
    parsed: false,
    schemaValid: false,
    countExact: false,
    returnedQuestions: 0,
    acceptedQuestions: 0,
    questions: [],
    issues: [],
    tfCount: 0,
    mcqCount: 0,
    mixedCountOk: null,
  };

  let parsed;
  try {
    parsed = parseGeneratedJson(rawText);
  } catch {
    result.issues.push('json_parse');
    return result;
  }
  result.parsed = true;

  if (!isObject(parsed) || !Array.isArray(parsed.questions)) {
    result.issues.push('missing_questions_array');
    return result;
  }

  const rawQuestions = parsed.questions;
  result.returnedQuestions = rawQuestions.length;

  let valid;
  if (task === 'mcq') {
    valid = rawQuestions.filter(isValidMcq);
  } else if (task === 'true_false') {
    valid = rawQuestions.filter(isValidTrueFalse);
  } else if (task === 'mixed') {
    valid = rawQuestions.filter(isValidMixed);
  } else {
    throw new Error(`Unknown task "${task}".`);
  }

  result.countExact = valid.length === expectedCount;

  if (task === 'mixed') {
    const trueFalse = valid.filter((item) => item.options.length === 2);
    const multipleChoice = valid.filter((item) => item.options.length === 4);
    result.tfCount = trueFalse.length;
    result.mcqCount = multipleChoice.length;
    result.mixedCountOk =
      trueFalse.length >= expectedTrueFalseCount &&
      multipleChoice.length >= expectedCount - expectedTrueFalseCount;
    if (valid.length < expectedCount) {
      result.issues.push('insufficient_valid_questions');
      return result;
    }
    if (!result.mixedCountOk) {
      result.issues.push('mixed_type_counts');
      return result;
    }
    result.questions = [
      ...trueFalse.slice(0, expectedTrueFalseCount),
      ...multipleChoice.slice(0, expectedCount - expectedTrueFalseCount),
    ];
  } else {
    if (valid.length < expectedCount) {
      result.issues.push('insufficient_valid_questions');
      return result;
    }
    result.questions = valid.slice(0, expectedCount);
  }

  result.acceptedQuestions = result.questions.length;
  result.schemaValid = true;
  return result;
}

export function normalizeText(text) {
  return String(text ?? '')
    .toLowerCase()
    .normalize('NFKC')
    .replace(/[^\p{L}\p{N}\s]+/gu, ' ')
    .replace(/\s+/g, ' ')
    .trim();
}

export function contentTokens(text) {
  return normalizeText(text)
    .split(' ')
    .filter((token) => token.length > 1 && !STOPWORDS.has(token));
}

function bigrams(tokens) {
  const grams = [];
  for (let index = 1; index < tokens.length; index++) {
    grams.push(`${tokens[index - 1]} ${tokens[index]}`);
  }
  return grams;
}

function jaccard(left, right) {
  if (left.size === 0 && right.size === 0) return 1;
  let intersection = 0;
  for (const token of left) {
    if (right.has(token)) intersection++;
  }
  return intersection / (left.size + right.size - intersection);
}

function mean(values) {
  const numeric = values.filter(
    (value) => typeof value === 'number' && Number.isFinite(value),
  );
  if (numeric.length === 0) return null;
  return numeric.reduce((sum, value) => sum + value, 0) / numeric.length;
}

function minimum(values) {
  const numeric = values.filter(
    (value) => typeof value === 'number' && Number.isFinite(value),
  );
  if (numeric.length === 0) return null;
  return Math.min(...numeric);
}

function round(value, digits = 4) {
  if (typeof value !== 'number' || !Number.isFinite(value)) return null;
  const factor = 10 ** digits;
  return Math.round(value * factor) / factor;
}

function wordCount(text) {
  return String(text ?? '')
    .trim()
    .split(/\s+/)
    .filter(Boolean).length;
}

function groundingScore(text, sourceTokens, sourceBigrams) {
  const tokens = contentTokens(text);
  if (tokens.length === 0) return { unigram: null, bigram: null };
  const unigram =
    tokens.filter((token) => sourceTokens.has(token)).length / tokens.length;
  const grams = bigrams(tokens);
  const bigram =
    grams.length === 0
      ? null
      : grams.filter((gram) => sourceBigrams.has(gram)).length / grams.length;
  return { unigram, bigram };
}

function duplicateStats(questions) {
  const normalized = questions.map((question) =>
    normalizeText(question.question),
  );
  const total = normalized.length;
  if (total === 0) return { exact: null, near: null };

  const exact = 1 - new Set(normalized).size / total;
  const clusters = [];
  for (const text of normalized) {
    const tokens = new Set(contentTokens(text));
    let merged = false;
    for (const cluster of clusters) {
      if (jaccard(tokens, cluster.tokens) >= 0.8) {
        merged = true;
        break;
      }
    }
    if (!merged) clusters.push({ tokens });
  }
  return { exact, near: 1 - clusters.length / total };
}

function answerDistribution(questions, optionCount) {
  const counts = Array(optionCount).fill(0);
  let total = 0;
  for (const question of questions) {
    if (question.options.length !== optionCount) continue;
    if (
      Number.isInteger(question.answerIndex) &&
      question.answerIndex >= 0 &&
      question.answerIndex < optionCount
    ) {
      counts[question.answerIndex]++;
      total++;
    }
  }
  if (total === 0 || optionCount < 2) {
    return { entropy: null, maxShare: null, total: 0 };
  }
  const entropy =
    -counts.reduce((sum, count) => {
      if (count === 0) return sum;
      const probability = count / total;
      return sum + probability * Math.log(probability);
    }, 0) / Math.log(optionCount);
  return {
    entropy,
    maxShare: Math.max(...counts) / total,
    total,
  };
}

export function emptyQualityMetrics() {
  return {
    duplicate_rate: null,
    near_duplicate_rate: null,
    option_duplicate_rate: null,
    answer_entropy: null,
    answer_entropy_mcq: null,
    answer_entropy_tf: null,
    max_answer_share: null,
    max_answer_share_mcq: null,
    max_answer_share_tf: null,
    grounding_unigram_mean: null,
    grounding_unigram_min: null,
    grounding_bigram_mean: null,
    grounding_bigram_min: null,
    explanation_bigram_mean: null,
    source_token_coverage: null,
    lexical_diversity: null,
    avg_question_words: null,
    avg_explanation_words: null,
    avg_option_words: null,
    tf_count: null,
    mcq_count: null,
  };
}

export function computeQualityMetrics({ questions, sourceText }) {
  if (!Array.isArray(questions) || questions.length === 0) {
    return emptyQualityMetrics();
  }

  const sourceTokenList = contentTokens(sourceText);
  const sourceTokens = new Set(sourceTokenList);
  const sourceBigrams = new Set(bigrams(sourceTokenList));

  const unigramScores = [];
  const bigramScores = [];
  const explanationBigrams = [];
  const questionWords = [];
  const explanationWords = [];
  const optionWords = [];
  const allTokens = [];
  let questionsWithDuplicateOptions = 0;

  for (const question of questions) {
    const answer =
      typeof question.answerIndex === 'number'
        ? question.options[question.answerIndex]
        : '';
    const qa = groundingScore(
      `${question.question} ${answer ?? ''}`,
      sourceTokens,
      sourceBigrams,
    );
    const explanation = groundingScore(
      question.explanation,
      sourceTokens,
      sourceBigrams,
    );
    if (qa.unigram !== null) unigramScores.push(qa.unigram);
    if (qa.bigram !== null) bigramScores.push(qa.bigram);
    if (explanation.bigram !== null) {
      explanationBigrams.push(explanation.bigram);
    }

    questionWords.push(wordCount(question.question));
    explanationWords.push(wordCount(question.explanation));
    for (const option of question.options) {
      optionWords.push(wordCount(option));
    }

    allTokens.push(
      ...contentTokens(question.question),
      ...contentTokens(question.explanation),
      ...question.options.flatMap((option) => contentTokens(option)),
    );

    const normalizedOptions = question.options.map(normalizeText);
    if (new Set(normalizedOptions).size < normalizedOptions.length) {
      questionsWithDuplicateOptions++;
    }
  }

  const duplicates = duplicateStats(questions);
  const mcqDistribution = answerDistribution(questions, 4);
  const tfDistribution = answerDistribution(questions, 2);

  const entropyGroups = [mcqDistribution, tfDistribution].filter(
    (group) => group.entropy !== null,
  );
  const entropyWeight = entropyGroups.reduce(
    (sum, group) => sum + group.total,
    0,
  );
  const answerEntropy =
    entropyWeight === 0
      ? null
      : entropyGroups.reduce(
          (sum, group) => sum + group.entropy * group.total,
          0,
        ) / entropyWeight;
  const maxShares = [mcqDistribution.maxShare, tfDistribution.maxShare].filter(
    (value) => value !== null,
  );

  const generatedTokenSet = new Set(allTokens);
  let coveredSourceTokens = 0;
  for (const token of generatedTokenSet) {
    if (sourceTokens.has(token)) coveredSourceTokens++;
  }

  return {
    duplicate_rate: round(duplicates.exact),
    near_duplicate_rate: round(duplicates.near),
    option_duplicate_rate: round(
      questionsWithDuplicateOptions / questions.length,
    ),
    answer_entropy: round(answerEntropy),
    answer_entropy_mcq: round(mcqDistribution.entropy),
    answer_entropy_tf: round(tfDistribution.entropy),
    max_answer_share:
      maxShares.length === 0 ? null : round(Math.max(...maxShares)),
    max_answer_share_mcq: round(mcqDistribution.maxShare),
    max_answer_share_tf: round(tfDistribution.maxShare),
    grounding_unigram_mean: round(mean(unigramScores)),
    grounding_unigram_min: round(minimum(unigramScores)),
    grounding_bigram_mean: round(mean(bigramScores)),
    grounding_bigram_min: round(minimum(bigramScores)),
    explanation_bigram_mean: round(mean(explanationBigrams)),
    source_token_coverage:
      sourceTokens.size === 0
        ? null
        : round(coveredSourceTokens / sourceTokens.size),
    lexical_diversity:
      allTokens.length === 0
        ? null
        : round(generatedTokenSet.size / allTokens.length),
    avg_question_words: round(mean(questionWords), 2),
    avg_explanation_words: round(mean(explanationWords), 2),
    avg_option_words: round(mean(optionWords), 2),
    tf_count: tfDistribution.total,
    mcq_count: mcqDistribution.total,
  };
}

export function validateJudgeResponse(rawText, questions) {
  let parsed;
  try {
    parsed = parseGeneratedJson(rawText);
  } catch {
    return {
      parsed: false,
      answers: Array(questions.length).fill(null),
      answered: 0,
      issues: ['json_parse'],
    };
  }

  if (!isObject(parsed) || !Array.isArray(parsed.answers)) {
    return {
      parsed: false,
      answers: Array(questions.length).fill(null),
      answered: 0,
      issues: ['missing_answers_array'],
    };
  }

  const answers = Array(questions.length).fill(null);
  for (const item of parsed.answers) {
    if (!isObject(item)) continue;
    const questionIndex = item.questionIndex;
    const answerIndex = item.answerIndex;
    if (
      !Number.isInteger(questionIndex) ||
      questionIndex < 0 ||
      questionIndex >= questions.length
    ) {
      continue;
    }
    if (
      !Number.isInteger(answerIndex) ||
      answerIndex < 0 ||
      answerIndex >= questions[questionIndex].options.length
    ) {
      continue;
    }
    if (answers[questionIndex] === null) {
      answers[questionIndex] = answerIndex;
    }
  }

  return {
    parsed: true,
    answers,
    answered: answers.filter((answer) => answer !== null).length,
    issues: [],
  };
}

export function judgeAgreement(answers, questions) {
  let matches = 0;
  let answered = 0;
  for (let index = 0; index < questions.length; index++) {
    if (answers[index] === null) continue;
    answered++;
    if (answers[index] === questions[index].answerIndex) {
      matches++;
    }
  }
  return {
    answered,
    matches,
    agreement: answered === 0 ? null : matches / answered,
    agreementAll: questions.length === 0 ? null : matches / questions.length,
  };
}
