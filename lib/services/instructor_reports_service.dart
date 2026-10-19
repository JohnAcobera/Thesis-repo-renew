import 'package:supabase_flutter/supabase_flutter.dart';

import '../models/instructor_report.dart';
import 'auth_service.dart';

abstract interface class InstructorReportsRepository {
  Future<List<InstructorReportClassroom>> loadReports();
}

class InstructorReportsService implements InstructorReportsRepository {
  InstructorReportsService({SupabaseClient? client, AuthService? authService})
    : _client = client ?? Supabase.instance.client,
      _authService = authService ?? AuthService();

  final SupabaseClient _client;
  final AuthService _authService;

  @override
  Future<List<InstructorReportClassroom>> loadReports() async {
    final token = await _authService.getSessionToken();
    if (token == null || token.isEmpty) {
      throw const InstructorReportsException(
        'Your session has expired. Please log in again.',
      );
    }

    try {
      final response = await _client.rpc<List<dynamic>>(
        'get_instructor_reports',
        params: {'p_session_token': token},
      );
      return response
          .map(
            (classroom) => InstructorReportClassroom.fromJson(
              Map<String, dynamic>.from(classroom as Map),
            ),
          )
          .toList(growable: false);
    } on PostgrestException catch (error) {
      if (error.message.contains('Invalid or expired session')) {
        throw const InstructorReportsException(
          'Your session has expired. Please log in again.',
        );
      }
      if (error.message.contains('Only instructors')) {
        throw const InstructorReportsException(
          'Only instructor accounts can view reports.',
        );
      }
      throw const InstructorReportsException(
        'Classroom reports could not be loaded. Please try again.',
      );
    } on FormatException {
      throw const InstructorReportsException(
        'The classroom reports could not be read. Please try again.',
      );
    } on TypeError {
      throw const InstructorReportsException(
        'The classroom reports could not be read. Please try again.',
      );
    }
  }
}

class InstructorReportsException implements Exception {
  const InstructorReportsException(this.message);

  final String message;

  @override
  String toString() => message;
}
