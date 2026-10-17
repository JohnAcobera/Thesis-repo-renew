-- Run once to convert the previous learner-points rules to additive rewards.
-- Then run the updated learner_points_automation.sql to install its triggers
-- and the per-attempt reward lookup function.
begin;

alter table public.learner_point_transactions
  drop constraint if exists learner_point_transactions_event_type_check;
alter table public.learner_point_transactions
  drop constraint if exists learner_point_transactions_fixed_awards_check;
alter table public.learner_point_transactions
  drop constraint if exists learner_point_transactions_nonnegative_check;

update public.learner_point_transactions
set points_delta = 25
where event_type = 'quiz_second_attempt'
  and points_delta = -25;

delete from public.learner_point_transactions
where event_type = 'quiz_score_average';

alter table public.learner_point_transactions
  add constraint learner_point_transactions_event_type_check
  check (
    event_type in (
      'quiz_first_attempt',
      'quiz_second_attempt',
      'perfect_quiz',
      'quiz_score_reward',
      'daily_login_streak'
    )
  );

alter table public.learner_point_transactions
  add constraint learner_point_transactions_fixed_awards_check check (
    (event_type <> 'quiz_first_attempt' or points_delta = 50)
    and (event_type <> 'quiz_second_attempt' or points_delta = 25)
    and (event_type <> 'perfect_quiz' or points_delta = 150)
  );

alter table public.learner_point_transactions
  add constraint learner_point_transactions_nonnegative_check
  check (points_delta >= 0);

insert into public.learner_point_transactions (
  user_id,
  event_type,
  points_delta,
  source_key,
  details,
  created_at
)
select
  a.user_id,
  'quiz_score_reward',
  round(a.score::numeric * 100 / a.total_questions)::integer,
  'quiz_score:' || a.id::text,
  jsonb_build_object(
    'attempt_id', a.id,
    'score_percentage',
    round(a.score::numeric * 100 / a.total_questions)
  ),
  a.created_at
from public.quiz_attempts a
on conflict (user_id, source_key) do nothing;

commit;
