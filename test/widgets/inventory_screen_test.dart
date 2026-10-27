import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:thesis_repo_renew/models/user_model.dart';
import 'package:thesis_repo_renew/screens/inventory_screen.dart';
import 'package:thesis_repo_renew/services/auth_service.dart';
import 'package:thesis_repo_renew/services/learning_mode_service.dart';
import 'package:thesis_repo_renew/services/quiz_service.dart';

void main() {
  testWidgets('archives items persistently without deleting quiz history', (
    tester,
  ) async {
    SharedPreferences.setMockInitialValues({});
    tester.view.physicalSize = const Size(1000, 900);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    final client = SupabaseClient(
      'https://example.supabase.co',
      'test-key',
      authOptions: const AuthClientOptions(autoRefreshToken: false),
    );
    final repository = _FakeQuizRepository([
      QuizActivity(
        id: 'quiz-id',
        title: 'Archived quiz',
        sourceFile: 'biology.pdf',
        createdAt: DateTime.now(),
        questions: const [
          QuizQuestion(
            question: 'Question',
            options: ['True', 'False'],
            answerIndex: 0,
            explanation: 'Explanation',
          ),
        ],
        attempts: [
          QuizScore(score: 1, totalQuestions: 1, createdAt: DateTime.now()),
        ],
      ),
    ]);
    final learningService = _FakeLearningModeService(client);

    Widget inventory() => MaterialApp(
      home: Scaffold(
        body: InventoryScreen(
          user: const UserModel(
            id: 42,
            fullName: 'Test Student',
            email: 'student@example.com',
            role: 'student',
          ),
          onMenuSelected: (_) {},
          quizRepository: repository,
          learningModeService: learningService,
        ),
      ),
    );

    await tester.pumpWidget(inventory());
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 100));
    expect(find.text('Archived quiz'), findsOneWidget);

    await tester.tap(find.byTooltip('Archive item'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));
    await tester.pump();
    expect(find.text('Item placed in the archive'), findsOneWidget);
    expect(find.text('Archived quiz'), findsNothing);
    final preferences = await SharedPreferences.getInstance();
    expect(preferences.getStringList('quizforge_inventory_archived_42'), [
      'quiz:quiz-id',
    ]);
    ScaffoldMessenger.of(
      tester.element(find.byType(InventoryScreen)),
    ).hideCurrentSnackBar();
    await tester.pump(const Duration(milliseconds: 300));

    await tester.tap(find.text('View archive (1)'));
    await tester.pump();
    expect(find.text('Archived quiz'), findsOneWidget);

    await tester.tap(find.byTooltip('Restore to inventory'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 100));
    expect(find.text('Archived quiz'), findsNothing);
    await tester.tap(find.text('View inventory'));
    await tester.pump();
    expect(find.text('Archived quiz'), findsOneWidget);

    unawaited(client.dispose());
  });
}

class _FakeQuizRepository implements QuizRepository {
  const _FakeQuizRepository(this.activities);

  final List<QuizActivity> activities;

  @override
  Future<List<QuizActivity>> recentAttempts() async => activities;
}

class _FakeLearningModeService extends LearningModeService {
  _FakeLearningModeService(SupabaseClient client)
    : super(
        client: client,
        authService: AuthService(client: client),
      );

  @override
  Future<List<LearningInventoryItem>> inventoryItems() async => const [];

  @override
  Future<Set<String>> inventoryFavorites() async => const {};

  @override
  Future<void> setInventoryFavorite({
    required String itemType,
    required String itemId,
    required bool isFavorite,
  }) async {}
}
