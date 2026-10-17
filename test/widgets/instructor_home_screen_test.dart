import 'package:flutter/gestures.dart';
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

    for (final size in [
      const Size(400, 800),
      const Size(1280, 900),
      const Size(1640, 900),
    ]) {
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
        'Class performance',
        'Recent quizzes',
        'Students needing attention',
      ]) {
        expect(find.text(heading), findsOneWidget);
      }

      for (final mockValue in ['128', '78%', 'Student A', 'Student B']) {
        expect(find.text(mockValue), findsNothing);
      }

      expect(find.text('3'), findsOneWidget);
      expect(find.text('2'), findsOneWidget);
      expect(find.text('4'), findsOneWidget);
      expect(find.text('Average score'), findsNothing);
      expect(find.text('Computer Networks'), findsOneWidget);
      expect(find.text('82%'), findsOneWidget);
      expect(find.text('Programming'), findsOneWidget);
      expect(find.text('75%'), findsOneWidget);
      expect(find.text('Database Systems'), findsOneWidget);
      expect(find.text('68%'), findsOneWidget);
      expect(find.text('32 students'), findsOneWidget);
      expect(find.text('4 activities posted'), findsOneWidget);
      expect(find.text('25 students'), findsOneWidget);
      expect(find.text('2 activities posted'), findsOneWidget);
      expect(find.text('—'), findsNothing);
      if (size.width >= 600) {
        final metricLabelTops = [
          'Total students',
          'Active classes',
          'Quizzes created',
        ].map((label) => tester.getTopLeft(find.text(label)).dy);
        expect(metricLabelTops.toSet(), hasLength(1));
      }
      if (size.width >= 1600) {
        final scrollbar = find.byType(Scrollbar);
        expect(scrollbar, findsOneWidget);
        await tester.sendEventToBinding(
          PointerScrollEvent(
            position: tester.getCenter(scrollbar),
            scrollDelta: const Offset(0, 120),
          ),
        );
        await tester.pumpAndSettle();
        expect(tester.takeException(), isNull);
      }
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
      final profileDetailsCount = size.width >= 600 ? 2 : 1;
      expect(find.text('Instructor Name'), findsNWidgets(profileDetailsCount));
      expect(
        find.text('instructor@example.com'),
        findsNWidgets(profileDetailsCount),
      );

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
      expect(find.text('Instructor Name'), findsNWidgets(profileDetailsCount));
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
      const InstructorDashboardStats(
        studentCount: 3,
        activeClassCount: 2,
        quizzesCreatedCount: 4,
        classroomPerformance: [
          ClassroomPerformance(
            name: 'Computer Networks',
            subject: 'Networking',
            studentCount: 32,
            activityCount: 4,
            averageScore: 82,
          ),
          ClassroomPerformance(
            name: 'Programming',
            subject: 'Computer Science',
            studentCount: 25,
            activityCount: 2,
            averageScore: 75,
          ),
          ClassroomPerformance(
            name: 'Database Systems',
            subject: 'Information Technology',
            studentCount: 28,
            activityCount: 3,
            averageScore: 68,
          ),
        ],
      );

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

  @override
  Future<void> deleteClassroom(String classroomId) async {}

  @override
  Future<void> deleteClassroomActivity({
    required String classroomId,
    required String activityId,
  }) async {}
}
