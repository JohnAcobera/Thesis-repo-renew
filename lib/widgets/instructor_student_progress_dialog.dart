import 'package:material_ui/material_ui.dart';

import '../models/instructor_report.dart';
import '../services/instructor_student_feedback_service.dart';
import 'instructor_student_feedback_form.dart';
import 'learning_metric_chart.dart';

class InstructorStudentProgressDialog extends StatefulWidget {
  const InstructorStudentProgressDialog({
    required this.classroom,
    required this.student,
    required this.metrics,
    required this.feedbackRepository,
    super.key,
  });

  final InstructorReportClassroom classroom;
  final InstructorReportStudent student;
  final List<(String, double)> metrics;
  final InstructorStudentFeedbackRepository feedbackRepository;

  @override
  State<InstructorStudentProgressDialog> createState() =>
      _InstructorStudentProgressDialogState();
}

class _InstructorStudentProgressDialogState
    extends State<InstructorStudentProgressDialog> {
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
    insetPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 24),
    contentPadding: const EdgeInsets.fromLTRB(24, 8, 24, 12),
    titlePadding: const EdgeInsets.fromLTRB(24, 22, 24, 8),
    actionsPadding: const EdgeInsets.fromLTRB(20, 4, 20, 16),
    backgroundColor: const Color(0xFFFFFCF8),
    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
    title: _StudentProgressHeader(
      student: widget.student,
      classroom: widget.classroom,
    ),
    content: ConstrainedBox(
      constraints: const BoxConstraints(maxWidth: 480),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Review recent results and send a supportive note.',
            style: TextStyle(
              color: Color(0xFF765C4F),
              fontSize: 12,
              height: 1.4,
            ),
          ),
          const SizedBox(height: 18),
          const _SectionLabel(label: 'METRICS TO REVIEW'),
          const SizedBox(height: 9),
          for (var index = 0; index < widget.metrics.length; index++) ...[
            if (index > 0) const SizedBox(height: 9),
            _StudentMetricCard(
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

class _StudentProgressHeader extends StatelessWidget {
  const _StudentProgressHeader({
    required this.student,
    required this.classroom,
  });

  final InstructorReportStudent student;
  final InstructorReportClassroom classroom;

  @override
  Widget build(BuildContext context) {
    final trimmedName = student.fullName.trim();
    final initial = trimmedName.isEmpty ? '?' : trimmedName[0].toUpperCase();
    return Row(
      children: [
        CircleAvatar(
          radius: 21,
          backgroundColor: const Color(0xFFFFEEE4),
          child: Text(
            initial,
            style: const TextStyle(
              color: Color(0xFFB8522D),
              fontSize: 14,
              fontWeight: FontWeight.w700,
            ),
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              const Text(
                'STUDENT PROGRESS',
                style: TextStyle(
                  color: Color(0xFFB8522D),
                  fontSize: 9,
                  fontWeight: FontWeight.w700,
                  letterSpacing: 1,
                ),
              ),
              const SizedBox(height: 3),
              Text(
                student.fullName,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                  color: Color(0xFF3B2419),
                  fontSize: 17,
                  height: 1.2,
                  fontWeight: FontWeight.w700,
                ),
              ),
              if (classroom.name.trim().isNotEmpty) ...[
                const SizedBox(height: 3),
                Text(
                  classroom.name,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    color: Color(0xFF765C4F),
                    fontSize: 11,
                  ),
                ),
              ],
            ],
          ),
        ),
      ],
    );
  }
}

class _SectionLabel extends StatelessWidget {
  const _SectionLabel({required this.label});

  final String label;

  @override
  Widget build(BuildContext context) => Text(
    label,
    style: const TextStyle(
      color: Color(0xFF9A725A),
      fontSize: 9,
      fontWeight: FontWeight.w700,
      letterSpacing: 1,
    ),
  );
}

class _StudentMetricCard extends StatelessWidget {
  const _StudentMetricCard({
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
        'Completed activities as a percentage of started classroom activities.',
      'Accuracy' => 'Percent correct across recent quiz attempts. The chart shows recent scores.',
      'Retention' => 'Average score across the latest two attempts for quizzes attempted twice.',
      'Improvement' => 'Average score change between quiz retries. Positive values indicate a rise.',
      'Consistency' => 'Percent of recent days with a completed quiz. Green bars mark quiz days.',
      'Focus' => 'Percent correct on the first attempt for each quiz.',
      _ => 'Current result for this learning metric.',
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
      'Accuracy' => const Color(0xFFE36F38),
      'Retention' => const Color(0xFFB28A20),
      'Improvement' => const Color(0xFF347EA3),
      'Consistency' => const Color(0xFF39865B),
      'Focus' => const Color(0xFFA14E83),
      _ => const Color(0xFFE36F38),
    };
    final formattedValue = metric == 'Improvement'
        ? '${value > 0 ? '+' : ''}${value.toStringAsFixed(0)} pts'
        : '${value.toStringAsFixed(0)}%';

    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(13),
        border: Border.all(color: const Color(0xFFEAE1D8)),
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
                    color: Color(0xFF4A352A),
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 5),
                decoration: BoxDecoration(
                  color: chartColor.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Text(
                  formattedValue,
                  style: TextStyle(
                    color: chartColor,
                    fontSize: 13,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Container(
            height: 48,
            width: double.infinity,
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
            decoration: BoxDecoration(
              color: const Color(0xFFFFFAF5),
              borderRadius: BorderRadius.circular(9),
            ),
            child: Semantics(
              label: '$metric chart for ${student.fullName}',
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
              color: Color(0xFF76685F),
              fontSize: 10,
              height: 1.35,
            ),
          ),
        ],
      ),
    );
  }
}
