-- Run after custom_auth.sql, quiz_attempts.sql, learning_inventory.sql,
-- learner_points.sql, learner_points_leaderboard.sql, and learning_streak.sql.
create table if not exists public.student_achievement_badges (
  user_id bigint not null references public.users(id) on delete cascade,
  badge_id text not null check (
    badge_id in (
      'FirstPerfect',
      'FirstStep',
      'FlashcardStarter',
      'FlawlessFive',
      'MatchMaker',
      'Podium',
      'QuizLegend',
      'QuizMaster',
      'QuizRegular',
      'QuizRookie',
      'QuizVeteran',
      'StudyMixer',
      'EarlyBird',
      'NightOwl',
      'PerfectWeek',
      'Marathon',
      'LuckySeven',
      'WeekendScholar',
      'WarmingUp',
      'FortnightFocus',
      'PointCollector'
    )
  ),
  earned_at timestamptz not null default now(),
  primary key (user_id, badge_id)
);

alter table public.student_achievement_badges
  drop constraint if exists student_achievement_badges_badge_id_check;
alter table public.student_achievement_badges
  add constraint student_achievement_badges_badge_id_check
  check (badge_id in (
    'FirstPerfect',
    'FirstStep',
    'FlashcardStarter',
    'FlawlessFive',
    'MatchMaker',
    'Podium',
    'QuizLegend',
    'QuizMaster',
    'QuizRegular',
    'QuizRookie',
    'QuizVeteran',
    'StudyMixer',
    'EarlyBird',
    'NightOwl',
    'PerfectWeek',
    'Marathon',
    'LuckySeven',
    'WeekendScholar',
    'WarmingUp',
    'FortnightFocus',
    'PointCollector'
  ));

alter table public.student_achievement_badges enable row level security;
revoke all on table public.student_achievement_badges from anon, authenticated;

create index if not exists learning_inventory_attempts_user_created_idx
  on public.learning_inventory_attempts (user_id, created_at desc);

create or replace function public.refresh_student_achievement_badges(
  p_user_id bigint
) returns void
language plpgsql
security definer
set search_path = public
as $$
declare
  week_start timestamptz;
  week_end timestamptz;
  total_answered_questions bigint;
  longest_learning_streak bigint;
  total_learner_points bigint;
  weekly_rank bigint;
  weekly_points bigint;
  earned_badge_ids text[] := '{}';
