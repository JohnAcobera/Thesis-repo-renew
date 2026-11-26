import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../models/instructor_report.dart';
import '../services/instructor_reports_service.dart';
import '../services/instructor_student_feedback_service.dart';
import '../widgets/app_glass_surface.dart';
import '../widgets/instructor_student_feedback_form.dart';
import '../widgets/instructor_student_insights.dart';
import '../widgets/learning_metric_chart.dart';

class InstructorReportsScreen extends StatefulWidget {
  const InstructorReportsScreen({
    required this.reportsRepository,
    this.feedbackRepository,
    this.header,
    super.key,
  });

  final InstructorReportsRepository reportsRepository;
  final InstructorStudentFeedbackRepository? feedbackRepository;
  final Widget? header;

  @override
  State<InstructorReportsScreen> createState() =>
      _InstructorReportsScreenState();
}

class _InstructorReportsScreenState extends State<InstructorReportsScreen> {
  static const _accent = Color(0xFFF4773C);
  static const _ink = Color(0xFF3B2419);
  static const _muted = Color(0xFF765C4F);
  static const _border = Color(0xFFE8D7C2);

  late Future<List<InstructorReportClassroom>> _reports;
  late final InstructorStudentFeedbackRepository _feedbackRepository =
      widget.feedbackRepository ?? InstructorStudentFeedbackService();

  @override
  void initState() {
    super.initState();
    _reports = widget.reportsRepository.loadReports();
  }

  void _reload() {
    setState(() => _reports = widget.reportsRepository.loadReports());
  }

