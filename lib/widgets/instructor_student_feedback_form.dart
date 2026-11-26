import 'package:material_ui/material_ui.dart';

import '../models/instructor_report.dart';
import '../services/instructor_student_feedback_service.dart';

class InstructorStudentFeedbackForm extends StatefulWidget {
  const InstructorStudentFeedbackForm({
    required this.classroom,
    required this.student,
    required this.metrics,
    required this.repository,
    this.showSendButton = true,
    this.onStateChanged,
    super.key,
  });

  final InstructorReportClassroom classroom;
  final InstructorReportStudent student;
  final List<(String, double)> metrics;
  final InstructorStudentFeedbackRepository repository;
  final bool showSendButton;
  final void Function(bool canSend, bool isSending)? onStateChanged;

  @override
  InstructorStudentFeedbackFormState createState() =>
      InstructorStudentFeedbackFormState();
}

class InstructorStudentFeedbackFormState
    extends State<InstructorStudentFeedbackForm> {
  late final (String, double) _focusMetric = _selectFocusMetric(widget.metrics);
  late final TextEditingController _messageController = TextEditingController(
    text: _buildEncouragementDraft(
      student: widget.student,
      metric: _focusMetric.$1,
    ),
  );
  bool _isSending = false;
  String? _errorMessage;

  bool get canSend => !_isSending && _messageController.text.trim().isNotEmpty;
  bool get isSending => _isSending;

  @override
  void dispose() {
    _messageController.dispose();
    super.dispose();
  }

  Future<void> sendFeedback() async {
    final message = _messageController.text.trim();
    if (message.isEmpty || _isSending) return;

    setState(() {
      _isSending = true;
      _errorMessage = null;
    });
    _notifyStateChanged();
    try {
      await widget.repository.sendStudentFeedback(
        studentId: widget.student.id,
        classroomId: widget.classroom.id,
        metric: _focusMetric.$1,
        message: message,
      );
      if (mounted) Navigator.of(context).pop(true);
    } on InstructorStudentFeedbackException catch (error) {
      if (mounted) setState(() => _errorMessage = error.message);
    } on Exception catch (error) {
      if (mounted) {
        setState(
          () => _errorMessage = 'Your message could not be sent: $error',
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isSending = false);
        _notifyStateChanged();
      }
    }
  }

  void _notifyStateChanged() {
    widget.onStateChanged?.call(canSend, _isSending);
  }

  @override
  Widget build(BuildContext context) => Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      const SizedBox(height: 20),
      const Text(
        'A note of encouragement',
        style: TextStyle(
          color: Color(0xFF3B2419),
          fontSize: 14,
          fontWeight: FontWeight.w700,
        ),
      ),
      const SizedBox(height: 4),
      Text(
        'Draft based on ${_focusMetric.$1.toLowerCase()}. Review or edit it before sending.',
        style: const TextStyle(color: Color(0xFF765C4F), fontSize: 12),
      ),
      const SizedBox(height: 10),
      TextField(
        key: const ValueKey('student-feedback-message'),
        controller: _messageController,
        minLines: 3,
        maxLines: 5,
        maxLength: 1000,
        enabled: !_isSending,
        onChanged: (_) {
          setState(() {});
          _notifyStateChanged();
        },
        decoration: InputDecoration(
          hintText: 'Write a supportive message...',
          filled: true,
          fillColor: const Color(0xFFFFF8EE),
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: const BorderSide(color: Color(0xFFE8D7C2)),
          ),
          enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: const BorderSide(color: Color(0xFFE8D7C2)),
          ),
        ),
      ),
      if (_errorMessage case final error?) ...[
        const SizedBox(height: 4),
        Text(
          error,
          style: const TextStyle(color: Color(0xFFB3261E), fontSize: 12),
        ),
      ],
      if (widget.showSendButton) ...[
        const SizedBox(height: 8),
        Align(
          alignment: Alignment.centerRight,
          child: FilledButton.icon(
            onPressed: canSend ? sendFeedback : null,
            icon: _isSending
                ? const SizedBox.square(
                    dimension: 16,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : const Icon(Icons.send_rounded, size: 17),
            label: const Text('Send encouragement'),
          ),
        ),
      ],
    ],
  );

  static (String, double) _selectFocusMetric(List<(String, double)> metrics) {
    for (final metric in metrics) {
      if (metric.$1 == 'Improvement' && metric.$2 <= 0) return metric;
    }
    final percentageMetrics = metrics
        .where((metric) => metric.$1 != 'Improvement')
        .toList(growable: false);
    if (percentageMetrics.isEmpty) return metrics.first;
    return percentageMetrics.reduce(
      (lowest, metric) => metric.$2 < lowest.$2 ? metric : lowest,
    );
  }

  static String _buildEncouragementDraft({
    required InstructorReportStudent student,
    required String metric,
  }) {
    final name = student.fullName.trim();
    final firstName = name.isEmpty ? 'there' : name.split(RegExp(r'\s+')).first;
    final nextStep = switch (metric) {
      'Consistency' => 'Try a short quiz a few days this week.',
      'Accuracy' => 'Take your time, then try the quiz again.',
      'Retention' => 'Try a quiz again later this week.',
      'Improvement' => 'Reattempt a quiz and see how you do.',
      'Focus' => 'Read each question carefully.',
      'Classroom completion' => 'Try a quiz at your own pace.',
      _ => 'Keep practicing with a quiz when you can.',
    };
    return 'Hi $firstName! $nextStep You’ve got this!';
  }
}
