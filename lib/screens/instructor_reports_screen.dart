import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../models/instructor_report.dart';
import '../services/instructor_reports_service.dart';
import '../widgets/app_glass_surface.dart';
import '../widgets/learning_metric_chart.dart';

class InstructorReportsScreen extends StatefulWidget {
  const InstructorReportsScreen({required this.reportsRepository, super.key});

  final InstructorReportsRepository reportsRepository;

  @override
  State<InstructorReportsScreen> createState() =>
      _InstructorReportsScreenState();
}

class _InstructorReportsScreenState extends State<InstructorReportsScreen> {
  static const _accent = Color(0xFFF4773C);
  static const _ink = Color(0xFF3B2419);
  static const _muted = Color(0xFF765C4F);

  late Future<List<InstructorReportClassroom>> _reports;

  @override
  void initState() {
    super.initState();
    _reports = widget.reportsRepository.loadReports();
  }

  void _reload() {
    setState(() => _reports = widget.reportsRepository.loadReports());
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

  bool _isAccountOlderThanAWeek(DateTime? createdAt) =>
      createdAt != null &&
      createdAt.isBefore(DateTime.now().subtract(const Duration(days: 7)));

  @override
  Widget build(
    BuildContext context,
  ) => FutureBuilder<List<InstructorReportClassroom>>(
    future: _reports,
    builder: (context, snapshot) {
      final reports = snapshot.data;
      final insights =
          <
            ({
              InstructorReportClassroom classroom,
              InstructorReportStudent student,
              List<(String, double)> metrics,
            })
          >[];
      for (final classroom in reports ?? const <InstructorReportClassroom>[]) {
        for (final student in classroom.students) {
          final metrics = _lowMetrics(student);
          if (_isAccountOlderThanAWeek(student.createdAt) &&
              metrics.isNotEmpty) {
            insights.add((
              classroom: classroom,
              student: student,
              metrics: metrics,
            ));
          }
        }
      }

      return LayoutBuilder(
        builder: (context, constraints) {
          final horizontalPadding = constraints.maxWidth < 600 ? 16.0 : 32.0;
          final contentWidth = math.min(
            constraints.maxWidth - horizontalPadding * 2,
            1160.0,
          );

          return SingleChildScrollView(
            padding: EdgeInsets.symmetric(
              horizontal: horizontalPadding,
              vertical: 28,
            ),
            child: Center(
              child: SizedBox(
                width: contentWidth,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: const [
                              Text(
                                'CLASSROOM REPORTS',
                                style: TextStyle(
                                  color: _accent,
                                  fontSize: 11,
                                  fontWeight: FontWeight.w700,
                                  letterSpacing: 1.4,
                                ),
                              ),
                              SizedBox(height: 8),
                              Text(
                                'Student performance',
                                style: TextStyle(
                                  color: _ink,
                                  fontSize: 27,
                                  fontWeight: FontWeight.w700,
                                ),
                              ),
                              SizedBox(height: 6),
                              Text(
                                'Review student metrics that need attention across your classrooms.',
                                style: TextStyle(color: _muted, height: 1.45),
                              ),
                            ],
                          ),
                        ),
                        IconButton(
                          tooltip: 'Refresh reports',
                          onPressed: _reload,
                          icon: const Icon(Icons.refresh),
                        ),
                      ],
                    ),
                    const SizedBox(height: 22),
                    if (snapshot.connectionState == ConnectionState.waiting)
                      const _ReportsLoading()
                    else if (snapshot.hasError)
                      _ReportsError(
                        message: snapshot.error.toString(),
                        onRetry: _reload,
                      )
                    else if (reports == null || reports.isEmpty)
                      const _ReportsEmpty()
                    else ...[
                      _StudentInsights(
                        insights: insights,
                        onStudentSelected: (student, metrics) =>
                            _showMetricInsights(context, student, metrics),
                      ),
                    ],
                  ],
                ),
              ),
            ),
          );
        },
      );
    },
  );

  Future<void> _showMetricInsights(
    BuildContext context,
    InstructorReportStudent student,
    List<(String, double)> metrics,
  ) => showDialog<void>(
    context: context,
    builder: (context) =>
        _StudentMetricInsightsDialog(student: student, metrics: metrics),
  );
}

class _StudentInsights extends StatelessWidget {
  const _StudentInsights({
    required this.insights,
    required this.onStudentSelected,
  });

  final List<
    ({
      InstructorReportClassroom classroom,
      InstructorReportStudent student,
      List<(String, double)> metrics,
    })
  >
  insights;
  final void Function(
    InstructorReportStudent student,
    List<(String, double)> metrics,
  )
  onStudentSelected;

