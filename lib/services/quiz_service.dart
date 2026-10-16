import 'package:supabase_flutter/supabase_flutter.dart';

import 'auth_service.dart';

class QuizQuestion {
  const QuizQuestion({
    required this.question,
    required this.options,
    required this.answerIndex,
    required this.explanation,
  });

  final String question;
  final List<String> options;
  final int answerIndex;
  final String explanation;

  Map<String, dynamic> toJson() => {
    'question': question,
    'options': options,
    'answerIndex': answerIndex,
    'explanation': explanation,
  };

  factory QuizQuestion.fromJson(Map<String, dynamic> json) {
    final options = (json['options'] as List<dynamic>)
        .map((option) => option as String)
        .toList(growable: false);
    final answerIndex = (json['answerIndex'] as num).toInt();
    final question = json['question'] as String;
    final explanation = json['explanation'] as String;
    if (question.trim().isEmpty ||
        explanation.trim().isEmpty ||
        options.length != 4 ||
        options.any((option) => option.trim().isEmpty) ||
        answerIndex < 0 ||
        answerIndex >= options.length) {
      throw const FormatException(
        'The generated quiz contains an invalid question.',
      );
    }

    return QuizQuestion(
      question: question,
      options: options,
      answerIndex: answerIndex,
      explanation: explanation,
    );
  }
}

class QuizActivity {
  const QuizActivity({
    required this.id,
    required this.title,
    required this.sourceFile,
    required this.createdAt,
    required this.questions,
    required this.attempts,
  });

  final String id;
  final String title;
  final String sourceFile;
  final DateTime createdAt;
  final List<QuizQuestion> questions;
  final List<QuizScore> attempts;

  int get totalQuestions => questions.length;

  int get highestPercentage => attempts.fold(0, (highest, attempt) {
    final percentage = (attempt.score / attempt.totalQuestions * 100).round();
    return percentage > highest ? percentage : highest;
  });

  factory QuizActivity.fromJson(Map<String, dynamic> json) {
    final questions = (json['questions'] as List<dynamic>)
        .map(
          (question) =>
              QuizQuestion.fromJson(Map<String, dynamic>.from(question as Map)),
        )
        .toList(growable: false);
    final attempts = (json['attempts'] as List<dynamic>)
        .map(
          (attempt) =>
              QuizScore.fromJson(Map<String, dynamic>.from(attempt as Map)),
        )
        .toList(growable: false);
    if (questions.isEmpty || attempts.isEmpty) {
      throw const FormatException('The saved quiz is incomplete.');
    }
    return QuizActivity(
      id: json['id'] as String,
      title: json['title'] as String,
      sourceFile: json['source_file'] as String,
      createdAt: DateTime.parse(json['created_at'] as String),
      questions: questions,
      attempts: attempts,
    );
  }
}

class QuizScore {
  const QuizScore({
    required this.score,
    required this.totalQuestions,
    required this.createdAt,
  });

  final int score;
  final int totalQuestions;
  final DateTime createdAt;

  factory QuizScore.fromJson(Map<String, dynamic> json) => QuizScore(
    score: (json['score'] as num).toInt(),
    totalQuestions: (json['total_questions'] as num).toInt(),
    createdAt: DateTime.parse(json['created_at'] as String),
  );
}

class QuizService {
  QuizService({SupabaseClient? client, AuthService? authService})
    : _client = client ?? Supabase.instance.client,
      _authService = authService ?? AuthService();

  final SupabaseClient _client;
  final AuthService _authService;

  Future<String> extractSourceText({
    required String fileName,
    required String fileBase64,
    required String mimeType,
  }) async {
    final token = await _requireSessionToken();
    final response = await _invokeFunction(
      'extract-source-text',
      {
        'sessionToken': token,
        'fileName': fileName,
        'fileBase64': fileBase64,
        'mimeType': mimeType,
      },
      failureMessage:
          'The document text could not be extracted. Please try again.',
    );
    final payload = response.data;
    if (payload is! Map || payload['text'] is! String) {
      throw const QuizServiceException(
        'The extraction service returned an invalid response.',
      );
    }
    final text = (payload['text'] as String).trim();
    if (text.isEmpty) {
      throw const QuizServiceException(
        'No readable text was found in the selected file.',
      );
    }
    return text;
  }