begin
  if not exists (
    select 1
    from public.users as user_account
    where user_account.id = p_user_id
      and user_account.role = 'student'
  ) then
    return;
  end if;

  week_start := date_trunc('week', now());
  week_end := week_start + interval '1 week';

  if exists (
    select 1
    from public.quiz_attempts as attempt
    where attempt.user_id = p_user_id
  ) then
    earned_badge_ids := array_append(earned_badge_ids, 'FirstStep');
  end if;

  if exists (
    select 1
    from public.quiz_attempts as attempt
    where attempt.user_id = p_user_id
      and attempt.total_questions > 0
      and attempt.score = attempt.total_questions
  ) then
    earned_badge_ids := array_append(earned_badge_ids, 'FirstPerfect');
  end if;

  if (
    select count(distinct attempt.quiz_id)
    from public.quiz_attempts as attempt
    where attempt.user_id = p_user_id
      and attempt.quiz_id is not null
      and attempt.total_questions > 0
      and attempt.score = attempt.total_questions
  ) >= 5 then
    earned_badge_ids := array_append(earned_badge_ids, 'FlawlessFive');
  end if;

  if exists (
    select 1
    from public.quiz_attempts as attempt
    where attempt.user_id = p_user_id
      and (attempt.created_at at time zone 'Asia/Manila')::time
        < time '08:00:00'
  ) then
    earned_badge_ids := array_append(earned_badge_ids, 'EarlyBird');
  end if;

  if exists (
    select 1
    from public.quiz_attempts as attempt
    where attempt.user_id = p_user_id
      and (attempt.created_at at time zone 'Asia/Manila')::time
        > time '22:00:00'
  ) then
    earned_badge_ids := array_append(earned_badge_ids, 'NightOwl');
  end if;

  if exists (
    select 1
    from public.quiz_attempts as attempt
    where attempt.user_id = p_user_id
      and attempt.score = 7
  ) then
    earned_badge_ids := array_append(earned_badge_ids, 'LuckySeven');
  end if;

  if exists (
    select 1
    from public.quiz_attempts as attempt
    where attempt.user_id = p_user_id
    group by (attempt.created_at at time zone 'Asia/Manila')::date
    having count(*) >= 5
  ) then
    earned_badge_ids := array_append(earned_badge_ids, 'Marathon');
  end if;

  if exists (
    select 1
    from public.quiz_attempts as attempt
    where attempt.user_id = p_user_id
    group by date_trunc(
      'week',
      attempt.created_at at time zone 'Asia/Manila'
    )
    having bool_or(
      extract(dow from attempt.created_at at time zone 'Asia/Manila') = 6
    ) and bool_or(
      extract(dow from attempt.created_at at time zone 'Asia/Manila') = 0
    )
  ) then
    earned_badge_ids := array_append(earned_badge_ids, 'WeekendScholar');
  end if;

  select coalesce(sum(attempt.total_questions), 0)
    into total_answered_questions
  from public.quiz_attempts as attempt
  where attempt.user_id = p_user_id;

  if total_answered_questions >= 50 then
    earned_badge_ids := array_append(earned_badge_ids, 'QuizRookie');
  end if;
  if total_answered_questions >= 100 then
    earned_badge_ids := array_append(earned_badge_ids, 'QuizRegular');
  end if;
  if total_answered_questions >= 150 then
    earned_badge_ids := array_append(earned_badge_ids, 'QuizVeteran');
  end if;
  if total_answered_questions >= 250 then
    earned_badge_ids := array_append(earned_badge_ids, 'QuizMaster');
  end if;
  if total_answered_questions >= 300 then
    earned_badge_ids := array_append(earned_badge_ids, 'QuizLegend');
  end if;

  with streak_groups as (
    select
      login_day.login_date
        - row_number() over (order by login_day.login_date)::integer
          as streak_group
    from public.user_login_days as login_day
    where login_day.user_id = p_user_id
  )
  select coalesce(max(streak_length), 0)
    into longest_learning_streak
  from (
    select count(*) as streak_length
    from streak_groups
    group by streak_group
  ) as streaks;

  if longest_learning_streak >= 3 then
    earned_badge_ids := array_append(earned_badge_ids, 'WarmingUp');
  end if;
  if longest_learning_streak >= 7 then
    earned_badge_ids := array_append(earned_badge_ids, 'PerfectWeek');
  end if;
  if longest_learning_streak >= 14 then
    earned_badge_ids := array_append(earned_badge_ids, 'FortnightFocus');
  end if;

  if exists (
    select 1
    from public.learning_inventory_attempts as attempt
    join public.learning_inventory_items as item
      on item.id = attempt.item_id
    where attempt.user_id = p_user_id
      and item.item_type = 'flashcards'
  ) then
    earned_badge_ids := array_append(earned_badge_ids, 'FlashcardStarter');
  end if;

  if exists (
    select 1
    from public.learning_inventory_attempts as attempt
    join public.learning_inventory_items as item
      on item.id = attempt.item_id
    where attempt.user_id = p_user_id
      and item.item_type = 'matching'
  ) then
    earned_badge_ids := array_append(earned_badge_ids, 'MatchMaker');
  end if;

  select ranked.position, ranked.points
    into weekly_rank, weekly_points
  from (
    select
      student.id,
      coalesce(sum(points.points_delta), 0)::bigint as points,
      row_number() over (
        order by coalesce(sum(points.points_delta), 0) desc,
          student.full_name,
          student.id
      ) as position
    from public.users as student
    left join public.learner_point_transactions as points
      on points.user_id = student.id
      and points.created_at >= week_start
      and points.created_at < week_end
    where student.role = 'student'
    group by student.id, student.full_name
  ) as ranked
  where ranked.id = p_user_id;

  if weekly_rank <= 3 and weekly_points > 0 then
    earned_badge_ids := array_append(earned_badge_ids, 'Podium');
  end if;

  select coalesce(sum(points.points_delta), 0)
    into total_learner_points
  from public.learner_point_transactions as points
  where points.user_id = p_user_id;

  if total_learner_points >= 10000 then
    earned_badge_ids := array_append(earned_badge_ids, 'PointCollector');
  end if;

  if exists (
    select 1
    from public.quiz_attempts as attempt
    where attempt.user_id = p_user_id
      and attempt.created_at >= week_start
      and attempt.created_at < week_end
  ) and exists (
    select 1
    from public.learning_inventory_attempts as attempt
    join public.learning_inventory_items as item
      on item.id = attempt.item_id
    where attempt.user_id = p_user_id
      and item.item_type = 'flashcards'
      and attempt.created_at >= week_start
      and attempt.created_at < week_end
  ) and exists (
    select 1
    from public.learning_inventory_attempts as attempt
    join public.learning_inventory_items as item
      on item.id = attempt.item_id
    where attempt.user_id = p_user_id
      and item.item_type = 'matching'
      and attempt.created_at >= week_start
      and attempt.created_at < week_end
  ) then
    earned_badge_ids := array_append(earned_badge_ids, 'StudyMixer');
  end if;

  insert into public.student_achievement_badges (user_id, badge_id)
  select p_user_id, earned_badge.badge_id
  from unnest(earned_badge_ids) as earned_badge(badge_id)
  on conflict (user_id, badge_id) do nothing;
