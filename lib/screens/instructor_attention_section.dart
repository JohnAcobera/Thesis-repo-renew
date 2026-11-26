import 'package:material_ui/material_ui.dart';

import '../models/instructor_report.dart';
import '../services/instructor_reports_service.dart';
import '../services/instructor_student_feedback_service.dart';
import '../widgets/app_glass_surface.dart';
import '../widgets/instructor_student_insights.dart';

class InstructorAttentionSection extends StatefulWidget {
  const InstructorAttentionSection({
    required this.reportsRepository,
    this.feedbackRepository,
    this.panelHeight,
    super.key,
  });

  final InstructorReportsRepository reportsRepository;
  final InstructorStudentFeedbackRepository? feedbackRepository;
  final double? panelHeight;

  @override
  State<InstructorAttentionSection> createState() =>
      _InstructorAttentionSectionState();
}

class _InstructorAttentionSectionState
    extends State<InstructorAttentionSection> {
  late Future<List<InstructorReportClassroom>> _reports;

  @override
  void initState() {
    super.initState();
    _reports = widget.reportsRepository.loadReports();
  }

  void _reload() {
    setState(() {
      _reports = widget.reportsRepository.loadReports();
    });
  }

  @override
  Widget build(BuildContext context) => SizedBox(
    height: widget.panelHeight,
    child: FutureBuilder<List<InstructorReportClassroom>>(
      future: _reports,
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const AppGlassSurface(
            borderRadius: 18,
            child: SizedBox(
              height: 160,
              child: Center(
                child: CircularProgressIndicator(color: Color(0xFFF4773C)),
              ),
            ),
          );
        }
        if (snapshot.hasError) {
          return _AttentionError(
            message: snapshot.error.toString(),
            onRetry: _reload,
          );
        }
        final reports = snapshot.data;
        if (reports == null || reports.isEmpty) {
          return const AppGlassSurface(
            borderRadius: 18,
            child: Padding(
              padding: EdgeInsets.all(20),
              child: Text(
                'No classroom reports yet.',
                style: TextStyle(color: Color(0xFF765C4F), fontSize: 13),
              ),
            ),
          );
        }
        return InstructorStudentInsights(
          reports: reports,
          feedbackRepository: widget.feedbackRepository,
          panelHeight: widget.panelHeight,
        );
      },
    ),
  );
}

class _AttentionError extends StatelessWidget {
  const _AttentionError({required this.message, required this.onRetry});

  final String message;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) => AppGlassSurface(
    borderRadius: 18,
    child: Padding(
      padding: const EdgeInsets.all(16),
      child: Row(
        children: [
          const Icon(Icons.error_outline, color: Color(0xFFB84735)),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              'Student insights could not be loaded. $message',
              style: const TextStyle(color: Color(0xFF87372C), fontSize: 12),
            ),
          ),
          TextButton(onPressed: onRetry, child: const Text('Retry')),
        ],
      ),
    ),
  );
}