  @override
  Widget build(
    BuildContext context,
  ) => FutureBuilder<List<InstructorReportClassroom>>(
    future: _reports,
    builder: (context, snapshot) {
      final reports = snapshot.data;
      final insights = getInstructorStudentInsights(
        reports ?? const <InstructorReportClassroom>[],
      );

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
                    if (widget.header != null) ...[
                      widget.header!,
                      const SizedBox(height: 24),
                    ],
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
                                  fontSize: 10,
                                  fontWeight: FontWeight.w700,
                                  letterSpacing: 1.5,
                                ),
                              ),
                              SizedBox(height: 7),
                              Text(
                                'Student performance',
                                style: TextStyle(
                                  color: _ink,
                                  fontSize: 28,
                                  fontWeight: FontWeight.w700,
                                  letterSpacing: -0.5,
                                ),
                              ),
                              SizedBox(height: 7),
                              Text(
                                'A clear view of learning progress across your classrooms.',
                                style: TextStyle(
                                  color: _muted,
                                  height: 1.5,
                                  fontSize: 13,
                                ),
                              ),
                            ],
                          ),
                        ),
                        Container(
                          decoration: BoxDecoration(
                            color: const Color(0xFFFFFCF8),
                            border: Border.all(color: _border),
                            borderRadius: BorderRadius.circular(14),
                          ),
                          child: IconButton(
                            tooltip: 'Refresh reports',
                            onPressed: _reload,
                            color: _muted,
                            icon: const Icon(Icons.refresh_rounded),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 24),
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
                        feedbackRepository: _feedbackRepository,
                        onStudentSelected: (classroom, student, metrics) =>
                            _showMetricInsights(
                              context,
                              classroom,
                              student,
                              metrics,
                            ),
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
    InstructorReportClassroom classroom,
    InstructorReportStudent student,
    List<(String, double)> metrics,
  ) async {
    final sent = await showDialog<bool>(
      context: context,
      builder: (context) => _StudentMetricInsightsDialog(
        classroom: classroom,
        student: student,
        metrics: metrics,
        feedbackRepository: _feedbackRepository,
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
  }
}

class _StudentInsights extends StatelessWidget {
  const _StudentInsights({
    required this.insights,
    required this.feedbackRepository,
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
  final InstructorStudentFeedbackRepository feedbackRepository;
  final void Function(
    InstructorReportClassroom classroom,
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
          Row(
            children: [
              Container(
                width: 42,
                height: 42,
                decoration: BoxDecoration(
                  color: const Color(0xFFFFEEE4),
                  borderRadius: BorderRadius.circular(13),
                ),
                child: const Icon(
                  Icons.insights_rounded,
                  color: Color(0xFFE86C35),
                  size: 21,
                ),
              ),
              const SizedBox(width: 12),
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
                      'Review progress and draft encouragement.',
                      style: TextStyle(color: Color(0xFF765C4F), fontSize: 11),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 10,
                  vertical: 7,
                ),
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
          const SizedBox(height: 16),
          Container(
            width: double.infinity,
            padding: const EdgeInsets.symmetric(horizontal: 11, vertical: 9),
            decoration: BoxDecoration(
              color: const Color(0xFFFFF8EE),
              borderRadius: BorderRadius.circular(11),
              border: Border.all(color: const Color(0xFFF0E5D8)),
            ),
            child: const Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Icon(
                  Icons.info_outline_rounded,
                  color: Color(0xFF9A725A),
                  size: 15,
                ),
                SizedBox(width: 8),
                Expanded(
                  child: Text(
                    'For accounts 7+ days old: metrics below 20% or improvement at/below 0.',
                    style: TextStyle(
                      color: Color(0xFF765C4F),
                      fontSize: 11,
                      height: 1.35,
                    ),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 12),
          if (insights.isEmpty)
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: const Color(0xFFF7FAF6),
                borderRadius: BorderRadius.circular(13),
                border: Border.all(color: const Color(0xFFDCE9DC)),
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
                      style: TextStyle(color: Color(0xFF56715A), fontSize: 12),
                    ),
                  ),
                ],
              ),
            )
          else
            for (var index = 0; index < insights.length; index++) ...[
              if (index > 0) const SizedBox(height: 9),
              _StudentInsightTile(
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
      child: Ink(
        decoration: BoxDecoration(
          color: Colors.white.withValues(alpha: 0.62),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: const Color(0xFFEDE5DB)),
        ),
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
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
                        Text(
                          insight.student.fullName,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                            color: Color(0xFF3B2419),
                            fontSize: 13,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                        const SizedBox(height: 3),
                        Text(
                          insight.classroom.name,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                            color: Color(0xFF765C4F),
                            fontSize: 11,
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 6),
                  const Icon(
                    Icons.arrow_forward_rounded,
                    color: Color(0xFF9A725A),
                    size: 17,
                  ),
                ],
              ),
              const SizedBox(height: 10),
              Wrap(
                spacing: 7,
                runSpacing: 7,
                children: [
                  for (final (label, value) in insight.metrics)
                    _MetricBadge(label: label, value: value),
                ],
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
    padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 6),
    decoration: BoxDecoration(
      color: const Color(0xFFFFF4EE),
      borderRadius: BorderRadius.circular(9),
      border: Border.all(color: const Color(0xFFF0D8CB)),
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

class _StudentMetricInsightsDialog extends StatefulWidget {
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
  State<_StudentMetricInsightsDialog> createState() =>
      _StudentMetricInsightsDialogState();
}

class _StudentMetricInsightsDialogState
    extends State<_StudentMetricInsightsDialog> {
  final _feedbackFormKey = GlobalKey<InstructorStudentFeedbackFormState>();
  bool _canSend = true;
  bool _isSending = false;

  void _updateFeedbackState(bool canSend, bool isSending) {
    setState(() {
      _canSend = canSend;
      _isSending = isSending;
    });
  }

  @override
  Widget build(BuildContext context) => AlertDialog(
    scrollable: true,
    backgroundColor: const Color(0xFFFFFCF8),
    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
    title: Text(
      'Learning progress for ${widget.student.fullName}',
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
          for (var index = 0; index < widget.metrics.length; index++) ...[
            if (index > 0) const SizedBox(height: 12),
            _StudentMetricChart(
              student: widget.student,
              metric: widget.metrics[index].$1,
              value: widget.metrics[index].$2,
            ),
          ],
          InstructorStudentFeedbackForm(
            key: _feedbackFormKey,
            classroom: widget.classroom,
            student: widget.student,
            metrics: widget.metrics,
            repository: widget.feedbackRepository,
            showSendButton: false,
            onStateChanged: _updateFeedbackState,
          ),
        ],
      ),
    ),
    actions: [
      TextButton(
        onPressed: _isSending ? null : () => Navigator.of(context).pop(),
        child: const Text('Close'),
      ),
      FilledButton.icon(
        onPressed: _canSend && !_isSending
            ? () => _feedbackFormKey.currentState?.sendFeedback()
            : null,
        icon: _isSending
            ? const SizedBox.square(
                dimension: 16,
                child: CircularProgressIndicator(strokeWidth: 2),
              )
            : const Icon(Icons.send_rounded, size: 17),
        label: const Text('Send encouragement'),
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
