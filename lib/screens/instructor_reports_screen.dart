import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../models/instructor_report.dart';
import '../services/instructor_reports_service.dart';
import '../widgets/student_performance_radar_chart.dart';

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

  @override
  Widget build(
    BuildContext context,
  ) => FutureBuilder<List<InstructorReportClassroom>>(
    future: _reports,
    builder: (context, snapshot) {
      final reports = snapshot.data;
      final totalStudents = reports?.fold<int>(
        0,
        (total, classroom) => total + classroom.studentCount,
      );
      final totalActivities = reports?.fold<int>(
        0,
        (total, classroom) => total + classroom.activityCount,
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
                                'Review quiz results and participation across your classrooms.',
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
                      _ReportSummary(
                        width: contentWidth,
                        classroomCount: reports.length,
                        studentCount: totalStudents ?? 0,
                        activityCount: totalActivities ?? 0,
                      ),
                      const SizedBox(height: 24),
                      for (final classroom in reports) ...[
                        _ClassroomReportCard(
                          classroom: classroom,
                          onStudentSelected: (student) =>
                              _showStudentDetails(context, classroom, student),
                        ),
                        const SizedBox(height: 16),
                      ],
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

  Future<void> _showStudentDetails(
    BuildContext context,
    InstructorReportClassroom classroom,
    InstructorReportStudent student,
  ) => showDialog<void>(
    context: context,
    builder: (context) =>
        _StudentDetailsDialog(classroom: classroom, student: student),
  );
}

class _ReportSummary extends StatelessWidget {
  const _ReportSummary({
    required this.width,
    required this.classroomCount,
    required this.studentCount,
    required this.activityCount,
  });

  final double width;
  final int classroomCount;
  final int studentCount;
  final int activityCount;

  @override
  Widget build(BuildContext context) {
    final columns = width >= 680 ? 3 : 1;
    final gap = 12.0;
    final cardWidth = (width - gap * (columns - 1)) / columns;
    final summaries = [
      ('Classrooms', classroomCount, Icons.class_outlined),
      ('Student enrollments', studentCount, Icons.people_outline),
      ('Activities posted', activityCount, Icons.assignment_outlined),
    ];

    return Wrap(
      spacing: gap,
      runSpacing: gap,
      children: [
        for (final (label, count, icon) in summaries)
          Container(
            width: cardWidth,
            padding: const EdgeInsets.all(18),
            decoration: BoxDecoration(
              color: const Color(0xFFFFFCF8),
              border: Border.all(color: const Color(0xFFE8D7C2)),
              borderRadius: BorderRadius.circular(16),
            ),
            child: Row(
              children: [
                Container(
                  width: 42,
                  height: 42,
                  decoration: BoxDecoration(
                    color: const Color(0xFFFFE9DA),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Icon(icon, color: const Color(0xFFF4773C)),
                ),
                const SizedBox(width: 13),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      '$count',
                      style: const TextStyle(
                        color: Color(0xFF3B2419),
                        fontSize: 22,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    Text(
                      label,
                      style: const TextStyle(
                        color: Color(0xFF765C4F),
                        fontSize: 12,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
      ],
    );
  }
}

class _ClassroomReportCard extends StatelessWidget {
  const _ClassroomReportCard({
    required this.classroom,
    required this.onStudentSelected,
  });

  final InstructorReportClassroom classroom;
  final ValueChanged<InstructorReportStudent> onStudentSelected;

  @override
  Widget build(BuildContext context) => Container(
    decoration: BoxDecoration(
      color: const Color(0xFFFFFCF8),
      border: Border.all(color: const Color(0xFFE8D7C2)),
      borderRadius: BorderRadius.circular(18),
    ),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(20, 18, 20, 15),
          child: Row(
            children: [
              Container(
                width: 44,
                height: 44,
                decoration: BoxDecoration(
                  color: const Color(0xFFFFF1E6),
                  borderRadius: BorderRadius.circular(13),
                ),
                child: const Icon(
                  Icons.menu_book_outlined,
                  color: Color(0xFFF4773C),
                ),
              ),
              const SizedBox(width: 13),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      classroom.name,
                      style: const TextStyle(
                        color: Color(0xFF3B2419),
                        fontSize: 16,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    const SizedBox(height: 3),
                    Text(
                      classroom.subject,
                      style: const TextStyle(
                        color: Color(0xFF765C4F),
                        fontSize: 12,
                      ),
                    ),
                  ],
                ),
              ),
              _ScoreBadge(score: classroom.averageScore),
            ],
          ),
        ),
        const Divider(height: 1, color: Color(0xFFE8D7C2)),
        Padding(
          padding: const EdgeInsets.fromLTRB(20, 13, 20, 10),
          child: Wrap(
            spacing: 18,
            runSpacing: 8,
            children: [
              _ClassroomMetric(
                icon: Icons.people_outline,
                label: '${classroom.studentCount} students',
              ),
              _ClassroomMetric(
                icon: Icons.assignment_outlined,
                label: '${classroom.activityCount} activities',
              ),
            ],
          ),
        ),
        if (classroom.students.isEmpty)
          const Padding(
            padding: EdgeInsets.fromLTRB(20, 8, 20, 18),
            child: Text(
              'No students have joined this classroom yet.',
              style: TextStyle(color: Color(0xFF765C4F), fontSize: 13),
            ),
          )
        else
          for (var index = 0; index < classroom.students.length; index++) ...[
            if (index > 0)
              const Divider(
                height: 1,
                indent: 20,
                endIndent: 20,
                color: Color(0xFFF0E5D8),
              ),
            _StudentReportTile(
              student: classroom.students[index],
              onTap: () => onStudentSelected(classroom.students[index]),
            ),
          ],
        if (classroom.students.isNotEmpty) const SizedBox(height: 6),
      ],
    ),
  );
}

class _ClassroomMetric extends StatelessWidget {
  const _ClassroomMetric({required this.icon, required this.label});

  final IconData icon;
  final String label;

  @override
  Widget build(BuildContext context) => Row(
    mainAxisSize: MainAxisSize.min,
    children: [
      Icon(icon, size: 15, color: const Color(0xFF9A725A)),
      const SizedBox(width: 5),
      Text(
        label,
        style: const TextStyle(color: Color(0xFF765C4F), fontSize: 11),
      ),
    ],
  );
}

class _StudentReportTile extends StatelessWidget {
  const _StudentReportTile({required this.student, required this.onTap});

  final InstructorReportStudent student;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) => Material(
    color: Colors.transparent,
    child: ListTile(
      onTap: onTap,
      contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 1),
      leading: CircleAvatar(
        radius: 18,
        backgroundColor: const Color(0xFFFFE9DA),
        child: Text(
          student.fullName.isEmpty ? '?' : student.fullName[0].toUpperCase(),
          style: const TextStyle(
            color: Color(0xFF9A512F),
            fontSize: 13,
            fontWeight: FontWeight.w700,
          ),
        ),
      ),
      title: Text(
        student.fullName,
        style: const TextStyle(
          color: Color(0xFF3B2419),
          fontSize: 13,
          fontWeight: FontWeight.w600,
        ),
      ),
      subtitle: Text(
        '${student.attemptCount} ${student.attemptCount == 1 ? 'quiz attempt' : 'quiz attempts'}',
        style: const TextStyle(color: Color(0xFF765C4F), fontSize: 11),
      ),
      trailing: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          _ScoreBadge(score: student.averageScore),
          const SizedBox(width: 4),
          const Icon(Icons.chevron_right, color: Color(0xFF9A725A), size: 20),
        ],
      ),
    ),
  );
}

