import 'package:material_ui/material_ui.dart';

import '../models/instructor_report.dart';
import '../services/instructor_student_feedback_service.dart';
import 'app_glass_surface.dart';
import 'learning_metric_chart.dart';
import 'instructor_student_feedback_form.dart';

typedef InstructorStudentInsight = ({
  InstructorReportClassroom classroom,
  InstructorReportStudent student,
  List<(String, double)> metrics,
});

List<InstructorStudentInsight> getInstructorStudentInsights(
  List<InstructorReportClassroom> reports,
) {
  final insights = <InstructorStudentInsight>[];
  for (final classroom in reports) {
    for (final student in classroom.students) {
      final metrics = _lowMetrics(student);
      final createdAt = student.createdAt;
      if (createdAt != null &&
          createdAt.isBefore(
            DateTime.now().subtract(const Duration(days: 7)),
          ) &&
          metrics.isNotEmpty) {
        insights.add((
          classroom: classroom,
          student: student,
          metrics: metrics,
        ));
      }
    }
  }
  return insights;
}

List<(String, double)> _lowMetrics(InstructorReportStudent student) {
  final metrics = <(String, double)>[
    if (student.averageScore != null)
      ('Classroom average', student.averageScore!),
    if (student.personalAverageScore != null)
      ('Overall average', student.personalAverageScore!),
    if (student.totalActivityCount > 0)
      (
        'Classroom completion',
        100 * student.completedActivityCount / student.totalActivityCount,
      ),
    if (student.accuracyPercentage != null)
      ('Accuracy', student.accuracyPercentage!),
    if (student.retentionPercentage != null)
      ('Retention', student.retentionPercentage!),
    if (student.improvementPercentage != null)
      ('Improvement', student.improvementPercentage!),
    if (student.consistencyPercentage != null)
      ('Consistency', student.consistencyPercentage!),
    if (student.focusPercentage != null) ('Focus', student.focusPercentage!),
  ];
  return metrics
      .where(
        (metric) =>
            metric.$1 == 'Improvement' ? metric.$2 <= 0 : metric.$2 < 20,
      )
      .toList(growable: false);
}

class InstructorStudentInsights extends StatelessWidget {
  const InstructorStudentInsights({
    required this.reports,
    this.feedbackRepository,
    this.panelHeight,
    super.key,
  });

  final List<InstructorReportClassroom> reports;
  final InstructorStudentFeedbackRepository? feedbackRepository;
  final double? panelHeight;

  @override
  Widget build(BuildContext context) {
    final repository = feedbackRepository ?? InstructorStudentFeedbackService();
    return _StudentInsightsCard(
      insights: getInstructorStudentInsights(reports),
      panelHeight: panelHeight,
      onStudentSelected: (classroom, student, metrics) async {
        final sent = await showDialog<bool>(
          context: context,
          builder: (context) => _StudentMetricInsightsDialog(
            classroom: classroom,
            student: student,
            metrics: metrics,
            feedbackRepository: repository,
          ),
        );
        if (sent == true && context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Encouragement sent to the student.'),
              behavior: SnackBarBehavior.floating,
            ),
          );
        }
      },
    );
  }
}

class _StudentInsightsCard extends StatelessWidget {
  const _StudentInsightsCard({
    required this.insights,
    required this.panelHeight,
    required this.onStudentSelected,
  });

  final List<InstructorStudentInsight> insights;
  final double? panelHeight;
  final void Function(
    InstructorReportClassroom classroom,
    InstructorReportStudent student,
    List<(String, double)> metrics,
  )
  onStudentSelected;

