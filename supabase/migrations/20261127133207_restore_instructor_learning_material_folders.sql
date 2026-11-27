-- Restore the instructor learning-material folders feature.
-- The two tables were never created on the remote project, so every folder RPC
-- failed with 42P01. This applies the exact local definitions and replaces the
-- remote-only (broken) variant of list_instructor_learning_materials, which
-- referenced the retired classroom_activities table.
-- No data changes; all statements are idempotent.

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
        'folder_name', folder.name
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

grant execute on function public.list_instructor_learning_materials(text)
  to anon, authenticated;

notify pgrst, 'reload schema';
