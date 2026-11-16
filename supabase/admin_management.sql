-- Run after custom_auth.sql and classrooms.sql.
alter table public.users
  add column if not exists is_active boolean not null default true;

create table if not exists public.admin_activity_events (
  id bigint generated always as identity primary key,
  admin_id bigint references public.users(id) on delete set null,
  action text not null,
  target_label text not null,
  created_at timestamptz not null default now()
);

create index if not exists admin_activity_events_created_idx
  on public.admin_activity_events (created_at desc);

alter table public.admin_activity_events enable row level security;
revoke all on table public.admin_activity_events from anon, authenticated;

create or replace function public._require_admin_session(p_session_token text)
returns bigint
language plpgsql
security definer
set search_path = public
as $$
declare verified_admin_id bigint;
begin
  select u.id into verified_admin_id
  from public.user_sessions s
  join public.users u on u.id = s.user_id
  where s.session_token = p_session_token
    and s.expires_at > now()
    and u.role = 'admin'
    and u.is_active;

  if verified_admin_id is null then
    raise exception 'Invalid or expired admin session';
  end if;

  return verified_admin_id;
end;
$$;

create or replace function public.get_admin_management_data(
  p_session_token text
) returns jsonb
language plpgsql
security definer
set search_path = public
as $$
declare verified_admin_id bigint;
begin
  verified_admin_id := public._require_admin_session(p_session_token);

  return jsonb_build_object(
    'teachers', coalesce((
      select jsonb_agg(jsonb_build_object(
        'id', u.id,
        'full_name', u.full_name,
        'email', coalesce(u.email, ''),
        'created_at', u.created_at,
        'is_active', u.is_active,
        'classroom_count', (
          select count(*) from public.classrooms c
          where c.instructor_id = u.id
        )
      ) order by u.full_name)
      from public.users u
      where u.role = 'instructor'
    ), '[]'::jsonb),
    'students', coalesce((
      select jsonb_agg(jsonb_build_object(
        'id', u.id,
        'full_name', u.full_name,
        'email', coalesce(u.email, ''),
        'created_at', u.created_at,
        'is_active', u.is_active,
        'classroom_count', (
          select count(distinct cs.classroom_id)
          from public.classroom_students cs
          where cs.student_id = u.id
        )
      ) order by u.full_name)
      from public.users u
      where u.role = 'student'
    ), '[]'::jsonb),
    'classrooms', coalesce((
      select jsonb_agg(jsonb_build_object(
        'id', c.id,
        'name', c.name,
        'subject', c.subject,
        'code', c.code,
        'created_at', c.created_at,
        'teacher_name', u.full_name,
        'teacher_email', coalesce(u.email, ''),
        'student_count', (
          select count(*) from public.classroom_students cs
          where cs.classroom_id = c.id
        )
      ) order by c.created_at desc)
      from public.classrooms c
      join public.users u on u.id = c.instructor_id
    ), '[]'::jsonb),
    'activity', coalesce((
      select jsonb_agg(jsonb_build_object(
        'id', event.id,
        'action', event.action,
        'target_label', event.target_label,
        'admin_name', coalesce(admin.full_name, 'Former admin'),
        'created_at', event.created_at
      ) order by event.created_at desc)
      from (
        select * from public.admin_activity_events
        order by created_at desc
        limit 100
      ) event
      left join public.users admin on admin.id = event.admin_id
    ), '[]'::jsonb)
  );
end;
$$;

create or replace function public.create_admin_teacher(
  p_session_token text,
  p_full_name text,
  p_email text,
  p_password text
) returns jsonb
language plpgsql
security definer
set search_path = public, extensions
as $$
declare
  verified_admin_id bigint;
  created_teacher public.users%rowtype;
