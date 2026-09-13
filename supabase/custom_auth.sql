-- Custom authentication migration.
-- This intentionally does not reference Supabase Auth or auth.users.
create extension if not exists pgcrypto;

alter table public.users
  add column if not exists email text,
  add column if not exists password_hash text;

create unique index if not exists users_email_unique_idx
  on public.users (lower(email))
  where email is not null;

alter table public.users drop constraint if exists users_role_check;
alter table public.users add constraint users_role_check
  check (role in ('student', 'instructor'));

create table if not exists public.user_sessions (
  id uuid primary key default gen_random_uuid(),
  user_id bigint not null references public.users(id) on delete cascade,
  session_token text not null unique,
  created_at timestamptz not null default now(),
  expires_at timestamptz not null
);

alter table public.users enable row level security;
alter table public.user_sessions enable row level security;

revoke all on table public.users from anon, authenticated;
revoke all on table public.user_sessions from anon, authenticated;

create or replace function public.register_user(
  p_full_name text,
  p_email text,
  p_password text,
  p_role text
) returns void
language plpgsql
security definer
set search_path = public, extensions
as $$
begin
  if length(trim(p_full_name)) < 2
     or length(p_password) < 8
     or p_role not in ('student', 'instructor')
     or p_email !~* '^[^@[:space:]]+@[^@[:space:]]+\.[^@[:space:]]+$' then
    raise exception 'Invalid registration details';
  end if;

  if exists (select 1 from public.users where lower(email) = lower(trim(p_email))) then
    raise exception 'Email is already registered';
  end if;

  insert into public.users (full_name, email, password_hash, role)
  values (trim(p_full_name), lower(trim(p_email)), crypt(p_password, gen_salt('bf', 12)), p_role);
end;
$$;

create or replace function public.login_user(p_email text, p_password text)
returns jsonb
language plpgsql
security definer
set search_path = public, extensions
as $$
declare
  found_user public.users%rowtype;
  new_token text;
begin
  select * into found_user
  from public.users
  where lower(email) = lower(trim(p_email))
    and password_hash is not null
    and password_hash = crypt(p_password, password_hash);

  if found_user.id is null then
    raise exception 'Invalid email or password';
  end if;

  new_token := encode(gen_random_bytes(32), 'hex');
  insert into public.user_sessions (user_id, session_token, expires_at)
  values (found_user.id, new_token, now() + interval '30 days');

  return jsonb_build_object(
    'session_token', new_token,
    'user', jsonb_build_object(
      'id', found_user.id,
      'full_name', found_user.full_name,
      'email', found_user.email,
      'role', found_user.role
    )
  );
end;
$$;

create or replace function public.verify_session(p_session_token text)
returns jsonb
language plpgsql
security definer
set search_path = public, extensions
as $$
declare result jsonb;
begin
  select jsonb_build_object(
    'id', u.id, 'full_name', u.full_name, 'email', u.email, 'role', u.role
  ) into result
  from public.user_sessions s
  join public.users u on u.id = s.user_id
  where s.session_token = p_session_token and s.expires_at > now();
  if result is null then raise exception 'Invalid or expired session'; end if;
  return result;
end;
$$;

create or replace function public.logout_user(p_session_token text)
returns void
language sql
security definer
set search_path = public
as $$ delete from public.user_sessions where session_token = p_session_token; $$;

revoke all on function public.register_user(text, text, text, text) from public;
revoke all on function public.login_user(text, text) from public;
revoke all on function public.verify_session(text) from public;
revoke all on function public.logout_user(text) from public;
grant execute on function public.register_user(text, text, text, text) to anon, authenticated;
grant execute on function public.login_user(text, text) to anon, authenticated;
grant execute on function public.verify_session(text) to anon, authenticated;
grant execute on function public.logout_user(text) to anon, authenticated;
