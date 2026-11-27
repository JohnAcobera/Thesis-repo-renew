-- Realtime instructor notifications, mirroring the student notification
-- broadcast already present in student_notifications.sql. Statement-level
-- triggers emit a data-free event; clients re-run the session-scoped list RPC.

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
