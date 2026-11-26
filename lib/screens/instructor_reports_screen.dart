import 'dart:math' as math;

import 'package:material_ui/material_ui.dart';

import '../models/instructor_report.dart';
import '../services/instructor_reports_service.dart';
import '../services/instructor_student_feedback_service.dart';
import '../widgets/app_glass_surface.dart';
import '../widgets/instructor_student_insights.dart';
import '../widgets/instructor_student_progress_dialog.dart';

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
  Widget build(BuildContext context) =>
      FutureBuilder<List<InstructorReportClassroom>>(
        future: _reports,
        builder: (context, snapshot) {
          final reports = snapshot.data;
          final insights = getInstructorStudentInsights(
            reports ?? const <InstructorReportClassroom>[],
          );

          return LayoutBuilder(
            builder: (context, constraints) {
              final horizontalPadding = constraints.maxWidth < 600
                  ? 16.0
                  : 32.0;
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
      builder: (context) => InstructorStudentProgressDialog(
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
