import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:thesis_repo_renew/models/user_model.dart';
import 'package:thesis_repo_renew/screens/home/instructor_home_screen.dart';

void main() {
  testWidgets('instructor dashboard and reusable side menu render', (
    tester,
  ) async {
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    for (final size in [const Size(400, 800), const Size(1280, 900)]) {
      tester.view.physicalSize = size;
      tester.view.devicePixelRatio = 1;
      await tester.pumpWidget(
        MaterialApp(
          home: InstructorHomeScreen(
            key: ValueKey(size),
            user: const UserModel(
              id: 1,
              fullName: 'Instructor Name',
              email: 'instructor@example.com',
              role: 'instructor',
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      for (final heading in [
        'Total students',
        'Active classes',
        'Quizzes created',
        'Average score',
        'Class performance',
        'Recent quizzes',
        'Students needing attention',
      ]) {
        expect(find.text(heading), findsOneWidget);
      }

      for (final mockValue in [
        '128',
        '78%',
        'Computer Networks',
        'Network Security',
        'Database Normalization',
        'Programming Basics',
        'Student A',
        'Student B',
      ]) {
        expect(find.text(mockValue), findsNothing);
      }

      expect(tester.takeException(), isNull);
      await tester.tap(find.byTooltip('Open menu'));
      await tester.pumpAndSettle();

      for (final menuItem in [
        'Instructor Name',
        'instructor@example.com',
        'Instructor',
        'Dashboard',
        'My Classroom',
        'Learning Materials',
        'Reports',
        'About',
        'Settings',
        'Logout',
      ]) {
        expect(find.text(menuItem), findsOneWidget);
      }

      expect(tester.takeException(), isNull);
    }
  });
}
