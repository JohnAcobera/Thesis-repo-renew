-- Performance-only migration: covering indexes for the 4 unindexed foreign keys
-- reported by Supabase's performance advisor. No data or function logic changes.

create index if not exists admin_activity_events_admin_id_idx
  on public.admin_activity_events (admin_id);

create index if not exists student_teacher_feedback_classroom_id_idx
  on public.student_teacher_feedback (classroom_id);

create index if not exists student_teacher_feedback_instructor_id_idx
  on public.student_teacher_feedback (instructor_id);

create index if not exists user_sessions_user_id_idx
  on public.user_sessions (user_id);
