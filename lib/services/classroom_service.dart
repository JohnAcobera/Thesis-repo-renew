import 'package:supabase_flutter/supabase_flutter.dart';

import '../models/classroom_model.dart';
import 'auth_service.dart';
import 'quiz_service.dart';

abstract interface class ClassroomRepository {
  Future<InstructorDashboardStats> getInstructorDashboardStats();

  Future<List<ClassroomActivity>> classroomActivities(String classroomId);

  Future<List<ClassroomModel>> listClassrooms();

  Future<List<ClassroomModel>> listStudentClassrooms();

  Future<ClassroomModel> joinClassroom({required String code});

  Future<ClassroomModel> createClassroom({
    required String name,
    required String subject,
    required String iconKey,
  });

  Future<void> deleteClassroom(String classroomId);

  Future<void> deleteClassroomActivity({
    required String classroomId,
    required String activityId,
  });
}

class ClassroomService implements ClassroomRepository {
  ClassroomService({SupabaseClient? client, AuthService? authService})
    : _client = client ?? Supabase.instance.client,
      _authService = authService ?? AuthService();

  final SupabaseClient _client;
  final AuthService _authService;

  @override
  Future<List<ClassroomActivity>> classroomActivities(
    String classroomId,
  ) async {
    final token = await _requireSessionToken();
    try {
      final response = await _client.rpc<List<dynamic>>(
        'list_classroom_activities',
        params: {'p_session_token': token, 'p_classroom_id': classroomId},
      );
      return response
          .map(
            (activity) => ClassroomActivity.fromJson(
              Map<String, dynamic>.from(activity as Map),
            ),
          )
          .toList(growable: false);
    } on PostgrestException catch (error) {
      throw ClassroomServiceException(
        _databaseMessage(
          error,
          failureMessage:
              'Activities for this classroom could not be loaded. Please try again.',
        ),
      );
    } on FormatException {
      throw const ClassroomServiceException(
        'Classroom activities could not be read.',
      );
    } on TypeError {
      throw const ClassroomServiceException(
        'Classroom activities could not be read.',
      );
    }
  }

  @override
  Future<InstructorDashboardStats> getInstructorDashboardStats() async {
    final token = await _requireSessionToken();
    try {
      final response = await _client.rpc<Map<String, dynamic>>(
        'get_instructor_dashboard_stats',
        params: {'p_session_token': token},
      );
      return InstructorDashboardStats.fromJson(response);
    } on PostgrestException catch (error) {
      throw ClassroomServiceException(
        _databaseMessage(
          error,
          failureMessage:
              'Your dashboard statistics could not be loaded. Please try again.',
        ),
      );
    } on FormatException {
      throw const ClassroomServiceException(
        'The dashboard statistics could not be read. Please try again.',
      );
    } on TypeError {
      throw const ClassroomServiceException(
        'The dashboard statistics could not be read. Please try again.',
      );
    }
  }

  @override
  Future<List<ClassroomModel>> listClassrooms() async {
    final token = await _requireSessionToken();
    try {
      final response = await _client.rpc<List<dynamic>>(
        'list_instructor_classrooms',
        params: {'p_session_token': token},
      );
      return response
          .map(
            (classroom) => ClassroomModel.fromJson(
              Map<String, dynamic>.from(classroom as Map),
            ),
          )
          .toList(growable: false);
    } on PostgrestException catch (error) {
      throw ClassroomServiceException(
        _databaseMessage(
          error,
          failureMessage:
              'Your classrooms could not be loaded. Please try again.',
        ),
      );
    } on FormatException {
      throw const ClassroomServiceException(
        'The classroom list could not be read. Please try again.',
      );
    } on TypeError {
      throw const ClassroomServiceException(
        'The classroom list could not be read. Please try again.',
      );
    }
  }

  @override
  Future<List<ClassroomModel>> listStudentClassrooms() async {
    final token = await _requireSessionToken();
    try {
      final response = await _client.rpc<List<dynamic>>(
        'list_student_classrooms',
        params: {'p_session_token': token},
      );
      return response
          .map(
            (classroom) => ClassroomModel.fromJson(
              Map<String, dynamic>.from(classroom as Map),
            ),
          )
          .toList(growable: false);
    } on PostgrestException catch (error) {
      throw ClassroomServiceException(
        _databaseMessage(
          error,
          failureMessage:
              'Your classrooms could not be loaded. Please try again.',
        ),
      );
    } on FormatException {
      throw const ClassroomServiceException(
        'The classroom list could not be read. Please try again.',
      );
    } on TypeError {
      throw const ClassroomServiceException(
        'The classroom list could not be read. Please try again.',
      );
    }
  }

