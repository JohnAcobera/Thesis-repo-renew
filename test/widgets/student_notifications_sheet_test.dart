import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:thesis_repo_renew/models/classroom_model.dart';
import 'package:thesis_repo_renew/models/user_model.dart';
import 'package:thesis_repo_renew/screens/home/student_home_screen.dart';
import 'package:thesis_repo_renew/services/classroom_service.dart';
import 'package:thesis_repo_renew/services/quiz_service.dart';
import 'package:thesis_repo_renew/services/student_notification_service.dart';

void main() {
  testWidgets('notifications mark individually and open their classroom', (
    tester,
  ) async {
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    tester.view.physicalSize = const Size(400, 800);
    tester.view.devicePixelRatio = 1;
    final notifications = _FakeStudentNotificationRepository();
    final classrooms = _FakeClassroomRepository();

    await tester.pumpWidget(
      MaterialApp(
        home: StudentHomeScreen(
          user: const UserModel(
            id: 1,
            fullName: 'Student Name',
            email: 'student@example.com',
            role: 'student',
          ),
          classroomService: classrooms,
          notificationRepository: notifications,
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.byTooltip('Notifications'), findsOneWidget);

    await tester.tap(find.byTooltip('Notifications'));
    await tester.pumpAndSettle();

    expect(find.text('Notifications'), findsOneWidget);
    expect(find.text('Quiz LP earned'), findsOneWidget);
    expect(
      find.text('Cell Structure: 280 LP total (50 LP first attempt).'),
      findsOneWidget,
    );

    await tester.tap(find.text('Last week’s leaderboard'));
    await tester.pumpAndSettle();
    expect(notifications.markedIds, isEmpty);
    expect(find.text('Notifications'), findsOneWidget);

    await tester.tap(find.text('Quiz LP earned'));
    await tester.pumpAndSettle();
    expect(notifications.markedIds, ['quiz-points:attempt-1']);
    expect(find.text('Mark all as read'), findsNothing);
    expect(find.byTooltip('Notifications'), findsOneWidget);

    await tester.tap(find.text('New classroom activity'));
    await tester.pumpAndSettle();

    expect(notifications.markedIds, ['quiz-points:attempt-1']);
    expect(classrooms.studentClassroomsRequested, isTrue);
    expect(find.text('Biology'), findsOneWidget);
    expect(find.text('Your classrooms'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
}

class _FakeStudentNotificationRepository
    implements StudentNotificationRepository {
  final List<String> markedIds = [];
  final Set<String> _readIds = {};

  @override
  Future<List<StudentNotification>> listNotifications() async => [
    StudentNotification(
      id: 'quiz-points:attempt-1',
      type: StudentNotificationType.quizPoints,
      title: 'Quiz LP earned',
      message: 'Cell Structure: 280 LP total (50 LP first attempt).',
      createdAt: DateTime(2026, 10, 18),
      isRead: _readIds.contains('quiz-points:attempt-1'),
    ),
    StudentNotification(
      id: 'classroom-activity:activity-1',
      type: StudentNotificationType.classroomActivity,
      title: 'New classroom activity',
      message: 'Biology: Cell Review was posted.',
      createdAt: DateTime(2026, 10, 17),
      isRead: true,
      classroomId: 'classroom-id',
    ),
    StudentNotification(
      id: 'weekly-rank:2026-10-12',
      type: StudentNotificationType.weeklyRank,
      title: 'Last week’s leaderboard',
      message: 'You finished #2 with 200 LP.',
      createdAt: DateTime(2026, 10, 12),
      isRead: true,
    ),
  ];

  @override
  Future<void> markNotificationsRead(List<String> notificationIds) async {
    markedIds.addAll(notificationIds);
    _readIds.addAll(notificationIds);
  }
}

class _FakeClassroomRepository implements ClassroomRepository {
  final classroom = ClassroomModel(
    id: 'classroom-id',
    name: 'Biology',
    subject: 'General Biology',
    code: 'BIOLOGY1',
    createdAt: DateTime.utc(2026),
  );
  bool studentClassroomsRequested = false;

  @override
  Future<List<ClassroomStudentSummary>> classroomStudents(
    String classroomId,
  ) async => [];

  @override
  Future<void> removeClassroomStudent({
    required String classroomId,
    required int studentId,
  }) async {}

  @override
  Future<List<ClassroomModel>> listStudentClassrooms() async {
    studentClassroomsRequested = true;
    return [classroom];
  }

  @override
  Future<List<ClassroomActivity>> classroomActivities(
    String classroomId,
  ) async => [];

  @override
  Future<InstructorDashboardStats> getInstructorDashboardStats() async =>
      const InstructorDashboardStats(studentCount: 0, activeClassCount: 0);

  @override
  Future<List<ClassroomModel>> listClassrooms() async => [classroom];

  @override
  Future<ClassroomModel> joinClassroom({required String code}) async =>
      classroom;

  @override
  Future<ClassroomModel> createClassroom({
    required String name,
    required String subject,
    required String iconKey,
  }) async => classroom;

  @override
  Future<void> deleteClassroom(String classroomId) async {}

  @override
  Future<void> deleteClassroomActivity({
    required String classroomId,
    required String activityId,
  }) async {}
}
