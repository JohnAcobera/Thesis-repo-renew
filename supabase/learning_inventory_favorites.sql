create table if not exists public.learning_inventory_favorites (
  id uuid primary key default gen_random_uuid(),
  user_id bigint not null references public.users(id) on delete cascade,
  item_type text not null check (item_type in ('quiz', 'flashcards', 'matching')),
  item_id uuid not null,
  created_at timestamptz not null default now(),
  constraint learning_inventory_favorites_unique
    unique (user_id, item_type, item_id)
);

create index if not exists learning_inventory_favorites_user_created_idx
  on public.learning_inventory_favorites (user_id, created_at desc);

alter table public.learning_inventory_favorites enable row level security;
revoke all on table public.learning_inventory_favorites from anon, authenticated;

create or replace function public.set_learning_inventory_favorite(
  p_session_token text,
  p_item_type text,
  p_item_id uuid,
  p_is_favorite boolean
) returns void
language plpgsql
security definer
set search_path = public
as $$
declare
  verified_user_id bigint;
  owns_item boolean := false;
begin
  select user_id into verified_user_id
  from public.user_sessions
  where session_token = p_session_token and expires_at > now();

  if verified_user_id is null then
    raise exception 'Invalid or expired session';
  end if;
  if p_item_type is null or p_item_id is null or p_is_favorite is null
     or p_item_type not in ('quiz', 'flashcards', 'matching') then
    raise exception 'Invalid inventory favorite';
  end if;

  if p_item_type = 'quiz' then
    select exists (
      select 1
      from public.student_generated_quizzes
      where id = p_item_id and user_id = verified_user_id
    ) into owns_item;
  else
    select exists (
      select 1
      from public.learning_inventory_items
      where id = p_item_id
        and user_id = verified_user_id
        and item_type = p_item_type
    ) into owns_item;
  end if;

  if not owns_item then
    raise exception 'Inventory activity not found';
  end if;

  if p_is_favorite then
    insert into public.learning_inventory_favorites (user_id, item_type, item_id)
    values (verified_user_id, p_item_type, p_item_id)
    on conflict (user_id, item_type, item_id) do nothing;
  else
    delete from public.learning_inventory_favorites
    where user_id = verified_user_id
      and item_type = p_item_type
      and item_id = p_item_id;
  end if;
end;
$$;

create or replace function public.list_learning_inventory_favorites(
  p_session_token text
) returns table (item_type text, item_id uuid)
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
  select favorite.item_type, favorite.item_id
  from public.learning_inventory_favorites favorite
  where favorite.user_id = verified_user_id
  order by favorite.created_at desc;
end;
$$;

revoke all on function public.set_learning_inventory_favorite(
  text, text, uuid, boolean
) from public;
revoke all on function public.list_learning_inventory_favorites(text)
  from public;
grant execute on function public.set_learning_inventory_favorite(
  text, text, uuid, boolean
) to anon, authenticated;
grant execute on function public.list_learning_inventory_favorites(text)
  to anon, authenticated;