  @override
  Future<ClassroomModel> joinClassroom({required String code}) async {
    final token = await _requireSessionToken();
    try {
      final response = await _client.rpc<Map<String, dynamic>>(
        'join_classroom',
        params: {'p_session_token': token, 'p_code': code.trim().toUpperCase()},
      );
      return ClassroomModel.fromJson(response);
    } on PostgrestException catch (error) {
      throw ClassroomServiceException(
        _databaseMessage(
          error,
          failureMessage: 'Could not join this classroom. Please try again.',
        ),
      );
    } on FormatException {
      throw const ClassroomServiceException(
        'The classroom response could not be read. Please try again.',
      );
    } on TypeError {
      throw const ClassroomServiceException(
        'The classroom response could not be read. Please try again.',
      );
    }
  }

  @override
  Future<ClassroomModel> createClassroom({
    required String name,
    required String subject,
    required String iconKey,
  }) async {
    final token = await _requireSessionToken();
    try {
      final response = await _client.rpc<Map<String, dynamic>>(
        'create_instructor_classroom',
        params: {
          'p_session_token': token,
          'p_name': name.trim(),
          'p_subject': subject.trim(),
          'p_icon_key': iconKey,
        },
      );
      return ClassroomModel.fromJson(response);
    } on PostgrestException catch (error) {
      throw ClassroomServiceException(
        _databaseMessage(
          error,
          failureMessage:
              'The classroom could not be created. Please try again.',
        ),
      );
    } on FormatException {
      throw const ClassroomServiceException(
        'The created classroom could not be read. Please try again.',
      );
    } on TypeError {
      throw const ClassroomServiceException(
        'The created classroom could not be read. Please try again.',
      );
    }
  }

  @override
  Future<void> deleteClassroom(String classroomId) async {
    final token = await _requireSessionToken();
    try {
      await _client.rpc<void>(
        'delete_instructor_classroom',
        params: {'p_session_token': token, 'p_classroom_id': classroomId},
      );
    } on PostgrestException catch (error) {
      throw ClassroomServiceException(
        _databaseMessage(
          error,
          failureMessage:
              'The classroom could not be deleted. Please try again.',
        ),
      );
    }
  }

  @override
  Future<void> deleteClassroomActivity({
    required String classroomId,
    required String activityId,
  }) async {
    final token = await _requireSessionToken();
    try {
      await _client.rpc<void>(
        'delete_classroom_activity',
        params: {
          'p_session_token': token,
          'p_classroom_id': classroomId,
          'p_activity_id': activityId,
        },
      );
    } on PostgrestException catch (error) {
      throw ClassroomServiceException(
        _databaseMessage(
          error,
          failureMessage:
              'The posted quiz could not be deleted. Please try again.',
        ),
      );
    }
  }

  Future<String> _requireSessionToken() async {
    final token = await _authService.getSessionToken();
    if (token == null || token.isEmpty) {
      throw const ClassroomServiceException(
        'Your session has expired. Please log in again.',
      );
    }
    return token;
  }

  String _databaseMessage(
    PostgrestException error, {
    required String failureMessage,
  }) {
    if (error.message.contains('Invalid or expired session')) {
      return 'Your session has expired. Please log in again.';
    }
    if (error.message.contains('Only instructors')) {
      if (error.message.contains('view dashboard statistics')) {
        return 'Only instructor accounts can view dashboard statistics.';
      }
      return 'Only instructor accounts can manage classrooms.';
    }
    if (error.message.contains('Classroom name and subject')) {
      return 'Enter both a class name and a subject.';
    }
    if (error.message.contains('Classroom code not found')) {
      return 'No classroom was found with that code. Check the code and try again.';
    }
    if (error.message.contains('Only students')) {
      return 'Only student accounts can join classrooms.';
    }
    return failureMessage;
  }
}

class ClassroomServiceException implements Exception {
  const ClassroomServiceException(this.message);

  final String message;

  @override
  String toString() => message;
}
