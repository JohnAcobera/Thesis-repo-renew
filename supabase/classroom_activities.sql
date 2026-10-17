-- Run after classrooms.sql and quiz_attempts.sql.
create table if not exists public.classroom_activities (
  id uuid primary key default gen_random_uuid(),
  classroom_id uuid not null references public.classrooms(id) on delete cascade,
  quiz_id uuid not null references public.student_generated_quizzes(id)
    on delete cascade,
  starts_at timestamptz not null,
  deadline_at timestamptz not null,
  max_attempts integer not null default 2,
  created_at timestamptz not null default now(),
  constraint classroom_activities_deadline_after_start
    check (deadline_at > starts_at),
  constraint classroom_activities_max_attempts_check
    check (max_attempts between 1 and 20)
);

alter table public.classroom_activities
  add column if not exists max_attempts integer not null default 2;

alter table public.classroom_activities
  drop constraint if exists classroom_activities_max_attempts_check;
alter table public.classroom_activities
  add constraint classroom_activities_max_attempts_check
  check (max_attempts between 1 and 20);

alter table public.quiz_attempts
  add column if not exists classroom_activity_id uuid;
alter table public.quiz_attempts
  drop constraint if exists quiz_attempts_classroom_activity_id_fkey;
alter table public.quiz_attempts
  add constraint quiz_attempts_classroom_activity_id_fkey
  foreign key (classroom_activity_id)
  references public.classroom_activities(id) on delete set null;

with matching_activities as (
  select qa.id as attempt_id, (array_agg(a.id order by a.id))[1] as activity_id,
    count(*) as match_count
  from public.quiz_attempts qa
  join public.classroom_activities a on a.quiz_id = qa.quiz_id
  join public.classroom_students cs
    on cs.classroom_id = a.classroom_id and cs.student_id = qa.user_id
  where qa.classroom_activity_id is null
    and qa.created_at between a.starts_at and a.deadline_at
  group by qa.id
)
update public.quiz_attempts qa
set classroom_activity_id = matching_activities.activity_id
from matching_activities
where qa.id = matching_activities.attempt_id
  and matching_activities.match_count = 1;

create index if not exists classroom_activities_classroom_schedule_idx
  on public.classroom_activities (classroom_id, starts_at, deadline_at);
create index if not exists quiz_attempts_classroom_activity_user_created_idx
  on public.quiz_attempts (classroom_activity_id, user_id, created_at desc)
  where classroom_activity_id is not null;

alter table public.classroom_activities enable row level security;
revoke all on table public.classroom_activities from anon, authenticated;

create or replace function public.save_quiz_draft(
  p_session_token text,
  p_title text,
  p_source_file text,
  p_questions jsonb
) returns uuid
language plpgsql
security definer
set search_path = public
as $$
declare
  verified_user_id bigint;
  saved_quiz_id uuid;
  question jsonb;
  option_value jsonb;
  question_count integer;
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
     or jsonb_typeof(p_questions) is distinct from 'array' then
    raise exception 'Invalid quiz draft';
  end if;

  question_count := jsonb_array_length(p_questions);
  if question_count < 1 or question_count > 30 then
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
       or jsonb_typeof(question->'answerIndex') is distinct from 'number' then
      raise exception 'Invalid quiz questions';
    end if;
    if jsonb_array_length(question->'options') not in (2, 4) then
      raise exception 'Invalid quiz questions';
    end if;
    if (
      jsonb_array_length(question->'options') = 2
      and (
        (question->>'answerIndex') !~ '^[0-1]$'
        or lower(trim(question->'options'->>0)) <> 'true'
        or lower(trim(question->'options'->>1)) <> 'false'
      )
    ) or (
      jsonb_array_length(question->'options') = 4
      and (question->>'answerIndex') !~ '^[0-3]$'
    ) then
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
  ) returning id into saved_quiz_id;
  return saved_quiz_id;
end;
$$;

drop function if exists public.post_classroom_activity(
  text, uuid, uuid[], timestamptz, timestamptz
);

create or replace function public.post_classroom_activity(
  p_session_token text,
  p_quiz_id uuid,
  p_classroom_ids uuid[],
  p_starts_at timestamptz,
  p_deadline_at timestamptz,
  p_max_attempts integer default 2
) returns integer
language plpgsql
security definer
set search_path = public
as $$
declare
  verified_user_id bigint;
  requested_classroom_count integer;
  owned_classroom_count integer;
  posted_count integer;
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
  if p_starts_at is null or p_starts_at < now()
     or p_deadline_at is null or p_deadline_at <= p_starts_at
     or p_max_attempts is null or p_max_attempts < 1
     or p_max_attempts > 20 then
    raise exception 'Invalid activity schedule';
  end if;
  if p_classroom_ids is null
     or array_position(p_classroom_ids, null) is not null then
    raise exception 'Choose valid classrooms';
  end if;
  if not exists (
    select 1 from public.student_generated_quizzes q
    where q.id = p_quiz_id and q.user_id = verified_user_id
  ) then
    raise exception 'Saved quiz not found';
  end if;

  select count(distinct classroom_id)
  into requested_classroom_count
  from unnest(coalesce(p_classroom_ids, '{}'::uuid[])) as selected(classroom_id);
  if requested_classroom_count = 0 then
    raise exception 'Choose at least one classroom';
  end if;

  select count(*)
  into owned_classroom_count
  from public.classrooms c
  where c.instructor_id = verified_user_id
    and c.id = any(p_classroom_ids);
  if owned_classroom_count <> requested_classroom_count then
    raise exception 'One or more classrooms could not be found';
  end if;

  insert into public.classroom_activities (
    classroom_id, quiz_id, starts_at, deadline_at, max_attempts
  )
  select distinct selected.classroom_id, p_quiz_id, p_starts_at,
    p_deadline_at, p_max_attempts
  from unnest(p_classroom_ids) as selected(classroom_id);
  get diagnostics posted_count = row_count;
  return posted_count;
