-- Run after custom_auth.sql, classrooms.sql, and quiz_attempts.sql.
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
        'activity_count', 0,
        'average_score', null,
        'students', coalesce((
          select jsonb_agg(
            jsonb_build_object(
              'id', student.id,
              'full_name', student.full_name,
              'email', student.email,
              'role', student.role,
              'joined_at', membership.joined_at,
              'created_at', student.created_at,
              'completed_activity_count', 0,
              'total_activity_count', 0,
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
              'focus_percentage', radar_metrics.focus_percentage,
              'metric_samples', jsonb_build_object(
                'accuracy', radar_metrics.accuracy_samples,
                'retention', radar_metrics.retention_samples,
                'improvement', radar_metrics.improvement_samples,
                'consistency', radar_metrics.consistency_samples,
                'focus', radar_metrics.focus_samples
              )
            )
            order by student.full_name, student.id
          )
          from public.classroom_students membership
          join public.users student on student.id = membership.student_id
          cross join lateral (
            select
              0::integer as completed_activity_count,
              0::integer as attempt_count,
              null::numeric as average_score
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
              select
                quiz_id,
                avg(percentage) as percentage,
                max(created_at) as latest_created_at
              from ranked_attempts
              where latest_rank <= 2
              group by quiz_id
              having count(*) >= 2
            ),
            improvement_by_quiz as (
              select
                quiz_id,
                avg(percentage - previous_percentage) as percentage,
                max(created_at) as latest_created_at
              from ranked_attempts
              where previous_percentage is not null
              group by quiz_id
            ),
            focus_by_quiz as (
              select quiz_id, percentage, created_at
              from ranked_attempts
              where first_rank = 1
            ),
            consistency_by_day as (
              select
                calendar.activity_date,
                case when count(attempt.created_at) > 0 then 1.0 else 0.0 end
                  as active
              from generate_series(
                greatest(student.created_at::date, current_date - 27),
                current_date,
                interval '1 day'
              ) as calendar(activity_date)
              left join ranked_attempts attempt
                on attempt.created_at::date = calendar.activity_date::date
              where student.created_at::date <= current_date
              group by calendar.activity_date
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
                ) as focus_percentage,
              (
                select coalesce(
                  jsonb_agg(sample.percentage order by sample.created_at),
                  '[]'::jsonb
                )
                from (
                  select percentage, created_at
                  from ranked_attempts
                  where created_at::date between
                    greatest(student.created_at::date, current_date - 27)
                    and current_date
                  order by created_at desc, quiz_id
                  limit 12
                ) sample
              ) as accuracy_samples,
              (
                select coalesce(
                  jsonb_agg(sample.percentage order by sample.latest_created_at),
                  '[]'::jsonb
                )
                from (
                  select percentage, latest_created_at
                  from retention_by_quiz
                  order by latest_created_at desc, quiz_id
                  limit 12
                ) sample
              ) as retention_samples,
              (
                select coalesce(
                  jsonb_agg(sample.percentage order by sample.latest_created_at),
                  '[]'::jsonb
                )
                from (
                  select percentage, latest_created_at
                  from improvement_by_quiz
                  order by latest_created_at desc, quiz_id
                  limit 12
                ) sample
              ) as improvement_samples,
              (
                select coalesce(
                  jsonb_agg(active order by activity_date),
                  '[]'::jsonb
                )
                from (
                  select activity_date, active
                  from consistency_by_day
                  order by activity_date desc
                  limit 28
                ) sample
              ) as consistency_samples,
              (
                select coalesce(
                  jsonb_agg(sample.percentage order by sample.created_at),
                  '[]'::jsonb
                )
                from (
                  select percentage, created_at
                  from focus_by_quiz
                  order by created_at desc, quiz_id
                  limit 12
                ) sample
              ) as focus_samples
            from ranked_attempts
          ) radar_metrics
          where membership.classroom_id = classroom.id
            and student.role = 'student'
        ), '[]'::jsonb)
      )
      order by classroom.name, classroom.id
    )
    from public.classrooms classroom
    where classroom.instructor_id = verified_user_id
  ), '[]'::jsonb);
end;
$$;

revoke all on function public.get_instructor_reports(text) from public;
grant execute on function public.get_instructor_reports(text)
  to anon, authenticated;

notify pgrst, 'reload schema';
