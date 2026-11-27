-- Run after custom_auth.sql and classrooms.sql.

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
        'student-joined:' || membership.classroom_id::text || ':' ||
          membership.student_id::text || ':' ||
          extract(epoch from membership.joined_at)::text as notification_id,
        'studentJoined'::text as notification_type,
        'A student joined your classroom'::text as title,
        format(
          '%s joined %s.',
          student.full_name,
          classroom.name
        ) as message,
        membership.joined_at as created_at,
        classroom.id as classroom_id
      from public.classroom_students membership
      join public.classrooms classroom
        on classroom.id = membership.classroom_id
      join public.users student on student.id = membership.student_id
      where classroom.instructor_id = verified_user_id
        and membership.joined_at >= now() - interval '90 days'
      -- Bound the result; this list is polled by the notification badge.
      order by membership.joined_at desc
      limit 100

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

-- Data-free Realtime broadcast used to refresh each instructor's notification
-- badge and open panel. The payload is empty: every client re-runs the
-- session-scoped list RPC, so no notification data leaks between accounts.
create or replace function public.broadcast_instructor_notification_change()
returns trigger
language plpgsql
security definer
set search_path = public
as $$
begin
  perform realtime.send(
    '{}'::jsonb,
    'instructor_notifications_changed',
    'instructor-notifications',
    false
  );
  return null;
end;
$$;

revoke all on function public.broadcast_instructor_notification_change()
  from public;

do $$
declare
  source_table text;
begin
  foreach source_table in array array[
    'classrooms',
    'classroom_students',
    'instructor_notification_reads'
  ]
  loop
    execute format(
      'drop trigger if exists instructor_notifications_broadcast on public.%I',
      source_table
    );
    execute format(
      'create trigger instructor_notifications_broadcast ' ||
      'after insert or update or delete on public.%I ' ||
      'for each statement execute function ' ||
      'public.broadcast_instructor_notification_change()',
      source_table
    );
  end loop;
end $$;

notify pgrst, 'reload schema';
