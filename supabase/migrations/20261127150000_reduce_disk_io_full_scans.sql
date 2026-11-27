-- Disk I/O optimization: close the remaining index gaps and remove two RPCs
-- that re-aggregate the whole database to answer a single-user question.
-- All statements are idempotent; no data is changed.

-- ---------------------------------------------------------------------------
-- 1. Missing foreign-key indexes (Supabase performance advisor).
-- ---------------------------------------------------------------------------

-- Live table: folder items are joined back to their folder when listing
-- instructor learning materials.
create index if not exists instructor_learning_material_folder_items_folder_id_idx
  on public.instructor_learning_material_folder_items (folder_id);

-- Legacy/retired table, so only create the index when the table still exists.
do $$
begin
  if to_regclass('public.classroom_activities') is not null then
    create index if not exists classroom_activities_quiz_id_idx
      on public.classroom_activities (quiz_id);
  end if;
end $$;

-- ---------------------------------------------------------------------------
-- 2. public.users is a pre-existing table, but nearly every session check and
--    admin/leaderboard query filters on role (+ is_active) or sorts by name.
-- ---------------------------------------------------------------------------
do $$
begin
  if to_regclass('public.users') is not null then
    create index if not exists users_role_is_active_idx
      on public.users (role, is_active);
    create index if not exists users_role_full_name_id_idx
      on public.users (role, full_name, id);
  end if;
end $$;

-- ---------------------------------------------------------------------------
-- 3. Points ledger: the hot lookup keys are the event type and the JSONB
--    attempt ids. Partial indexes keep these small because the ledger is the
--    most write-heavy table in the project.
-- ---------------------------------------------------------------------------
create index if not exists learner_point_transactions_event_user_created_idx
  on public.learner_point_transactions (user_id, event_type, created_at desc)
  where event_type in (
    'daily_login_streak', 'quiz_first_attempt', 'quiz_second_attempt',
    'perfect_quiz', 'quiz_score_reward'
  );

create index if not exists learner_point_transactions_attempt_id_idx
  on public.learner_point_transactions (user_id, (details->>'attempt_id'))
  where details ? 'attempt_id';

create index if not exists learner_point_transactions_perfect_attempt_id_idx
  on public.learner_point_transactions (user_id, (details->>'perfect_attempt_id'))
  where details ? 'perfect_attempt_id';

-- ---------------------------------------------------------------------------
-- 4. quiz_attempts: the common case has a real quiz_id, which makes the
--    computed legacy group key unnecessary. The partial index also serves the
--    "latest attempt for this user + quiz" lookup.
-- ---------------------------------------------------------------------------
create index if not exists quiz_attempts_user_quiz_latest_idx
  on public.quiz_attempts (user_id, quiz_id, created_at desc, id desc)
  where quiz_id is not null;

create or replace function public.award_quiz_learner_points()
returns trigger
language plpgsql
security definer
set search_path = public
as $$
declare
  quiz_group_key text;
  attempt_number bigint;
  award_type text;
  award_points integer;
