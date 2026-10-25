import 'dart:math';

import 'package:supabase_flutter/supabase_flutter.dart';

import 'auth_service.dart';

enum QuizQuestionType {
  multipleChoice('generate-quiz'),
  trueOrFalse('generate-true-or-false');

  const QuizQuestionType(this.functionName);

  final String functionName;
}

List<QuizQuestion> shuffledQuizQuestions(
  List<QuizQuestion> questions, {
  Random? random,
}) {
  final randomizer = random ?? Random();
  final shuffled = List<QuizQuestion>.of(questions)..shuffle(randomizer);
  if (shuffled.length > 1 &&
      List<int>.generate(
        shuffled.length,
        (index) => index,
      ).every((index) => identical(shuffled[index], questions[index]))) {
    final offset = randomizer.nextInt(shuffled.length - 1) + 1;
    return [...shuffled.skip(offset), ...shuffled.take(offset)];
  }
  return shuffled;
}

List<QuizQuestion> randomizedQuizAnswers(
  List<QuizQuestion> questions, {
  Random? random,
}) {
  final randomizer = random ?? Random();
  final correctAnswerPositions = <int>[];
  final correctPositionCounts = List<int>.filled(4, 0);
  var previousCorrectPosition = -1;

  for (final question in questions) {
    if (question.options.length != 4) continue;

    final lowestCount = correctPositionCounts.reduce(
      (current, next) => current < next ? current : next,
    );
    var candidates = List<int>.generate(
      4,
      (index) => index,
    ).where((index) => correctPositionCounts[index] == lowestCount).toList();
    if (candidates.length > 1) {
      candidates.remove(previousCorrectPosition);
    }
    final position = candidates[randomizer.nextInt(candidates.length)];
    correctPositionCounts[position]++;
    correctAnswerPositions.add(position);
    previousCorrectPosition = position;
  }

  var multipleChoiceIndex = 0;
  return questions
      .map((question) {
        if (question.options.length != 4) return question;

        final correctPosition = correctAnswerPositions[multipleChoiceIndex++];
        final correctAnswer = question.options[question.answerIndex];
        final distractors = List<String>.of(question.options)
          ..removeAt(question.answerIndex)
          ..shuffle(randomizer);
        final options = distractors..insert(correctPosition, correctAnswer);
        return QuizQuestion(
          question: question.question,
          options: options,
          answerIndex: correctPosition,
          explanation: question.explanation,
        );
      })
      .toList(growable: false);
}

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
        (options.length != 2 && options.length != 4) ||
        options.any((option) => option.trim().isEmpty) ||
        (options.length == 2 &&
            (options[0].trim().toLowerCase() != 'true' ||
                options[1].trim().toLowerCase() != 'false')) ||
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
    this.classroomActivityId,
    this.classroomName,
    this.maxAttempts,
  });

  final String id;
  final String title;
  final String sourceFile;
  final DateTime createdAt;
  final List<QuizQuestion> questions;
  final List<QuizScore> attempts;
  final String? classroomActivityId;
  final String? classroomName;
  final int? maxAttempts;

  int get totalQuestions => questions.length;

  QuizScore? get latestAttempt {
    if (attempts.isEmpty) return null;

    return attempts.reduce(
      (latest, attempt) =>
          attempt.createdAt.isAfter(latest.createdAt) ? attempt : latest,
    );
  }

  QuizScore? get firstAttempt {
    if (attempts.isEmpty) return null;

    return attempts.reduce(
      (first, attempt) =>
          attempt.createdAt.isBefore(first.createdAt) ? attempt : first,
    );
  }

  double? get retentionPercentage {
    if (attempts.length < 2) return null;

    final orderedAttempts = List<QuizScore>.of(attempts)
      ..sort((first, second) => second.createdAt.compareTo(first.createdAt));
    return (orderedAttempts[0].percentage + orderedAttempts[1].percentage) / 2;
  }

  double? get improvementPercentage {
    if (attempts.length < 2) return null;

    final chronologicalAttempts = List<QuizScore>.of(attempts)
      ..sort((first, second) => first.createdAt.compareTo(second.createdAt));
    var totalChange = 0.0;
    for (var index = 1; index < chronologicalAttempts.length; index++) {
      totalChange +=
          chronologicalAttempts[index].percentage -
          chronologicalAttempts[index - 1].percentage;
    }
    return totalChange / (chronologicalAttempts.length - 1);
  }

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
      classroomActivityId: json['classroom_activity_id'] as String?,
      classroomName: json['classroom_name'] as String?,
      maxAttempts: (json['max_attempts'] as num?)?.toInt(),
    );
  }
}

double? averageQuizRetentionPercentage(Iterable<QuizActivity> quizzes) {
  final quizAverages = quizzes
      .map((quiz) => quiz.retentionPercentage)
      .whereType<double>()
      .toList(growable: false);
  if (quizAverages.isEmpty) return null;

  return quizAverages.reduce((sum, average) => sum + average) /
      quizAverages.length;
}

