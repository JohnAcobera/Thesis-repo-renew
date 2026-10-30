-- Run after learner_points.sql, quiz_attempts.sql, and learning_streak.sql.
-- Run learner_points_backfill.sql first if historical activity has not yet
-- been imported. These triggers award LP for activity recorded afterward.

create or replace function public.lock_quiz_learner_points()
returns trigger
language plpgsql
security definer
set search_path = public
as $$
begin
  perform pg_advisory_xact_lock(
    hashtextextended(new.user_id::text, 1)
  );
  return new;
end;
$$;

revoke all on function public.lock_quiz_learner_points() from public;

drop trigger if exists quiz_attempts_lock_learner_points
  on public.quiz_attempts;
create trigger quiz_attempts_lock_learner_points
before insert on public.quiz_attempts
for each row execute function public.lock_quiz_learner_points();

create or replace function public.award_quiz_learner_points()
returns trigger
language plpgsql
security definer
set search_path = public
as $$
declare
  quiz_group_key text;
  attempt_number bigint;
  award_type text;
  award_points integer;
begin
  if new.quiz_id is not null then
    quiz_group_key := 'quiz:' || new.quiz_id::text;
  else
    quiz_group_key := 'legacy:' || md5(
      lower(trim(new.title)) || chr(31) || lower(trim(new.source_file))
    );
  end if;

  select count(*) into attempt_number
  from public.quiz_attempts a
  where a.user_id = new.user_id
    and case
      when a.quiz_id is not null then 'quiz:' || a.quiz_id::text
      else 'legacy:' || md5(
        lower(trim(a.title)) || chr(31) || lower(trim(a.source_file))
      )
    end = quiz_group_key
    and (a.created_at, a.id) <= (new.created_at, new.id);

  if attempt_number = 1 then
    award_type := 'quiz_first_attempt';
    award_points := 50;
  elsif attempt_number = 2 then
    award_type := 'quiz_second_attempt';
    award_points := 25;
  else
    award_type := null;
  end if;

  if award_type is not null then
    insert into public.learner_point_transactions (
      user_id, event_type, points_delta, source_key, details, created_at
    ) values (
      new.user_id,
      award_type,
      award_points,
      award_type || ':' || new.id::text,
      jsonb_build_object(
        'attempt_id', new.id,
        'quiz_group_key', quiz_group_key,
        'attempt_number', attempt_number
      ),
      new.created_at
    )
    on conflict (user_id, source_key) do nothing;
  end if;

  if new.score = new.total_questions then
    insert into public.learner_point_transactions (
      user_id, event_type, points_delta, source_key, details, created_at
    ) values (
      new.user_id,
      'perfect_quiz',
      150,
      'perfect_quiz:' || quiz_group_key,
      jsonb_build_object(
        'quiz_group_key', quiz_group_key,
        'perfect_attempt_id', new.id
      ),
      new.created_at
    )
    on conflict (user_id, source_key) do nothing;
  end if;

  insert into public.learner_point_transactions (
    user_id, event_type, points_delta, source_key, details, created_at
  ) values (
    new.user_id,
    'quiz_score_reward',
    round(new.score::numeric * 100 / new.total_questions)::integer,
    'quiz_score:' || new.id::text,
    jsonb_build_object(
      'attempt_id', new.id,
      'score_percentage',
      round(new.score::numeric * 100 / new.total_questions)
    ),
    new.created_at
  )
  on conflict (user_id, source_key) do nothing;

  return new;
end;
$$;

revoke all on function public.award_quiz_learner_points() from public;

drop trigger if exists quiz_attempts_award_learner_points
  on public.quiz_attempts;
create trigger quiz_attempts_award_learner_points
after insert on public.quiz_attempts
for each row execute function public.award_quiz_learner_points();

create or replace function public.lock_login_day_learner_points()
returns trigger
language plpgsql
security definer
set search_path = public
as $$
begin
  perform pg_advisory_xact_lock(
    hashtextextended('login:' || new.user_id::text, 1)
  );
  return new;
end;
$$;

revoke all on function public.lock_login_day_learner_points() from public;

drop trigger if exists user_login_days_lock_learner_points
  on public.user_login_days;
create trigger user_login_days_lock_learner_points
before insert on public.user_login_days
for each row execute function public.lock_login_day_learner_points();

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

revoke all on function public.award_login_day_learner_points() from public;

drop trigger if exists user_login_days_award_learner_points
  on public.user_login_days;
create trigger user_login_days_award_learner_points
after insert on public.user_login_days
for each row execute function public.award_login_day_learner_points();

drop function if exists public.get_quiz_attempt_learner_points(
  text, uuid, uuid
);

create or replace function public.get_quiz_attempt_learner_points(
  p_session_token text,
  p_quiz_id uuid
) returns integer
language plpgsql
security definer
set search_path = public
as $$
declare
  verified_user_id bigint;
  saved_attempt_id uuid;
  earned_points integer;
begin
  select user_id into verified_user_id
  from public.user_sessions
  where session_token = p_session_token and expires_at > now()
  limit 1;

  if verified_user_id is null then
    raise exception 'Invalid or expired session';
  end if;

  select id into saved_attempt_id
  from public.quiz_attempts
  where user_id = verified_user_id
    and quiz_id = p_quiz_id
  order by created_at desc, id desc
  limit 1;

  if saved_attempt_id is null then
    raise exception 'Saved quiz attempt not found';
  end if;

  select coalesce(sum(points_delta), 0)::integer into earned_points
  from public.learner_point_transactions
  where user_id = verified_user_id
    and (
      details->>'attempt_id' = saved_attempt_id::text
      or details->>'perfect_attempt_id' = saved_attempt_id::text
    );

  return earned_points;
end;
$$;

revoke all on function public.get_quiz_attempt_learner_points(
  text, uuid
) from public;
grant execute on function public.get_quiz_attempt_learner_points(
  text, uuid
) to anon, authenticated;

notify pgrst, 'reload schema';
