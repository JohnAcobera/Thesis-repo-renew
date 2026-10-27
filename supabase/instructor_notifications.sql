-- Run after custom_auth.sql, classrooms.sql, classroom_activities.sql, and
-- quiz_attempts.sql.

create table if not exists public.instructor_notification_reads (
  user_id bigint not null references public.users(id) on delete cascade,
  notification_id text not null,
  read_at timestamptz not null default now(),
  primary key (user_id, notification_id)
);

alter table public.instructor_notification_reads enable row level security;
revoke all on table public.instructor_notification_reads from anon, authenticated;

create or replace function public.list_instructor_notifications(
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
    and u.role = 'instructor'
  limit 1;

  if verified_user_id is null then
    if exists (
      select 1
      from public.user_sessions s
      join public.users u on u.id = s.user_id
      where s.session_token = p_session_token and s.expires_at > now()
    ) then
      raise exception 'Only instructor accounts can view notifications';
    end if;
    raise exception 'Invalid or expired session';
  end if;

  return coalesce((
    with notifications as (
      select
        'quiz-answered:' || attempt.id::text as notification_id,
        'quizAnswered'::text as notification_type,
        'Quiz completed'::text as title,
        format(
          '%s completed "%s" in %s and scored %s out of %s.',
          student.full_name,
          quiz.title,
          classroom.name,
          attempt.score,
          attempt.total_questions
        ) as message,
        attempt.created_at,
        classroom.id as classroom_id
      from public.quiz_attempts attempt
      join public.classroom_activities activity
        on activity.id = attempt.classroom_activity_id
      join public.classrooms classroom
        on classroom.id = activity.classroom_id
      join public.student_generated_quizzes quiz
        on quiz.id = activity.quiz_id
      join public.users student on student.id = attempt.user_id
      where classroom.instructor_id = verified_user_id
        and attempt.created_at >= now() - interval '90 days'

      union all

      select
        'student-joined:' || membership.classroom_id::text || ':' ||
          membership.student_id::text || ':' ||
          extract(epoch from membership.joined_at)::text,
        'studentJoined'::text,
        'A student joined your classroom'::text,
        format(
          '%s joined %s.',
          student.full_name,
          classroom.name
        ),
        membership.joined_at,
        classroom.id
      from public.classroom_students membership
      join public.classrooms classroom
        on classroom.id = membership.classroom_id
      join public.users student on student.id = membership.student_id
      where classroom.instructor_id = verified_user_id
        and membership.joined_at >= now() - interval '90 days'

    )
    select jsonb_agg(
      jsonb_build_object(
        'id', notification.notification_id,
        'type', notification.notification_type,
        'title', notification.title,
        'message', notification.message,
        'created_at', notification.created_at,
        'is_read', reads.notification_id is not null,
        'classroom_id', notification.classroom_id
      )
      order by notification.created_at desc, notification.notification_id
    )
    from notifications notification
    left join public.instructor_notification_reads reads
      on reads.user_id = verified_user_id
     and reads.notification_id = notification.notification_id
  ), '[]'::jsonb);
end;
$$;

create or replace function public.mark_instructor_notifications_read(
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
    and u.role = 'instructor'
  limit 1;

  if verified_user_id is null then
    if exists (
      select 1
      from public.user_sessions s
      join public.users u on u.id = s.user_id
      where s.session_token = p_session_token and s.expires_at > now()
    ) then
      raise exception 'Only instructor accounts can update notifications';
    end if;
    raise exception 'Invalid or expired session';
  end if;

  insert into public.instructor_notification_reads (user_id, notification_id)
  select verified_user_id, notification_id
  from unnest(coalesce(p_notification_ids, array[]::text[]))
    as requested(notification_id)
  where length(notification_id) > 0
  on conflict (user_id, notification_id) do nothing;
end;
$$;

revoke all on function public.list_instructor_notifications(text) from public;
revoke all on function public.mark_instructor_notifications_read(text, text[])
  from public;

grant execute on function public.list_instructor_notifications(text)
  to anon, authenticated;
grant execute on function public.mark_instructor_notifications_read(text, text[])
  to anon, authenticated;
