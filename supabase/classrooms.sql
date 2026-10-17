-- Instructor-owned classrooms for the app's custom session-token auth.
create extension if not exists pgcrypto;

create table if not exists public.classrooms (
  id uuid primary key default gen_random_uuid(),
  instructor_id bigint not null references public.users(id) on delete cascade,
  name text not null,
  subject text not null,
  code text not null unique,
  created_at timestamptz not null default now(),
  constraint classrooms_name_not_empty check (length(trim(name)) > 0),
  constraint classrooms_subject_not_empty check (length(trim(subject)) > 0)
);

alter table public.classrooms
  add column if not exists icon_key text not null default 'book';

alter table public.classrooms
  drop constraint if exists classrooms_icon_key_check;
alter table public.classrooms
  add constraint classrooms_icon_key_check check (
    icon_key in (
      'book',
      'science',
      'computer',
      'calculate',
      'palette',
      'language',
      'history',
      'music'
    )
  );

create index if not exists classrooms_instructor_created_idx
  on public.classrooms (instructor_id, created_at desc);

create table if not exists public.classroom_students (
  classroom_id uuid not null references public.classrooms(id) on delete cascade,
  student_id bigint not null references public.users(id) on delete cascade,
  joined_at timestamptz not null default now(),
  primary key (classroom_id, student_id)
);

create index if not exists classroom_students_student_idx
  on public.classroom_students (student_id);

alter table public.classrooms enable row level security;
alter table public.classroom_students enable row level security;
revoke all on table public.classrooms from anon, authenticated;
revoke all on table public.classroom_students from anon, authenticated;

drop function if exists public.create_instructor_classroom(text, text, text);

create or replace function public.create_instructor_classroom(
  p_session_token text,
  p_name text,
  p_subject text,
  p_icon_key text
) returns jsonb
language plpgsql
security definer
set search_path = public, extensions
as $$
declare
  verified_user_id bigint;
  created_classroom public.classrooms%rowtype;
  classroom_code text;
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
      raise exception 'Only instructors can manage classrooms';
    end if;
    raise exception 'Invalid or expired session';
  end if;

  if length(trim(coalesce(p_name, ''))) = 0
     or length(trim(coalesce(p_subject, ''))) = 0 then
    raise exception 'Classroom name and subject are required';
  end if;

  if p_icon_key is null or p_icon_key not in (
    'book',
    'science',
    'computer',
    'calculate',
    'palette',
    'language',
    'history',
    'music'
  ) then
    raise exception 'Invalid classroom icon';
  end if;

  loop
    classroom_code := upper(encode(gen_random_bytes(6), 'hex'));

    exit when not exists (
      select 1 from public.classrooms c where c.code = classroom_code
    );
  end loop;

  insert into public.classrooms (instructor_id, name, subject, code, icon_key)
  values (
    verified_user_id,
    trim(p_name),
    trim(p_subject),
    classroom_code,
    p_icon_key
  )
  returning * into created_classroom;

  return jsonb_build_object(
    'id', created_classroom.id,
    'name', created_classroom.name,
    'subject', created_classroom.subject,
    'code', created_classroom.code,
    'icon_key', created_classroom.icon_key,
    'created_at', created_classroom.created_at,
    'student_count', 0,
    'activity_count', 0
  );
end;
$$;

create or replace function public.list_instructor_classrooms(
  p_session_token text
) returns jsonb
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
      raise exception 'Only instructors can manage classrooms';
    end if;
    raise exception 'Invalid or expired session';
  end if;

  return coalesce(
    (
      select jsonb_agg(
        jsonb_build_object(
          'id', c.id,
          'name', c.name,
          'subject', c.subject,
          'code', c.code,
          'icon_key', c.icon_key,
          'created_at', c.created_at,
          'student_count', (
            select count(*)
            from public.classroom_students cs
            where cs.classroom_id = c.id
          ),
          'activity_count', (
            select count(*)
            from public.classroom_activities a
            where a.classroom_id = c.id
          )
        )
        order by c.created_at desc
      )
      from public.classrooms c
      where c.instructor_id = verified_user_id
    ),
    '[]'::jsonb
  );
end;
$$;

