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
  add column if not exists created_at timestamptz default now(),
  add column if not exists quiz_id uuid;

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

create table if not exists public.student_generated_quizzes (
  id uuid primary key default gen_random_uuid(),
  user_id bigint not null references public.users(id) on delete cascade,
  title text not null,
  source_file text not null,
  questions jsonb not null,
  created_at timestamptz not null default now()
);

alter table public.student_generated_quizzes enable row level security;
revoke all on table public.student_generated_quizzes from anon, authenticated;

alter table public.quiz_attempts
  drop constraint if exists quiz_attempts_quiz_id_fkey;

do $$
begin
  alter table public.quiz_attempts
    add constraint quiz_attempts_quiz_id_fkey
    foreign key (quiz_id)
    references public.student_generated_quizzes(id) on delete set null;
end;
$$;

create index if not exists quiz_attempts_user_created_idx
  on public.quiz_attempts (user_id, created_at desc);
create index if not exists quiz_attempts_quiz_created_idx
  on public.quiz_attempts (quiz_id, created_at desc);
create index if not exists student_generated_quizzes_user_created_idx
  on public.student_generated_quizzes (user_id, created_at desc);

revoke all on table public.quiz_attempts from anon, authenticated;

drop function if exists public.save_quiz_attempt(text, text, integer, integer, text);

create or replace function public.save_quiz_attempt(
  p_session_token text,
  p_title text,
  p_score integer,
  p_total_questions integer,
  p_source_file text,
  p_quiz_id uuid,
  p_questions jsonb
) returns uuid
language plpgsql
security definer
set search_path = public
as $$
declare
  verified_user_id bigint;
  saved_quiz_id uuid;
  saved_title text;
  saved_source_file text;
  saved_question_count integer;
  question jsonb;
  option_value jsonb;
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

  if p_quiz_id is null then
    if jsonb_typeof(p_questions) is distinct from 'array' then
      raise exception 'Invalid quiz questions';
    end if;
    if jsonb_array_length(p_questions) <> p_total_questions then
      raise exception 'Invalid quiz questions';
    end if;
    for question in select value from jsonb_array_elements(p_questions)
    loop
      if jsonb_typeof(question) is distinct from 'object'
         or jsonb_typeof(question->'question') is distinct from 'string'
         or length(trim(question->>'question')) = 0
         or jsonb_typeof(question->'explanation') is distinct from 'string'
         or length(trim(question->>'explanation')) = 0
         or jsonb_typeof(question->'options') is distinct from 'array'
         or jsonb_typeof(question->'answerIndex') is distinct from 'number'
         or (question->>'answerIndex') !~ '^[0-3]$' then
        raise exception 'Invalid quiz questions';
      end if;
      if jsonb_array_length(question->'options') <> 4 then
        raise exception 'Invalid quiz questions';
      end if;
      for option_value in
        select value from jsonb_array_elements(question->'options')
      loop
        if jsonb_typeof(option_value) is distinct from 'string'
           or length(trim(option_value#>>'{}')) = 0 then
          raise exception 'Invalid quiz questions';
        end if;
      end loop;
    end loop;

    insert into public.student_generated_quizzes (
      user_id, title, source_file, questions
    ) values (
      verified_user_id, trim(p_title), trim(p_source_file), p_questions
    ) returning id, title, source_file
      into saved_quiz_id, saved_title, saved_source_file;
    saved_question_count := p_total_questions;
  else
    select q.id, q.title, q.source_file, jsonb_array_length(q.questions)
      into saved_quiz_id, saved_title, saved_source_file, saved_question_count
    from public.student_generated_quizzes q
    where q.id = p_quiz_id and q.user_id = verified_user_id;

    if saved_quiz_id is null then
      raise exception 'Saved quiz not found';
    end if;

    if p_questions is not null then
      raise exception 'Questions cannot be changed when retaking a quiz';
    end if;
    if p_total_questions <> saved_question_count then
      raise exception 'Invalid quiz attempt';
    end if;
  end if;

  insert into public.quiz_attempts (
    user_id, title, score, total_questions, source_file, quiz_id
  ) values (
    verified_user_id, saved_title, p_score, p_total_questions,
    saved_source_file, saved_quiz_id
  );
  return saved_quiz_id;
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
  order by a.created_at desc;
end;
$$;

create or replace function public.list_saved_quizzes(
  p_session_token text
) returns table (
  id uuid,
  title text,
  source_file text,
  questions jsonb,
  created_at timestamptz,
  attempts jsonb
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
  select q.id, q.title, q.source_file, q.questions, q.created_at,
    coalesce(
      jsonb_agg(
        jsonb_build_object(
          'score', a.score,
          'total_questions', a.total_questions,
          'created_at', a.created_at
        ) order by a.created_at desc
      ) filter (where a.id is not null),
      '[]'::jsonb
    )
  from public.student_generated_quizzes q
  left join public.quiz_attempts a
    on a.quiz_id = q.id and a.user_id = verified_user_id
  where q.user_id = verified_user_id
  group by q.id
  order by q.created_at desc;
end;
$$;

revoke all on function public.save_quiz_attempt(
  text, text, integer, integer, text, uuid, jsonb
)
  from public;
revoke all on function public.list_saved_quizzes(text) from public;
revoke all on function public.list_recent_quiz_attempts(text) from public;
grant execute on function public.save_quiz_attempt(
  text, text, integer, integer, text, uuid, jsonb
)
  to anon, authenticated;
grant execute on function public.list_saved_quizzes(text)
  to anon, authenticated;
grant execute on function public.list_recent_quiz_attempts(text)
  to anon, authenticated;