begin
  if new.quiz_id is not null then
    quiz_group_key := 'quiz:' || new.quiz_id::text;
    -- Index-backed range scan instead of computing an md5 key for every
    -- previous attempt of this user.
    select count(*) into attempt_number
    from public.quiz_attempts a
    where a.user_id = new.user_id
      and a.quiz_id = new.quiz_id
      and (a.created_at, a.id) <= (new.created_at, new.id);
  else
    quiz_group_key := 'legacy:' || md5(
      lower(trim(new.title)) || chr(31) || lower(trim(new.source_file))
    );
    select count(*) into attempt_number
    from public.quiz_attempts a
    where a.user_id = new.user_id
      and a.quiz_id is null
      and case
        when a.quiz_id is not null then 'quiz:' || a.quiz_id::text
        else 'legacy:' || md5(
          lower(trim(a.title)) || chr(31) || lower(trim(a.source_file))
        )
      end = quiz_group_key
      and (a.created_at, a.id) <= (new.created_at, new.id);
  end if;

  if attempt_number = 1 then
    award_type := 'quiz_first_attempt';
    award_points := 50;
  elsif attempt_number = 2 then
    award_type := 'quiz_second_attempt';
    award_points := 25;
  else
    award_type := null;
  end if;

  if award_type is not null then
    insert into public.learner_point_transactions (
      user_id, event_type, points_delta, source_key, details, created_at
    ) values (
      new.user_id,
      award_type,
      award_points,
      award_type || ':' || new.id::text,
      jsonb_build_object(
        'attempt_id', new.id,
        'quiz_group_key', quiz_group_key,
        'attempt_number', attempt_number
      ),
      new.created_at
    )
    on conflict (user_id, source_key) do nothing;
  end if;

  if new.score = new.total_questions then
    insert into public.learner_point_transactions (
      user_id, event_type, points_delta, source_key, details, created_at
    ) values (
      new.user_id,
      'perfect_quiz',
      150,
      'perfect_quiz:' || quiz_group_key,
      jsonb_build_object(
        'quiz_group_key', quiz_group_key,
        'perfect_attempt_id', new.id
      ),
      new.created_at
    )
    on conflict (user_id, source_key) do nothing;
  end if;

  insert into public.learner_point_transactions (
    user_id, event_type, points_delta, source_key, details, created_at
  ) values (
    new.user_id,
    'quiz_score_reward',
    round(new.score::numeric * 100 / new.total_questions)::integer,
    'quiz_score:' || new.id::text,
    jsonb_build_object(
      'attempt_id', new.id,
      'score_percentage',
      round(new.score::numeric * 100 / new.total_questions)
    ),
    new.created_at
  )
  on conflict (user_id, source_key) do nothing;

  return new;
end;
$$;

revoke all on function public.award_quiz_learner_points() from public;

-- The trigger definition is unchanged; recreated only to keep the migration
-- self-contained if it is applied out of order.
drop trigger if exists quiz_attempts_award_learner_points on public.quiz_attempts;
create trigger quiz_attempts_award_learner_points
after insert on public.quiz_attempts
for each row execute function public.award_quiz_learner_points();

-- ---------------------------------------------------------------------------
-- 5. classroom_students: membership lookups and 90-day joins sort by joined_at.
-- ---------------------------------------------------------------------------
create index if not exists classroom_students_student_joined_idx
  on public.classroom_students (student_id, joined_at desc);
create index if not exists classroom_students_classroom_joined_idx
  on public.classroom_students (classroom_id, joined_at desc);

-- ---------------------------------------------------------------------------
-- 6. get_learner_points() used the user_learner_point_totals view, which
--    aggregates every user and every ledger row before filtering to one user.
-- ---------------------------------------------------------------------------
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

  select coalesce(sum(lp.points_delta), 0)::integer into point_balance
  from public.learner_point_transactions lp
  where lp.user_id = verified_user_id;

  return coalesce(point_balance, 0);
end;
$$;

revoke all on function public.get_learner_points(text) from public;
grant execute on function public.get_learner_points(text) to anon, authenticated;

-- ---------------------------------------------------------------------------
-- 7. get_admin_management_data() ran three correlated subqueries per row of
--    the users/classrooms lists. Pre-aggregate each child table once and join.
-- ---------------------------------------------------------------------------
create or replace function public.get_admin_management_data(
  p_session_token text
) returns jsonb
language plpgsql
security definer
set search_path = public
as $$
declare verified_admin_id bigint;
begin
  verified_admin_id := public._require_admin_session(p_session_token);

  return jsonb_build_object(
    'teachers', coalesce((
      select jsonb_agg(jsonb_build_object(
        'id', u.id,
        'full_name', u.full_name,
        'email', coalesce(u.email, ''),
        'created_at', u.created_at,
        'is_active', u.is_active,
        'classroom_count', coalesce(tc.classroom_count, 0)
      ) order by u.full_name)
      from public.users u
      left join (
        select instructor_id, count(*) as classroom_count
        from public.classrooms
        group by instructor_id
      ) tc on tc.instructor_id = u.id
      where u.role = 'instructor'
    ), '[]'::jsonb),
    'students', coalesce((
      select jsonb_agg(jsonb_build_object(
        'id', u.id,
        'full_name', u.full_name,
        'email', coalesce(u.email, ''),
        'created_at', u.created_at,
        'is_active', u.is_active,
        'classroom_count', coalesce(sc.classroom_count, 0)
      ) order by u.full_name)
      from public.users u
      left join (
        select student_id, count(distinct classroom_id) as classroom_count
        from public.classroom_students
        group by student_id
      ) sc on sc.student_id = u.id
      where u.role = 'student'
    ), '[]'::jsonb),
    'classrooms', coalesce((
      select jsonb_agg(jsonb_build_object(
        'id', c.id,
        'name', c.name,
        'subject', c.subject,
        'code', c.code,
        'created_at', c.created_at,
        'teacher_name', u.full_name,
        'teacher_email', coalesce(u.email, ''),
        'student_count', coalesce(cc.student_count, 0)
      ) order by c.created_at desc)
      from public.classrooms c
      join public.users u on u.id = c.instructor_id
      left join (
        select classroom_id, count(*) as student_count
        from public.classroom_students
        group by classroom_id
      ) cc on cc.classroom_id = c.id
    ), '[]'::jsonb),
    'activity', coalesce((
      select jsonb_agg(jsonb_build_object(
        'id', event.id,
        'action', event.action,
        'target_label', event.target_label,
        'admin_name', coalesce(admin.full_name, 'Former admin'),
        'created_at', event.created_at
      ) order by event.created_at desc)
      from (
        select * from public.admin_activity_events
        order by created_at desc
        limit 100
      ) event
      left join public.users admin on admin.id = event.admin_id
    ), '[]'::jsonb)
  );