begin
  verified_admin_id := public._require_admin_session(p_session_token);

  if length(trim(coalesce(p_full_name, ''))) < 2
     or length(coalesce(p_password, '')) < 8
     or coalesce(p_email, '') !~* '^[^@[:space:]]+@[^@[:space:]]+\.[^@[:space:]]+$' then
    raise exception 'Invalid teacher account details';
  end if;

  if exists (
    select 1 from public.users where lower(email) = lower(trim(p_email))
  ) then
    raise exception 'Email is already registered';
  end if;

  insert into public.users (full_name, email, password_hash, role)
  values (
    trim(p_full_name),
    lower(trim(p_email)),
    crypt(p_password, gen_salt('bf', 12)),
    'instructor'
  )
  returning * into created_teacher;

  insert into public.admin_activity_events (admin_id, action, target_label)
  values (
    verified_admin_id,
    'Created teacher account',
    created_teacher.full_name || ' (' || coalesce(created_teacher.email, '') || ')'
  );

  return jsonb_build_object(
    'id', created_teacher.id,
    'full_name', created_teacher.full_name,
    'email', created_teacher.email,
    'created_at', created_teacher.created_at,
    'is_active', created_teacher.is_active,
    'classroom_count', 0
  );
end;
$$;

create or replace function public.update_admin_user(
  p_session_token text,
  p_user_id bigint,
  p_full_name text,
  p_email text,
  p_password text default null
) returns void
language plpgsql
security definer
set search_path = public, extensions
as $$
declare
  verified_admin_id bigint;
  target_user public.users%rowtype;
begin
  verified_admin_id := public._require_admin_session(p_session_token);

  select * into target_user
  from public.users
  where id = p_user_id
    and role in ('student', 'instructor')
  for update;

  if target_user.id is null then
    raise exception 'Account not found';
  end if;

  if length(trim(coalesce(p_full_name, ''))) < 2
     or coalesce(p_email, '') !~* '^[^@[:space:]]+@[^@[:space:]]+\.[^@[:space:]]+$'
     or (p_password is not null and length(p_password) < 8) then
    raise exception 'Invalid account details';
  end if;

  if exists (
    select 1 from public.users
    where lower(email) = lower(trim(p_email)) and id <> p_user_id
  ) then
    raise exception 'Email is already registered';
  end if;

  update public.users
  set full_name = trim(p_full_name),
      email = lower(trim(p_email)),
      password_hash = case
        when p_password is null or p_password = '' then password_hash
        else crypt(p_password, gen_salt('bf', 12))
      end
  where id = p_user_id;

  if p_password is not null and p_password <> '' then
    delete from public.user_sessions where user_id = p_user_id;
  end if;

  insert into public.admin_activity_events (admin_id, action, target_label)
  values (
    verified_admin_id,
    'Updated account details',
    trim(p_full_name) || ' (' || lower(trim(p_email)) || ')'
  );
end;
$$;

create or replace function public.set_admin_user_active(
  p_session_token text,
  p_user_id bigint,
  p_is_active boolean
) returns void
language plpgsql
security definer
set search_path = public
as $$
declare
  verified_admin_id bigint;
  target_user public.users%rowtype;
begin
  verified_admin_id := public._require_admin_session(p_session_token);

  select * into target_user
  from public.users
  where id = p_user_id
    and role in ('student', 'instructor')
  for update;

  if target_user.id is null then
    raise exception 'Account not found';
  end if;

  if target_user.is_active is distinct from p_is_active then
    update public.users set is_active = p_is_active where id = p_user_id;

    if not p_is_active then
      delete from public.user_sessions where user_id = p_user_id;
    end if;

    insert into public.admin_activity_events (admin_id, action, target_label)
    values (
      verified_admin_id,
      case when p_is_active then 'Reactivated account' else 'Deactivated account' end,
      target_user.full_name || ' (' || coalesce(target_user.email, '') || ')'
    );
  end if;
end;
$$;

create or replace function public.update_admin_classroom(
  p_session_token text,
  p_classroom_id uuid,
  p_name text,
  p_subject text
) returns void
language plpgsql
security definer
set search_path = public
as $$
declare
  verified_admin_id bigint;
  target_classroom public.classrooms%rowtype;
