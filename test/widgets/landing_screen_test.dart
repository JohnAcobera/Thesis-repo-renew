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

      expect(find.text('QuizForge'), findsNWidgets(2));
      expect(find.byIcon(Icons.auto_stories_rounded), findsNWidgets(2));
      expect(find.text('Study plan'), findsNothing);
      expect(find.text('Review your notes'), findsNothing);
      expect(find.text('Why QuizForge?'), findsOneWidget);
      expect(find.text('EduSmart'), findsNothing);
      expect(find.text('Study tools'), findsNothing);
      expect(find.text('Create'), findsNothing);
      expect(find.text("I'm a teacher"), findsNothing);
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets('register back arrow returns to the landing page', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(1200, 1000);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(
      MaterialApp(home: LandingScreen(sessionRestorer: () async => null)),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.text('Get started'));
    await tester.pumpAndSettle();

    expect(find.text('Create account'), findsOneWidget);
    await tester.tap(find.byTooltip('Back to landing page'));
    await tester.pumpAndSettle();

    expect(find.text('How do you want to study?'), findsOneWidget);
    expect(find.text('Get started'), findsOneWidget);
    expect(find.text('Create account'), findsNothing);
    expect(tester.takeException(), isNull);
  });

  testWidgets('landing page explains study features in plain language', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(1200, 1600);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(
      MaterialApp(home: LandingScreen(sessionRestorer: () async => null)),
    );
    await tester.pumpAndSettle();

    expect(find.text('Practice Questions'), findsOneWidget);
    expect(find.text('Printable Study Guides'), findsOneWidget);
    expect(find.text('Study Anywhere'), findsOneWidget);
    expect(find.text('Track Your Progress'), findsOneWidget);
    expect(find.text('AI Quiz Generation'), findsNothing);
    expect(find.text('Export to PDF'), findsNothing);
    expect(tester.takeException(), isNull);
  });

  testWidgets('landing page adapts without overflow across viewport sizes', (
    tester,
  ) async {
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    tester.view.devicePixelRatio = 1;

    for (final width in [320.0, 390.0, 768.0, 1200.0]) {
      tester.view.physicalSize = Size(width, 900);
      await tester.pumpWidget(
        MaterialApp(home: LandingScreen(sessionRestorer: () async => null)),
      );
      await tester.pumpAndSettle();

      expect(find.text('How do you want to study?'), findsOneWidget);
      expect(find.text('Why QuizForge?'), findsOneWidget);
      expect(tester.takeException(), isNull, reason: 'Viewport width: $width');
    }
  });

  testWidgets(
    'portrait landing header keeps the login action beside branding',
    (tester) async {
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      tester.view.devicePixelRatio = 1;
      for (final width in [390.0, 320.0, 272.0]) {
        tester.view.physicalSize = Size(width, 844);
        await tester.pumpWidget(
          MaterialApp(
            home: Scaffold(
              body: Align(
                alignment: Alignment.topCenter,
                child: SizedBox(
                  width: width,
                  child: LandingTopNav(onLogin: _noop),
                ),
              ),
            ),
          ),
        );
        await tester.pumpAndSettle();

        final brandCenter = tester.getCenter(
          find.byIcon(Icons.auto_stories_rounded),
        );
        final loginCenter = tester.getCenter(find.text('Log in'));
        expect((brandCenter.dy - loginCenter.dy).abs(), lessThan(1));
        expect(tester.takeException(), isNull);
      }
    },
  );
}

void _noop() {}
