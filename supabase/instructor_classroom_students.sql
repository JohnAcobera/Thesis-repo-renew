-- Run after custom_auth.sql and classrooms.sql.

create or replace function public.list_instructor_classroom_students(
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
      raise exception 'Only instructors can view classroom students';
    end if;
    raise exception 'Invalid or expired session';
  end if;

  if not exists (
    select 1
    from public.classrooms c
    where c.id = p_classroom_id
      and c.instructor_id = verified_user_id
  ) then
    raise exception 'Classroom not found';
  end if;

  return coalesce((
    select jsonb_agg(
      jsonb_build_object(
        'id', student.id,
        'full_name', student.full_name,
        'email', student.email,
        'joined_at', membership.joined_at
      )
      order by student.full_name, student.id
    )
    from public.classroom_students membership
    join public.users student on student.id = membership.student_id
    where membership.classroom_id = p_classroom_id
  ), '[]'::jsonb);
end;
$$;

create or replace function public.list_student_classroom_classmates(
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
      raise exception 'Only students can view classroom classmates';
    end if;
    raise exception 'Invalid or expired session';
  end if;

  if not exists (
    select 1
    from public.classroom_students membership
    where membership.classroom_id = p_classroom_id
      and membership.student_id = verified_user_id
  ) then
    raise exception 'Classroom not found';
  end if;

  return coalesce((
    select jsonb_agg(
      jsonb_build_object(
        'id', student.id,
        'full_name', student.full_name,
        'email', '',
        'joined_at', membership.joined_at
      )
      order by student.full_name, student.id
    )
    from public.classroom_students membership
    join public.users student on student.id = membership.student_id
    where membership.classroom_id = p_classroom_id
  ), '[]'::jsonb);
end;
$$;

create or replace function public.remove_instructor_classroom_student(
  p_session_token text,
  p_classroom_id uuid,
  p_student_id bigint
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
      raise exception 'Only instructors can remove classroom students';
    end if;
    raise exception 'Invalid or expired session';
  end if;

  delete from public.classroom_students membership
  using public.classrooms classroom, public.users student
  where membership.classroom_id = p_classroom_id
    and membership.student_id = p_student_id
    and classroom.id = membership.classroom_id
    and classroom.instructor_id = verified_user_id
    and student.id = membership.student_id
    and student.role = 'student';
  if not found then
    raise exception 'Classroom student not found';
  end if;
end;
$$;

revoke all on function public.list_instructor_classroom_students(text, uuid)
  from public;
revoke all on function public.list_student_classroom_classmates(text, uuid)
  from public;
revoke all on function public.remove_instructor_classroom_student(
  text, uuid, bigint
) from public;

grant execute on function public.list_instructor_classroom_students(text, uuid)
  to anon, authenticated;
grant execute on function public.list_student_classroom_classmates(text, uuid)
  to anon, authenticated;
grant execute on function public.remove_instructor_classroom_student(
  text, uuid, bigint
) to anon, authenticated;

notify pgrst, 'reload schema';
