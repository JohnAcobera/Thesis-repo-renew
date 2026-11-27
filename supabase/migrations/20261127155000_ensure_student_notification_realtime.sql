-- Ensure the student notification broadcast triggers exist on the remote
-- project. Without them no realtime event is emitted, so the badge only
-- updates when the sheet is opened. Idempotent: triggers are recreated.

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
end $$;

notify pgrst, 'reload schema';
