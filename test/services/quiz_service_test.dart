import 'dart:convert';
import 'dart:math';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:thesis_repo_renew/services/auth_service.dart';
import 'package:thesis_repo_renew/services/quiz_service.dart';

void main() {
  test('does not expose Edge Function error details to the caller', () async {
    final client = _supabaseClient((request) async {
      return http.Response(
        jsonEncode({'error': 'Internal provider key or endpoint diagnostic'}),
        500,
        headers: {'content-type': 'application/json'},
      );
    });
    final service = QuizService(
      client: client,
      authService: _TestAuthService(client),
    );

    await expectLater(
      service.generateQuiz(
        questionCount: 1,
        fileName: 'biology.pdf',
        sourceText: 'Cells store genetic information.',
      ),
      throwsA(
        isA<QuizServiceException>().having(
          (error) => error.message,
          'message',
          'The quiz could not be generated. Please try again.',
        ),
      ),
    );
    await client.dispose();
  });

  test(
    'uses the mixed quiz function when both question types are selected',
    () async {
      String? invokedPath;
      final client = _supabaseClient((request) async {
        invokedPath = request.url.path;
        return http.Response(
          jsonEncode({
            'questions': [
              {
                'question': 'Which planet is known as the Red Planet?',
                'options': ['Venus', 'Mars', 'Jupiter', 'Mercury'],
                'answerIndex': 1,
                'explanation': 'Mars appears red due to iron oxide.',
              },
              {
                'question': 'Mars is the closest planet to the Sun.',
                'options': ['True', 'False'],
                'answerIndex': 1,
                'explanation': 'Mercury is the closest planet to the Sun.',
              },
            ],
          }),
          200,
          headers: {'content-type': 'application/json'},
        );
      });
      final service = QuizService(
        client: client,
        authService: _TestAuthService(client),
      );

      final questions = await service.generateQuiz(
        questionCount: 2,
        fileName: 'astronomy.pdf',
        sourceText: 'Mercury is closest to the Sun. Mars appears red.',
        questionTypes: {
          QuizQuestionType.multipleChoice,
          QuizQuestionType.trueOrFalse,
        },
      );

      expect(invokedPath, endsWith('/generate-mixed-quiz'));
      expect(questions, hasLength(2));
      expect(questions.map((question) => question.options.length), [4, 2]);
      await client.dispose();
    },
  );

  group('QuizQuestion.fromJson', () {
    test('parses a valid four-option multiple-choice question', () {
      final question = QuizQuestion.fromJson({
        'question': 'Which planet is known as the Red Planet?',
        'options': ['Venus', 'Mars', 'Jupiter', 'Mercury'],
        'answerIndex': 1,
        'explanation': 'Iron oxide gives Mars its reddish appearance.',
      });

      expect(question.question, 'Which planet is known as the Red Planet?');
      expect(question.options, hasLength(4));
      expect(question.answerIndex, 1);
      expect(question.explanation, contains('Iron oxide'));
    });

    test('parses a true-or-false question', () {
      final question = QuizQuestion.fromJson({
        'question': 'Mars is known as the Red Planet.',
        'options': ['True', 'False'],
        'answerIndex': 0,
        'explanation': 'Iron oxide gives Mars its reddish appearance.',
      });

      expect(question.options, ['True', 'False']);
      expect(question.answerIndex, 0);
    });

    test('rejects malformed question options and answer indexes', () {
      expect(
        () => QuizQuestion.fromJson({
          'question': 'Pick an answer',
          'options': ['A', 'B', 'C'],
          'answerIndex': 0,
          'explanation': 'An explanation.',
        }),
        throwsFormatException,
      );
      expect(
        () => QuizQuestion.fromJson({
          'question': 'Pick an answer',
          'options': ['A', 'B', 'C', 'D'],
          'answerIndex': 4,
          'explanation': 'An explanation.',
        }),
        throwsFormatException,
      );
      expect(
        () => QuizQuestion.fromJson({
          'question': 'Mars is known as the Red Planet.',
          'options': ['False', 'True'],
          'answerIndex': 0,
          'explanation': 'An explanation.',
        }),
        throwsFormatException,
      );
    });
  });

  group('QuizActivity.fromJson', () {
    test('parses saved questions and all completed attempt scores', () {
      final activity = QuizActivity.fromJson({
        'id': 'saved-quiz-id',
        'title': 'Biology',
        'source_file': 'biology.pdf',
        'created_at': '2026-10-16T05:00:00Z',
        'questions': [
          {
            'question': 'Question?',
            'options': ['A', 'B', 'C', 'D'],
            'answerIndex': 2,
            'explanation': 'Because.',
          },
        ],
        'attempts': [
          {
            'score': 6,
            'total_questions': 10,
            'created_at': '2026-10-16T06:00:00Z',
            'classroom_name': 'Biology 11-A',
          },
          {
            'score': 8,
            'total_questions': 10,
            'created_at': '2026-10-15T06:00:00Z',
          },
        ],
      });

      expect(activity.id, 'saved-quiz-id');
      expect(activity.questions, hasLength(1));
      expect(activity.attempts, hasLength(2));
      expect(activity.highestPercentage, 80);
      expect(activity.attempts.first.score, 6);
      expect(activity.attempts.first.classroomName, 'Biology 11-A');
    });

    test('rejects saved quizzes without questions or completed attempts', () {
      expect(
        () => QuizActivity.fromJson({
          'id': 'saved-quiz-id',
          'title': 'Biology',
          'source_file': 'biology.pdf',
          'created_at': '2026-10-16T05:00:00Z',
          'questions': [],
          'attempts': [],
        }),
        throwsFormatException,
      );
    });
  });

  test('QuizScore percentage is based on score over total questions', () {
    final score = QuizScore(
      score: 3,
      totalQuestions: 10,
      createdAt: DateTime.utc(2026, 10, 16),
    );

    expect(score.percentage, 30);
  });

  test('quiz retention averages each quiz latest two attempt percentages', () {
    final now = DateTime.utc(2026, 10, 16);
    QuizScore score(int points, int daysAgo) => QuizScore(
      score: points,
      totalQuestions: 10,
      createdAt: now.subtract(Duration(days: daysAgo)),
    );
    QuizActivity quiz(String id, List<QuizScore> attempts) => QuizActivity(
      id: id,
      title: id,
      sourceFile: '$id.pdf',
      createdAt: now,
      questions: const [],
      attempts: attempts,
    );

    final quizzes = [
      quiz('first', [score(0, 3), score(2, 2), score(8, 1)]),
      quiz('second', [score(5, 2), score(7, 1)]),
      quiz('not-retained', [score(10, 1)]),
    ];

    expect(quizzes.first.retentionPercentage, 50);
    expect(averageQuizRetentionPercentage(quizzes), 55);
    expect(averageQuizRetentionPercentage([quizzes.last]), isNull);
  });

  test('latest quiz accuracy uses only the newest attempt per quiz', () {
    final now = DateTime.utc(2026, 10, 16);
    QuizScore score(int points, int total, int daysAgo) => QuizScore(
      score: points,
      totalQuestions: total,
      createdAt: now.subtract(Duration(days: daysAgo)),
    );
    QuizActivity quiz(String id, List<QuizScore> attempts) => QuizActivity(
      id: id,
      title: id,
      sourceFile: '$id.pdf',
      createdAt: now,
      questions: const [],
      attempts: attempts,
    );

    final quizzes = [
      quiz('first', [score(0, 10, 1), score(8, 10, 0)]),
      quiz('second', [score(1, 20, 2), score(1, 20, 1)]),
    ];

    expect(latestQuizAccuracyPercentage(quizzes), 30);
    expect(latestQuizAccuracyPercentage([]), isNull);
  });

  test('Focus uses the first attempt for each quiz', () {
    final now = DateTime.utc(2026, 10, 16);
    QuizScore score(int points, int total, int daysAgo) => QuizScore(
      score: points,
      totalQuestions: total,
      createdAt: now.subtract(Duration(days: daysAgo)),
    );
    QuizActivity quiz(String id, List<QuizScore> attempts) => QuizActivity(
      id: id,
      title: id,
      sourceFile: '$id.pdf',
      createdAt: now,
      questions: const [],
      attempts: attempts,
    );

    final quizzes = [
      quiz('first', [score(8, 10, 0), score(0, 10, 1)]),
      quiz('second', [score(1, 20, 1), score(1, 20, 2)]),
    ];

    expect(
      firstQuizAttemptFocusPercentage(quizzes),
      closeTo(1 / 30 * 100, 0.001),
    );
    expect(firstQuizAttemptFocusPercentage([]), isNull);
  });

  test(
    'quiz consistency measures active days in the rolling 28-day window',
    () {
      final today = DateTime(2026, 10, 16);
      QuizActivity quiz(List<int> daysAgo) => QuizActivity(
        id: 'activity',
        title: 'activity',
        sourceFile: 'activity.pdf',
        createdAt: today,
        questions: const [],
        attempts: [
          for (final days in daysAgo)
            QuizScore(
              score: 1,
              totalQuestions: 10,
              createdAt: today.subtract(Duration(days: days)),
            ),
        ],
      );

      expect(
        quizLearningConsistencyPercentage(
          quizzes: [
            quiz([0, 2, 28, -1]),
          ],
          accountCreatedAt: DateTime(2026, 1, 1),
          now: today,
        ),
        closeTo(2 / 28 * 100, 0.001),
      );
    },
  );

  test('quiz consistency uses days since creation for a newer account', () {
    final today = DateTime(2026, 10, 16);
    final quiz = QuizActivity(
      id: 'activity',
      title: 'activity',
      sourceFile: 'activity.pdf',
      createdAt: today,
      questions: const [],
      attempts: [
        QuizScore(score: 1, totalQuestions: 10, createdAt: today),
        QuizScore(
          score: 1,
          totalQuestions: 10,
          createdAt: today.subtract(const Duration(days: 2)),
        ),
      ],
    );

    expect(
      quizLearningConsistencyPercentage(
        quizzes: [quiz],
        accountCreatedAt: today.subtract(const Duration(days: 5)),
        now: today,
      ),
      closeTo(2 / 6 * 100, 0.001),
    );
    expect(
      quizLearningConsistencyPercentage(
        quizzes: [quiz],
        accountCreatedAt: null,
        now: today,
      ),
      isNull,
    );
  });

  test('quiz improvement averages chronological changes for each quiz', () {
    final now = DateTime.utc(2026, 10, 16);
    QuizScore score(int points, int daysAgo) => QuizScore(
      score: points,
      totalQuestions: 10,
      createdAt: now.subtract(Duration(days: daysAgo)),
    );
    QuizActivity quiz(String id, List<QuizScore> attempts) => QuizActivity(
      id: id,
      title: id,
      sourceFile: '$id.pdf',
      createdAt: now,
      questions: const [],
      attempts: attempts,
    );

    final quizzes = [
      quiz('first', [score(5, 0), score(8, 1), score(4, 2)]),
      quiz('second', [score(4, 1), score(6, 2)]),
      quiz('one-attempt', [score(10, 1)]),
    ];

    expect(quizzes.first.improvementPercentage, 5);
    expect(averageQuizImprovementPercentage(quizzes), -7.5);
    expect(averageQuizImprovementPercentage([quizzes.last]), isNull);
  });

  test('ClassroomActivity parses its schedule and availability', () {
    final now = DateTime.now().toUtc();
    final activity = ClassroomActivity.fromJson({
      'id': 'activity-id',
      'classroom_id': 'classroom-id',
      'classroom_name': 'Biology',
      'quiz_id': 'quiz-id',
      'title': 'Cell Structure',
      'source_file': 'biology.pdf',
      'questions': [
        {
          'question': 'Which organelle stores DNA?',
          'options': ['Nucleus', 'Ribosome', 'Cell wall', 'Vacuole'],
          'answerIndex': 0,
          'explanation': 'The nucleus contains the cell DNA.',
        },
      ],
      'starts_at': now.subtract(const Duration(days: 1)).toIso8601String(),
      'deadline_at': now.add(const Duration(days: 1)).toIso8601String(),
      'max_attempts': 2,
      'attempt_count': 0,
      'attempts': [],
    });

    expect(activity.classroomName, 'Biology');
    expect(activity.questions, hasLength(1));
    expect(activity.isAvailable, isTrue);
    expect(activity.status, 'Open');
    expect(activity.maxAttempts, 2);
    expect(activity.attemptCount, 0);
  });

  test(
    'ClassroomActivity reports completion when the attempt limit is used',
    () {
      final now = DateTime.now().toUtc();
      final activity = ClassroomActivity.fromJson({
        'id': 'activity-id',
        'classroom_id': 'classroom-id',
        'classroom_name': 'Biology',
        'quiz_id': 'quiz-id',
        'title': 'Cell Structure',
        'source_file': 'biology.pdf',
        'questions': [
          {
            'question': 'Which organelle stores DNA?',
            'options': ['Nucleus', 'Ribosome', 'Cell wall', 'Vacuole'],
            'answerIndex': 0,
            'explanation': 'The nucleus contains the cell DNA.',
          },
        ],
        'starts_at': now.subtract(const Duration(days: 1)).toIso8601String(),
        'deadline_at': now.add(const Duration(days: 1)).toIso8601String(),
        'max_attempts': 2,
        'attempt_count': 2,
        'attempts': [
          {
            'score': 1,
            'total_questions': 1,
            'created_at': now.toIso8601String(),
            'classroom_name': 'Biology',
          },
        ],
      });

      expect(activity.status, 'Completed');
      expect(activity.isAvailable, isFalse);
      expect(activity.attempts.single.classroomName, 'Biology');
    },
  );

  test('shuffles questions while keeping question data intact', () {
    final questions = [
      for (var index = 0; index < 5; index++)
        QuizQuestion(
          question: 'Question $index',
          options: ['A', 'B', 'C', 'D'],
          answerIndex: index % 4,
          explanation: 'Explanation $index',
        ),
    ];

    final shuffled = shuffledQuizQuestions(questions, random: Random(1));

    expect(shuffled, hasLength(questions.length));
    expect(
      shuffled.map((question) => question.question).toSet(),
      questions.map((question) => question.question).toSet(),
    );
    expect(
      shuffled.map((question) => question.question).toList(),
      isNot(equals(questions.map((question) => question.question).toList())),
    );
    for (final question in shuffled) {
      final original = questions.firstWhere(
        (item) => item.question == question.question,
      );
      expect(question.answerIndex, original.answerIndex);
      expect(question.explanation, original.explanation);
    }
  });

  test('randomizes correct answer positions evenly and preserves answers', () {
    final questions = [
      for (var index = 0; index < 12; index++)
        QuizQuestion(
          question: 'Question $index',
          options: ['Wrong 1', 'Correct $index', 'Wrong 2', 'Wrong 3'],
          answerIndex: 1,
          explanation: 'Explanation $index',
        ),
      const QuizQuestion(
        question: 'True or false',
        options: ['True', 'False'],
        answerIndex: 1,
        explanation: 'True/false explanation',
      ),
    ];

    final randomized = randomizedQuizAnswers(questions, random: Random(1));
    final correctPositions = randomized
        .take(12)
        .map((question) => question.answerIndex)
        .toList();
    final positionCounts = List<int>.generate(
      4,
      (position) => correctPositions.where((item) => item == position).length,
    );

    expect(positionCounts, everyElement(3));
    for (var index = 0; index < 12; index++) {
      final question = randomized[index];
      expect(question.options[question.answerIndex], 'Correct $index');
      expect(question.options.toSet(), questions[index].options.toSet());
      if (index > 0) {
        expect(question.answerIndex, isNot(correctPositions[index - 1]));
      }
    }
    expect(randomized.last.options, ['True', 'False']);
    expect(randomized.last.answerIndex, 1);
  });

  test('randomizes mixed questions without changing true-or-false answers', () {
    final questions = [
      const QuizQuestion(
        question: 'The Earth orbits the Sun.',
        options: ['True', 'False'],
        answerIndex: 0,
        explanation: 'The Earth orbits the Sun.',
      ),
      const QuizQuestion(
        question: 'Which planet is known as the Red Planet?',
        options: ['Venus', 'Mars', 'Jupiter', 'Mercury'],
        answerIndex: 1,
        explanation: 'Mars appears red due to iron oxide.',
      ),
      const QuizQuestion(
        question: 'The Sun is a star.',
        options: ['True', 'False'],
        answerIndex: 0,
        explanation: 'The Sun is a star.',
      ),
      const QuizQuestion(
        question: 'Which is closest to the Sun?',
        options: ['Earth', 'Venus', 'Mercury', 'Mars'],
        answerIndex: 2,
        explanation: 'Mercury is closest to the Sun.',
      ),
    ];

    final randomized = randomizedQuizAnswers(questions, random: Random(1));

    expect(randomized, hasLength(questions.length));
    expect(randomized[0].options, ['True', 'False']);
    expect(randomized[0].answerIndex, 0);
    expect(randomized[2].options, ['True', 'False']);
    expect(randomized[2].answerIndex, 0);
    expect(randomized[1].options[randomized[1].answerIndex], 'Mars');
    expect(randomized[3].options[randomized[3].answerIndex], 'Mercury');
  });
}

SupabaseClient _supabaseClient(
  Future<http.Response> Function(http.Request request) handler,
) => SupabaseClient(
  'https://example.supabase.co',
  'test-anon-key',
  httpClient: MockClient(handler),
);

class _TestAuthService extends AuthService {
  _TestAuthService(SupabaseClient client) : super(client: client);

  @override
  Future<String?> getSessionToken() async => 's' * 40;
}
