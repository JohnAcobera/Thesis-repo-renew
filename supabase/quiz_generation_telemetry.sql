create table if not exists public.quiz_generation_attempts (
  id uuid primary key default gen_random_uuid(),
  request_id uuid not null,
  attempt_number integer not null check (attempt_number > 0),
  generation_type text not null default 'quiz',
  api_key_label text,
  model text not null,
  is_key_failover boolean not null default false,
  is_winner boolean not null default false,
  requested_item_count integer not null,
  generated_item_count integer,
  accepted_item_count integer not null default 0,
  requested_question_count integer
    check (
      requested_question_count is null
      or requested_question_count between 1 and 30
    ),
  generated_question_count integer
    check (generated_question_count is null or generated_question_count >= 0),
  accepted_question_count integer default 0
    check (
      accepted_question_count is null
      or (
        accepted_question_count >= 0
        and (
          requested_question_count is null
          or accepted_question_count <= requested_question_count
        )
      )
    ),
  latency_ms integer not null check (latency_ms >= 0),
  outcome text not null check (outcome in (
    'success',
    'rate_limit',
    'overload',
    'network',
    'invalid_output',
    'not_found',
    'auth',
    'bad_request',
    'cancelled'
  )),
  failure_kind text check (failure_kind is null or failure_kind in (
    'rate_limit',
    'overload',
    'network',
    'invalid_output',
    'not_found',
    'auth',
    'bad_request',
    'cancelled'
  )),
  http_status integer,
  validation_error text,
  prompt_tokens bigint check (prompt_tokens is null or prompt_tokens >= 0),
  completion_tokens bigint
    check (completion_tokens is null or completion_tokens >= 0),
  total_tokens bigint check (total_tokens is null or total_tokens >= 0),
  source_char_count integer not null check (source_char_count >= 0),
  created_at timestamptz not null default now(),
  constraint quiz_generation_attempts_request_attempt_key
    unique (request_id, attempt_number),
  constraint quiz_generation_attempts_winner_check
    check (
      not is_winner
      or (
        outcome = 'success'
        and accepted_item_count > 0
        and accepted_item_count <= requested_item_count
      )
    )
);

drop view if exists public.quiz_generation_model_performance;

alter table public.quiz_generation_attempts
  add column if not exists generation_type text not null default 'quiz',
  add column if not exists api_key_label text,
  add column if not exists is_key_failover boolean not null default false,
  add column if not exists requested_item_count integer,
  add column if not exists generated_item_count integer,
  add column if not exists accepted_item_count integer not null default 0;

update public.quiz_generation_attempts
set requested_item_count = requested_question_count,
    generated_item_count = generated_question_count,
    accepted_item_count = accepted_question_count
where requested_item_count is null;

alter table public.quiz_generation_attempts
  alter column requested_item_count set not null;

alter table public.quiz_generation_attempts
  drop constraint if exists quiz_generation_attempts_requested_question_count_check,
  drop constraint if exists quiz_generation_attempts_check,
  alter column requested_question_count drop not null,
  alter column accepted_question_count drop not null;

alter table public.quiz_generation_attempts
  drop constraint if exists quiz_generation_attempts_generation_type_check,
  drop constraint if exists quiz_generation_attempts_requested_item_count_check,
  drop constraint if exists quiz_generation_attempts_generated_item_count_check,
  drop constraint if exists quiz_generation_attempts_accepted_item_count_check,
  drop constraint if exists quiz_generation_attempts_winner_check;

alter table public.quiz_generation_attempts
  add constraint quiz_generation_attempts_generation_type_check
    check (generation_type in (
      'quiz', 'true_false', 'mixed_quiz', 'matching', 'flashcards', 'handout'
    )),
  add constraint quiz_generation_attempts_requested_item_count_check
    check (requested_item_count between 1 and 30),
  add constraint quiz_generation_attempts_generated_item_count_check
    check (generated_item_count is null or generated_item_count >= 0),
  add constraint quiz_generation_attempts_accepted_item_count_check
    check (
      accepted_item_count >= 0
      and accepted_item_count <= requested_item_count
    ),
  add constraint quiz_generation_attempts_winner_check
    check (
      not is_winner
      or (
        outcome = 'success'
        and accepted_item_count > 0
        and accepted_item_count <= requested_item_count
      )
    );

alter table public.quiz_generation_attempts
    drop column if exists request_duration_ms;

drop index if exists public.quiz_generation_attempts_model_hedge_created_idx;
alter table public.quiz_generation_attempts
  drop column if exists is_hedge,
  drop column if exists hedges_started,
  drop column if exists provider;

create index if not exists quiz_generation_attempts_created_idx
  on public.quiz_generation_attempts (created_at desc);
