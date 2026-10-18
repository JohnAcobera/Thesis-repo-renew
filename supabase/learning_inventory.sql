create table if not exists public.learning_inventory_items (
  id uuid primary key default gen_random_uuid(),
  user_id bigint not null references public.users(id) on delete cascade,
  item_type text not null check (item_type in ('flashcards', 'matching')),
  title text not null,
  source_file text not null,
  content jsonb not null,
  created_at timestamptz not null default now()
);

create table if not exists public.learning_inventory_attempts (
  id uuid primary key default gen_random_uuid(),
  item_id uuid not null references public.learning_inventory_items(id) on delete cascade,
  user_id bigint not null references public.users(id) on delete cascade,
  score integer not null,
  total_items integer not null,
  created_at timestamptz not null default now(),
  constraint learning_inventory_attempts_score_check
    check (score >= 0 and score <= total_items),
  constraint learning_inventory_attempts_total_check
    check (total_items between 1 and 30)
);

create index if not exists learning_inventory_items_user_created_idx
  on public.learning_inventory_items (user_id, created_at desc);
create index if not exists learning_inventory_attempts_item_created_idx
  on public.learning_inventory_attempts (item_id, created_at desc);

alter table public.learning_inventory_items enable row level security;
alter table public.learning_inventory_attempts enable row level security;
revoke all on table public.learning_inventory_items from anon, authenticated;
revoke all on table public.learning_inventory_attempts from anon, authenticated;

create or replace function public.save_learning_inventory_item(
  p_session_token text,
  p_item_type text,
  p_title text,
  p_source_file text,
  p_content jsonb
) returns uuid
language plpgsql
security definer
set search_path = public
as $$
declare
  verified_user_id bigint;
  saved_id uuid;
  entry jsonb;
  left_values text[] := '{}';
  right_values text[] := '{}';
  distinct_left_count integer;
  distinct_right_count integer;
begin
  select user_id into verified_user_id
  from public.user_sessions
  where session_token = p_session_token and expires_at > now();

  if verified_user_id is null then
    raise exception 'Invalid or expired session';
  end if;
  if p_item_type is null or p_item_type not in ('flashcards', 'matching')
     or p_title is null or length(trim(p_title)) = 0 or length(p_title) > 200
     or p_source_file is null or length(trim(p_source_file)) = 0
     or length(p_source_file) > 200
     or jsonb_typeof(p_content) is distinct from 'array' then
    raise exception 'Invalid learning activity';
  end if;
  if jsonb_array_length(p_content) not between 1 and 30 then
    raise exception 'Invalid learning activity';
  end if;

  for entry in select value from jsonb_array_elements(p_content)
  loop
    if jsonb_typeof(entry) is distinct from 'object'
       or jsonb_typeof(entry->'explanation') is distinct from 'string'
       or length(trim(entry->>'explanation')) = 0 then
      raise exception 'Invalid learning activity content';
    end if;

    if p_item_type = 'flashcards' then
      if jsonb_typeof(entry->'question') is distinct from 'string'
         or length(trim(entry->>'question')) = 0
         or jsonb_typeof(entry->'answer') is distinct from 'string'
         or length(trim(entry->>'answer')) = 0 then
        raise exception 'Invalid flashcard content';
      end if;
    else
      if jsonb_typeof(entry->'left') is distinct from 'string'
         or length(trim(entry->>'left')) = 0
         or jsonb_typeof(entry->'right') is distinct from 'string'
         or length(trim(entry->>'right')) = 0 then
        raise exception 'Invalid matching content';
      end if;
      left_values := array_append(left_values, lower(trim(entry->>'left')));
      right_values := array_append(right_values, lower(trim(entry->>'right')));
    end if;
  end loop;

  if p_item_type = 'matching' then
    select count(distinct label) into distinct_left_count
    from unnest(left_values) as labels(label);
    select count(distinct label) into distinct_right_count
    from unnest(right_values) as labels(label);
    if cardinality(left_values) <> distinct_left_count
       or cardinality(right_values) <> distinct_right_count then
      raise exception 'Matching prompts and answers must be unique';
    end if;
  end if;

  insert into public.learning_inventory_items (
    user_id, item_type, title, source_file, content
  ) values (
    verified_user_id, trim(p_item_type), trim(p_title), trim(p_source_file), p_content
  ) returning id into saved_id;

  return saved_id;
end;
$$;

create or replace function public.save_learning_inventory_attempt(
  p_session_token text,
  p_item_id uuid,
  p_score integer,
  p_total_items integer
) returns void
language plpgsql
security definer
set search_path = public
as $$
declare
  verified_user_id bigint;
  expected_items integer;
begin
  select user_id into verified_user_id
  from public.user_sessions
  where session_token = p_session_token and expires_at > now();

  if verified_user_id is null then
    raise exception 'Invalid or expired session';
  end if;
  select jsonb_array_length(content)
  into expected_items
  from public.learning_inventory_items
  where id = p_item_id and user_id = verified_user_id;

  if expected_items is null
     or p_total_items is null
     or p_total_items <> expected_items
     or p_score is null or p_score < 0 or p_score > p_total_items then
    raise exception 'Invalid learning activity result';
  end if;

  insert into public.learning_inventory_attempts (
    item_id, user_id, score, total_items
  ) values (
    p_item_id, verified_user_id, p_score, p_total_items
  );
end;
$$;

create or replace function public.list_learning_inventory_items(
  p_session_token text
) returns table (
  id uuid,
  item_type text,
  title text,
  source_file text,
  content jsonb,
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
  select item.id, item.item_type, item.title, item.source_file,
    item.content, item.created_at,
    coalesce(
      jsonb_agg(
        jsonb_build_object(
          'score', attempt.score,
          'total_items', attempt.total_items,
          'created_at', attempt.created_at
        ) order by attempt.created_at desc
      ) filter (where attempt.id is not null),
      '[]'::jsonb
    )
  from public.learning_inventory_items item
  left join public.learning_inventory_attempts attempt
    on attempt.item_id = item.id and attempt.user_id = verified_user_id
  where item.user_id = verified_user_id
  group by item.id
  order by item.created_at desc;
end;
$$;

revoke all on function public.save_learning_inventory_item(
  text, text, text, text, jsonb
) from public;
revoke all on function public.save_learning_inventory_attempt(
  text, uuid, integer, integer
) from public;
revoke all on function public.list_learning_inventory_items(text) from public;
grant execute on function public.save_learning_inventory_item(
  text, text, text, text, jsonb
) to anon, authenticated;
grant execute on function public.save_learning_inventory_attempt(
  text, uuid, integer, integer
) to anon, authenticated;
grant execute on function public.list_learning_inventory_items(text)
  to anon, authenticated;
