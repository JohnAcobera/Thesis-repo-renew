import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:thesis_repo_renew/models/classroom_model.dart';
import 'package:thesis_repo_renew/models/user_model.dart';
import 'package:thesis_repo_renew/services/classroom_service.dart';
import 'package:thesis_repo_renew/services/quiz_service.dart';
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
            classroomService: _FakeClassroomRepository(),
            user: UserModel(
              id: 1,
              fullName: 'Instructor Name',
              email: 'instructor@example.com',
              role: 'instructor',
              createdAt: DateTime(2023, 9, 5),
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

      expect(find.text('3'), findsOneWidget);
      expect(find.text('2'), findsOneWidget);
      expect(find.text('—'), findsNWidgets(2));
      expect(tester.takeException(), isNull);
      await tester.tap(find.text('Create activity'));
      await tester.pumpAndSettle();
      expect(
        find.text('Upload your notes and generate a practice quiz'),
        findsOneWidget,
      );
      await tester.tap(find.byTooltip('Open menu'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Dashboard'));
      await tester.pumpAndSettle();
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

      await tester.tap(find.byTooltip('Close menu'));
      await tester.pumpAndSettle();
      await tester.tap(find.byTooltip('Open menu'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('My Classroom'));
      await tester.pumpAndSettle();
      expect(find.text('Your classrooms'), findsOneWidget);
      expect(find.text('Grade 11 - STEM A'), findsOneWidget);
      expect(find.text('General Biology 1'), findsOneWidget);
      await tester.tap(find.text('Grade 11 - STEM A'));
      await tester.pumpAndSettle();
      expect(find.text('0 students'), findsOneWidget);
      expect(find.text('Join code: ABCD2345'), findsOneWidget);
      expect(
        find.descendant(
          of: find.byType(AppBar),
          matching: find.text('My Classroom'),
        ),
        findsOneWidget,
      );
      expect(find.byTooltip('Open menu'), findsOneWidget);
      await tester.tap(find.byTooltip('Open menu'));
      await tester.pumpAndSettle();
      expect(find.text('Instructor Name'), findsOneWidget);
      await tester.tap(find.byTooltip('Close menu'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Your classrooms'));
      await tester.pumpAndSettle();
      expect(find.text('Your classrooms'), findsOneWidget);

      await tester.tap(find.byTooltip('Open profile menu'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Profile'));
      await tester.pumpAndSettle();
      expect(find.text('Instructor'), findsWidgets);
      expect(find.text('September 5, 2023'), findsOneWidget);

      await tester.tap(find.byTooltip('Open menu'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('My Classroom'));
      await tester.pumpAndSettle();
      expect(find.text('Your classrooms'), findsOneWidget);
      expect(tester.takeException(), isNull);
    }
  });
}

class _FakeClassroomRepository implements ClassroomRepository {
  @override
  Future<List<ClassroomActivity>> classroomActivities(
    String classroomId,
  ) async => [];

  @override
  Future<InstructorDashboardStats> getInstructorDashboardStats() async =>
      const InstructorDashboardStats(studentCount: 3, activeClassCount: 2);

  @override
  Future<ClassroomModel> joinClassroom({required String code}) async =>
      throw UnimplementedError();

  @override
  Future<ClassroomModel> createClassroom({
    required String name,
    required String subject,
    required String iconKey,
  }) async => ClassroomModel(
    id: 'test-id',
    name: name,
    subject: subject,
    code: 'ABCD2345',
    createdAt: DateTime.utc(2026),
    iconKey: iconKey,
  );

  @override
  Future<List<ClassroomModel>> listClassrooms() async => [
    ClassroomModel(
      id: 'test-id',
      name: 'Grade 11 - STEM A',
      subject: 'General Biology 1',
      code: 'ABCD2345',
      createdAt: DateTime.utc(2026),
      iconKey: 'book',
    ),
  ];

  @override
  Future<List<ClassroomModel>> listStudentClassrooms() async => [];
}
