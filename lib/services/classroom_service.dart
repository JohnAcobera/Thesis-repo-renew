import 'package:supabase_flutter/supabase_flutter.dart';

import '../models/classroom_model.dart';
import 'auth_service.dart';

abstract interface class ClassroomRepository {
  Future<List<ClassroomModel>> listClassrooms();

  Future<List<ClassroomModel>> listStudentClassrooms();

  Future<ClassroomModel> joinClassroom({required String code});

  Future<ClassroomModel> createClassroom({
    required String name,
    required String subject,
    required String iconKey,
  });
}

class ClassroomService implements ClassroomRepository {
  ClassroomService({SupabaseClient? client, AuthService? authService})
    : _client = client ?? Supabase.instance.client,
      _authService = authService ?? AuthService();

  final SupabaseClient _client;
  final AuthService _authService;

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