class _ScoreBadge extends StatelessWidget {
  const _ScoreBadge({required this.score});

  final double? score;

  @override
  Widget build(BuildContext context) {
    final score = this.score;
    final hasScore = score != null;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: hasScore ? const Color(0xFFEAF5EC) : const Color(0xFFF4EEE8),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Text(
        hasScore ? '${score.toStringAsFixed(0)}%' : 'No score',
        style: TextStyle(
          color: hasScore ? const Color(0xFF39704A) : const Color(0xFF765C4F),
          fontSize: 11,
          fontWeight: FontWeight.w700,
        ),
      ),
    );
  }
}

class _StudentDetailsDialog extends StatelessWidget {
  const _StudentDetailsDialog({required this.classroom, required this.student});

  final InstructorReportClassroom classroom;
  final InstructorReportStudent student;

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
          const _DetailsSectionTitle(title: 'ACCOUNT DETAILS'),
          const SizedBox(height: 8),
          _DetailRow(label: 'Role', value: _capitalize(student.role)),
          _DetailRow(
            label: 'Account created',
            value: _formatDate(student.createdAt),
          ),
          _DetailRow(
            label: 'Joined classroom',
            value: _formatDate(student.joinedAt),
          ),
          const SizedBox(height: 18),
          const _DetailsSectionTitle(title: 'PERSONAL STATS'),
          const SizedBox(height: 8),
          _DetailRow(
            label: 'Quizzes generated',
            value: '${student.generatedQuizCount}',
          ),
          _DetailRow(
            label: 'All quiz attempts',
            value: '${student.personalAttemptCount}',
          ),
          _DetailRow(
            label: 'Overall average score',
            value: _formatScore(student.personalAverageScore),
          ),
          const SizedBox(height: 18),
          _DetailsSectionTitle(title: classroom.name.toUpperCase()),
          const SizedBox(height: 8),
          _DetailRow(
            label: 'Average quiz score',
            value: _formatScore(student.averageScore),
          ),
          _DetailRow(label: 'Quiz attempts', value: '${student.attemptCount}'),
          _DetailRow(
            label: 'Activities completed',
            value:
                '${student.completedActivityCount} of ${student.totalActivityCount}',
          ),
          const SizedBox(height: 20),
          const _DetailsSectionTitle(title: 'YOUR STATS'),
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

class _DetailsSectionTitle extends StatelessWidget {
  const _DetailsSectionTitle({required this.title});

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

class _DetailRow extends StatelessWidget {
  const _DetailRow({required this.label, required this.value});

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
