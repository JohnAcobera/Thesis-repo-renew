import 'package:supabase_flutter/supabase_flutter.dart';

import '../models/learning_material_model.dart';
import 'auth_service.dart';
import 'quiz_service.dart';

abstract interface class InstructorLearningMaterialsRepository {
  Future<List<LearningMaterialModel>> listMaterials();

  Future<List<LearningMaterialFolder>> listFolders();

  Future<LearningMaterialFolder> createFolder(String name);

  Future<void> assignMaterialToFolder({
    required String quizId,
    required String? folderId,
  });

  Future<void> deleteMaterial(String quizId);

  Future<void> postMaterial({
    required String quizId,
    required List<String> classroomIds,
    required DateTime startsAt,
  });
}

class InstructorLearningMaterialsService
    implements InstructorLearningMaterialsRepository {
  InstructorLearningMaterialsService({
    SupabaseClient? client,
    AuthService? authService,
    QuizService? quizService,
  }) : _client = client,
       _authService = authService,
       _quizService = quizService;

  final SupabaseClient? _client;
  final AuthService? _authService;
  final QuizService? _quizService;

  SupabaseClient get _supabase => _client ?? Supabase.instance.client;
  AuthService get _auth => _authService ?? AuthService();
  QuizService get _quizzes => _quizService ?? QuizService();

  @override
  Future<List<LearningMaterialModel>> listMaterials() async {
    final token = await _requireSessionToken();
    try {
      final response = await _supabase.rpc<List<dynamic>>(
        'list_instructor_learning_materials',
        params: {'p_session_token': token},
      );
      return response
          .map(
            (row) => LearningMaterialModel.fromJson(
              Map<String, dynamic>.from(row as Map),
            ),
          )
          .toList(growable: false);
    } on PostgrestException catch (error) {
      throw InstructorLearningMaterialsException(
        _databaseMessage(
          error,
          fallback: error.code == 'PGRST202' || error.code == '42883'
              ? 'Learning Materials are not configured. Run '
                    'supabase/instructor_learning_materials.sql in the '
                    'Supabase SQL Editor, then reload the app.'
              : 'Learning materials could not be loaded. Please try again.',
        ),
      );
    } on FormatException {
      throw const InstructorLearningMaterialsException(
        'Learning materials could not be read. Please try again.',
      );
    } on TypeError {
      throw const InstructorLearningMaterialsException(
        'Learning materials could not be read. Please try again.',
      );
    }
  }

  @override
  Future<void> deleteMaterial(String quizId) async {
    final token = await _requireSessionToken();
    try {
      await _supabase.rpc<void>(
        'delete_instructor_learning_material',
        params: {'p_session_token': token, 'p_quiz_id': quizId},
      );
    } on PostgrestException catch (error) {
      throw InstructorLearningMaterialsException(
        _databaseMessage(
          error,
          fallback: error.code == 'PGRST202' || error.code == '42883'
              ? 'Learning Materials are not configured. Run '
                    'supabase/instructor_learning_materials.sql in the '
                    'Supabase SQL Editor, then reload the app.'
              : 'The quiz could not be deleted. Please try again.',
        ),
      );
    }
  }

  @override
  Future<List<LearningMaterialFolder>> listFolders() async {
    final token = await _requireSessionToken();
    try {
      final response = await _supabase.rpc<List<dynamic>>(
        'list_instructor_learning_material_folders',
        params: {'p_session_token': token},
      );
      return response
          .map(
            (row) => LearningMaterialFolder.fromJson(
              Map<String, dynamic>.from(row as Map),
            ),
          )
          .toList(growable: false);
    } on PostgrestException catch (error) {
      throw InstructorLearningMaterialsException(
        _databaseMessage(
          error,
          fallback:
              'Learning material folders could not be loaded. Please try again.',
        ),
      );
    } on FormatException {
      throw const InstructorLearningMaterialsException(
        'Learning material folders could not be read.',
      );
    } on TypeError {
      throw const InstructorLearningMaterialsException(
        'Learning material folders could not be read.',
      );
    }
  }

  @override
  Future<LearningMaterialFolder> createFolder(String name) async {
    final token = await _requireSessionToken();
    try {
      final response = await _supabase.rpc<Map<String, dynamic>>(
        'create_instructor_learning_material_folder',
        params: {'p_session_token': token, 'p_name': name.trim()},
      );
      return LearningMaterialFolder.fromJson(response);
    } on PostgrestException catch (error) {
      throw InstructorLearningMaterialsException(
        _databaseMessage(
          error,
          fallback: 'The folder could not be created. Please try again.',
        ),
      );
    } on FormatException {
      throw const InstructorLearningMaterialsException(
        'The created folder could not be read.',
      );
    } on TypeError {
      throw const InstructorLearningMaterialsException(
        'The created folder could not be read.',
      );
    }
  }

  @override
  Future<void> assignMaterialToFolder({
    required String quizId,
    required String? folderId,
  }) async {
    final token = await _requireSessionToken();
    try {
      await _supabase.rpc<void>(
        'assign_instructor_learning_material_folder',
        params: {
          'p_session_token': token,
          'p_quiz_id': quizId,
          'p_folder_id': folderId,
        },
      );
    } on PostgrestException catch (error) {
      throw InstructorLearningMaterialsException(
        _databaseMessage(
          error,
          fallback: 'The quiz could not be moved to that folder.',
        ),
      );
    }
  }

  @override
  Future<void> postMaterial({
    required String quizId,
    required List<String> classroomIds,
    required DateTime startsAt,
  }) async {
    try {
      await _quizzes.postToClassrooms(
        quizId: quizId,
        classroomIds: classroomIds,
        startsAt: startsAt,
      );
    } on QuizServiceException catch (error) {
      throw InstructorLearningMaterialsException(error.message);
    }
  }

  Future<String> _requireSessionToken() async {
    final token = await _auth.getSessionToken();
    if (token == null || token.isEmpty) {
      throw const InstructorLearningMaterialsException(
        'Your session has expired. Please log in again.',
      );
    }
    return token;
  }

  String _databaseMessage(
    PostgrestException error, {
    required String fallback,
  }) => error.message.contains('Invalid or expired session')
      ? 'Your session has expired. Please log in again.'
      : fallback;
}

class InstructorLearningMaterialsException implements Exception {
  const InstructorLearningMaterialsException(this.message);

  final String message;

  @override
  String toString() => message;
}
