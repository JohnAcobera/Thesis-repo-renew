-- Run after learner_points.sql, quiz_attempts.sql, and learning_streak.sql.
-- This idempotently imports the existing quiz attempts and login days into
-- the learner-points ledger. Unlinked attempts are grouped by user, title,
-- and source file because they do not have a quiz_id.
begin;

with grouped_attempts as (
  select
    a.id,
    a.user_id,
    a.quiz_id,
    a.title,
    a.source_file,
    a.score,
    a.total_questions,
    a.created_at,
    case
      when a.quiz_id is not null then 'quiz:' || a.quiz_id::text
      else 'legacy:' || md5(
        lower(trim(a.title)) || chr(31) || lower(trim(a.source_file))
      )
    end as quiz_group_key
  from public.quiz_attempts a
),
ranked_attempts as (
  select
    grouped_attempts.*,
    row_number() over (
      partition by user_id, quiz_group_key
      order by created_at, id
    ) as attempt_number
  from grouped_attempts
),
first_second_awards as (
  select
    user_id,
    case attempt_number
      when 1 then 'quiz_first_attempt'
      when 2 then 'quiz_second_attempt'
    end as event_type,
    case attempt_number
      when 1 then 50
      when 2 then 25
    end as points_delta,
    case attempt_number
      when 1 then 'quiz_first_attempt:'
      when 2 then 'quiz_second_attempt:'
    end || id::text as source_key,
    jsonb_build_object(
      'attempt_id', id,
      'quiz_group_key', quiz_group_key,
      'attempt_number', attempt_number
    ) as details,
    created_at
  from ranked_attempts
  where attempt_number in (1, 2)
),
score_reward_awards as (
  select
    user_id,
    'quiz_score_reward'::text as event_type,
    round(score::numeric * 100 / total_questions)::integer as points_delta,
    'quiz_score:' || id::text as source_key,
    jsonb_build_object(
      'attempt_id', id,
      'score_percentage',
      round(score::numeric * 100 / total_questions)
    ) as details,
    created_at
  from public.quiz_attempts
),
perfect_quiz_awards as (
  select
    user_id,
    'perfect_quiz'::text as event_type,
    150 as points_delta,
    'perfect_quiz:' || quiz_group_key as source_key,
    jsonb_build_object(
      'quiz_group_key', quiz_group_key,
      'perfect_attempt_id', id
    ) as details,
    created_at
  from (
    select
      grouped_attempts.*,
      row_number() over (
        partition by user_id, quiz_group_key
        order by created_at, id
      ) as perfect_attempt_number
    from grouped_attempts
    where score = total_questions
  ) perfect_attempts
  where perfect_attempt_number = 1
),
numbered_login_days as (
  select
    user_id,
    login_date,
    login_date - row_number() over (
      partition by user_id
      order by login_date
    )::integer as streak_group
  from public.user_login_days
),
streaked_login_days as (
  select
    user_id,
    login_date,
    row_number() over (
      partition by user_id, streak_group
      order by login_date
    ) as streak_length
  from numbered_login_days
),
login_day_awards as (
  select
    user_id,
    'daily_login_streak'::text as event_type,
    (100 * least(streak_length, 7))::integer as points_delta,
    'daily_login_streak:' || login_date::text as source_key,
    jsonb_build_object(
      'login_date', login_date,
      'streak_length', streak_length,
      'effective_streak_length', least(streak_length, 7),
      'max_streak_multiplier', 7,
      'points_per_streak_day', 100
    ) as details,
    login_date::timestamptz as created_at
  from streaked_login_days
),
all_awards as (
  select * from first_second_awards
  union all
  select * from score_reward_awards
  union all
  select * from perfect_quiz_awards
  union all
  select * from login_day_awards
)
insert into public.learner_point_transactions (
  user_id,
  event_type,
  points_delta,
  source_key,
  details,
  created_at
)
select
  user_id,
  event_type,
  points_delta,
  source_key,
  details,
  created_at
from all_awards
on conflict (user_id, source_key) do nothing;

commit;