  @override
  Widget build(BuildContext context) => AppGlassSurface(
    key: const ValueKey('instructor-low-stats-panel'),
    borderRadius: 18,
    padding: const EdgeInsets.all(18),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Container(
              width: 40,
              height: 40,
              decoration: BoxDecoration(
                color: const Color(0xFFFFEEE4),
                borderRadius: BorderRadius.circular(12),
              ),
              child: const Icon(
                Icons.insights_rounded,
                color: Color(0xFFE86C35),
                size: 21,
              ),
            ),
            const SizedBox(width: 11),
            const Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Students with low stats',
                    style: TextStyle(
                      color: Color(0xFF3B2419),
                      fontSize: 16,
                      fontWeight: FontWeight.w700,
                      letterSpacing: -0.2,
                    ),
                  ),
                  SizedBox(height: 3),
                  Text(
                    'Learning progress to review',
                    style: TextStyle(color: Color(0xFF765C4F), fontSize: 11),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 8),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 6),
              decoration: BoxDecoration(
                color: insights.isEmpty
                    ? const Color(0xFFF1F1ED)
                    : const Color(0xFFFFEEE8),
                borderRadius: BorderRadius.circular(20),
              ),
              child: Text(
                '${insights.length} flagged',
                style: TextStyle(
                  color: insights.isEmpty
                      ? const Color(0xFF765C4F)
                      : const Color(0xFF9B3D26),
                  fontSize: 10,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 14),
        const Text(
          'Accounts 7+ days old; metrics below 20% or improvement at/below 0.',
          style: TextStyle(color: Color(0xFF765C4F), fontSize: 11, height: 1.4),
        ),
        const SizedBox(height: 12),
        if (insights.isEmpty)
          Container(
            width: double.infinity,
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 18),
            decoration: BoxDecoration(
              color: const Color(0xFFF8F7F3).withValues(alpha: 0.72),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: const Color(0xFFE8E5DC)),
            ),
            child: const Row(
              children: [
                Icon(
                  Icons.check_circle_outline_rounded,
                  color: Color(0xFF5C8A65),
                  size: 19,
                ),
                SizedBox(width: 9),
                Expanded(
                  child: Text(
                    'No students currently meet the review criteria.',
                    style: TextStyle(color: Color(0xFF765C4F), fontSize: 12),
                  ),
                ),
              ],
            ),
          )
        else if (panelHeight == null)
          ConstrainedBox(
            constraints: const BoxConstraints(maxHeight: 360),
            child: _buildStudentList(shrinkWrap: true),
          )
        else
          Expanded(child: _buildStudentList(shrinkWrap: false)),
      ],
    ),
  );

  Widget _buildStudentList({required bool shrinkWrap}) => ListView.separated(
    key: const ValueKey('instructor-low-stats-list'),
    primary: false,
    shrinkWrap: shrinkWrap,
    physics: const ClampingScrollPhysics(),
    itemCount: insights.length,
    separatorBuilder: (_, _) => const SizedBox(height: 8),
    itemBuilder: (context, index) => _StudentInsightTile(
      key: ValueKey(
        'student-insight-${insights[index].classroom.id}-'
        '${insights[index].student.id}',
      ),
      insight: insights[index],
      onTap: () => onStudentSelected(
        insights[index].classroom,
        insights[index].student,
        insights[index].metrics,
      ),
    ),
  );
}

class _StudentInsightTile extends StatelessWidget {
  const _StudentInsightTile({
    required this.insight,
    required this.onTap,
    super.key,
  });

