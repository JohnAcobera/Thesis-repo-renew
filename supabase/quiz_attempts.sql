create table if not exists public.quiz_attempts (
  id uuid primary key default gen_random_uuid(),
  user_id bigint not null references public.users(id) on delete cascade,
  title text not null,
  score integer not null,
  total_questions integer not null,
  source_file text not null,
  created_at timestamptz not null default now()
);

-- Make this migration safe to rerun if table creation previously stopped
-- after creating only part of the quiz_attempts schema.
alter table public.quiz_attempts
  add column if not exists id uuid default gen_random_uuid(),
  add column if not exists user_id bigint references public.users(id) on delete cascade,
  add column if not exists title text,
  add column if not exists score integer,
  add column if not exists total_questions integer,
  add column if not exists source_file text,
  add column if not exists created_at timestamptz default now();

alter table public.quiz_attempts
  alter column id set default gen_random_uuid(),
  alter column id set not null,
  alter column user_id set not null,
  alter column title set not null,
  alter column score set not null,
  alter column total_questions set not null,
  alter column source_file set not null,
  alter column created_at set default now(),
  alter column created_at set not null;

do $$
begin
  if not exists (
    select 1
    from pg_constraint
    where conrelid = 'public.quiz_attempts'::regclass
      and contype = 'p'
  ) then
    alter table public.quiz_attempts
      add constraint quiz_attempts_pkey primary key (id);
  end if;

  if not exists (
    select 1
    from pg_constraint
    where conrelid = 'public.quiz_attempts'::regclass
      and conname = 'quiz_attempts_score_check'
  ) then
    alter table public.quiz_attempts
      add constraint quiz_attempts_score_check
      check (score >= 0 and score <= total_questions);
  end if;

  alter table public.quiz_attempts
    drop constraint if exists quiz_attempts_total_questions_check;
  alter table public.quiz_attempts
    add constraint quiz_attempts_total_questions_check
    check (total_questions in (10, 20, 30, 50));
end;
$$;

create index if not exists quiz_attempts_user_created_idx
  on public.quiz_attempts (user_id, created_at desc);

alter table public.quiz_attempts enable row level security;
revoke all on table public.quiz_attempts from anon, authenticated;

create or replace function public.save_quiz_attempt(
  p_session_token text,
  p_title text,
  p_score integer,
  p_total_questions integer,
  p_source_file text
) returns void
language plpgsql
security definer
set search_path = public
as $$
declare
  verified_user_id bigint;
begin
  select user_id into verified_user_id
  from public.user_sessions
  where session_token = p_session_token and expires_at > now();

  if verified_user_id is null then
    raise exception 'Invalid or expired session';
  end if;
  if p_title is null or length(trim(p_title)) = 0 or length(p_title) > 200
     or p_source_file is null or length(trim(p_source_file)) = 0
     or length(p_source_file) > 200
     or p_score is null or p_total_questions is null
     or p_total_questions not in (10, 20, 30, 50)
     or p_score < 0 or p_score > p_total_questions then
    raise exception 'Invalid quiz attempt';
  end if;

  insert into public.quiz_attempts (
    user_id, title, score, total_questions, source_file
  ) values (
    verified_user_id, trim(p_title), p_score, p_total_questions, trim(p_source_file)
  );
end;
$$;

create or replace function public.list_recent_quiz_attempts(
  p_session_token text
) returns table (
  id uuid,
  title text,
  score integer,
  total_questions integer,
  source_file text,
  created_at timestamptz
)
language plpgsql
stable
security definer
set search_path = public
as $$
declare
  verified_user_id bigint;
begin
  select user_id into verified_user_id
  from public.user_sessions
  where session_token = p_session_token and expires_at > now();

  if verified_user_id is null then
    raise exception 'Invalid or expired session';
  end if;

  return query
  select a.id, a.title, a.score, a.total_questions, a.source_file, a.created_at
  from public.quiz_attempts a
  where a.user_id = verified_user_id
  order by a.created_at desc
  limit 5;
end;
$$;

revoke all on function public.save_quiz_attempt(text, text, integer, integer, text)
  from public;
revoke all on function public.list_recent_quiz_attempts(text) from public;
grant execute on function public.save_quiz_attempt(text, text, integer, integer, text)
  to anon, authenticated;
grant execute on function public.list_recent_quiz_attempts(text)
  to anon, authenticated;
