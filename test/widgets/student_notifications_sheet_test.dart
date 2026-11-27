import 'dart:async';

import 'package:material_ui/material_ui.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:thesis_repo_renew/models/instructor_todo_task.dart';
import 'package:thesis_repo_renew/screens/profile_screen.dart';
import 'package:thesis_repo_renew/services/achievement_service.dart';
import 'package:thesis_repo_renew/services/auth_service.dart';
import 'package:thesis_repo_renew/services/student_notification_service.dart';
import 'package:thesis_repo_renew/services/instructor_todo_service.dart';
import 'package:thesis_repo_renew/widgets/student_notifications_sheet.dart';

void main() {
  test(
    'legacy classroom notifications are parsed without activity actions',
    () {
      final notification = StudentNotification.fromJson({
        'id': 'legacy-notification',
        'type': 'classroomActivity',
        'title': 'New classroom activity',
        'message': 'A legacy notification.',
        'created_at': DateTime(2026, 10, 17).toIso8601String(),
        'is_read': true,
        'classroom_id': 'classroom-id',
      });

      expect(notification.type, StudentNotificationType.legacy);
    },
  );

  test('teacher feedback notification type is recognized', () {
    final notification = StudentNotification.fromJson({
      'id': 'teacher-feedback:feedback-1',
      'type': 'teacherFeedback',
      'title': 'A message from your teacher',
      'message': 'From john instructor: You have got this!',
      'created_at': DateTime(2026, 10, 17).toIso8601String(),
      'is_read': false,
    });

    expect(notification.type, StudentNotificationType.teacherFeedback);
    expect(notification.senderName, 'john instructor');
    expect(notification.message, 'You have got this!');
  });

  testWidgets('teacher-message bubble stays visible until feedback is read', (
    tester,
  ) async {
    final notifications = _FakeStudentNotificationRepository();

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          appBar: AppBar(
            actions: [StudentNotificationsButton(repository: notifications)],
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.byTooltip('Notifications'), findsOneWidget);
    await notifications.addNotification(
      StudentNotification(
        id: 'teacher-feedback:feedback-1',
        type: StudentNotificationType.teacherFeedback,
        title: 'A message from your teacher',
        message: 'You have got this!',
        createdAt: DateTime(2026, 10, 19),
        isRead: false,
        senderName: 'john instructor',
      ),
    );
    await tester.pumpAndSettle();

    const teacherMessageCallout = 'New teacher message';
    final speechBubble = find.byKey(
      const ValueKey('teacher-feedback-speech-bubble'),
    );
    expect(speechBubble, findsOneWidget);
    expect(find.text(teacherMessageCallout), findsOneWidget);
    final bubbleRect = tester.getRect(speechBubble);
    final notificationRect = tester.getRect(find.byTooltip('Notifications'));
    expect(bubbleRect.width, 190);
    expect(bubbleRect.right - 24, closeTo(notificationRect.center.dx, 2));
    expect(bubbleRect.top, greaterThan(notificationRect.bottom));
    await tester.tap(find.byTooltip('Notifications'));
    await tester.pumpAndSettle();

    expect(find.text('From: John Instructor'), findsOneWidget);
    expect(find.text('You have got this!'), findsOneWidget);
    await tester.tap(find.text('A message from your teacher').last);
    await tester.pumpAndSettle();

    expect(notifications.markedIds, ['teacher-feedback:feedback-1']);
    expect(speechBubble, findsNothing);
    expect(find.byTooltip('Notifications'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('notifications update live and can be marked as read', (
    tester,
  ) async {
    final notifications = _FakeStudentNotificationRepository();
    final todos = _FakeTodoRepository([
      InstructorTodoTask(
        id: 'due-tomorrow',
        title: 'Finish chapter notes',
        dueDate: DateTime.now().add(const Duration(days: 1)),
        priority: InstructorTodoPriority.high,
      ),
      InstructorTodoTask(
        id: 'due-later',
        title: 'Later study task',
        dueDate: DateTime.now().add(const Duration(days: 3)),
        priority: InstructorTodoPriority.normal,
      ),
    ]);

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          appBar: AppBar(
            actions: [
              StudentNotificationsButton(
                repository: notifications,
                todoRepository: todos,
                todoOwnerId: 23,
              ),
            ],
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('2'), findsOneWidget);
    await tester.tap(find.byTooltip('Notifications'));
    await tester.pumpAndSettle();

    expect(find.text('Quiz LP earned'), findsOneWidget);
    expect(
      find.text('Cell Structure: 280 LP total (50 LP first attempt).'),
      findsOneWidget,
    );
    expect(find.text('Task due tomorrow'), findsOneWidget);
    expect(
      find.text('"Finish chapter notes" is due tomorrow.'),
      findsOneWidget,
    );
    expect(find.text('Later study task'), findsNothing);

    await notifications.addNotification(
      StudentNotification(
        id: 'daily-points:today',
        type: StudentNotificationType.dailyPoints,
        title: 'Daily LP acquired',
        message: 'You earned 10 LP for a 2-day streak.',
        createdAt: DateTime(2026, 10, 19),
        isRead: false,
      ),
    );
    await tester.pumpAndSettle();
    expect(find.text('Daily LP acquired'), findsOneWidget);
    expect(find.text('3'), findsOneWidget);

    await tester.tap(find.text('Quiz LP earned'));
    await tester.pumpAndSettle();
    expect(notifications.markedIds, ['quiz-points:attempt-1']);
    expect(find.text('Mark all as read'), findsOneWidget);

    await tester.tap(find.text('Mark all as read'));
    await tester.pumpAndSettle();
    expect(notifications.markedIds, [
      'quiz-points:attempt-1',
      'daily-points:today',
    ]);
    expect(todos.readTaskIds, ['todo-reminder:due-tomorrow:due-tomorrow']);
    expect(find.text('Mark all as read'), findsNothing);

    await tester.tap(find.text('New classroom activity'));
    await tester.pumpAndSettle();
    expect(find.text('New classroom activity'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('badge refreshes every 15 seconds without opening the sheet', (
    tester,
  ) async {
    final notifications = _FakeStudentNotificationRepository();
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          appBar: AppBar(
            actions: [StudentNotificationsButton(repository: notifications)],
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
    final callsBefore = notifications.unreadCountCalls;

    await tester.pump(const Duration(seconds: 16));
    await tester.pumpAndSettle();

    expect(notifications.unreadCountCalls, greaterThan(callsBefore));
    expect(find.byTooltip('Notifications'), findsOneWidget);
  });

  testWidgets('todo reminders appear in notifications opened from Profile', (
    tester,
  ) async {
    final notifications = _FakeStudentNotificationRepository();
    final todos = _FakeTodoRepository([
      InstructorTodoTask(
        id: 'profile-task',
        title: 'Profile task',
        dueDate: DateTime.now().add(const Duration(days: 1)),
        priority: InstructorTodoPriority.normal,
      ),
    ]);

    await tester.pumpWidget(
      MaterialApp(
        home: ProfileScreen(
          username: 'Student Name',
          email: 'student@example.com',
          role: 'student',
          authService: _FakeProfileDataService(),
          achievementService: _FakeAchievementRepository(),
          notificationRepository: notifications,
          todoRepository: todos,
          todoOwnerId: 12,
        ),
      ),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.byTooltip('Notifications'));
    await tester.pumpAndSettle();

    expect(find.text('Task due tomorrow'), findsOneWidget);
  });
}

class _FakeProfileDataService implements ProfileDataService {
  @override
  Future<Set<DateTime>> loginDates() async => {};

  @override
  Future<int> learnerPoints() async => 100;

  @override
  Future<int?> weeklyRanking() async => 1;
}

class _FakeAchievementRepository implements AchievementRepository {
  @override
  Future<Set<String>> earnedBadges() async => {};
}

class _FakeStudentNotificationRepository
    implements StudentNotificationRepository {
  int listCalls = 0;
  int unreadCountCalls = 0;
  final List<String> markedIds = [];
  final Set<String> _readIds = {};
  final List<StudentNotification> _addedNotifications = [];
  late final StreamController<List<StudentNotification>> _updates =
      StreamController<List<StudentNotification>>.broadcast(
        onListen: () => unawaited(refreshNotifications()),
      );

  @override
  Stream<List<StudentNotification>> watchNotifications() => _updates.stream;

  @override
  Future<int> unreadCount() async {
    unreadCountCalls++;
    return (await listNotifications()).where((item) => !item.isRead).length;
  }

  @override
  Future<List<StudentNotification>> listNotifications() async {
    listCalls++;
    final notifications = [
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
        type: StudentNotificationType.legacy,
        title: 'New classroom activity',
        message: 'Biology: Cell Review was posted.',
        createdAt: DateTime(2026, 10, 17),
        isRead: true,
      ),
      ..._addedNotifications.map(
        (notification) => StudentNotification(
          id: notification.id,
          type: notification.type,
          title: notification.title,
          message: notification.message,
          createdAt: notification.createdAt,
          isRead: _readIds.contains(notification.id),
          senderName: notification.senderName,
        ),
      ),
    ];
    notifications.sort((a, b) => b.createdAt.compareTo(a.createdAt));
    return notifications;
  }

  @override
  Future<void> refreshNotifications() async {
    _updates.add(await listNotifications());
  }

  Future<void> addNotification(StudentNotification notification) async {
    _addedNotifications.add(notification);
    await refreshNotifications();
  }

  @override
  Future<void> markNotificationsRead(List<String> notificationIds) async {
    markedIds.addAll(notificationIds);
    _readIds.addAll(notificationIds);
  }
}

class _FakeTodoRepository
    implements InstructorTodoRepository, TodoReminderReadRepository {
  _FakeTodoRepository(this.tasks);

  final List<InstructorTodoTask> tasks;
  final List<String> readTaskIds = [];
  final Map<String, DateTime> firstSeen = {};

  @override
  Future<bool> isReminderRead(int ownerId, String taskId) async =>
      readTaskIds.contains(taskId);

  @override
  Future<DateTime?> reminderFirstSeen(int ownerId, String taskId) async =>
      firstSeen[taskId];

  @override
  Future<void> recordReminderSeen(
    int ownerId,
    String taskId,
    DateTime seenAt,
  ) async => firstSeen[taskId] = seenAt;

  @override
  Future<List<InstructorTodoTask>> listTasks(int instructorId) async => tasks;

  @override
  Future<void> markReminderRead(int ownerId, String taskId) async {
    if (!readTaskIds.contains(taskId)) readTaskIds.add(taskId);
  }

  @override
  Future<void> saveTasks(
    int instructorId,
    List<InstructorTodoTask> tasks,
  ) async {}
}