end;
$$;

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

  return coalesce(
    (
      select jsonb_agg(
        jsonb_build_object(
          'id', a.id,
          'classroom_id', c.id,
          'classroom_name', c.name,
          'quiz_id', q.id,
          'title', q.title,
          'source_file', q.source_file,
          'questions', q.questions,
          'starts_at', a.starts_at,
          'deadline_at', a.deadline_at,
          'max_attempts', a.max_attempts,
          'attempt_count', case when verified_role = 'student' then (
            select count(*)::integer
            from public.quiz_attempts qa
            where qa.classroom_activity_id = a.id
              and qa.user_id = verified_user_id
          ) else 0 end,
          'attempts', case when verified_role = 'student' then coalesce((
            select jsonb_agg(
              jsonb_build_object(
                'score', qa.score,
                'total_questions', qa.total_questions,
                'created_at', qa.created_at,
                'classroom_name', c.name
              ) order by qa.created_at desc
            )
            from public.quiz_attempts qa
            where qa.classroom_activity_id = a.id
              and qa.user_id = verified_user_id
          ), '[]'::jsonb) else '[]'::jsonb end
        )
        order by a.starts_at desc
      )
      from public.classroom_activities a
      join public.classrooms c on c.id = a.classroom_id
      join public.student_generated_quizzes q on q.id = a.quiz_id
      where a.classroom_id = p_classroom_id
    ),
    '[]'::jsonb
  );
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
  saved_activity_id uuid;
  saved_quiz_id uuid;
  saved_title text;
  saved_source_file text;
  saved_question_count integer;
  saved_max_attempts integer;
  existing_attempt_count integer;
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

  select a.id, a.max_attempts, q.id, q.title, q.source_file,
    jsonb_array_length(q.questions)
    into saved_activity_id, saved_max_attempts, saved_quiz_id, saved_title,
      saved_source_file, saved_question_count
  from public.classroom_activities a
  join public.classrooms c on c.id = a.classroom_id
  join public.classroom_students cs
    on cs.classroom_id = c.id and cs.student_id = verified_user_id
  join public.student_generated_quizzes q on q.id = a.quiz_id
  where a.id = p_activity_id
    and now() >= a.starts_at
    and now() <= a.deadline_at
  for update of a;

  if saved_quiz_id is null then
    raise exception 'This activity is not available';
  end if;
  select count(*)::integer into existing_attempt_count
  from public.quiz_attempts
  where classroom_activity_id = saved_activity_id
    and user_id = verified_user_id;
  if existing_attempt_count >= saved_max_attempts then
    raise exception 'You have reached the attempt limit for this activity';
  end if;
  if p_score is null or p_total_questions is null
     or p_total_questions <> saved_question_count
     or p_score < 0 or p_score > p_total_questions then
    raise exception 'Invalid activity result';
  end if;

  insert into public.quiz_attempts (
    user_id, title, score, total_questions, source_file, quiz_id,
    classroom_activity_id
  ) values (
    verified_user_id, saved_title, p_score, p_total_questions,
    saved_source_file, saved_quiz_id, saved_activity_id
  );
  return saved_quiz_id;
end;
$$;

drop function if exists public.list_saved_quizzes(text);

create function public.list_saved_quizzes(
  p_session_token text
) returns table (
  id uuid,
  title text,
  source_file text,
  questions jsonb,
  created_at timestamptz,
  attempts jsonb,
  classroom_activity_id uuid,
  classroom_name text,
  max_attempts integer
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
    ),
    null::uuid,
    null::text,
    null::integer
  from public.student_generated_quizzes q
  left join public.quiz_attempts a
    on a.quiz_id = q.id and a.user_id = verified_user_id
      and a.classroom_activity_id is null
  where q.user_id = verified_user_id
  group by q.id

  union all

  select q.id, q.title, q.source_file, q.questions, max(a.created_at),
    jsonb_agg(
      jsonb_build_object(
        'score', a.score,
        'total_questions', a.total_questions,
        'created_at', a.created_at,
        'classroom_name', c.name
      ) order by a.created_at desc
    ),
    ca.id,
    c.name,
    ca.max_attempts
  from public.quiz_attempts a
  join public.classroom_activities ca on ca.id = a.classroom_activity_id
  join public.classrooms c on c.id = ca.classroom_id
  join public.student_generated_quizzes q on q.id = a.quiz_id
  where a.user_id = verified_user_id
  group by q.id, ca.id, c.name, ca.max_attempts
  order by 5 desc;
end;
$$;

revoke all on function public.save_quiz_draft(text, text, text, jsonb)
  from public;
revoke all on function public.post_classroom_activity(
  text, uuid, uuid[], timestamptz, timestamptz, integer
) from public;
revoke all on function public.list_classroom_activities(text, uuid)
  from public;
revoke all on function public.submit_classroom_activity_attempt(
  text, uuid, integer, integer
) from public;

grant execute on function public.save_quiz_draft(text, text, text, jsonb)
  to anon, authenticated;
grant execute on function public.post_classroom_activity(
  text, uuid, uuid[], timestamptz, timestamptz, integer
) to anon, authenticated;
grant execute on function public.list_classroom_activities(text, uuid)
  to anon, authenticated;
grant execute on function public.submit_classroom_activity_attempt(
  text, uuid, integer, integer
) to anon, authenticated;
revoke all on function public.list_saved_quizzes(text) from public;
grant execute on function public.list_saved_quizzes(text)
  to anon, authenticated;

notify pgrst, 'reload schema';
