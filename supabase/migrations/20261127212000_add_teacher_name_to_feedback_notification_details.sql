create or replace function public.list_student_notifications(
  p_session_token text
) returns jsonb
language plpgsql
stable
security definer
set search_path = public
as $$
declare
  verified_user_id bigint;
begin
  select u.id into verified_user_id
  from public.user_sessions s
  join public.users u on u.id = s.user_id
  where s.session_token = p_session_token
    and s.expires_at > now()
    and u.role = 'student'
  limit 1;

  if verified_user_id is null then
    if exists (
      select 1
      from public.user_sessions s
      join public.users u on u.id = s.user_id
      where s.session_token = p_session_token and s.expires_at > now()
    ) then
      raise exception 'Only student accounts can view notifications';
    end if;
    raise exception 'Invalid or expired session';
  end if;

  return coalesce((
    with notifications as (
      select
        'daily-points:' || lp.id::text as notification_id,
        'dailyPoints'::text as notification_type,
        'Daily LP acquired'::text as title,
        format(
          'You earned %s LP for a %s-day streak.',
          lp.points_delta,
          coalesce((lp.details->>'streak_length')::integer, 1)
        ) as message,
        lp.created_at,
        null::uuid as classroom_id
      from public.learner_point_transactions lp
      where lp.user_id = verified_user_id
        and lp.event_type = 'daily_login_streak'
        and lp.created_at >= now() - interval '90 days'

      union all

      select
        'quiz-points:' || attempt.id::text,
        'quizPoints'::text,
        'Quiz LP earned'::text,
        format(
          '%s: %s LP total (%s).',
          attempt.title,
          sum(lp.points_delta),
          string_agg(
            format(
              '%s LP %s',
              lp.points_delta,
              case lp.event_type
                when 'quiz_first_attempt' then 'first attempt'
                when 'quiz_second_attempt' then 'second attempt'
                when 'perfect_quiz' then 'perfect quiz'
                when 'quiz_score_reward' then 'score reward'
                else lp.event_type
              end
            ),
            ', '
            order by lp.created_at, lp.id
          )
        ),
        attempt.created_at,
        null::uuid
      from public.quiz_attempts attempt
      join public.learner_point_transactions lp
        on lp.user_id = attempt.user_id
       and (
         lp.details->>'attempt_id' = attempt.id::text
         or lp.details->>'perfect_attempt_id' = attempt.id::text
       )
      where attempt.user_id = verified_user_id
        and attempt.created_at >= now() - interval '90 days'
        and lp.event_type in (
          'quiz_first_attempt', 'quiz_second_attempt',
          'perfect_quiz', 'quiz_score_reward'
        )
      group by attempt.id, attempt.title, attempt.created_at

      union all

      select
        'streak-ended:' || streak.last_day::text,
        'streakEnded'::text,
        'Streak ended'::text,
        format('Your %s streak ended.', streak.streak_length),
        streak.next_first_day::timestamptz,
        null::uuid
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

      select
        'weekly-rank:' || (week_period.week_start::date)::text,
        'weeklyRank'::text,
        'Last week''s leaderboard'::text,
        format(
          'You finished #%s with %s LP.',
          ranked.position,
          ranked.points
        ),
        week_period.notification_at,
        null::uuid
      from (
        select
          date_trunc('week', now()) - interval '1 week' as week_start,
          date_trunc('week', now()) as notification_at
      ) week_period
      join (
        select
          student.id,
          student.created_at,
          row_number() over (
            order by coalesce(sum(lp.points_delta), 0) desc,
              student.full_name,
              student.id
          ) as position,
          coalesce(sum(lp.points_delta), 0)::bigint as points
        from public.users student
        left join public.learner_point_transactions lp
          on lp.user_id = student.id
         and lp.created_at >=
            date_trunc('week', now()) - interval '1 week'
         and lp.created_at < date_trunc('week', now())
        where student.role = 'student'
        group by student.id, student.full_name, student.created_at
      ) ranked on ranked.id = verified_user_id
      where ranked.position <= 99
        and ranked.points > 0
        and ranked.created_at <= week_period.week_start

      union all

      select
        'classroom-joined:' || membership.classroom_id::text || ':' ||
          extract(epoch from membership.joined_at)::text,
        'classroomJoined'::text,
        'Joined a classroom'::text,
        format('You joined %s.', classroom.name),
        membership.joined_at,
        null::uuid
      from public.classroom_students membership
      join public.classrooms classroom
        on classroom.id = membership.classroom_id
      where membership.student_id = verified_user_id
        and membership.joined_at >= now() - interval '90 days'

      union all

      select
        'classroom-removed:' || removal.id::text,
        'classroomRemoved'::text,
        'Removed from a classroom'::text,
        format('You were removed from %s.', removal.classroom_name),
        removal.removed_at,
        null::uuid
      from public.student_classroom_removals removal
      where removal.student_id = verified_user_id
        and removal.removed_at >= now() - interval '90 days'

      union all

      select
        'teacher-feedback:' || feedback.id::text,
        'teacherFeedback'::text,
        'A message from your teacher'::text,
        format('From %s: %s', instructor.full_name, feedback.message),
        feedback.created_at,
        null::uuid
      from public.student_teacher_feedback feedback
      join public.users instructor
        on instructor.id = feedback.instructor_id
      where feedback.student_id = verified_user_id
        and feedback.created_at >= now() - interval '90 days'
    )
    select jsonb_agg(
      jsonb_build_object(
        'id', notifications.notification_id,
        'type', notifications.notification_type,
        'title', notifications.title,
        'message', notifications.message,
        'created_at', notifications.created_at,
        'classroom_id', notifications.classroom_id,
        'is_read', reads.notification_id is not null
      )
      order by notifications.created_at desc, notifications.notification_id
    )
    from (
      select *
      from notifications
      where notifications.created_at >= now() - interval '90 days'
      order by notifications.created_at desc
      limit 100
    ) notifications
    left join public.student_notification_reads reads
      on reads.user_id = verified_user_id
     and reads.notification_id = notifications.notification_id
  ), '[]'::jsonb);
end;
$$;

revoke all on function public.list_student_notifications(text) from public;
grant execute on function public.list_student_notifications(text)
  to anon, authenticated;

notify pgrst, 'reload schema';