end;
$$;

revoke all on function public.get_admin_management_data(text) from public;
grant execute on function public.get_admin_management_data(text)
  to anon, authenticated;

-- ---------------------------------------------------------------------------
-- 8. list_instructor_notifications() had no LIMIT and is polled by the badge.
--    Cap it at 100 rows, matching list_student_notifications().
-- ---------------------------------------------------------------------------
create or replace function public.list_instructor_notifications(
  p_session_token text
) returns jsonb
language plpgsql
stable
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
    and u.role = 'instructor'
  limit 1;

  if verified_user_id is null then
    if exists (
      select 1
      from public.user_sessions s
      join public.users u on u.id = s.user_id
      where s.session_token = p_session_token and s.expires_at > now()
    ) then
      raise exception 'Only instructor accounts can view notifications';
    end if;
    raise exception 'Invalid or expired session';
  end if;

  return coalesce((
    with notifications as (
      select
        'student-joined:' || membership.classroom_id::text || ':' ||
          membership.student_id::text || ':' ||
          extract(epoch from membership.joined_at)::text as notification_id,
        'studentJoined'::text as notification_type,
        'A student joined your classroom'::text as title,
        format(
          '%s joined %s.',
          student.full_name,
          classroom.name
        ) as message,
        membership.joined_at as created_at,
        classroom.id as classroom_id
      from public.classroom_students membership
      join public.classrooms classroom
        on classroom.id = membership.classroom_id
      join public.users student on student.id = membership.student_id
      where classroom.instructor_id = verified_user_id
        and membership.joined_at >= now() - interval '90 days'
      order by membership.joined_at desc
      limit 100
    )
    select jsonb_agg(
      jsonb_build_object(
        'id', notification.notification_id,
        'type', notification.notification_type,
        'title', notification.title,
        'message', notification.message,
        'created_at', notification.created_at,
        'is_read', reads.notification_id is not null,
        'classroom_id', notification.classroom_id
      )
      order by notification.created_at desc, notification.notification_id
    )
    from notifications notification
    left join public.instructor_notification_reads reads
      on reads.user_id = verified_user_id
     and reads.notification_id = notification.notification_id
  ), '[]'::jsonb);
end;
$$;

revoke all on function public.list_instructor_notifications(text) from public;
grant execute on function public.list_instructor_notifications(text)
  to anon, authenticated;

-- ---------------------------------------------------------------------------
-- 9. LEDGER-ROW BADGE REFRESH IS REDUNDANT.
--    Every learner_point_transactions row is created by the quiz-attempt or
--    login-day trigger, both of which already refresh badges. Firing the
--    refresh per ledger row recomputed ~20 aggregates 2-3 times per save.
-- ---------------------------------------------------------------------------
drop trigger if exists learner_point_transactions_award_student_achievements
  on public.learner_point_transactions;

-- Refresh planner statistics so the new indexes are considered immediately.
analyze public.users;
analyze public.quiz_attempts;
analyze public.learner_point_transactions;
analyze public.classroom_students;
analyze public.classrooms;

notify pgrst, 'reload schema';
