-- Run after learner_points.sql. Returns students ranked by LP earned in a
-- calendar week: 0 = this week, -1 = last week, -2 = two weeks ago.
create or replace function public.get_weekly_learner_points(
  p_session_token text,
  p_week_offset integer default 0
) returns table (
  rank bigint,
  user_id bigint,
  full_name text,
  weekly_points bigint
)
language plpgsql
stable
security definer
set search_path = public
as $$
declare
  verified_user_id bigint;
  week_start timestamptz;
  week_end timestamptz;
begin
  select session.user_id into verified_user_id
  from public.user_sessions as session
  where session.session_token = p_session_token
    and session.expires_at > now()
  limit 1;

  if verified_user_id is null then
    raise exception 'Invalid or expired session';
  end if;

  if p_week_offset not between -2 and 0 then
    raise exception 'Invalid leaderboard week';
  end if;

  week_start :=
    date_trunc('week', now()) + (p_week_offset * interval '1 week');
  week_end := week_start + interval '1 week';

  return query
  with weekly_totals as (
    select
      student.id,
      student.full_name,
      coalesce(sum(points.points_delta), 0)::bigint as points
    from public.users as student
    left join public.learner_point_transactions as points
      on points.user_id = student.id
     and points.created_at >= week_start
     and points.created_at < week_end
    where student.role = 'student'
    group by student.id, student.full_name
  )
  select
    dense_rank() over (order by totals.points desc),
    totals.id,
    totals.full_name,
    totals.points
  from weekly_totals as totals
  order by totals.points desc, totals.full_name, totals.id;
end;
$$;

revoke all on function public.get_weekly_learner_points(text, integer)
  from public;
grant execute on function public.get_weekly_learner_points(text, integer)
  to anon, authenticated;