double? latestQuizAccuracyPercentage(Iterable<QuizActivity> quizzes) {
  var totalScore = 0;
  var totalQuestions = 0;
  for (final quiz in quizzes) {
    final attempt = quiz.latestAttempt;
    if (attempt == null) continue;

    totalScore += attempt.score;
    totalQuestions += attempt.totalQuestions;
  }
  if (totalQuestions == 0) return null;

  return totalScore / totalQuestions * 100;
}

double? firstQuizAttemptFocusPercentage(Iterable<QuizActivity> quizzes) {
  var totalScore = 0;
  var totalQuestions = 0;
  for (final quiz in quizzes) {
    final attempt = quiz.firstAttempt;
    if (attempt == null) continue;

    totalScore += attempt.score;
    totalQuestions += attempt.totalQuestions;
  }
  if (totalQuestions == 0) return null;

  return totalScore / totalQuestions * 100;
}

double? quizLearningConsistencyPercentage({
  required Iterable<QuizActivity> quizzes,
  required DateTime? accountCreatedAt,
  DateTime? now,
}) {
  if (accountCreatedAt == null) return null;

  DateTime calendarDate(DateTime date) =>
      DateTime.utc(date.year, date.month, date.day);

  final today = calendarDate((now ?? DateTime.now()).toLocal());
  final creationDate = calendarDate(accountCreatedAt.toLocal());
  if (creationDate.isAfter(today)) return null;

  final windowStart = today.subtract(const Duration(days: 27));
  final firstEligibleDate = creationDate.isAfter(windowStart)
      ? creationDate
      : windowStart;
  final activeQuizDays = <DateTime>{};
  for (final quiz in quizzes) {
    for (final attempt in quiz.attempts) {
      final date = calendarDate(attempt.createdAt.toLocal());
      if (!date.isBefore(firstEligibleDate) && !date.isAfter(today)) {
        activeQuizDays.add(date);
      }
    }
  }

  final eligibleDays = today.difference(firstEligibleDate).inDays + 1;
  return activeQuizDays.length / eligibleDays * 100;
}

double? averageQuizImprovementPercentage(Iterable<QuizActivity> quizzes) {
  final quizAverages = quizzes
      .map((quiz) => quiz.improvementPercentage)
      .whereType<double>()
      .toList(growable: false);
  if (quizAverages.isEmpty) return null;

  return quizAverages.reduce((sum, average) => sum + average) /
      quizAverages.length;
}

class ClassroomActivity {
  const ClassroomActivity({
    required this.id,
    required this.classroomId,
    required this.classroomName,
    required this.quizId,
    required this.title,
    required this.sourceFile,
    required this.questions,
    required this.startsAt,
    required this.deadlineAt,
    this.maxAttempts = 2,
    this.attemptCount = 0,
    this.attempts = const [],
  });

  final String id;
  final String classroomId;
  final String classroomName;
  final String quizId;
  final String title;
  final String sourceFile;
  final List<QuizQuestion> questions;
  final DateTime startsAt;
  final DateTime deadlineAt;
  final int maxAttempts;
  final int attemptCount;
  final List<QuizScore> attempts;

  bool get isAvailable {
    final now = DateTime.now().toUtc();
    return attemptCount < maxAttempts &&
        !now.isBefore(startsAt.toUtc()) &&
        !now.isAfter(deadlineAt.toUtc());
  }

  String get status {
    final now = DateTime.now().toUtc();
    if (attemptCount >= maxAttempts) return 'Completed';
    if (now.isBefore(startsAt.toUtc())) return 'Upcoming';
    if (now.isAfter(deadlineAt.toUtc())) return 'Closed';
    return attemptCount == 0 ? 'Open' : 'In progress';
  }

  factory ClassroomActivity.fromJson(Map<String, dynamic> json) =>
      ClassroomActivity(
        id: json['id'] as String,
        classroomId: json['classroom_id'] as String,
        classroomName: json['classroom_name'] as String,
        quizId: json['quiz_id'] as String,
        title: json['title'] as String,
        sourceFile: json['source_file'] as String,
        questions: (json['questions'] as List<dynamic>)
            .map(
              (question) => QuizQuestion.fromJson(
                Map<String, dynamic>.from(question as Map),
              ),
            )
            .toList(growable: false),
        startsAt: DateTime.parse(json['starts_at'] as String),
        deadlineAt: DateTime.parse(json['deadline_at'] as String),
        maxAttempts: (json['max_attempts'] as num?)?.toInt() ?? 2,
        attemptCount: (json['attempt_count'] as num?)?.toInt() ?? 0,
        attempts: (json['attempts'] as List<dynamic>? ?? const [])
            .map(
              (attempt) =>
                  QuizScore.fromJson(Map<String, dynamic>.from(attempt as Map)),
            )
            .toList(growable: false),
      );
}

