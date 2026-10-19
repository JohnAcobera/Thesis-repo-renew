-- Run after custom_auth.sql, quiz_attempts.sql, and classroom_activities.sql.

create table if not exists public.instructor_learning_material_folders (
  id uuid primary key default gen_random_uuid(),
  instructor_id bigint not null references public.users(id) on delete cascade,
  name text not null check (length(trim(name)) between 1 and 80),
  created_at timestamptz not null default now()
);

create unique index if not exists instructor_learning_material_folders_name_idx
  on public.instructor_learning_material_folders (instructor_id, lower(name));

create table if not exists public.instructor_learning_material_folder_items (
  quiz_id uuid primary key
    references public.student_generated_quizzes(id) on delete cascade,
  folder_id uuid not null
    references public.instructor_learning_material_folders(id) on delete cascade
);

alter table public.instructor_learning_material_folders enable row level security;
alter table public.instructor_learning_material_folder_items enable row level security;
revoke all on table public.instructor_learning_material_folders
  from anon, authenticated;
revoke all on table public.instructor_learning_material_folder_items
  from anon, authenticated;

create or replace function public.list_instructor_learning_materials(
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
      raise exception 'Only instructors can view learning materials';
    end if;
    raise exception 'Invalid or expired session';
  end if;

  return coalesce((
    select jsonb_agg(
      jsonb_build_object(
        'id', quiz.id,
        'title', quiz.title,
        'source_file', quiz.source_file,
        'created_at', quiz.created_at,
        'question_count', jsonb_array_length(quiz.questions),
        'folder_id', folder.id,
        'folder_name', folder.name,
        'posted_classrooms', coalesce((
          select jsonb_agg(classrooms.name order by classrooms.name)
          from (
            select distinct classroom.name
            from public.classroom_activities activity
            join public.classrooms classroom
              on classroom.id = activity.classroom_id
            where activity.quiz_id = quiz.id
              and classroom.instructor_id = verified_user_id
          ) classrooms
        ), '[]'::jsonb)
      )
      order by quiz.created_at desc, quiz.id
    )
    from public.student_generated_quizzes quiz
    left join public.instructor_learning_material_folder_items folder_item
      on folder_item.quiz_id = quiz.id
    left join public.instructor_learning_material_folders folder
      on folder.id = folder_item.folder_id
    where quiz.user_id = verified_user_id
  ), '[]'::jsonb);
end;
$$;

create or replace function public.list_instructor_learning_material_folders(
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
    raise exception 'Invalid or unauthorized instructor session';
  end if;

  return coalesce((
    select jsonb_agg(
      jsonb_build_object(
        'id', folder.id,
        'name', folder.name,
        'created_at', folder.created_at
      )
      order by lower(folder.name), folder.created_at
    )
    from public.instructor_learning_material_folders folder
    where folder.instructor_id = verified_user_id
  ), '[]'::jsonb);
end;
$$;

create or replace function public.create_instructor_learning_material_folder(
  p_session_token text,
  p_name text
) returns jsonb
language plpgsql
security definer
set search_path = public
as $$
declare
  verified_user_id bigint;
  created_folder public.instructor_learning_material_folders%rowtype;
begin
  select u.id into verified_user_id
  from public.user_sessions s
  join public.users u on u.id = s.user_id
  where s.session_token = p_session_token
    and s.expires_at > now()
    and u.role = 'instructor'
  limit 1;
  if verified_user_id is null then
    raise exception 'Invalid or unauthorized instructor session';
  end if;
  if length(trim(coalesce(p_name, ''))) not between 1 and 80 then
    raise exception 'Folder names must be between 1 and 80 characters';
  end if;

  insert into public.instructor_learning_material_folders (
    instructor_id, name
  ) values (verified_user_id, trim(p_name))
  returning * into created_folder;

  return jsonb_build_object(
    'id', created_folder.id,
    'name', created_folder.name,
    'created_at', created_folder.created_at
  );
exception
  when unique_violation then
    raise exception 'A folder with that name already exists';
end;
$$;

create or replace function public.assign_instructor_learning_material_folder(
  p_session_token text,
  p_quiz_id uuid,
  p_folder_id uuid
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
    raise exception 'Invalid or unauthorized instructor session';
  end if;
  if not exists (
    select 1 from public.student_generated_quizzes quiz
    where quiz.id = p_quiz_id and quiz.user_id = verified_user_id
  ) then
    raise exception 'Saved quiz not found';
  end if;

  if p_folder_id is null then
    delete from public.instructor_learning_material_folder_items item
    using public.instructor_learning_material_folders folder
    where item.quiz_id = p_quiz_id
      and folder.id = item.folder_id
      and folder.instructor_id = verified_user_id;
    return;
  end if;

  if not exists (
    select 1 from public.instructor_learning_material_folders folder
    where folder.id = p_folder_id
      and folder.instructor_id = verified_user_id
  ) then
    raise exception 'Folder not found';
  end if;

  insert into public.instructor_learning_material_folder_items (
    quiz_id, folder_id
  ) values (p_quiz_id, p_folder_id)
  on conflict (quiz_id) do update set folder_id = excluded.folder_id;
end;
$$;

create or replace function public.delete_instructor_learning_material(
  p_session_token text,
  p_quiz_id uuid
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
      raise exception 'Only instructors can delete learning materials';
    end if;
    raise exception 'Invalid or expired session';
  end if;

  delete from public.student_generated_quizzes quiz
  where quiz.id = p_quiz_id
    and quiz.user_id = verified_user_id;
  if not found then
    raise exception 'Saved quiz not found';
  end if;
end;
$$;

revoke all on function public.list_instructor_learning_materials(text)
  from public;
revoke all on function public.list_instructor_learning_material_folders(text)
  from public;
revoke all on function public.create_instructor_learning_material_folder(
  text, text
) from public;
revoke all on function public.assign_instructor_learning_material_folder(
  text, uuid, uuid
) from public;
revoke all on function public.delete_instructor_learning_material(text, uuid)
  from public;

grant execute on function public.list_instructor_learning_materials(text)
  to anon, authenticated;
grant execute on function public.list_instructor_learning_material_folders(text)
  to anon, authenticated;
grant execute on function public.create_instructor_learning_material_folder(
  text, text
) to anon, authenticated;
grant execute on function public.assign_instructor_learning_material_folder(
  text, uuid, uuid
) to anon, authenticated;
grant execute on function public.delete_instructor_learning_material(text, uuid)
  to anon, authenticated;
