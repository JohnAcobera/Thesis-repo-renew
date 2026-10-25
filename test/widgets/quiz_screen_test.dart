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
