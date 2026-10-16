import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:thesis_repo_renew/main.dart';

void main() {
  testWidgets('all platforms use the same smooth screen transition', (
    tester,
  ) async {
    await tester.pumpWidget(const MainApp(isConfigured: false));

    final theme = Theme.of(tester.element(find.byType(Scaffold)));
    for (final platform in TargetPlatform.values) {
      expect(
        theme.pageTransitionsTheme.builders[platform],
        isA<FadeUpwardsPageTransitionsBuilder>(),
      );
    }
  });
}
