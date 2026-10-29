import 'package:flutter/material.dart';

import '../models/instructor_report.dart';
import 'student_performance_radar_chart.dart';

class InstructorStudentProfileDialog extends StatelessWidget {
  const InstructorStudentProfileDialog({
    required this.student,
    this.joinedAt,
    super.key,
  });

  final InstructorReportStudent student;
  final DateTime? joinedAt;

  @override
  Widget build(BuildContext context) => AlertDialog(
    scrollable: true,
    backgroundColor: const Color(0xFFFFFCF8),
    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
    titlePadding: const EdgeInsets.fromLTRB(22, 22, 22, 8),
    contentPadding: const EdgeInsets.fromLTRB(22, 4, 22, 12),
    title: Row(
      children: [
        CircleAvatar(
          radius: 22,
          backgroundColor: const Color(0xFFFFE9DA),
          child: Text(
            student.fullName.isEmpty ? '?' : student.fullName[0].toUpperCase(),
            style: const TextStyle(
              color: Color(0xFF9A512F),
              fontWeight: FontWeight.w700,
            ),
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                student.fullName,
                style: const TextStyle(
                  color: Color(0xFF3B2419),
                  fontSize: 17,
                  fontWeight: FontWeight.w700,
                ),
              ),
              const SizedBox(height: 3),
              Text(
                student.email,
                style: const TextStyle(
                  color: Color(0xFF765C4F),
                  fontSize: 11,
                  fontWeight: FontWeight.normal,
                ),
              ),
            ],
          ),
        ),
      ],
    ),
    content: SizedBox(
      width: 440,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const SizedBox(height: 12),
          const _ProfileSectionTitle(title: 'ACCOUNT DETAILS'),
          const SizedBox(height: 8),
          _ProfileDetailRow(label: 'Role', value: _capitalize(student.role)),
          _ProfileDetailRow(
            label: 'Account created',
            value: _formatDate(student.createdAt),
          ),
          _ProfileDetailRow(
            label: 'Joined classroom',
            value: _formatDate(joinedAt ?? student.joinedAt),
          ),
          const SizedBox(height: 18),
          const _ProfileSectionTitle(title: 'PERSONAL STATS'),
          const SizedBox(height: 8),
          _ProfileDetailRow(
            label: 'Quizzes generated',
            value: '${student.generatedQuizCount}',
          ),
          _ProfileDetailRow(
            label: 'All quiz attempts',
            value: '${student.personalAttemptCount}',
          ),
          _ProfileDetailRow(
            label: 'Overall average score',
            value: _formatScore(student.personalAverageScore),
          ),
          const SizedBox(height: 20),
          const _ProfileSectionTitle(title: 'YOUR STATS'),
          const SizedBox(height: 5),
          const Text(
            'A snapshot of quiz performance and study habits.',
            style: TextStyle(color: Color(0xFF765C4F), fontSize: 11),
          ),
          const SizedBox(height: 8),
          Semantics(
            label: _radarSemanticsLabel(student),
            child: SizedBox(
              height: 226,
              width: double.infinity,
              child: StudentPerformanceRadarChart(
                accuracyPercentage: student.accuracyPercentage,
                retentionPercentage: student.retentionPercentage,
                improvementPercentage: student.improvementPercentage,
                consistencyPercentage: student.consistencyPercentage,
                focusPercentage: student.focusPercentage,
              ),
            ),
          ),
          const SizedBox(height: 2),
          const Text(
            'Metrics use the student’s saved quizzes and recent attempt history.',
            textAlign: TextAlign.center,
            style: TextStyle(color: Color(0xFF9A725A), fontSize: 10),
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

  static String _formatDate(DateTime? date) {
    if (date == null) return 'Not available';
    return '${_monthName(date.month)} ${date.day}, ${date.year}';
  }

  static String _monthName(int month) => const [
    'January',
    'February',
    'March',
    'April',
    'May',
    'June',
    'July',
    'August',
    'September',
    'October',
    'November',
    'December',
  ][month - 1];

  static String _formatScore(double? score) =>
      score == null ? 'No score yet' : '${score.toStringAsFixed(1)}%';

  static String _capitalize(String value) => value.isEmpty
      ? value
      : '${value[0].toUpperCase()}${value.substring(1).toLowerCase()}';

  static String _radarSemanticsLabel(InstructorReportStudent student) {
    String metric(String label, double? value) =>
        '$label ${value == null ? 'not available' : '${value.toStringAsFixed(0)} percent'}';

    return 'Student dashboard stats. '
        '${metric('Accuracy', student.accuracyPercentage)}, '
        '${metric('Retention', student.retentionPercentage)}, '
        '${metric('Improvement', student.improvementPercentage)}, '
        '${metric('Consistency', student.consistencyPercentage)}, '
        '${metric('Focus', student.focusPercentage)}.';
  }
}

class _ProfileSectionTitle extends StatelessWidget {
  const _ProfileSectionTitle({required this.title});

  final String title;

  @override
  Widget build(BuildContext context) => Text(
    title,
    style: const TextStyle(
      color: Color(0xFF9A725A),
      fontSize: 10,
      fontWeight: FontWeight.w700,
      letterSpacing: 0.9,
    ),
  );
}

class _ProfileDetailRow extends StatelessWidget {
  const _ProfileDetailRow({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.symmetric(vertical: 5),
    child: Row(
      children: [
        Expanded(
          child: Text(
            label,
            style: const TextStyle(color: Color(0xFF765C4F), fontSize: 12),
          ),
        ),
        const SizedBox(width: 12),
        Flexible(
          child: Text(
            value,
            textAlign: TextAlign.right,
            style: const TextStyle(
              color: Color(0xFF3B2419),
              fontSize: 12,
              fontWeight: FontWeight.w600,
            ),
          ),
        ),
      ],
    ),
  );
}
