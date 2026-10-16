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
            'score': 8,
            'total_questions': 10,
            'created_at': '2026-10-16T06:00:00Z',
          },
          {
            'score': 6,
            'total_questions': 10,
            'created_at': '2026-10-15T06:00:00Z',
          },
        ],
      });

      expect(activity.id, 'saved-quiz-id');
      expect(activity.questions, hasLength(1));
      expect(activity.attempts, hasLength(2));
      expect(activity.latestScore, 8);
      expect(activity.attempts.last.score, 6);
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
}
