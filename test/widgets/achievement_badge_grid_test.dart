import 'package:material_ui/material_ui.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:thesis_repo_renew/models/achievement_badge.dart';
import 'package:thesis_repo_renew/widgets/achievement_badge_grid.dart';

void main() {
  testWidgets('shows only earned badges in consistent image frames', (
    tester,
  ) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: Scaffold(
          body: SingleChildScrollView(
            child: AchievementBadgeGrid(
              earnedBadges: {'FirstStep', 'QuizRookie'},
            ),
          ),
        ),
      ),
    );

    expect(find.text('2 badges earned'), findsOneWidget);
    expect(find.text('First Step'), findsOneWidget);
    expect(find.text('Quiz Rookie'), findsOneWidget);
    expect(find.text('First Perfect'), findsNothing);
    expect(find.text('Locked'), findsNothing);
    expect(find.byType(Image), findsNWidgets(2));
    for (final image in find.byType(Image).evaluate()) {
      expect(tester.getSize(find.byWidget(image.widget)), const Size(64, 64));
    }
  });

  testWidgets('shows a clean empty state without locked badges', (
    tester,
  ) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: Scaffold(
          body: SingleChildScrollView(
            child: AchievementBadgeGrid(earnedBadges: {}),
          ),
        ),
      ),
    );

    expect(find.text('0 badges earned'), findsOneWidget);
    expect(find.text('No badges earned yet'), findsOneWidget);
    expect(find.text('Locked'), findsNothing);
    expect(find.byType(Image), findsNothing);
  });

  testWidgets('scrolls the badge list after it reaches its height limit', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(420, 800);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: SingleChildScrollView(
            child: AchievementBadgeGrid(
              earnedBadges: AchievementBadge.all
                  .map((badge) => badge.id)
                  .toSet(),
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    final viewport = find.byKey(
      const ValueKey('achievement-badge-list-viewport'),
    );
    final list = find.byKey(const ValueKey('achievement-badge-list'));
    expect(tester.getSize(viewport).height, 420);
    expect(
      tester.getRect(find.text('Point Collector')).top,
      greaterThan(tester.getRect(viewport).bottom),
    );

    await tester.scrollUntilVisible(
      find.text('Point Collector'),
      300,
      scrollable: find
          .descendant(of: list, matching: find.byType(Scrollable))
          .first,
    );
    await tester.pumpAndSettle();

    expect(
      tester.getRect(find.text('Point Collector')).bottom,
      lessThan(tester.getRect(viewport).bottom),
    );
    expect(tester.takeException(), isNull);
  });
}
