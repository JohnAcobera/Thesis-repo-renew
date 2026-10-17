import 'dart:math';

import 'package:flutter_test/flutter_test.dart';
import 'package:thesis_repo_renew/services/quiz_service.dart';

void main() {
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
}
