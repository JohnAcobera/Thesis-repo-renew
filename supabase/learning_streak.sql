-- Record one learning streak date per user per calendar day.
create table if not exists public.user_login_days (
  user_id bigint not null references public.users(id) on delete cascade,
  login_date date not null,
  primary key (user_id, login_date)
);

alter table public.user_login_days enable row level security;
revoke all on table public.user_login_days from anon, authenticated;

-- Preserve login history already present in the custom session table.
insert into public.user_login_days (user_id, login_date)
select distinct user_id, created_at::date
from public.user_sessions
on conflict (user_id, login_date) do nothing;

create or replace function public.record_user_login_day()
returns trigger
language plpgsql
security definer
set search_path = public
as $$
begin
  insert into public.user_login_days (user_id, login_date)
  values (new.user_id, current_date)
  on conflict (user_id, login_date) do nothing;
  return new;
end;
$$;

revoke all on function public.record_user_login_day() from public;

drop trigger if exists user_sessions_record_login_day on public.user_sessions;
create trigger user_sessions_record_login_day
after insert on public.user_sessions
for each row execute function public.record_user_login_day();

create or replace function public.get_login_activity(p_session_token text)
returns jsonb
language plpgsql
security definer
set search_path = public
as $$
declare
  found_user_id bigint;
  login_dates jsonb;
begin
  select user_id into found_user_id
  from public.user_sessions
  where session_token = p_session_token and expires_at > now()
  limit 1;

  if found_user_id is null then
    raise exception 'Invalid or expired session';
  end if;

  select coalesce(
    jsonb_agg(to_char(login_date, 'YYYY-MM-DD') order by login_date),
    '[]'::jsonb
  ) into login_dates
  from public.user_login_days
  where user_id = found_user_id;

  return jsonb_build_object('login_dates', login_dates);
end;
$$;

revoke all on function public.get_login_activity(text) from public;
grant execute on function public.get_login_activity(text) to anon, authenticated;
