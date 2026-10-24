-- Run after custom_auth.sql, classrooms.sql, quiz_attempts.sql, and
-- classroom_activities.sql.
create or replace function public.get_admin_overview(
  p_session_token text
) returns jsonb
language plpgsql
security definer
set search_path = public
as $$
declare
  verified_admin_id bigint;
begin
  select u.id into verified_admin_id
  from public.user_sessions s
  join public.users u on u.id = s.user_id
  where s.session_token = p_session_token
    and s.expires_at > now()
    and u.role = 'admin';

  if verified_admin_id is null then
    if exists (
      select 1
      from public.user_sessions s
      where s.session_token = p_session_token
        and s.expires_at > now()
    ) then
      raise exception 'Only admins can view the admin overview';
    end if;
    raise exception 'Invalid or expired session';
  end if;

  return jsonb_build_object(
    'student_count', (
      select count(*) from public.users where role = 'student'
    ),
    'instructor_count', (
      select count(*) from public.users where role = 'instructor'
    ),
    'classroom_count', (
      select count(*) from public.classrooms
    ),
    'recent_updates', coalesce(
      (
        select jsonb_agg(
          jsonb_build_object(
            'type', updates.type,
            'title', updates.title,
            'description', updates.description,
            'created_at', updates.created_at
          )
          order by updates.created_at desc
        )
        from (
          select *
          from (
            select
              'person'::text as type,
              u.full_name || ' joined as ' || initcap(u.role) as title,
              coalesce(u.email, '') as description,
              u.created_at
            from public.users u
            where u.role in ('student', 'instructor')

            union all

            select
              'classroom'::text as type,
              'Classroom created: ' || c.name as title,
              c.subject || ' - ' || u.full_name as description,
              c.created_at
            from public.classrooms c
            join public.users u on u.id = c.instructor_id

            union all

            select
              'enrollment'::text as type,
              u.full_name || ' joined a classroom' as title,
              c.name as description,
              cs.joined_at as created_at
            from public.classroom_students cs
            join public.users u on u.id = cs.student_id
            join public.classrooms c on c.id = cs.classroom_id

            union all

            select
              'activity'::text as type,
              'Activity posted: ' || q.title as title,
              c.name as description,
              a.created_at
            from public.classroom_activities a
            join public.classrooms c on c.id = a.classroom_id
            join public.student_generated_quizzes q on q.id = a.quiz_id
          ) all_updates
          order by all_updates.created_at desc
          limit 8
        ) updates
      ),
      '[]'::jsonb
    )
  );
end;
$$;

revoke all on function public.get_admin_overview(text) from public;
grant execute on function public.get_admin_overview(text) to anon, authenticated;

notify pgrst, 'reload schema';