class QuizScore {
  const QuizScore({
    required this.score,
    required this.totalQuestions,
    required this.createdAt,
    this.classroomName,
  });

  final int score;
  final int totalQuestions;
  final DateTime createdAt;
  final String? classroomName;

  double get percentage => score / totalQuestions * 100;

  factory QuizScore.fromJson(Map<String, dynamic> json) => QuizScore(
    score: (json['score'] as num).toInt(),
    totalQuestions: (json['total_questions'] as num).toInt(),
    createdAt: DateTime.parse(json['created_at'] as String),
    classroomName: json['classroom_name'] as String?,
  );
}

class QuizService {
  QuizService({SupabaseClient? client, AuthService? authService})
    : _client = client ?? Supabase.instance.client,
      _authService = authService ?? AuthService();

  final SupabaseClient _client;
  final AuthService _authService;

  Future<int> learnerPointsForAttempt({
    required String quizId,
    String? classroomActivityId,
  }) async {
    final token = await _requireSessionToken();
    try {
      return await _client.rpc<int>(
        'get_quiz_attempt_learner_points',
        params: {
          'p_session_token': token,
          'p_quiz_id': quizId,
          'p_classroom_activity_id': classroomActivityId,
        },
      );
    } on PostgrestException catch (error) {
      throw QuizServiceException(
        _databaseMessage(
          error,
          failureMessage: 'Learner points could not be loaded.',
        ),
      );
    }
  }

  Future<String> saveDraft({
    required String title,
    required String sourceFile,
    required List<QuizQuestion> questions,
  }) async {
    final token = await _requireSessionToken();
    try {
      return await _client.rpc<String>(
        'save_quiz_draft',
        params: {
          'p_session_token': token,
          'p_title': title,
          'p_source_file': sourceFile,
          'p_questions': questions
              .map((question) => question.toJson())
              .toList(),
        },
      );
    } on PostgrestException catch (error) {
      throw QuizServiceException(
        _databaseMessage(
          error,
          failureMessage: 'The quiz could not be saved. Please try again.',
        ),
      );
    }
  }

  Future<void> postToClassrooms({
    required String quizId,
    required List<String> classroomIds,
    required DateTime startsAt,
    required DateTime deadlineAt,
    int maxAttempts = 2,
  }) async {
    if (classroomIds.isEmpty) {
      throw const QuizServiceException('Choose at least one classroom.');
    }
    if (!deadlineAt.isAfter(startsAt)) {
      throw const QuizServiceException(
        'The deadline must be after the start time.',
      );
    }

    final token = await _requireSessionToken();
    try {
      await _client.rpc<int>(
        'post_classroom_activity',
        params: {
          'p_session_token': token,
          'p_quiz_id': quizId,
          'p_classroom_ids': classroomIds,
          'p_starts_at': startsAt.toUtc().toIso8601String(),
          'p_deadline_at': deadlineAt.toUtc().toIso8601String(),
          'p_max_attempts': maxAttempts,
        },
      );
    } on PostgrestException catch (error) {
      throw QuizServiceException(
        _databaseMessage(
          error,
          failureMessage: 'The activity could not be posted. Please try again.',
        ),
      );
    }
  }

  Future<String> saveClassroomActivityAttempt({
    required String activityId,
    required int score,
    required int totalQuestions,
  }) async {
    final token = await _requireSessionToken();
    try {
      return await _client.rpc<String>(
        'submit_classroom_activity_attempt',
        params: {
          'p_session_token': token,
          'p_activity_id': activityId,
          'p_score': score,
          'p_total_questions': totalQuestions,
        },
      );
    } on PostgrestException catch (error) {
      throw QuizServiceException(
        _databaseMessage(
          error,
          failureMessage: 'Your activity result could not be saved.',
        ),
      );
    }
  }

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
    Set<QuizQuestionType> questionTypes = const {
      QuizQuestionType.multipleChoice,
    },
  }) async {
    if (questionCount < 1 || questionCount > 30) {
      throw const QuizServiceException('Choose between 1 and 30 questions.');
    }
    if (questionTypes.isEmpty) {
      throw const QuizServiceException('Choose at least one question type.');
    }

    final token = await _requireSessionToken();
    final functionName = questionTypes.length > 1
        ? 'generate-mixed-quiz'
        : questionTypes.single.functionName;
    final response = await _invokeFunction(functionName, {
      'sessionToken': token,
      'questionCount': questionCount,
      'sourceFileName': fileName,
      'sourceText': sourceText,
    }, failureMessage: 'The quiz could not be generated. Please try again.');

    final payload = response.data;
    if (response.status < 200 || response.status >= 300) {
      throw const QuizServiceException(
        'The quiz could not be generated. Please try again.',
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
      throw QuizServiceException(
        error.status == 0
            ? 'Could not connect to the quiz service. Please try again.'
            : failureMessage,
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
