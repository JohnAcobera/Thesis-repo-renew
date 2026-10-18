import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:thesis_repo_renew/screens/study_activity_screens.dart';
import 'package:thesis_repo_renew/services/learning_mode_service.dart';

void main() {
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
    expect(
      find.textContaining('Drag an answer onto its prompt'),
      findsOneWidget,
    );
    expect(find.byType(Draggable<int>), findsNWidgets(10));
    expect(find.text('Prompt 0'), findsOneWidget);
    expect(find.text('Next set'), findsOneWidget);
    expect(
      tester
          .widget<FilledButton>(find.widgetWithText(FilledButton, 'Next set'))
          .onPressed,
      isNull,
    );
    expect(tester.takeException(), isNull);
  });

  testWidgets('matching answers can be selected then placed in a prompt', (
    tester,
  ) async {
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
    await tester.tap(find.text('Tap to place selected answer').first);
    await tester.pumpAndSettle();

    expect(find.text('Answer 0'), findsNWidgets(2));
    expect(find.text('1 of 2 paired'), findsOneWidget);
    expect(
      tester
          .widget<FilledButton>(
            find.widgetWithText(FilledButton, 'Finish matching'),
          )
          .onPressed,
      isNull,
    );
    expect(tester.takeException(), isNull);
  });
}
