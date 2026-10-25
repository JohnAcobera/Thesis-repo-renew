import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:thesis_repo_renew/screens/quiz_screen.dart';
import 'package:thesis_repo_renew/services/auth_service.dart';
import 'package:thesis_repo_renew/services/quiz_service.dart';

void main() {
  testWidgets('quiz results review the selected and correct answers', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(1000, 1000);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    final client = SupabaseClient(
      'https://example.supabase.co',
      'test-key',
      authOptions: const AuthClientOptions(autoRefreshToken: false),
    );
    await tester.pumpWidget(
      MaterialApp(
        home: QuizScreen(
          username: 'Student',
          email: 'student@example.com',
          title: 'Science review',
          sourceFile: 'science.txt',
          questions: const [
            QuizQuestion(
              question: 'The Earth orbits the Sun.',
              options: ['True', 'False'],
              answerIndex: 0,
              explanation: 'Earth travels around the Sun.',
            ),
          ],
          quizService: _TestQuizService(client),
        ),
      ),
    );

    await tester.tap(find.text('False'));
    await tester.pump();
    await tester.tap(find.text('See your score'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 100));

    expect(find.text('Review your answers'), findsOneWidget);
    expect(find.text('The Earth orbits the Sun.'), findsOneWidget);
    expect(find.text('Your answer: False'), findsOneWidget);
    expect(find.text('Correct answer: True'), findsOneWidget);
    expect(find.text('Earth travels around the Sun.'), findsOneWidget);
  });

  testWidgets('quiz answer review scrolls through all 30 questions', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(1000, 800);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    final client = SupabaseClient(
      'https://example.supabase.co',
      'test-key',
      authOptions: const AuthClientOptions(autoRefreshToken: false),
    );
    final questions = List<QuizQuestion>.generate(
      30,
      (index) => QuizQuestion(
        question: 'Question prompt $index',
        options: ['Correct answer $index', 'Incorrect answer $index'],
        answerIndex: 0,
        explanation: 'Explanation $index',
      ),
    );
    await tester.pumpWidget(
      MaterialApp(
        home: QuizScreen(
          username: 'Student',
          email: 'student@example.com',
          title: 'Science review',
          sourceFile: 'science.txt',
          questions: questions,
          quizService: _TestQuizService(client),
        ),
      ),
    );

    for (var index = 0; index < questions.length; index++) {
      await tester.tap(find.text('Correct answer $index'));
      await tester.pump();
      final nextButton = find.text(
        index == questions.length - 1 ? 'See your score' : 'Next question',
      );
      await tester.ensureVisible(nextButton);
      await tester.tap(nextButton);
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 100));
    }
    await tester.pumpAndSettle();

    final reviewScroll = find.descendant(
      of: find.byKey(const ValueKey('quiz-result-review-scroll')),
      matching: find.byType(Scrollable),
    );
    await tester.scrollUntilVisible(
      find.text('Question 30'),
      250,
      scrollable: reviewScroll,
    );
    expect(find.text('Question prompt 29'), findsOneWidget);
    expect(find.text('Your answer: Correct answer 29'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
}

class _TestQuizService extends QuizService {
  _TestQuizService(SupabaseClient client)
    : super(
        client: client,
        authService: AuthService(client: client),
      );

  @override
  Future<String> saveAttempt({
    required String title,
    required String sourceFile,
    required int score,
    required int totalQuestions,
    required List<QuizQuestion> questions,
    String? quizId,
  }) async => 'saved-quiz-id';

  @override
  Future<int> learnerPointsForAttempt({
    required String quizId,
    String? classroomActivityId,
  }) async => 0;
}