  final InstructorStudentInsight insight;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) => Material(
    color: Colors.transparent,
    child: InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(12),
      child: Ink(
        decoration: BoxDecoration(
          color: Colors.white.withValues(alpha: 0.38),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: const Color(0xFFEDE5DB)),
        ),
        child: Padding(
          padding: const EdgeInsets.all(11),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              CircleAvatar(
                radius: 17,
                backgroundColor: const Color(0xFFFFE9DA),
                child: Text(
                  insight.student.fullName.trim().isEmpty
                      ? '?'
                      : insight.student.fullName.trim()[0].toUpperCase(),
                  style: const TextStyle(
                    color: Color(0xFFB8522D),
                    fontSize: 12,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: Text(
                            insight.student.fullName,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(
                              color: Color(0xFF3B2419),
                              fontSize: 13,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                        ),
                        const SizedBox(width: 4),
                        const Icon(
                          Icons.chevron_right_rounded,
                          color: Color(0xFF9A725A),
                          size: 18,
                        ),
                      ],
                    ),
                    const SizedBox(height: 3),
                    Row(
                      children: [
                        const Icon(
                          Icons.menu_book_outlined,
                          color: Color(0xFF9A725A),
                          size: 13,
                        ),
                        const SizedBox(width: 4),
                        Expanded(
                          child: Text(
                            insight.classroom.name,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(
                              color: Color(0xFF765C4F),
                              fontSize: 11,
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    Wrap(
                      spacing: 6,
                      runSpacing: 6,
                      children: [
                        for (final (label, value) in insight.metrics)
                          _MetricBadge(label: label, value: value),
                      ],
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    ),
  );
}

class _MetricBadge extends StatelessWidget {
  const _MetricBadge({required this.label, required this.value});

  final String label;
  final double value;

  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 5),
    decoration: BoxDecoration(
      color: const Color(0xFFFFF1EA),
      borderRadius: BorderRadius.circular(8),
      border: Border.all(color: const Color(0xFFF4D8CA)),
    ),
    child: Text(
      label == 'Improvement'
          ? '$label ${value > 0 ? '+' : ''}${value.toStringAsFixed(0)} pts'
          : '$label ${value.toStringAsFixed(0)}%',
      style: const TextStyle(
        color: Color(0xFF93452F),
        fontSize: 10,
        fontWeight: FontWeight.w600,
      ),
    ),
  );
}

class _StudentMetricInsightsDialog extends StatelessWidget {
  const _StudentMetricInsightsDialog({
    required this.classroom,
    required this.student,
    required this.metrics,
    required this.feedbackRepository,
  });

  final InstructorReportClassroom classroom;
  final InstructorReportStudent student;
  final List<(String, double)> metrics;
  final InstructorStudentFeedbackRepository feedbackRepository;

  @override
  Widget build(BuildContext context) => AlertDialog(
    scrollable: true,
    backgroundColor: const Color(0xFFFFFCF8),
    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
    title: Text(
      'Learning progress for ${student.fullName}',
      style: const TextStyle(
        color: Color(0xFF3B2419),
        fontSize: 18,
        fontWeight: FontWeight.w700,
      ),
    ),
    content: SizedBox(
      width: 440,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'These charts highlight areas where a little more practice may help.',
            style: TextStyle(color: Color(0xFF765C4F), fontSize: 12),
          ),
          const SizedBox(height: 16),
          for (var index = 0; index < metrics.length; index++) ...[
            if (index > 0) const SizedBox(height: 12),
            _StudentMetricChart(
              student: student,
              metric: metrics[index].$1,
              value: metrics[index].$2,
            ),
          ],
          InstructorStudentFeedbackForm(
            classroom: classroom,
            student: student,
            metrics: metrics,
            repository: feedbackRepository,
          ),
        ],
      ),
    ),
    actions: [
      TextButton(
        onPressed: () => Navigator.of(context).pop(),
        child: const Text('Close'),
      ),
    ],
  );
}

class _StudentMetricChart extends StatelessWidget {
  const _StudentMetricChart({
    required this.student,
    required this.metric,
    required this.value,
  });

  final InstructorReportStudent student;
  final String metric;
  final double value;

  @override
  Widget build(BuildContext context) {
    final description = switch (metric) {
      'Classroom average' =>
        'Average score across the student’s quiz attempts in this classroom.',
      'Overall average' =>
        'Average score across all quiz attempts saved by the student.',
      'Classroom completion' =>
        'Completed activities divided by started classroom activities, shown as a percentage.',
      'Accuracy' =>
        'Percent correct across quiz attempts in the last 28 days, or since account creation if newer. The line shows recent attempt scores.',
      'Retention' =>
        'Average score across each quiz’s two latest attempts. Quizzes with fewer than two attempts are skipped.',
      'Improvement' =>
        'Shows whether scores tend to rise or fall when you retry quizzes. '
            'For example, 60% to 70% is a 10-point gain. The value is the average '
            'score change between retries; each bar represents a quiz, with bars '
            'above zero indicating improvement and bars below zero indicating a drop.',
      'Consistency' =>
        'Percent of days with a completed quiz in the last 28 days, or since account creation if newer. Green bars mark quiz days.',
      'Focus' =>
        'Percent correct on the first attempt for each quiz. Bars show first-attempt scores.',
      _ => 'This chart shows the student’s current value for this metric.',
    };
    final metricKey = switch (metric) {
      'Accuracy' => 'accuracy',
      'Retention' => 'retention',
      'Improvement' => 'improvement',
      'Consistency' => 'consistency',
      'Focus' => 'focus',
      _ => metric.toLowerCase().replaceAll(' ', '_'),
    };
    final storedSamples = student.metricSamples[metricKey];
    final samples = storedSamples == null || storedSamples.isEmpty
        ? [value]
        : storedSamples;
    final chartKind = switch (metric) {
      'Accuracy' => LearningMetricChartKind.line,
      'Improvement' => LearningMetricChartKind.diverging,
      'Consistency' => LearningMetricChartKind.activity,
      _ => LearningMetricChartKind.bars,
    };
    final chartColor = switch (metric) {
      'Accuracy' => const Color(0xFFF4773C),
      'Retention' => const Color(0xFFF2C230),
      'Improvement' => const Color(0xFF2F8AB9),
      'Consistency' => const Color(0xFF42A765),
      'Focus' => const Color(0xFFD04FA2),
      _ => const Color(0xFFF4773C),
    };

    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: const Color(0xFFFFF8EE),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: const Color(0xFFE8D7C2)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  metric,
                  style: const TextStyle(
                    color: Color(0xFF765C4F),
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
              Text(
                metric == 'Improvement'
                    ? '${value > 0 ? '+' : ''}${value.toStringAsFixed(0)} pts'
                    : '${value.toStringAsFixed(0)}%',
                style: TextStyle(
                  color: chartColor,
                  fontSize: 16,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Semantics(
            label: '$metric chart for ${student.fullName}',
            child: SizedBox(
              height: 42,
              width: double.infinity,
              child: CustomPaint(
                painter: LearningMetricChartPainter(
                  samples: samples,
                  kind: chartKind,
                  color: chartColor,
                ),
              ),
            ),
          ),
          const SizedBox(height: 8),
          Text(
            description,
            style: const TextStyle(
              color: Color(0xFF765C4F),
              fontSize: 11,
              height: 1.35,
            ),
          ),
        ],
      ),
    );
  }
}
