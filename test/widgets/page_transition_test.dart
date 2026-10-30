import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:thesis_repo_renew/main.dart';

void main() {
  testWidgets('all platforms use the same smooth screen transition', (
    tester,
  ) async {
    await tester.pumpWidget(const MainApp(isConfigured: false));

    final theme = Theme.of(tester.element(find.byType(Scaffold)));
    final builderTypes = TargetPlatform.values
        .map(
          (platform) =>
              theme.pageTransitionsTheme.builders[platform]!.runtimeType,
        )
        .toSet();

    expect(builderTypes, hasLength(1));
    for (final platform in TargetPlatform.values) {
      expect(
        theme.pageTransitionsTheme.builders[platform],
        isNot(isA<FadeUpwardsPageTransitionsBuilder>()),
      );
    }

    final navigator = tester.state<NavigatorState>(find.byType(Navigator));
    unawaited(
      navigator.push<void>(
        MaterialPageRoute<void>(
          builder: (_) => const Scaffold(body: Text('Next screen')),
        ),
      ),
    );
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 100));

    expect(find.byType(FadeTransition), findsWidgets);
    expect(find.byType(SlideTransition), findsWidgets);
    final routeFade = tester.widget<FadeTransition>(
      find
          .ancestor(
            of: find.text('Next screen'),
            matching: find.byType(FadeTransition),
          )
          .first,
    );
    expect(routeFade.opacity.value, greaterThan(0));
    expect(routeFade.opacity.value, lessThan(1));
  });
}