  Future<List<QuizQuestion>> generateQuiz({
    required int questionCount,
    required String fileName,
    required String sourceText,
  }) async {
    final token = await _requireSessionToken();
    final response = await _invokeFunction('generate-quiz', {
      'sessionToken': token,
      'questionCount': questionCount,
      'sourceFileName': fileName,
      'sourceText': sourceText,
    }, failureMessage: 'The quiz could not be generated. Please try again.');

    final payload = response.data;
    if (response.status < 200 || response.status >= 300) {
      final message = payload is Map ? payload['error']?.toString() : null;
      throw QuizServiceException(
        message ?? 'The quiz could not be generated. Please try again.',
      );
    }
    if (payload is! Map || payload['questions'] is! List) {
      throw const QuizServiceException(
        'The quiz service returned an invalid response.',
      );
    }

    try {
      final questions = (payload['questions'] as List<dynamic>)
          .map(
            (question) => QuizQuestion.fromJson(
              Map<String, dynamic>.from(question as Map),
            ),
          )
          .toList(growable: false);
      if (questions.length != questionCount) {
        throw const FormatException('The question count does not match.');
      }
      return questions;
    } on FormatException {
      throw const QuizServiceException(
        'The generated quiz was incomplete. Please generate it again.',
      );
    } on TypeError {
      throw const QuizServiceException(
        'The generated quiz response was invalid. Please try again.',
      );
    }
  }

  Future<FunctionResponse> _invokeFunction(
    String name,
    Map<String, dynamic> body, {
    required String failureMessage,
  }) async {
    try {
      return await _client.functions.invoke(name, body: body);
    } on FunctionException catch (error) {
      final details = error.details;
      final message = details is Map ? details['error']?.toString() : null;
      throw QuizServiceException(
        message ??
            (error.status == 0
                ? 'Could not connect to the quiz service. Please try again.'
                : failureMessage),
      );
    }
  }

  Future<String> saveAttempt({
    required String title,
    required String sourceFile,
    required int score,
    required int totalQuestions,
    required List<QuizQuestion> questions,
    String? quizId,
  }) async {
    final token = await _requireSessionToken();
    try {
      final savedQuizId = await _client.rpc<String>(
        'save_quiz_attempt',
        params: {
          'p_session_token': token,
          'p_title': title,
          'p_score': score,
          'p_total_questions': totalQuestions,
          'p_source_file': sourceFile,
          'p_quiz_id': quizId,
          'p_questions': quizId == null
              ? questions.map((question) => question.toJson()).toList()
              : null,
        },
      );
      return savedQuizId;
    } on PostgrestException catch (error) {
      throw QuizServiceException(
        _databaseMessage(
          error,
          failureMessage:
              'Your quiz activity could not be saved. Please try again.',
        ),
      );
    }
  }

  Future<List<QuizActivity>> recentAttempts() async {
    final token = await _requireSessionToken();
    try {
      final response = await _client.rpc<List<dynamic>>(
        'list_saved_quizzes',
        params: {'p_session_token': token},
      );
      return response
          .map(
            (activity) => QuizActivity.fromJson(
              Map<String, dynamic>.from(activity as Map),
            ),
          )
          .toList(growable: false);
    } on PostgrestException catch (error) {
      throw QuizServiceException(
        _databaseMessage(
          error,
          failureMessage:
              'Your quiz activity could not be loaded. Please try again.',
        ),
      );
    } on FormatException {
      throw const QuizServiceException(
        'Recent quiz activity could not be read.',
      );
    } on TypeError {
      throw const QuizServiceException(
        'Recent quiz activity could not be read.',
      );
    }
  }

  Future<String> _requireSessionToken() async {
    final token = await _authService.getSessionToken();
    if (token == null || token.isEmpty) {
      throw const QuizServiceException(
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
    return failureMessage;
  }
}

class QuizServiceException implements Exception {
  const QuizServiceException(this.message);

  final String message;

  @override
  String toString() => message;
}
