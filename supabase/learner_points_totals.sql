-- Run after learner_points.sql. This view always reflects current ledger totals.
create or replace view public.user_learner_point_totals as
select
  u.id as user_id,
  u.full_name,
  coalesce(sum(lp.points_delta), 0)::bigint as total_learner_points,
  max(lp.created_at) as last_points_updated_at
from public.users u
left join public.learner_point_transactions lp on lp.user_id = u.id
group by u.id, u.full_name;

revoke all on public.user_learner_point_totals from anon, authenticated;

-- The app reads a signed-in user's total through this RPC; it does not need
-- direct access to the totals view or the underlying points ledger.
create or replace function public.get_learner_points(p_session_token text)
returns integer
language plpgsql
security definer
set search_path = public
as $$
declare
  verified_user_id bigint;
  point_balance integer;
begin
  select user_id into verified_user_id
  from public.user_sessions
  where session_token = p_session_token and expires_at > now()
  limit 1;

  if verified_user_id is null then
    raise exception 'Invalid or expired session';
  end if;

  select total_learner_points::integer into point_balance
  from public.user_learner_point_totals
  where user_id = verified_user_id;

  return coalesce(point_balance, 0);
end;
$$;

revoke all on function public.get_learner_points(text) from public;
grant execute on function public.get_learner_points(text) to anon, authenticated;

-- View totals ordered by highest accumulated points:
-- select user_id, full_name, total_learner_points, last_points_updated_at
-- from public.user_learner_point_totals
-- order by total_learner_points desc, user_id;
