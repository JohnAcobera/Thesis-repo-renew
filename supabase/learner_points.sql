-- Ledger of learner point changes. A source key prevents duplicate rewards
-- when an event is retried (for example, one perfect-quiz reward per quiz).
-- Fixed awards: first quiz attempt +50, second attempt +25, perfect quiz +150.
-- Each attempt also earns LP equal to its rounded score percentage. Later
-- attempts receive no attempt-number award.
create table if not exists public.learner_point_transactions (
  id uuid primary key default gen_random_uuid(),
  user_id bigint not null references public.users(id) on delete cascade,
  event_type text not null check (
    event_type in (
      'quiz_first_attempt',
      'quiz_second_attempt',
      'perfect_quiz',
      'quiz_score_reward',
      'daily_login_streak'
    )
  ),
  points_delta integer not null,
  source_key text not null,
  details jsonb not null default '{}'::jsonb,
  created_at timestamptz not null default now(),
  constraint learner_point_transactions_fixed_awards_check check (
    (event_type <> 'quiz_first_attempt' or points_delta = 50)
    and (event_type <> 'quiz_second_attempt' or points_delta = 25)
    and (event_type <> 'perfect_quiz' or points_delta = 150)
  ),
  constraint learner_point_transactions_nonnegative_check
    check (points_delta >= 0),
  unique (user_id, source_key)
);

create index if not exists learner_point_transactions_user_created_idx
  on public.learner_point_transactions (user_id, created_at desc);

alter table public.learner_point_transactions enable row level security;
revoke all on table public.learner_point_transactions from anon, authenticated;

create or replace view public.user_learner_point_totals as
select
  u.id as user_id,
  u.full_name,
  coalesce(sum(lp.points_delta), 0)::bigint as total_learner_points,
  max(lp.created_at) as last_points_updated_at
from public.users u
left join public.learner_point_transactions lp on lp.user_id = u.id
group by u.id, u.full_name;

revoke all on public.user_learner_point_totals from anon, authenticated;

create or replace function public.get_learner_points(p_session_token text)
returns integer
language plpgsql
security definer
set search_path = public
as $$
declare
  verified_user_id bigint;
  point_balance integer;
begin
  select user_id into verified_user_id
  from public.user_sessions
  where session_token = p_session_token and expires_at > now()
  limit 1;

  if verified_user_id is null then
    raise exception 'Invalid or expired session';
  end if;

  select total_learner_points::integer into point_balance
  from public.user_learner_point_totals
  where user_id = verified_user_id;

  return coalesce(point_balance, 0);
end;
$$;

revoke all on function public.get_learner_points(text) from public;
grant execute on function public.get_learner_points(text) to anon, authenticated;

-- Example balance query for a known user:
-- select coalesce(sum(points_delta), 0)::integer as learner_points
-- from public.learner_point_transactions
-- where user_id = 123;
