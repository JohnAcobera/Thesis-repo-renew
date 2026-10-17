-- Cap daily login-streak awards at 7x (+700 LP per login day).
-- Run once after learner_points_automation.sql.
begin;

update public.learner_point_transactions
set
  points_delta = least((details->>'streak_length')::integer, 7) * 100,
  details = details || jsonb_build_object(
    'effective_streak_length',
    least((details->>'streak_length')::integer, 7),
    'max_streak_multiplier',
    7
  )
where event_type = 'daily_login_streak'
  and details ? 'streak_length';

create or replace function public.award_login_day_learner_points()
returns trigger
language plpgsql
security definer
set search_path = public
as $$
declare
  current_streak integer;
begin
  with recursive consecutive_days(login_date, streak_length) as (
    select new.login_date, 1
    union all
    select d.login_date, c.streak_length + 1
    from consecutive_days c
    join public.user_login_days d
      on d.user_id = new.user_id
     and d.login_date = c.login_date - 1
  )
  select max(streak_length) into current_streak
  from consecutive_days;

  insert into public.learner_point_transactions (
    user_id, event_type, points_delta, source_key, details, created_at
  ) values (
    new.user_id,
    'daily_login_streak',
    100 * least(current_streak, 7),
    'daily_login_streak:' || new.login_date::text,
    jsonb_build_object(
      'login_date', new.login_date,
      'streak_length', current_streak,
      'effective_streak_length', least(current_streak, 7),
      'max_streak_multiplier', 7,
      'points_per_streak_day', 100
    ),
    new.login_date::timestamptz
  )
  on conflict (user_id, source_key) do nothing;

  return new;
end;
$$;

commit;