begin
  verified_admin_id := public._require_admin_session(p_session_token);

  select * into target_classroom
  from public.classrooms
  where id = p_classroom_id
  for update;

  if target_classroom.id is null then
    raise exception 'Classroom not found';
  end if;

  if length(trim(coalesce(p_name, ''))) = 0
     or length(trim(coalesce(p_subject, ''))) = 0 then
    raise exception 'Classroom name and subject are required';
  end if;

  update public.classrooms
  set name = trim(p_name),
      subject = trim(p_subject)
  where id = p_classroom_id;

  insert into public.admin_activity_events (admin_id, action, target_label)
  values (
    verified_admin_id,
    'Updated classroom details',
    trim(p_name)
  );
end;
$$;

create or replace function public.get_admin_classroom_students(
  p_session_token text,
  p_classroom_id uuid
) returns jsonb
language plpgsql
stable
security definer
set search_path = public
as $$
declare verified_admin_id bigint;
begin
  verified_admin_id := public._require_admin_session(p_session_token);

  if not exists (
    select 1 from public.classrooms where id = p_classroom_id
  ) then
    raise exception 'Classroom not found';
  end if;

  return coalesce((
    select jsonb_agg(jsonb_build_object(
      'id', student.id,
      'full_name', student.full_name,
      'email', coalesce(student.email, ''),
      'joined_at', membership.joined_at
    ) order by student.full_name, student.id)
    from public.classroom_students membership
    join public.users student on student.id = membership.student_id
    where membership.classroom_id = p_classroom_id
      and student.role = 'student'
  ), '[]'::jsonb);
end;
$$;

create or replace function public.remove_admin_classroom_student(
  p_session_token text,
  p_classroom_id uuid,
  p_student_id bigint
) returns void
language plpgsql
security definer
set search_path = public
as $$
declare
  verified_admin_id bigint;
  classroom_name text;
  student_name text;
begin
  verified_admin_id := public._require_admin_session(p_session_token);

  select name into classroom_name
  from public.classrooms
  where id = p_classroom_id;

  if classroom_name is null then
    raise exception 'Classroom not found';
  end if;

  select full_name into student_name
  from public.users
  where id = p_student_id and role = 'student';

  if student_name is null then
    raise exception 'Account not found';
  end if;

  delete from public.classroom_students
  where classroom_id = p_classroom_id
    and student_id = p_student_id;

  if not found then
    raise exception 'Classroom student not found';
  end if;

  insert into public.admin_activity_events (admin_id, action, target_label)
  values (
    verified_admin_id,
    'Removed student from classroom',
    student_name || ' from ' || classroom_name
  );
end;
$$;

revoke all on function public._require_admin_session(text) from public;
revoke all on function public.get_admin_management_data(text) from public;
revoke all on function public.create_admin_teacher(text, text, text, text) from public;
revoke all on function public.update_admin_user(text, bigint, text, text, text) from public;
revoke all on function public.set_admin_user_active(text, bigint, boolean) from public;
revoke all on function public.update_admin_classroom(text, uuid, text, text)
  from public;
revoke all on function public.get_admin_classroom_students(text, uuid)
  from public;
revoke all on function public.remove_admin_classroom_student(text, uuid, bigint)
  from public;
grant execute on function public.get_admin_management_data(text) to anon, authenticated;
grant execute on function public.create_admin_teacher(text, text, text, text) to anon, authenticated;
grant execute on function public.update_admin_user(text, bigint, text, text, text) to anon, authenticated;
grant execute on function public.set_admin_user_active(text, bigint, boolean) to anon, authenticated;
grant execute on function public.update_admin_classroom(text, uuid, text, text)
  to anon, authenticated;
grant execute on function public.get_admin_classroom_students(text, uuid)
  to anon, authenticated;
grant execute on function public.remove_admin_classroom_student(text, uuid, bigint)
  to anon, authenticated;

notify pgrst, 'reload schema';
