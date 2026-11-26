-- Run after learner_points.sql, quiz_attempts.sql,
-- learner_points_automation.sql, learning_streak.sql,
-- learner_points_leaderboard.sql, and classrooms.sql. This also installs a
-- data-free Realtime broadcast used to refresh each student's notifications.

create table if not exists public.student_notification_reads (
  user_id bigint not null references public.users(id) on delete cascade,
  notification_id text not null,
  read_at timestamptz not null default now(),
  primary key (user_id, notification_id)
);

alter table public.student_notification_reads enable row level security;
revoke all on table public.student_notification_reads from anon, authenticated;

create table if not exists public.student_classroom_removals (
  id uuid primary key default gen_random_uuid(),
  student_id bigint not null references public.users(id) on delete cascade,
  classroom_name text not null,
  removed_at timestamptz not null default now()
);

create index if not exists student_classroom_removals_student_removed_idx
  on public.student_classroom_removals (student_id, removed_at desc);

alter table public.student_classroom_removals enable row level security;
revoke all on table public.student_classroom_removals from anon, authenticated;

create table if not exists public.student_teacher_feedback (
  id uuid primary key default gen_random_uuid(),
  instructor_id bigint not null references public.users(id) on delete cascade,
  student_id bigint not null references public.users(id) on delete cascade,
  classroom_id uuid not null references public.classrooms(id) on delete cascade,
  metric text not null,
  message text not null,
  created_at timestamptz not null default now(),
  constraint student_teacher_feedback_message_length
    check (length(trim(message)) between 1 and 1000),
  constraint student_teacher_feedback_metric_check
    check (metric in (
      'Classroom average',
      'Overall average',
      'Classroom completion',
      'Accuracy',
      'Retention',
      'Improvement',
      'Consistency',
      'Focus'
    ))
);

create index if not exists student_teacher_feedback_student_created_idx
  on public.student_teacher_feedback (student_id, created_at desc);

alter table public.student_teacher_feedback enable row level security;
revoke all on table public.student_teacher_feedback from anon, authenticated;

create or replace function public.record_student_classroom_removal()
returns trigger
language plpgsql
security definer
set search_path = public
as $$
declare
  removed_classroom_name text;
begin
  select c.name into removed_classroom_name
  from public.classrooms c
  where c.id = old.classroom_id;

  if removed_classroom_name is not null then
    insert into public.student_classroom_removals (
      student_id, classroom_name
    ) values (
      old.student_id, removed_classroom_name
    );
  end if;
  return old;
end;
$$;

revoke all on function public.record_student_classroom_removal() from public;

drop trigger if exists classroom_students_record_removal
  on public.classroom_students;
create trigger classroom_students_record_removal
before delete on public.classroom_students
for each row execute function public.record_student_classroom_removal();

create or replace function public.send_student_feedback(
  p_session_token text,
  p_student_id bigint,
  p_classroom_id uuid,
  p_metric text,
  p_message text
) returns void
language plpgsql
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
    and u.role = 'instructor'
  limit 1;

  if verified_user_id is null then
    if exists (
      select 1
      from public.user_sessions s
      join public.users u on u.id = s.user_id
      where s.session_token = p_session_token and s.expires_at > now()
    ) then
      raise exception 'Only instructors can send student feedback';
    end if;
    raise exception 'Invalid or expired session';
  end if;

  if p_message is null or length(trim(p_message)) not between 1 and 1000 then
    raise exception 'Feedback must contain between 1 and 1000 characters';
  end if;

  if not exists (
    select 1
    from public.classrooms classroom
    join public.classroom_students membership
      on membership.classroom_id = classroom.id
    join public.users student
      on student.id = membership.student_id
     and student.role = 'student'
    where classroom.id = p_classroom_id
      and classroom.instructor_id = verified_user_id
      and membership.student_id = p_student_id
  ) then
    raise exception 'Student is not in this instructor classroom';
  end if;

  insert into public.student_teacher_feedback (
    instructor_id,
    student_id,
    classroom_id,
    metric,
    message
  ) values (
    verified_user_id,
    p_student_id,
    p_classroom_id,
    p_metric,
    trim(p_message)
  );
end;
$$;

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
          'quiz_first_attempt',
          'quiz_second_attempt',
          'perfect_quiz',
          'quiz_score_reward'
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
        group by student.id, student.full_name
      ) ranked on ranked.id = verified_user_id
      where ranked.position <= 99

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
        feedback.message,
        feedback.created_at,
        null::uuid
      from public.student_teacher_feedback feedback
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

create or replace function public.mark_student_notifications_read(
  p_session_token text,
  p_notification_ids text[]
) returns void
language plpgsql
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
    raise exception 'Invalid or expired student session';
  end if;

  insert into public.student_notification_reads (user_id, notification_id)
  select verified_user_id, notification_id
  from unnest(coalesce(p_notification_ids, array[]::text[]))
    as ids(notification_id)
  where length(notification_id) between 1 and 200
  on conflict (user_id, notification_id)
  do update set read_at = excluded.read_at;
end;
$$;

revoke all on function public.list_student_notifications(text) from public;
revoke all on function public.mark_student_notifications_read(text, text[])
  from public;
revoke all on function public.send_student_feedback(
  text, bigint, uuid, text, text
) from public;
grant execute on function public.list_student_notifications(text)
  to anon, authenticated;
grant execute on function public.mark_student_notifications_read(text, text[])
  to anon, authenticated;
grant execute on function public.send_student_feedback(
  text, bigint, uuid, text, text
) to anon, authenticated;

create or replace function public.broadcast_student_notification_change()
returns trigger
language plpgsql
security definer
set search_path = public
as $$
begin
  perform realtime.send(
    '{}'::jsonb,
    'student_notifications_changed',
    'student-notifications',
    false
  );
  return null;
end;
$$;

revoke all on function public.broadcast_student_notification_change()
  from public;

do $$
declare
  source_table text;
begin
  foreach source_table in array array[
    'classrooms',
    'classroom_students',
    'learner_point_transactions',
    'quiz_attempts',
    'student_classroom_removals',
    'student_generated_quizzes',
    'student_teacher_feedback',
    'student_notification_reads',
    'user_login_days'
  ]
  loop
    execute format(
      'drop trigger if exists student_notifications_broadcast on public.%I',
      source_table
    );
    execute format(
      'create trigger student_notifications_broadcast ' ||
      'after insert or update or delete on public.%I ' ||
      'for each statement execute function ' ||
      'public.broadcast_student_notification_change()',
      source_table
    );
  end loop;
end;
$$;

notify pgrst, 'reload schema';
