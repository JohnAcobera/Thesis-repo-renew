import { createClient } from "https://esm.sh/@supabase/supabase-js@2";

const corsHeaders = {
  "Access-Control-Allow-Origin": "*",
  "Access-Control-Allow-Headers":
    "authorization, x-client-info, apikey, content-type",
  "Access-Control-Allow-Methods": "POST, OPTIONS",
  "Content-Type": "application/json",
};

const responseSchema = {
  type: "OBJECT",
  properties: {
    questions: {
      type: "ARRAY",
      items: {
        type: "OBJECT",
        properties: {
          question: { type: "STRING" },
          options: { type: "ARRAY", items: { type: "STRING" } },
          answerIndex: { type: "INTEGER" },
          explanation: { type: "STRING" },
        },
        required: ["question", "options", "answerIndex", "explanation"],
      },
    },
  },
  required: ["questions"],
};

function jsonResponse(status: number, body: Record<string, unknown>) {
  return new Response(JSON.stringify(body), {
    status,
    headers: corsHeaders,
  });
}

function providerErrorMessage(body: unknown): string | undefined {
  if (
    typeof body !== "object" ||
    body === null ||
    !("error" in body) ||
    typeof body.error !== "object" ||
    body.error === null ||
    !("message" in body.error) ||
    typeof body.error.message !== "string"
  ) {
    return undefined;
  }

  return body.error.message
    .replace(/[\r\n\t]+/g, " ")
    .replace(/\s+/g, " ")
    .slice(0, 300);
}

