import 'package:material_ui/material_ui.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:thesis_repo_renew/models/achievement_badge.dart';
import 'package:thesis_repo_renew/widgets/achievement_unlocked_dialog.dart';

void main() {
  testWidgets('shows earned badges and a dashboard dismiss action', (
    tester,
  ) async {
    final badge = AchievementBadge.all.first;
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: Builder(
            builder: (context) => FilledButton(
              onPressed: () => showDialog<void>(
                context: context,
                builder: (_) => AchievementUnlockedDialog(badges: [badge]),
              ),
              child: const Text('Open'),
            ),
          ),
        ),
      ),
    );

    await tester.tap(find.text('Open'));
    await tester.pumpAndSettle();

    expect(find.text('Achievement unlocked!'), findsOneWidget);
    expect(find.text(badge.name), findsOneWidget);
    expect(find.text(badge.description), findsOneWidget);

    await tester.tap(find.text('Continue to dashboard'));
    await tester.pumpAndSettle();

    expect(find.text('Achievement unlocked!'), findsNothing);
  });
}
