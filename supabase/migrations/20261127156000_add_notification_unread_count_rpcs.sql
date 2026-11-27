-- Lightweight unread counts for the 30-second badge refresh.
-- These mirror the notification IDs produced by the list RPCs, but avoid the
-- expensive jsonb aggregation and the global weekly-leaderboard ranking.

create or replace function public.get_student_notification_unread_count(
  p_session_token text
) returns integer
language plpgsql
stable
security definer
set search_path = public
as $$
declare
  verified_user_id bigint;
  unread integer;
begin
  select u.id into verified_user_id
  from public.user_sessions s
  join public.users u on u.id = s.user_id
  where s.session_token = p_session_token
    and s.expires_at > now()
    and u.role = 'student'
  limit 1;

  if verified_user_id is null then
    raise exception 'Invalid or expired session';
  end if;

  with notification_ids as (
    select 'daily-points:' || lp.id::text as id
    from public.learner_point_transactions lp
    where lp.user_id = verified_user_id
      and lp.event_type = 'daily_login_streak'
      and lp.created_at >= now() - interval '90 days'

    union all

    select 'quiz-points:' || attempt.id::text
    from public.quiz_attempts attempt
    where attempt.user_id = verified_user_id
      and attempt.created_at >= now() - interval '90 days'
      and exists (
        select 1
        from public.learner_point_transactions lp
        where lp.user_id = attempt.user_id
          and (
            lp.details->>'attempt_id' = attempt.id::text
            or lp.details->>'perfect_attempt_id' = attempt.id::text
          )
          and lp.event_type in (
            'quiz_first_attempt', 'quiz_second_attempt',
            'perfect_quiz', 'quiz_score_reward'
          )
      )

    union all

    select 'streak-ended:' || streak.last_day::text
    from (
      select
        segments.*,
        lead(segments.first_day) over (order by segments.first_day)
          as next_first_day
      from (
        select
          min(login_date) as first_day,
          max(login_date) as last_day,
          count(*)::integer as streak_length
        from (
          select
            login_date,
            login_date - row_number() over (order by login_date)::integer
              as streak_group
          from public.user_login_days
          where user_id = verified_user_id
        ) grouped_days
        group by streak_group
      ) segments
    ) streak
    where streak.streak_length >= 3
      and streak.next_first_day > streak.last_day + 1
      and streak.next_first_day >= current_date - 90

    union all

    -- Presence of the weekly-rank notification without ranking all students.
    select 'weekly-rank:' || (week_period.week_start::date)::text
    from (
      select date_trunc('week', now()) - interval '1 week' as week_start
    ) week_period
    where exists (
      select 1
      from public.users student
      where student.id = verified_user_id
        and student.role = 'student'
        and student.created_at <= week_period.week_start
        and exists (
          select 1
          from public.learner_point_transactions lp
          where lp.user_id = student.id
            and lp.created_at >= week_period.week_start
            and lp.created_at < date_trunc('week', now())
            and lp.points_delta > 0
        )
    )

    union all

    select 'classroom-joined:' || membership.classroom_id::text || ':' ||
      extract(epoch from membership.joined_at)::text
    from public.classroom_students membership
    where membership.student_id = verified_user_id
      and membership.joined_at >= now() - interval '90 days'

    union all

    select 'classroom-removed:' || removal.id::text
    from public.student_classroom_removals removal
    where removal.student_id = verified_user_id
      and removal.removed_at >= now() - interval '90 days'

    union all

    select 'teacher-feedback:' || feedback.id::text
    from public.student_teacher_feedback feedback
    where feedback.student_id = verified_user_id
      and feedback.created_at >= now() - interval '90 days'
  )
  select count(*)::integer into unread
  from (
    select id from notification_ids
    except
    select notification_id
    from public.student_notification_reads
    where user_id = verified_user_id
  ) unread_ids;

  return coalesce(unread, 0);
end;
$$;

revoke all on function public.get_student_notification_unread_count(text)
  from public;
grant execute on function public.get_student_notification_unread_count(text)
  to anon, authenticated;

create or replace function public.get_instructor_notification_unread_count(
  p_session_token text
) returns integer
language plpgsql
stable
security definer
set search_path = public
as $$
declare
  verified_user_id bigint;
  unread integer;
begin
  select u.id into verified_user_id
  from public.user_sessions s
  join public.users u on u.id = s.user_id
  where s.session_token = p_session_token
    and s.expires_at > now()
    and u.role = 'instructor'
  limit 1;

  if verified_user_id is null then
    raise exception 'Invalid or expired session';
  end if;

  with notification_ids as (
    select
      'student-joined:' || membership.classroom_id::text || ':' ||
        membership.student_id::text || ':' ||
        extract(epoch from membership.joined_at)::text as id
    from public.classroom_students membership
    join public.classrooms classroom
      on classroom.id = membership.classroom_id
    where classroom.instructor_id = verified_user_id
      and membership.joined_at >= now() - interval '90 days'
  )
  select count(*)::integer into unread
  from (
    select id from notification_ids
    except
    select notification_id
    from public.instructor_notification_reads
    where user_id = verified_user_id
  ) unread_ids;

  return coalesce(unread, 0);
end;
$$;

revoke all on function public.get_instructor_notification_unread_count(text)
  from public;
grant execute on function public.get_instructor_notification_unread_count(text)
  to anon, authenticated;

notify pgrst, 'reload schema';
