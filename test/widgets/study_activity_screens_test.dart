import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:thesis_repo_renew/screens/study_activity_screens.dart';
import 'package:thesis_repo_renew/services/auth_service.dart';
import 'package:thesis_repo_renew/services/learning_mode_service.dart';

void main() {
  testWidgets('matching targets do not reveal whether an answer is correct', (
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
        home: MatchingScreen(
          activityId: 'activity-id',
          username: 'Student',
          email: 'student@example.com',
          title: 'Cell biology',
          sourceFile: 'biology.txt',
          pairs: const [
            MatchingPair(
              left: 'Prompt 0',
              right: 'Answer 0',
              explanation: 'Explanation 0',
            ),
            MatchingPair(
              left: 'Prompt 1',
              right: 'Answer 1',
              explanation: 'Explanation 1',
            ),
          ],
          learningModeService: _TestLearningModeService(client),
        ),
      ),
    );

    BoxDecoration targetDecoration(int index) =>
        tester
                .widget<AnimatedContainer>(
                  find.byKey(ValueKey('matching-answer-target-$index')),
                )
                .decoration!
            as BoxDecoration;

    expect(targetDecoration(0).color, Colors.white);

    await tester.tap(find.text('Answer 1'));
    await tester.pumpAndSettle();
    final prompt = find.byKey(const ValueKey('matching-answer-target-0'));
    await tester.ensureVisible(prompt);
    await tester.tap(prompt);
    await tester.pumpAndSettle();

    expect(targetDecoration(0).color, Colors.white);
    expect(targetDecoration(0).border!.top.color, const Color(0xFFE8D7C2));
    expect(find.text('That match may need another look.'), findsNothing);

    await tester.tap(find.text('Answer 1').last);
    await tester.pumpAndSettle();
    await tester.ensureVisible(find.text('Answer 0'));
    await tester.tap(find.text('Answer 0'));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('matching-answer-target-0')));
    await tester.pumpAndSettle();

    expect(targetDecoration(0).color, Colors.white);
    expect(targetDecoration(0).border!.top.color, const Color(0xFFE8D7C2));
    expect(find.text('That match may need another look.'), findsNothing);
    expect(tester.takeException(), isNull);
  });

  testWidgets('matching results review wrong answers and show corrections', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(1000, 1000);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    final client = SupabaseClient(
      'https://example.supabase.co',
      'test-key',
      authOptions: const AuthClientOptions(autoRefreshToken: false),
    );
    await tester.pumpWidget(
      MaterialApp(
        home: MatchingScreen(
          activityId: 'activity-id',
          username: 'Student',
          email: 'student@example.com',
          title: 'Cell biology',
          sourceFile: 'biology.txt',
          pairs: const [
            MatchingPair(
              left: 'Prompt 0',
              right: 'Answer 0',
              explanation: 'The first pair belongs together.',
            ),
            MatchingPair(
              left: 'Prompt 1',
              right: 'Answer 1',
              explanation: 'The second pair belongs together.',
            ),
          ],
          learningModeService: _TestLearningModeService(client),
        ),
      ),
    );

    await tester.tap(find.text('Answer 1'));
    await tester.pumpAndSettle();
    final firstTarget = find.byKey(const ValueKey('matching-answer-target-0'));
    await tester.ensureVisible(firstTarget);
    await tester.tap(firstTarget);
    await tester.pumpAndSettle();

    await tester.tap(find.text('Answer 0'));
    await tester.pumpAndSettle();
    final secondTarget = find.byKey(const ValueKey('matching-answer-target-1'));
    await tester.ensureVisible(secondTarget);
    await tester.tap(secondTarget);
    await tester.pumpAndSettle();
    await tester.tap(find.text('Finish matching'));
    await tester.pumpAndSettle();

    expect(find.text('Matching complete'), findsNWidgets(2));
    expect(find.text('0 / 2'), findsOneWidget);
    expect(find.text('Review your matches'), findsOneWidget);
    expect(find.text('Your answer: Answer 1'), findsOneWidget);
    expect(find.text('Correct answer: Answer 0'), findsOneWidget);
    expect(find.text('The first pair belongs together.'), findsOneWidget);
    expect(find.text('Your answer: Answer 0'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('matching answer review scrolls through 11 pairs', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(1000, 1000);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    final pairs = List<MatchingPair>.generate(
      11,
      (index) => MatchingPair(
        left: 'Prompt $index',
        right: 'Answer $index',
        explanation: 'Explanation $index',
      ),
    );
    final client = SupabaseClient(
      'https://example.supabase.co',
      'test-key',
      authOptions: const AuthClientOptions(autoRefreshToken: false),
    );
    await tester.pumpWidget(
      MaterialApp(
        home: MatchingScreen(
          activityId: 'activity-id',
          username: 'Student',
          email: 'student@example.com',
          title: 'Cell biology',
          sourceFile: 'biology.txt',
          pairs: pairs,
          learningModeService: _TestLearningModeService(client),
        ),
      ),
    );

    for (var index = 0; index < pairs.length; index++) {
      await tester.tap(find.text('Answer $index'));
      await tester.pump();
      final prompt = find.text('Tap to place selected answer').first;
      await tester.ensureVisible(prompt);
      await tester.tap(prompt);
      await tester.pump();
      if (index == 9) {
        await tester.tap(find.text('Next set'));
        await tester.pump();
      }
    }
    await tester.tap(find.text('Finish matching'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 100));
    await tester.pumpAndSettle();

    final reviewScroll = find.descendant(
      of: find.byKey(const ValueKey('matching-result-review-scroll')),
      matching: find.byType(Scrollable),
    );
    await tester.scrollUntilVisible(
      find.text('Pair 11: Prompt 10'),
      250,
      scrollable: reviewScroll,
    );
    expect(find.text('Your answer: Answer 10'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('flashcard flips smoothly to its answer and explanation', (
    tester,
  ) async {
    await tester.pumpWidget(
      MaterialApp(
        home: FlashcardsScreen(
          activityId: 'activity-id',
          username: 'Student',
          email: 'student@example.com',
          title: 'Cell biology',
          sourceFile: 'biology.txt',
          cards: const [
            Flashcard(
              question: 'What is osmosis?',
              answer: 'Movement of water across a membrane.',
              explanation: 'Water moves toward a higher solute concentration.',
              hint:
                  'Think about water crossing a selectively permeable barrier.',
            ),
            Flashcard(
              question: 'What stores genetic information?',
              answer: 'The nucleus.',
              explanation: 'The nucleus contains DNA.',
            ),
          ],
        ),
      ),
    );

    expect(find.text('What is osmosis?'), findsOneWidget);
    expect(find.text('Need a hint?'), findsOneWidget);
    expect(find.textContaining('Think about water crossing'), findsNothing);
    await tester.tap(find.text('Need a hint?'));
    await tester.pumpAndSettle();
    expect(find.textContaining('Think about water crossing'), findsOneWidget);
    await tester.tap(find.text('What is osmosis?'));
    await tester.pump(const Duration(milliseconds: 230));
    await tester.pump(const Duration(milliseconds: 230));

    expect(find.text('Movement of water across a membrane.'), findsOneWidget);
    expect(
      find.textContaining('Water moves toward a higher solute concentration.'),
      findsOneWidget,
    );
    expect(find.text('Explanation'), findsOneWidget);
    expect(find.text('Review again'), findsOneWidget);
    expect(find.text('Got it'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('flashcards offer a separate, unscored review round', (
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
    final service = _TestLearningModeService(client);
    await tester.pumpWidget(
      MaterialApp(
        home: FlashcardsScreen(
          activityId: 'activity-id',
          username: 'Student',
          email: 'student@example.com',
          title: 'Cell biology',
          sourceFile: 'biology.txt',
          learningModeService: service,
          cards: const [
            Flashcard(
              question: 'What is osmosis?',
              answer: 'Movement of water across a membrane.',
              explanation:
                  'Water moves across a selectively permeable barrier.',
            ),
            Flashcard(
              question: 'What stores genetic information?',
              answer: 'The nucleus.',
              explanation: 'The nucleus contains DNA.',
            ),
          ],
        ),
      ),
    );

    await tester.tap(find.text('What is osmosis?'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Review again'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('What stores genetic information?'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Got it'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('What is osmosis?'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Got it'));
    await tester.pumpAndSettle();

    expect(find.text('Review 1 card marked for review'), findsOneWidget);
    expect(service.saveAttemptCalls, 1);
    await tester.tap(find.text('Review 1 card marked for review'));
    await tester.pumpAndSettle();
    expect(find.text('CARD REVIEW'), findsOneWidget);
    expect(find.text('What is osmosis?'), findsOneWidget);
    await tester.tap(find.text('What is osmosis?'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Got it'));
    await tester.pumpAndSettle();

    expect(find.text('Review complete'), findsOneWidget);
    expect(
      find.text('This review round was not added to your activity history.'),
      findsOneWidget,
    );
    expect(service.saveAttemptCalls, 1);
    await tester.tap(find.text('Back to activity summary'));
    await tester.pumpAndSettle();
    expect(find.text('All cards mastered'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('matching activities present at most ten pairs per set', (
    tester,
  ) async {
    final pairs = List<MatchingPair>.generate(
      11,
      (index) => MatchingPair(
        left: 'Prompt $index',
        right: 'Answer $index',
        explanation: 'Pair $index belongs together.',
      ),
    );
    await tester.pumpWidget(
      MaterialApp(
        home: MatchingScreen(
          activityId: 'activity-id',
          username: 'Student',
          email: 'student@example.com',
          title: 'Cell biology',
          sourceFile: 'biology.txt',
          pairs: pairs,
        ),
      ),
    );

    expect(find.text('Set 1 of 2'), findsOneWidget);
    expect(find.text('Answer bank'), findsOneWidget);
    expect(find.textContaining('Drag an answer onto a prompt'), findsOneWidget);
    expect(find.byType(Draggable<int>), findsNWidgets(10));
    expect(find.text('Prompt 0'), findsOneWidget);
    await tester.scrollUntilVisible(
      find.text('Prompt 9'),
      200,
      scrollable: find.byType(Scrollable).first,
    );
    expect(find.text('Prompt 9'), findsOneWidget);
    expect(find.text('Answer bank'), findsOneWidget);
    expect(tester.takeException(), isNull);

    expect(find.text('Next set'), findsOneWidget);
    expect(
      tester
          .widget<FilledButton>(find.widgetWithText(FilledButton, 'Next set'))
          .onPressed,
      isNull,
    );
    expect(tester.takeException(), isNull);
  });

  testWidgets('placed answers leave the bank and can be removed to return', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(1000, 1000);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    final pairs = List<MatchingPair>.generate(
      2,
      (index) => MatchingPair(
        left: 'Prompt $index',
        right: 'Answer $index',
        explanation: 'Pair $index belongs together.',
      ),
    );
    await tester.pumpWidget(
      MaterialApp(
        home: MatchingScreen(
          activityId: 'activity-id',
          username: 'Student',
          email: 'student@example.com',
          title: 'Cell biology',
          sourceFile: 'biology.txt',
          pairs: pairs,
        ),
      ),
    );

    await tester.tap(find.text('Answer 0'));
    await tester.pumpAndSettle();
    await tester.ensureVisible(find.text('Tap to place selected answer').first);
    await tester.tap(find.text('Tap to place selected answer').first);
    await tester.pumpAndSettle();

    expect(find.text('Answer 0'), findsOneWidget);
    expect(find.text('1 of 2 paired'), findsOneWidget);

    await tester.ensureVisible(find.text('Answer 0'));
    await tester.tap(find.text('Answer 0'));
    await tester.pumpAndSettle();
    expect(find.text('Answer 0'), findsOneWidget);
    expect(find.text('0 of 2 paired'), findsOneWidget);
    expect(find.text('Drop an answer here or tap to fill'), findsNWidgets(2));
    expect(tester.takeException(), isNull);
  });

  testWidgets('an occupied prompt must be cleared before another answer fits', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(1000, 1000);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    final pairs = List<MatchingPair>.generate(
      2,
      (index) => MatchingPair(
        left: 'Prompt $index',
        right: 'Answer $index',
        explanation: 'Pair $index belongs together.',
      ),
    );
    await tester.pumpWidget(
      MaterialApp(
        home: MatchingScreen(
          activityId: 'activity-id',
          username: 'Student',
          email: 'student@example.com',
          title: 'Cell biology',
          sourceFile: 'biology.txt',
          pairs: pairs,
        ),
      ),
    );

    await tester.tap(find.text('Answer 0'));
    await tester.pumpAndSettle();
    await tester.ensureVisible(find.text('Tap to place selected answer').first);
    await tester.tap(find.text('Tap to place selected answer').first);
    await tester.pumpAndSettle();

    await tester.tap(find.text('Answer 1'));
    await tester.pumpAndSettle();
    await tester.ensureVisible(find.text('Answer 0'));
    await tester.tap(find.text('Answer 0'));
    await tester.pumpAndSettle();

    expect(find.text('Answer 0'), findsOneWidget);
    expect(find.text('Answer 1'), findsOneWidget);
    expect(find.text('0 of 2 paired'), findsOneWidget);

    await tester.ensureVisible(find.text('Tap to place selected answer').first);
    await tester.tap(find.text('Tap to place selected answer').first);
    await tester.pumpAndSettle();
    expect(find.text('Answer 1'), findsOneWidget);
    expect(find.text('Answer 0'), findsOneWidget);
    expect(find.text('1 of 2 paired'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
}

class _TestLearningModeService extends LearningModeService {
  _TestLearningModeService(SupabaseClient client)
    : super(
        client: client,
        authService: AuthService(client: client),
      );

  int saveAttemptCalls = 0;

  @override
  Future<void> saveAttempt({
    required String itemId,
    required int score,
    required int totalItems,
  }) async {
    saveAttemptCalls++;
  }
}
