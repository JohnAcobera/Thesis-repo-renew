import { createClient } from "https://esm.sh/@supabase/supabase-js@2";

export type GenerationType =
  | "quiz"
  | "true_false"
  | "mixed_quiz"
  | "matching"
  | "flashcards"
  | "handout";

export type GenerationAttemptTelemetry = {
  attempt_number: number;
  generation_type: GenerationType;
  api_key_label: string;
  model: string;
  is_key_failover: boolean;
  is_winner: boolean;
  requested_item_count: number;
  generated_item_count: number | null;
  accepted_item_count: number;
  requested_question_count: number | null;
  generated_question_count: number | null;
  accepted_question_count: number | null;
  latency_ms: number;
  outcome: string;
  failure_kind: string | null;
  http_status: number | null;
  validation_error: string | null;
  prompt_tokens: number | null;
  completion_tokens: number | null;
  total_tokens: number | null;
  source_char_count: number;
};

const supabaseUrl = Deno.env.get("SUPABASE_URL");
const serviceRoleKey = Deno.env.get("SUPABASE_SERVICE_ROLE_KEY");
const telemetryClient = supabaseUrl && serviceRoleKey
  ? createClient(supabaseUrl, serviceRoleKey, {
    auth: { autoRefreshToken: false, persistSession: false },
  })
  : null;

export async function insertGenerationTelemetry(
  requestId: string,
  rows: GenerationAttemptTelemetry[],
): Promise<void> {
  if (rows.length === 0) return;

  if (!telemetryClient) {
    console.error(
      "Generation telemetry was not persisted: SUPABASE_SERVICE_ROLE_KEY is not configured.",
      { requestId, attemptCount: rows.length },
    );
    return;
  }

  try {
    const { error } = await telemetryClient
      .from("quiz_generation_attempts")
      .insert(rows.map((row) => ({ ...row, request_id: requestId })));
    if (error) {
      console.error("Generation telemetry insert failed.", {
        requestId,
        error: error.message,
      });
    }
  } catch (error) {
    console.error("Generation telemetry insert failed.", {
      requestId,
      error: error instanceof Error ? error.message : "Unknown error",
    });
  }
}