create unique index if not exists quiz_generation_attempts_one_winner_idx
  on public.quiz_generation_attempts (request_id)
  where is_winner;

alter table public.quiz_generation_attempts enable row level security;
revoke all on table public.quiz_generation_attempts from public, anon, authenticated;
grant insert, select on table public.quiz_generation_attempts to service_role;

drop function if exists public.reserve_quiz_generation_tokens(uuid, uuid, integer);
drop function if exists public.settle_quiz_generation_tokens(uuid, integer);
drop table if exists public.quiz_generation_token_reservations;

create or replace view public.quiz_generation_model_performance
with (security_invoker = true)
as
select
  generation_type,
  api_key_label,
  model,
  count(*) as attempt_count,
  count(*) filter (where outcome <> 'cancelled') as completed_attempt_count,
  count(*) filter (where outcome = 'cancelled') as cancelled_attempt_count,
  count(*) filter (where outcome = 'success') as successful_attempt_count,
  count(*) filter (where outcome = 'invalid_output') as invalid_output_count,
  round(
    100.0 * count(*) filter (where outcome = 'success')
      / nullif(count(*) filter (where outcome <> 'cancelled'), 0),
    2
  ) as successful_attempt_rate_pct,
  count(*) filter (where is_winner) as winner_count,
  round(avg(latency_ms) filter (where outcome <> 'cancelled'), 2)
    as avg_latency_ms,
  round(
    (percentile_cont(0.50) within group (order by latency_ms)
      filter (where outcome <> 'cancelled'))::numeric,
    2
  ) as p50_latency_ms,
  round(
    (percentile_cont(0.90) within group (order by latency_ms)
      filter (where outcome <> 'cancelled'))::numeric,
    2
  ) as p90_latency_ms,
  coalesce(sum(generated_item_count), 0) as generated_item_count,
  coalesce(sum(accepted_item_count), 0) as accepted_item_count,
  coalesce(
    sum(generated_question_count)
      filter (where generation_type in ('quiz', 'true_false', 'mixed_quiz')),
    0
  ) as generated_question_count,
  coalesce(
    sum(accepted_question_count)
      filter (where generation_type in ('quiz', 'true_false', 'mixed_quiz')),
    0
  ) as accepted_question_count,
  count(*) filter (where is_key_failover) as key_failover_attempt_count,
  count(distinct request_id) filter (where is_key_failover)
    as key_failover_request_count,
  round(avg(requested_item_count), 2) as avg_requested_item_count,
  round(avg(requested_question_count)
      filter (where generation_type in ('quiz', 'true_false', 'mixed_quiz')), 2)
    as avg_requested_question_count,
  round(avg(source_char_count), 2) as avg_source_char_count
from public.quiz_generation_attempts
where api_key_label is not null
group by generation_type, api_key_label, model;

revoke all on table public.quiz_generation_model_performance
  from public, anon, authenticated;
grant select on table public.quiz_generation_model_performance to service_role;

create or replace view public.quiz_generation_model_latency_range
with (security_invoker = true)
as
select
  model,
  count(*) as attempt_count,
  count(*) filter (where outcome <> 'cancelled') as latency_sample_count,
  min(latency_ms) filter (where outcome <> 'cancelled') as min_latency_ms,
  max(latency_ms) filter (where outcome <> 'cancelled') as max_latency_ms
from public.quiz_generation_attempts
where api_key_label is not null
group by model;

revoke all on table public.quiz_generation_model_latency_range
  from public, anon, authenticated;
grant select on table public.quiz_generation_model_latency_range to service_role;

drop view if exists public.quiz_generation_model_attempt_summary;

create or replace view public.quiz_generation_model_attempt_summary
with (security_invoker = true)
as
select
  model,
  count(*) as attempt_count,
  round(
    100.0 * count(*) filter (where outcome = 'success')
      / nullif(count(*) filter (where outcome <> 'cancelled'), 0),
    2
  ) as success_rate_pct,
  round(avg(latency_ms) filter (where outcome <> 'cancelled'), 2)
    as avg_latency_ms,
  round(
    (percentile_cont(0.50) within group (order by latency_ms)
      filter (where outcome <> 'cancelled'))::numeric,
    2
  ) as p50_latency_ms,
  round(
    (percentile_cont(0.90) within group (order by latency_ms)
      filter (where outcome <> 'cancelled'))::numeric,
    2
  ) as p90_latency_ms
from public.quiz_generation_attempts
where api_key_label is not null
  and created_at >= (
    ((now() at time zone 'Asia/Manila')::date - 1 + time '20:00')
      at time zone 'Asia/Manila'
  )
group by model;

revoke all on table public.quiz_generation_model_attempt_summary
  from public, anon, authenticated;
grant select on table public.quiz_generation_model_attempt_summary to service_role;
