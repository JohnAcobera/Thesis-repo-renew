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

  testWidgets(
    'missed questions can be practiced without saving another score',
    (tester) async {
      tester.view.physicalSize = const Size(1000, 1000);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      final client = SupabaseClient(
        'https://example.supabase.co',
        'test-key',
        authOptions: const AuthClientOptions(autoRefreshToken: false),
      );
      final service = _TestQuizService(client);
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
            quizService: service,
          ),
        ),
      );

      await tester.tap(find.text('False'));
      await tester.pump();
      await tester.tap(find.text('See your score'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 100));
      expect(find.text('Practice 1 missed question'), findsOneWidget);
      expect(service.saveAttemptCalls, 1);
      expect(service.pointsCalls, 1);

      await tester.tap(find.text('Practice 1 missed question'));
      await tester.pumpAndSettle();
      expect(find.text('PRACTICE ROUND'), findsOneWidget);
      expect(find.text('The Earth orbits the Sun.'), findsOneWidget);
      await tester.tap(find.text('False'));
      await tester.pump();
      await tester.tap(find.text('See your score'));
      await tester.pumpAndSettle();
      expect(find.text('Practice 1 question again'), findsOneWidget);
      await tester.tap(find.text('Practice 1 question again'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('True'));
      await tester.pump();
      await tester.tap(find.text('See your score'));
      await tester.pumpAndSettle();

      expect(find.text('Practice complete!'), findsOneWidget);
      expect(
        find.text('This practice round was not saved as a quiz score.'),
        findsOneWidget,
      );
      expect(find.text('Learner points from this quiz'), findsNothing);
      expect(service.saveAttemptCalls, 1);
      expect(service.pointsCalls, 1);
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets('practice results can return directly to the dashboard', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(1000, 1000);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);

    await tester.pumpWidget(
      MaterialApp(
        home: Builder(
          builder: (context) => Scaffold(
            body: Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Text('Student dashboard'),
                  TextButton(
                    onPressed: () => Navigator.of(context).push<void>(
                      MaterialPageRoute<void>(
                        builder: (_) => QuizScreen(
                          username: 'Student',
                          email: 'student@example.com',
                          title: 'Science review',
                          sourceFile: 'science.txt',
                          isPracticeRound: true,
                          questions: const [
                            QuizQuestion(
                              question: 'The Earth orbits the Sun.',
                              options: ['True', 'False'],
                              answerIndex: 0,
                              explanation: 'Earth travels around the Sun.',
                            ),
                          ],
                        ),
                      ),
                    ),
                    child: const Text('Open practice'),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
    await tester.tap(find.text('Open practice'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('False'));
    await tester.pump();
    await tester.tap(find.text('See your score'));
    await tester.pumpAndSettle();

    expect(find.text('Return to quiz results'), findsOneWidget);
    final dashboardButton = find.text('Return to dashboard');
    await tester.ensureVisible(dashboardButton);
    await tester.tap(dashboardButton);
    await tester.pumpAndSettle();

    expect(find.text('Student dashboard'), findsOneWidget);
    expect(find.text('Practice complete!'), findsNothing);
    expect(tester.takeException(), isNull);
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

  int saveAttemptCalls = 0;
  int pointsCalls = 0;

  @override
  Future<String> saveAttempt({
    required String title,
    required String sourceFile,
    required int score,
    required int totalQuestions,
    required List<QuizQuestion> questions,
    String? quizId,
  }) async {
    saveAttemptCalls++;
    return 'saved-quiz-id';
  }

  @override
  Future<int> learnerPointsForAttempt({
    required String quizId,
    String? classroomActivityId,
  }) async {
    pointsCalls++;
    return 0;
  }
}