Deno.serve(async (request: Request) => {
  if (request.method === "OPTIONS") {
    return new Response("ok", { headers: corsHeaders });
  }
  if (request.method !== "POST") {
    return jsonResponse(405, { error: "Use POST to generate a quiz." });
  }

  let requestBody: unknown;
  try {
    requestBody = await request.json();
  } catch {
    return jsonResponse(400, { error: "The request body must be valid JSON." });
  }
  if (
    typeof requestBody !== "object" ||
    requestBody === null ||
    Array.isArray(requestBody)
  ) {
    return jsonResponse(400, {
      error: "The request body must be a JSON object.",
    });
  }
  const body = requestBody as Record<string, unknown>;

  const sessionToken = body.sessionToken;
  const questionCount = body.questionCount;
  const sourceFileName = body.sourceFileName;
  const sourceText = body.sourceText;

  if (
    typeof sessionToken !== "string" ||
    sessionToken.length < 32 ||
    sessionToken.length > 256
  ) {
    return jsonResponse(401, { error: "Please log in to generate a quiz." });
  }
  if (
    typeof questionCount !== "number" ||
    ![10, 20, 30].includes(questionCount)
  ) {
    return jsonResponse(400, { error: "Choose 10, 20, or 30 questions." });
  }
  if (
    typeof sourceFileName !== "string" ||
    sourceFileName.trim().length === 0 ||
    sourceFileName.length > 200
  ) {
    return jsonResponse(400, { error: "A source file name is required." });
  }

  if (
    typeof sourceText !== "string" ||
    sourceText.trim().length === 0 ||
    sourceText.length > 100_000
  ) {
    return jsonResponse(400, {
      error: "Provide extracted document text of 100,000 characters or less.",
    });
  }

  const supabaseUrl = Deno.env.get("SUPABASE_URL");
  const supabaseAnonKey = Deno.env.get("SUPABASE_ANON_KEY");
  if (!supabaseUrl || !supabaseAnonKey) {
    return jsonResponse(500, {
      error: "Quiz service configuration is incomplete.",
    });
  }

  const supabase = createClient(supabaseUrl, supabaseAnonKey, {
    auth: { autoRefreshToken: false, persistSession: false },
  });
  try {
    const { error: sessionError } = await supabase.rpc("verify_session", {
      p_session_token: sessionToken,
    });
    if (sessionError) {
      return jsonResponse(401, {
        error: "Your session has expired. Please log in again.",
      });
    }
  } catch {
    return jsonResponse(503, {
      error: "Could not verify your login session. Please try again.",
    });
  }
  const prompt = [
    "Create a multiple-choice quiz using only the supplied learning material.",
    `Return exactly ${questionCount} questions in the required JSON schema.`,
    "Each question must have exactly four distinct answer options.",
    "answerIndex must be the zero-based index of the only correct option.",
    "Write clear questions, plausible distractors, and a brief explanation.",
    "Do not refer to information outside the supplied material.",
    `Source file: ${sourceFileName.trim()}`,
  ].join("\n");

  const parts: Record<string, unknown>[] = [
    { text: prompt },
    { text: `\n\nLearning material:\n${sourceText}` },
  ];

  const geminiKeys = [
    Deno.env.get("GEMINI_API_KEY_1"),
    Deno.env.get("GEMINI_API_KEY_2"),
    Deno.env.get("GEMINI_API_KEY_3"),
    Deno.env.get("GEMINI_API_KEY_4"),
    Deno.env.get("GEMINI_API_KEY_5"),
    Deno.env.get("GEMINI_API_KEY_6"),
  ].filter((key): key is string => Boolean(key));
  if (geminiKeys.length === 0) {
    return jsonResponse(500, {
      error: "No Gemini API keys are configured for quiz generation.",
    });
  }

  const models = [
    "gemini-3.8-flash",
    "gemini-3.7-flash",
    "gemini-3.6-flash",
    "gemini-3.5-flash-lite",
    "gemini-3.5-flash",
    "gemini-3.1-pro-preview",
    "gemini-3-flash-preview",
  ];
  let rateLimitedKeys = 0;
  let overloadedKeys = 0;
  let rejectedKeys = 0;
  let networkFailures = 0;
  let attemptedResponses = 0;
  let lastProviderStatus = 0;
  let lastProviderMessage: string | undefined;
  const retryDeadline = Date.now() + 60_000;
  for (const [keyIndex, key] of geminiKeys.entries()) {
    for (const model of models) {
      const remainingMs = retryDeadline - Date.now();
      if (remainingMs <= 0) break;

      const timeoutMs = Math.min(keyIndex === 0 ? 12_000 : 4_000, remainingMs);
      let response: Response;
      try {
        response = await fetch(
          `https://generativelanguage.googleapis.com/v1beta/models/${model}:generateContent`,
          {
            method: "POST",
            headers: {
              "Content-Type": "application/json",
              "x-goog-api-key": key,
            },
            signal: AbortSignal.timeout(timeoutMs),
            body: JSON.stringify({
              contents: [{ role: "user", parts }],
              generationConfig: {
                responseMimeType: "application/json",
                responseSchema,
                maxOutputTokens: 32_768,
                temperature: 0.4,
              },
            }),
          },
        );
      } catch (error) {
        networkFailures++;
        console.error("Gemini request could not be completed", {
          model,
          keyAttempt: keyIndex + 1,
          error: error instanceof Error ? error.name : "Unknown network error",
        });
        continue;
      }

      if (!response.ok) {
        attemptedResponses++;
        lastProviderStatus = response.status;
        try {
          lastProviderMessage = providerErrorMessage(await response.json());
        } catch {
          lastProviderMessage = undefined;
        }
        console.error("Gemini request failed", {
          model,
          status: lastProviderStatus,
          message: lastProviderMessage,
        });

        if (response.status === 429) rateLimitedKeys++;
        if (response.status === 503) overloadedKeys++;
        if (response.status === 401 || response.status === 403) rejectedKeys++;
        if (
          response.status === 400 || response.status === 401 ||
          response.status === 403 || response.status === 404 ||
          response.status === 429 || response.status >= 500
        ) {
          if (response.status === 401 || response.status === 403) break;
          continue;
        }
        return jsonResponse(502, {
          error: `Gemini rejected the request (HTTP ${response.status}). ${
            lastProviderMessage ?? "Check the Edge Function logs for details."
          }`,
        });
      }

      try {
        const result = await response.json();
        const candidate = result?.candidates?.[0];
        const generatedText = candidate?.content?.parts?.find(
          (part: { text?: unknown }) => typeof part.text === "string",
        )?.text;
        if (typeof generatedText !== "string") {
          const finishReason = candidate?.finishReason;
          if (finishReason === "MAX_TOKENS") {
            lastProviderMessage =
              "Gemini stopped before finishing the quiz. Try fewer questions.";
            continue;
          }
          if (finishReason === "SAFETY") {
            lastProviderMessage =
              "Gemini could not generate questions from this source.";
            continue;
          }
          throw new Error("Gemini response did not contain quiz text.");
        }

        const quiz = JSON.parse(generatedText);
        if (
          !Array.isArray(quiz.questions) ||
          quiz.questions.length !== questionCount ||
          quiz.questions.some((question: Record<string, unknown>) =>
            typeof question.question !== "string" ||
            question.question.trim().length === 0 ||
            !Array.isArray(question.options) ||
            question.options.length !== 4 ||
            new Set(
                question.options.map((option: unknown) =>
                  typeof option === "string"
                    ? option.trim().toLocaleLowerCase()
                    : ""
                ),
              ).size !== 4 ||
            question.options.some((option: unknown) =>
              typeof option !== "string" || option.trim().length === 0
            ) ||
            typeof question.answerIndex !== "number" ||
            !Number.isInteger(question.answerIndex) ||
            question.answerIndex < 0 ||
            question.answerIndex > 3 ||
            typeof question.explanation !== "string" ||
            question.explanation.trim().length === 0
          )
        ) {
          throw new Error("Invalid quiz structure");
        }
        return jsonResponse(200, { questions: quiz.questions });
      } catch (error) {
        console.error("Gemini returned an invalid quiz response", {
          model,
          error: error instanceof Error
            ? error.message
            : "Unknown response error",
        });
        lastProviderMessage =
          "Gemini returned an incomplete or invalid quiz. Try fewer questions.";
        continue;
      }
    }
  }

  if (attemptedResponses > 0 && rateLimitedKeys === attemptedResponses) {
    return new Response(
      JSON.stringify({
        error:
          "All attempted Gemini models and API keys are currently rate-limited.",
      }),
      { status: 503, headers: { ...corsHeaders, "Retry-After": "60" } },
    );
  }
  if (attemptedResponses > 0 && overloadedKeys === attemptedResponses) {
    return new Response(
      JSON.stringify({
        error:
          "All attempted Gemini models are temporarily overloaded. Please wait a minute and try again.",
      }),
      { status: 503, headers: { ...corsHeaders, "Retry-After": "60" } },
    );
  }
  if (
    attemptedResponses > 0 && rejectedKeys === attemptedResponses &&
    lastProviderMessage
  ) {
    return jsonResponse(502, {
      error:
        `Gemini rejected all attempted API keys (HTTP ${lastProviderStatus}). ` +
        lastProviderMessage,
    });
  }
  if (networkFailures === geminiKeys.length) {
    return jsonResponse(504, {
      error:
        "All configured Gemini keys timed out or could not connect. Try again shortly.",
    });
  }
  if (lastProviderStatus > 0 && lastProviderMessage) {
    return jsonResponse(502, {
      error:
        `Gemini could not generate the quiz after trying available models and configured keys (last HTTP ${lastProviderStatus}). ` +
        lastProviderMessage,
    });
  }
  if (lastProviderStatus > 0) {
    return jsonResponse(502, {
      error:
        `Gemini could not generate the quiz after trying available models and configured keys (last HTTP ${lastProviderStatus}).`,
    });
  }
  if (networkFailures > 0) {
    return jsonResponse(504, {
      error:
        "Gemini requests timed out or could not connect. Try again shortly.",
    });
  }
  return jsonResponse(502, {
    error:
      "Could not reach Gemini. Check the Edge Function logs or try again shortly.",
  });
});
