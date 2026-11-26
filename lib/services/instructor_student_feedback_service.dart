import 'package:supabase_flutter/supabase_flutter.dart';

import 'auth_service.dart';

abstract interface class InstructorStudentFeedbackRepository {
  Future<void> sendStudentFeedback({
    required int studentId,
    required String classroomId,
    required String metric,
    required String message,
  });
}

class InstructorStudentFeedbackService
    implements InstructorStudentFeedbackRepository {
  InstructorStudentFeedbackService({
    SupabaseClient? client,
    AuthService? authService,
  }) : _client = client,
       _authService = authService;

  final SupabaseClient? _client;
  final AuthService? _authService;

  SupabaseClient get _supabase => _client ?? Supabase.instance.client;
  AuthService get _auth => _authService ?? AuthService();

  @override
  Future<void> sendStudentFeedback({
    required int studentId,
    required String classroomId,
    required String metric,
    required String message,
  }) async {
    final token = await _auth.getSessionToken();
    if (token == null || token.isEmpty) {
      throw const InstructorStudentFeedbackException(
        'Your session has expired. Please log in again.',
      );
    }

    try {
      await _supabase.rpc<void>(
        'send_student_feedback',
        params: {
          'p_session_token': token,
          'p_student_id': studentId,
          'p_classroom_id': classroomId,
          'p_metric': metric,
          'p_message': message,
        },
      );
    } on PostgrestException catch (error) {
      throw InstructorStudentFeedbackException(_databaseMessage(error));
    }
  }

  String _databaseMessage(PostgrestException error) {
    if (error.message.contains('Invalid or expired session')) {
      return 'Your session has expired. Please log in again.';
    }
    if (error.message.contains('Only instructors')) {
      return 'Only instructor accounts can send student feedback.';
    }
    if (error.message.contains('not in this instructor classroom')) {
      return 'This student is no longer in your classroom. Refresh the reports and try again.';
    }
    if (error.code == 'PGRST202' || error.code == '42883') {
      return 'Student feedback is not configured. Run '
          'supabase/student_notifications.sql in the Supabase SQL Editor, '
          'then reload the app.';
    }
    return 'Your message could not be sent. Please try again.';
  }
}

class InstructorStudentFeedbackException implements Exception {
  const InstructorStudentFeedbackException(this.message);

  final String message;

  @override
  String toString() => message;
}