end;
$$;

revoke all on function public.refresh_student_achievement_badges(bigint)
  from public;

delete from public.student_achievement_badges as award
where award.badge_id = 'Podium'
  and not exists (
    select 1
    from lateral (
      select
        student.id,
        coalesce(sum(points.points_delta), 0)::bigint as weekly_points,
        row_number() over (
          order by coalesce(sum(points.points_delta), 0) desc,
            student.full_name,
            student.id
        ) as position
      from public.users as student
      left join public.learner_point_transactions as points
        on points.user_id = student.id
        and points.created_at >= date_trunc('week', award.earned_at)
        and points.created_at <
          date_trunc('week', award.earned_at) + interval '1 week'
      where student.role = 'student'
      group by student.id, student.full_name
    ) as ranked
    where ranked.id = award.user_id
      and ranked.position <= 3
      and ranked.weekly_points > 0
  );

create or replace function public.get_student_achievement_badges(
  p_session_token text
) returns table (
  badge_id text,
  earned_at timestamptz
)
language plpgsql
security definer
set search_path = public
as $$
declare
  verified_user_id bigint;
  verified_role text;
begin
  select session.user_id, user_account.role
    into verified_user_id, verified_role
  from public.user_sessions as session
  join public.users as user_account on user_account.id = session.user_id
  where session.session_token = p_session_token
    and session.expires_at > now()
  limit 1;

  if verified_user_id is null then
    raise exception 'Invalid or expired session';
  end if;
  if verified_role <> 'student' then
    raise exception 'Student role required';
  end if;

  perform public.refresh_student_achievement_badges(verified_user_id);

  return query
  select badge.badge_id, saved_badge.earned_at
  from (
    values
      ('FirstPerfect'),
      ('FirstStep'),
      ('FlashcardStarter'),
      ('FlawlessFive'),
      ('MatchMaker'),
      ('Podium'),
      ('QuizLegend'),
      ('QuizMaster'),
      ('QuizRegular'),
      ('QuizRookie'),
      ('QuizVeteran'),
      ('StudyMixer'),
      ('EarlyBird'),
      ('NightOwl'),
      ('PerfectWeek'),
      ('Marathon'),
      ('LuckySeven'),
      ('WeekendScholar'),
      ('WarmingUp'),
      ('FortnightFocus'),
      ('PointCollector')
  ) as badge(badge_id)
  left join public.student_achievement_badges as saved_badge
    on saved_badge.user_id = verified_user_id
    and saved_badge.badge_id = badge.badge_id
  order by badge.badge_id;
end;
$$;

create or replace function public.award_student_achievement_badges()
returns trigger
language plpgsql
security definer
set search_path = public
as $$
begin
  perform public.refresh_student_achievement_badges(new.user_id);
  return new;
end;
$$;

revoke all on function public.award_student_achievement_badges() from public;

drop trigger if exists quiz_attempts_award_student_achievements
  on public.quiz_attempts;
create trigger quiz_attempts_award_student_achievements
after insert on public.quiz_attempts
for each row execute function public.award_student_achievement_badges();

drop trigger if exists learning_inventory_attempts_award_student_achievements
  on public.learning_inventory_attempts;
create trigger learning_inventory_attempts_award_student_achievements
after insert on public.learning_inventory_attempts
for each row execute function public.award_student_achievement_badges();

drop trigger if exists learner_point_transactions_award_student_achievements
  on public.learner_point_transactions;
create trigger learner_point_transactions_award_student_achievements
after insert on public.learner_point_transactions
for each row execute function public.award_student_achievement_badges();

drop trigger if exists user_login_days_award_student_achievements
  on public.user_login_days;
create trigger user_login_days_award_student_achievements
after insert on public.user_login_days
for each row execute function public.award_student_achievement_badges();

revoke all on function public.get_student_achievement_badges(text)
  from public;
grant execute on function public.get_student_achievement_badges(text)
  to anon, authenticated;
