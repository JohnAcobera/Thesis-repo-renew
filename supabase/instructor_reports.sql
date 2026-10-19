-- Run after custom_auth.sql, classrooms.sql, quiz_attempts.sql, and
-- classroom_activities.sql.
create or replace function public.get_instructor_reports(
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
      raise exception 'Only instructors can view reports';
    end if;
    raise exception 'Invalid or expired session';
  end if;

  return coalesce((
    select jsonb_agg(
      jsonb_build_object(
        'id', classroom.id,
        'name', classroom.name,
        'subject', classroom.subject,
        'student_count', (
          select count(*)::integer
          from public.classroom_students membership
          where membership.classroom_id = classroom.id
        ),
        'activity_count', activity_totals.activity_count,
        'average_score', classroom_performance.average_score,
        'students', coalesce((
          select jsonb_agg(
            jsonb_build_object(
              'id', student.id,
              'full_name', student.full_name,
              'email', student.email,
              'role', student.role,
              'joined_at', membership.joined_at,
              'created_at', student.created_at,
              'completed_activity_count',
                student_performance.completed_activity_count,
              'total_activity_count', activity_totals.started_activity_count,
              'attempt_count', student_performance.attempt_count,
              'average_score', student_performance.average_score,
              'generated_quiz_count', (
                select count(*)::integer
                from public.student_generated_quizzes quiz
                where quiz.user_id = student.id
              ),
              'personal_attempt_count', personal_performance.attempt_count,
              'personal_average_score', personal_performance.average_score,
              'accuracy_percentage', radar_metrics.accuracy_percentage,
              'retention_percentage', radar_metrics.retention_percentage,
              'improvement_percentage', radar_metrics.improvement_percentage,
              'consistency_percentage', radar_metrics.consistency_percentage,
              'focus_percentage', radar_metrics.focus_percentage
            )
            order by student.full_name, student.id
          )
          from public.classroom_students membership
          join public.users student on student.id = membership.student_id
          cross join lateral (
            select
              count(distinct attempt.classroom_activity_id)::integer
                as completed_activity_count,
              count(attempt.id)::integer as attempt_count,
              avg(
                100.0 * attempt.score / nullif(attempt.total_questions, 0)
              ) as average_score
            from public.quiz_attempts attempt
            join public.classroom_activities activity
              on activity.id = attempt.classroom_activity_id
            where activity.classroom_id = classroom.id
              and activity.starts_at <= now()
              and attempt.user_id = student.id
          ) student_performance
          cross join lateral (
            select
              count(attempt.id)::integer as attempt_count,
              avg(
                100.0 * attempt.score / nullif(attempt.total_questions, 0)
              ) as average_score
            from public.quiz_attempts attempt
            where attempt.user_id = student.id
          ) personal_performance
          cross join lateral (
            with ranked_attempts as (
              select
                attempt.quiz_id,
                attempt.score,
                attempt.total_questions,
                attempt.created_at,
                row_number() over (
                  partition by attempt.quiz_id
                  order by attempt.created_at desc, attempt.id desc
                ) as latest_rank,
                row_number() over (
                  partition by attempt.quiz_id
                  order by attempt.created_at, attempt.id
                ) as first_rank,
                100.0 * attempt.score
                  / nullif(attempt.total_questions, 0) as percentage,
                lag(
                  100.0 * attempt.score
                    / nullif(attempt.total_questions, 0)
                ) over (
                  partition by attempt.quiz_id
                  order by attempt.created_at, attempt.id
                ) as previous_percentage
              from public.student_generated_quizzes quiz
              join public.quiz_attempts attempt
                on attempt.quiz_id = quiz.id
              where quiz.user_id = student.id
            ),
            retention_by_quiz as (
              select quiz_id, avg(percentage) as percentage
              from ranked_attempts
              where latest_rank <= 2
              group by quiz_id
              having count(*) >= 2
            ),
            improvement_by_quiz as (
              select quiz_id, avg(percentage - previous_percentage) as percentage
              from ranked_attempts
              where previous_percentage is not null
              group by quiz_id
            )
            select
              100.0 * sum(score) filter (where latest_rank = 1)
                / nullif(
                  sum(total_questions) filter (where latest_rank = 1),
                  0
                ) as accuracy_percentage,
              (select avg(percentage) from retention_by_quiz)
                as retention_percentage,
              (select avg(percentage) from improvement_by_quiz)
                as improvement_percentage,
              case
                when student.created_at::date > current_date then null
                else 100.0 * count(distinct created_at::date)
                  filter (
                    where created_at::date between
                      greatest(student.created_at::date, current_date - 27)
                      and current_date
                  )
                  / (
                    current_date
                    - greatest(student.created_at::date, current_date - 27)
                    + 1
                  )
              end as consistency_percentage,
              100.0 * sum(score) filter (where first_rank = 1)
                / nullif(
                  sum(total_questions) filter (where first_rank = 1),
                  0
                ) as focus_percentage
            from ranked_attempts
          ) radar_metrics
          where membership.classroom_id = classroom.id
            and student.role = 'student'
        ), '[]'::jsonb)
      )
      order by classroom.name, classroom.id
    )
    from public.classrooms classroom
    cross join lateral (
      select
        count(*)::integer as activity_count,
        count(*) filter (where activity.starts_at <= now())::integer
          as started_activity_count
      from public.classroom_activities activity
      where activity.classroom_id = classroom.id
    ) activity_totals
    cross join lateral (
      select
        avg(100.0 * attempt.score / nullif(attempt.total_questions, 0))
          as average_score
      from public.quiz_attempts attempt
      join public.classroom_activities activity
        on activity.id = attempt.classroom_activity_id
      where activity.classroom_id = classroom.id
    ) classroom_performance
    where classroom.instructor_id = verified_user_id
  ), '[]'::jsonb);
end;
$$;

revoke all on function public.get_instructor_reports(text) from public;
grant execute on function public.get_instructor_reports(text)
  to anon, authenticated;
