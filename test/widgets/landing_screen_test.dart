import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:thesis_repo_renew/screens/landing/landing_screen.dart';

void main() {
  testWidgets(
    'landing page uses QuizForge branding without removed nav items',
    (tester) async {
      tester.view.physicalSize = const Size(1200, 1000);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      await tester.pumpWidget(
        MaterialApp(home: LandingScreen(sessionRestorer: () async => null)),
      );
      await tester.pumpAndSettle();

      expect(find.text('QuizForge'), findsOneWidget);
      expect(find.text('Why QuizForge?'), findsOneWidget);
      expect(find.text('EduSmart'), findsNothing);
      expect(find.text('Study tools'), findsNothing);
      expect(find.text('Create'), findsNothing);
      expect(tester.takeException(), isNull);
    },
  );
}
