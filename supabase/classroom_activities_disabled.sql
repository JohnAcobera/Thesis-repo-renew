-- Retired feature compatibility script. Use only to disable legacy activity
-- support in deployments that previously applied classroom_activities.sql.
-- Follow the upgrade steps in README.md before running this script.
-- Apply after dropping classroom_activities.sql's table and after the
-- classrooms.sql and quiz_attempts.sql RPCs have been refreshed.

create or replace function public.list_classroom_activities(
  p_session_token text,
  p_classroom_id uuid
) returns jsonb
language plpgsql
stable
security definer
set search_path = public
as $$
declare
  verified_user_id bigint;
  verified_role text;
begin
  select u.id, u.role into verified_user_id, verified_role
  from public.user_sessions s
  join public.users u on u.id = s.user_id
  where s.session_token = p_session_token and s.expires_at > now();

  if verified_user_id is null then
    raise exception 'Invalid or expired session';
  end if;

  if verified_role = 'instructor' then
    if not exists (
      select 1 from public.classrooms c
      where c.id = p_classroom_id and c.instructor_id = verified_user_id
    ) then
      raise exception 'Classroom not found';
    end if;
  elsif verified_role = 'student' then
    if not exists (
      select 1 from public.classroom_students cs
      where cs.classroom_id = p_classroom_id
        and cs.student_id = verified_user_id
    ) then
      raise exception 'Join this classroom to view its activities';
    end if;
  else
    raise exception 'Only classroom instructors and students can view activities';
  end if;

  return '[]'::jsonb;
end;
$$;

create or replace function public.post_classroom_activity(
  p_session_token text,
  p_quiz_id uuid,
  p_classroom_ids uuid[],
  p_starts_at timestamptz,
  p_max_attempts integer default null
) returns integer
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
    and u.role = 'instructor';

  if verified_user_id is null then
    if exists (
      select 1
      from public.user_sessions s
      join public.users u on u.id = s.user_id
      where s.session_token = p_session_token and s.expires_at > now()
    ) then
      raise exception 'Only instructors can post classroom activities';
    end if;
    raise exception 'Invalid or expired session';
  end if;

  raise exception 'Classroom activities are disabled';
end;
$$;

create or replace function public.delete_classroom_activity(
  p_session_token text,
  p_classroom_id uuid,
  p_activity_id uuid
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
    and u.role = 'instructor';

  if verified_user_id is null then
    if exists (
      select 1
      from public.user_sessions s
      join public.users u on u.id = s.user_id
      where s.session_token = p_session_token and s.expires_at > now()
    ) then
      raise exception 'Only instructors can manage classroom activities';
    end if;
    raise exception 'Invalid or expired session';
  end if;

  raise exception 'Classroom activities are disabled';
end;
$$;

create or replace function public.submit_classroom_activity_attempt(
  p_session_token text,
  p_activity_id uuid,
  p_score integer,
  p_total_questions integer
) returns uuid
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
    and u.role = 'student';

  if verified_user_id is null then
    if exists (
      select 1
      from public.user_sessions s
      join public.users u on u.id = s.user_id
      where s.session_token = p_session_token and s.expires_at > now()
    ) then
      raise exception 'Only students can submit classroom activities';
    end if;
    raise exception 'Invalid or expired session';
  end if;

  raise exception 'Classroom activities are disabled';
end;
$$;

revoke all on function public.list_classroom_activities(text, uuid)
  from public;
revoke all on function public.post_classroom_activity(
  text, uuid, uuid[], timestamptz, integer
) from public;
revoke all on function public.delete_classroom_activity(text, uuid, uuid)
  from public;
revoke all on function public.submit_classroom_activity_attempt(
  text, uuid, integer, integer
) from public;

grant execute on function public.list_classroom_activities(text, uuid)
  to anon, authenticated;
grant execute on function public.post_classroom_activity(
  text, uuid, uuid[], timestamptz, integer
) to anon, authenticated;
grant execute on function public.delete_classroom_activity(text, uuid, uuid)
  to anon, authenticated;
grant execute on function public.submit_classroom_activity_attempt(
  text, uuid, integer, integer
) to anon, authenticated;

notify pgrst, 'reload schema';