create or replace function public.get_instructor_dashboard_stats(
  p_session_token text
) returns jsonb
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
      raise exception 'Only instructors can view dashboard statistics';
    end if;
    raise exception 'Invalid or expired session';
  end if;

  return jsonb_build_object(
    'student_count', (
      select count(distinct cs.student_id)
      from public.classrooms c
      join public.classroom_students cs on cs.classroom_id = c.id
      where c.instructor_id = verified_user_id
    ),
    'active_class_count', (
      select count(*)
      from public.classrooms c
      where c.instructor_id = verified_user_id
    ),
    'quizzes_created_count', (
      select count(distinct a.quiz_id)
      from public.classroom_activities a
      join public.classrooms c on c.id = a.classroom_id
      join public.student_generated_quizzes q on q.id = a.quiz_id
      where c.instructor_id = verified_user_id
        and q.user_id = verified_user_id
    ),
    'classroom_performance', coalesce((
      select jsonb_agg(
        jsonb_build_object(
          'name', c.name,
          'subject', c.subject,
          'student_count', (
            select count(*)
            from public.classroom_students cs
            where cs.classroom_id = c.id
          ),
          'activity_count', (
            select count(*)
            from public.classroom_activities a
            where a.classroom_id = c.id
          ),
          'average_score', (
            select avg(
              100.0 * qa.score / nullif(qa.total_questions, 0)
            )
            from public.classroom_activities a
            join public.quiz_attempts qa
              on qa.classroom_activity_id = a.id
            where a.classroom_id = c.id
          )
        )
        order by c.created_at desc
      )
      from public.classrooms c
      where c.instructor_id = verified_user_id
    ), '[]'::jsonb)
  );
end;
$$;

create or replace function public.delete_instructor_classroom(
  p_session_token text,
  p_classroom_id uuid
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
      raise exception 'Only instructors can manage classrooms';
    end if;
    raise exception 'Invalid or expired session';
  end if;

  delete from public.classrooms c
  where c.id = p_classroom_id
    and c.instructor_id = verified_user_id;
  if not found then
    raise exception 'Classroom not found';
  end if;
end;
$$;

create or replace function public.join_classroom(
  p_session_token text,
  p_code text
) returns jsonb
language plpgsql
security definer
set search_path = public
as $$
declare
  verified_user_id bigint;
  joined_classroom public.classrooms%rowtype;
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
      raise exception 'Only students can join classrooms';
    end if;
    raise exception 'Invalid or expired session';
  end if;

  if length(trim(coalesce(p_code, ''))) = 0 then
    raise exception 'Classroom code not found';
  end if;

  select * into joined_classroom
  from public.classrooms c
  where c.code = upper(trim(p_code));

  if joined_classroom.id is null then
    raise exception 'Classroom code not found';
  end if;

  insert into public.classroom_students (classroom_id, student_id)
  values (joined_classroom.id, verified_user_id)
  on conflict (classroom_id, student_id) do nothing;

  return jsonb_build_object(
    'id', joined_classroom.id,
    'name', joined_classroom.name,
    'subject', joined_classroom.subject,
    'code', joined_classroom.code,
    'icon_key', joined_classroom.icon_key,
    'created_at', joined_classroom.created_at,
    'student_count', (
      select count(*)
      from public.classroom_students cs
      where cs.classroom_id = joined_classroom.id
    ),
    'activity_count', (
      select count(*)
      from public.classroom_activities a
      where a.classroom_id = joined_classroom.id
    )
  );
end;
$$;

create or replace function public.list_student_classrooms(
  p_session_token text
) returns jsonb
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
      raise exception 'Only students can view joined classrooms';
    end if;
    raise exception 'Invalid or expired session';
  end if;

  return coalesce(
    (
      select jsonb_agg(
        jsonb_build_object(
          'id', c.id,
          'name', c.name,
          'subject', c.subject,
          'code', c.code,
          'icon_key', c.icon_key,
          'created_at', c.created_at,
          'student_count', (
            select count(*)
            from public.classroom_students all_students
            where all_students.classroom_id = c.id
          ),
          'activity_count', (
            select count(*)
            from public.classroom_activities a
            where a.classroom_id = c.id
          )
        )
        order by cs.joined_at desc
      )
      from public.classroom_students cs
      join public.classrooms c on c.id = cs.classroom_id
      where cs.student_id = verified_user_id
    ),
    '[]'::jsonb
  );
end;
$$;

revoke all on function public.create_instructor_classroom(
  text,
  text,
  text,
  text
) from public;
revoke all on function public.list_instructor_classrooms(text) from public;
revoke all on function public.get_instructor_dashboard_stats(text) from public;
revoke all on function public.delete_instructor_classroom(text, uuid)
  from public;
revoke all on function public.join_classroom(text, text) from public;
revoke all on function public.list_student_classrooms(text) from public;
grant execute on function public.create_instructor_classroom(
  text,
  text,
  text,
  text
) to anon, authenticated;
grant execute on function public.list_instructor_classrooms(text)
  to anon, authenticated;
grant execute on function public.get_instructor_dashboard_stats(text)
  to anon, authenticated;
grant execute on function public.delete_instructor_classroom(text, uuid)
  to anon, authenticated;
grant execute on function public.join_classroom(text, text)
  to anon, authenticated;
grant execute on function public.list_student_classrooms(text)
  to anon, authenticated;

notify pgrst, 'reload schema';
