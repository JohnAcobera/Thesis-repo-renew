-- Run after custom_auth.sql. Todo payloads are AES-GCM encrypted in the app
-- before they reach this table; only the owning account can read or write them.

create table if not exists public.encrypted_user_todos (
  user_id bigint primary key references public.users(id) on delete cascade,
  encrypted_tasks text not null,
  updated_at timestamptz not null default now(),
  check (length(encrypted_tasks) between 1 and 250000)
);

alter table public.encrypted_user_todos enable row level security;
revoke all on table public.encrypted_user_todos from anon, authenticated;

create or replace function public.get_my_encrypted_todos(
  p_session_token text
) returns text
language plpgsql
stable
security definer
set search_path = public
as $$
declare
  verified_user_id bigint;
  encrypted_payload text;
begin
  select u.id into verified_user_id
  from public.user_sessions s
  join public.users u on u.id = s.user_id
  where s.session_token = p_session_token
    and s.expires_at > now()
    and u.is_active
    and u.role in ('student', 'instructor')
  limit 1;

  if verified_user_id is null then
    raise exception 'Invalid or expired session';
  end if;

  select encrypted_tasks into encrypted_payload
  from public.encrypted_user_todos
  where user_id = verified_user_id;

  return encrypted_payload;
end;
$$;

create or replace function public.save_my_encrypted_todos(
  p_session_token text,
  p_encrypted_tasks text
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
    and u.is_active
    and u.role in ('student', 'instructor')
  limit 1;

  if verified_user_id is null then
    raise exception 'Invalid or expired session';
  end if;
  if p_encrypted_tasks is null
     or length(p_encrypted_tasks) not between 1 and 250000 then
    raise exception 'Encrypted task data is invalid or too large';
  end if;

  insert into public.encrypted_user_todos (
    user_id, encrypted_tasks, updated_at
  ) values (
    verified_user_id, p_encrypted_tasks, now()
  )
  on conflict (user_id) do update
  set encrypted_tasks = excluded.encrypted_tasks,
      updated_at = excluded.updated_at;
end;
$$;

revoke all on function public.get_my_encrypted_todos(text) from public;
revoke all on function public.save_my_encrypted_todos(text, text) from public;
grant execute on function public.get_my_encrypted_todos(text)
  to anon, authenticated;
grant execute on function public.save_my_encrypted_todos(text, text)
  to anon, authenticated;

notify pgrst, 'reload schema';