  @override
  Widget build(BuildContext context) => AppGlassSurface(
    borderRadius: 18,
    child: Padding(
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Students with low stats',
            style: TextStyle(
              color: Color(0xFF3B2419),
              fontSize: 17,
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 4),
          const Text(
            'Insights show percentage metrics below 20% and improvement at or below 0 points for accounts older than 7 days.',
            style: TextStyle(color: Color(0xFF765C4F), fontSize: 12),
          ),
          const SizedBox(height: 12),
          if (insights.isEmpty)
            const Text(
              'No eligible students currently have percentage metrics below 20% or improvement at or below 0 points.',
              style: TextStyle(color: Color(0xFF765C4F), fontSize: 13),
            )
          else
            for (var index = 0; index < insights.length; index++) ...[
              if (index > 0)
                const Divider(height: 16, color: Color(0xFFF0E5D8)),
              _StudentInsightTile(
                key: ValueKey(
                  'student-insight-${insights[index].classroom.id}-'
                  '${insights[index].student.id}',
                ),
                insight: insights[index],
                onTap: () => onStudentSelected(
                  insights[index].student,
                  insights[index].metrics,
                ),
              ),
            ],
        ],
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

  final ({
    InstructorReportClassroom classroom,
    InstructorReportStudent student,
    List<(String, double)> metrics,
  })
  insight;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) => Material(
    color: Colors.transparent,
    child: InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(12),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 5),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(
                    insight.student.fullName,
                    style: const TextStyle(
                      color: Color(0xFF3B2419),
                      fontSize: 13,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
                Flexible(
                  child: Text(
                    insight.classroom.name,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    textAlign: TextAlign.right,
                    style: const TextStyle(
                      color: Color(0xFF765C4F),
                      fontSize: 11,
                    ),
                  ),
                ),
                const Icon(
                  Icons.chevron_right,
                  color: Color(0xFF9A725A),
                  size: 19,
                ),
              ],
            ),
            const SizedBox(height: 7),
            Wrap(
              spacing: 7,
              runSpacing: 6,
              children: [
                for (final (label, value) in insight.metrics)
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 9,
                      vertical: 5,
                    ),
                    decoration: BoxDecoration(
                      color: const Color(0xFFFFEEE8),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Text(
                      label == 'Improvement'
                          ? '$label ${value > 0 ? '+' : ''}${value.toStringAsFixed(0)} pts'
                          : '$label ${value.toStringAsFixed(0)}%',
                      style: const TextStyle(
                        color: Color(0xFF9B3D26),
                        fontSize: 11,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
              ],
            ),
          ],
        ),
      ),
    ),
  );
}

class _StudentMetricInsightsDialog extends StatelessWidget {
  const _StudentMetricInsightsDialog({
    required this.student,
    required this.metrics,
  });

  final InstructorReportStudent student;
  final List<(String, double)> metrics;

  @override
  Widget build(BuildContext context) => AlertDialog(
    scrollable: true,
    backgroundColor: const Color(0xFFFFFCF8),
    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
    title: Text(
      'Low stats for ${student.fullName}',
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
            'Charts for each metric flagged as low.',
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

class _ReportsLoading extends StatelessWidget {
  const _ReportsLoading();

  @override
  Widget build(BuildContext context) => const Padding(
    padding: EdgeInsets.symmetric(vertical: 100),
    child: Center(child: CircularProgressIndicator(color: Color(0xFFF4773C))),
  );
}

class _ReportsError extends StatelessWidget {
  const _ReportsError({required this.message, required this.onRetry});

  final String message;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) => Center(
    child: Padding(
      padding: const EdgeInsets.symmetric(vertical: 70, horizontal: 24),
      child: Column(
        children: [
          const Icon(
            Icons.cloud_off_outlined,
            color: Color(0xFF9A725A),
            size: 38,
          ),
          const SizedBox(height: 12),
          const Text(
            'Reports could not be loaded',
            style: TextStyle(
              color: Color(0xFF3B2419),
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            message,
            textAlign: TextAlign.center,
            style: const TextStyle(color: Color(0xFF765C4F), fontSize: 12),
          ),
          const SizedBox(height: 12),
          OutlinedButton.icon(
            onPressed: onRetry,
            icon: const Icon(Icons.refresh),
            label: const Text('Try again'),
          ),
        ],
      ),
    ),
  );
}

class _ReportsEmpty extends StatelessWidget {
  const _ReportsEmpty();

  @override
  Widget build(BuildContext context) => Container(
    width: double.infinity,
    padding: const EdgeInsets.symmetric(vertical: 56, horizontal: 24),
    decoration: BoxDecoration(
      color: const Color(0xFFFFFCF8),
      border: Border.all(color: const Color(0xFFE8D7C2)),
      borderRadius: BorderRadius.circular(18),
    ),
    child: const Column(
      children: [
        Icon(Icons.bar_chart_outlined, color: Color(0xFFF4773C), size: 42),
        SizedBox(height: 12),
        Text(
          'No classroom reports yet',
          style: TextStyle(
            color: Color(0xFF3B2419),
            fontSize: 16,
            fontWeight: FontWeight.w700,
          ),
        ),
        SizedBox(height: 6),
        Text(
          'Create a classroom to start tracking student progress.',
          textAlign: TextAlign.center,
          style: TextStyle(color: Color(0xFF765C4F), fontSize: 12),
        ),
      ],
    ),
  );
}
