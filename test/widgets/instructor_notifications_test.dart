import 'dart:async';

import 'package:material_ui/material_ui.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:thesis_repo_renew/models/instructor_todo_task.dart';
import 'package:thesis_repo_renew/services/instructor_notification_service.dart';
import 'package:thesis_repo_renew/services/instructor_todo_service.dart';
import 'package:thesis_repo_renew/widgets/student_nav_bar.dart';

void main() {
  test('legacy quiz-answer notifications are parsed as generic notices', () {
    final notification = InstructorNotification.fromJson({
      'id': 'legacy-notification',
      'type': 'quizAnswered',
      'title': 'Quiz completed',
      'message': 'A legacy notification.',
      'created_at': DateTime(2026, 10, 17).toIso8601String(),
      'is_read': true,
      'classroom_id': 'classroom-id',
    });

    expect(notification.type, InstructorNotificationType.legacy);
  });

  testWidgets('badge updates from the realtime stream without polling', (
    tester,
  ) async {
    final notifications = _FakeInstructorNotificationRepository();
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          appBar: StudentNavBar(
            roleLabel: 'Instructor',
            instructorNotificationRepository: notifications,
          ),
          body: const SizedBox.shrink(),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('2'), findsOneWidget);

    await notifications.addNotification(
      InstructorNotification(
        id: 'student-joined:class-2:student-2',
        type: InstructorNotificationType.studentJoined,
        title: 'A student joined your classroom',
        message: 'A new student joined.',
        createdAt: DateTime(2026, 10, 18, 13),
        isRead: false,
        classroomId: 'class-2',
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('3'), findsOneWidget);
  });

  testWidgets('instructor notifications use the shared navbar bell and panel', (
    tester,
  ) async {
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    tester.view.physicalSize = const Size(900, 1600);
    tester.view.devicePixelRatio = 1;
    final notifications = _FakeInstructorNotificationRepository();
    final todos = _FakeTodoRepository([
      InstructorTodoTask(
        id: 'overdue-task',
        title: 'Review lesson plan',
        dueDate: DateTime.now().subtract(const Duration(days: 1)),
        priority: InstructorTodoPriority.high,
      ),
      InstructorTodoTask(
        id: 'today-task',
        title: 'Prepare lab activity',
        dueDate: DateTime.now().add(const Duration(hours: 1)),
        priority: InstructorTodoPriority.normal,
      ),
      InstructorTodoTask(
        id: 'tomorrow-task',
        title: 'Grade quizzes',
        dueDate: DateTime.now().add(const Duration(days: 1)),
        priority: InstructorTodoPriority.low,
      ),
      InstructorTodoTask(
        id: 'later-task',
        title: 'Future task',
        dueDate: DateTime.now().add(const Duration(days: 4)),
        priority: InstructorTodoPriority.low,
      ),
      InstructorTodoTask(
        id: 'completed-task',
        title: 'Finished task',
        dueDate: DateTime.now(),
        priority: InstructorTodoPriority.low,
        isCompleted: true,
      ),
    ]);
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          appBar: StudentNavBar(
            roleLabel: 'Instructor',
            instructorNotificationRepository: notifications,
            todoRepository: todos,
            todoOwnerId: 17,
          ),
          body: const SizedBox.shrink(),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.byTooltip('Notifications'), findsOneWidget);
    expect(find.byIcon(Icons.notifications_none_rounded), findsOneWidget);
    expect(find.text('5'), findsOneWidget);

    await tester.tap(find.byTooltip('Notifications'));
    await tester.pumpAndSettle();

    expect(find.text('Notifications'), findsOneWidget);
    expect(find.text('Quiz completed'), findsOneWidget);
    expect(
      find.text(
        'Ari Santos completed "Cell Structure" in Biology and scored 8 out of 10.',
      ),
      findsOneWidget,
    );
    expect(find.text('A student joined your classroom'), findsOneWidget);
    expect(find.text('Task overdue'), findsOneWidget);
    expect(find.textContaining('Review lesson plan'), findsOneWidget);
    expect(find.text('Task due today'), findsOneWidget);
    expect(find.textContaining('Prepare lab activity'), findsOneWidget);
    expect(find.text('Task due tomorrow'), findsOneWidget);
    expect(find.textContaining('Grade quizzes'), findsOneWidget);
    expect(find.text('Future task'), findsNothing);
    expect(find.text('Finished task'), findsNothing);
    await tester.tap(find.text('Quiz completed'));
    await tester.pumpAndSettle();
    expect(notifications.markedIds, ['quiz-answered:attempt-1']);
    expect(find.text('Mark all as read'), findsOneWidget);

    await tester.tap(find.text('Mark all as read'));
    await tester.pumpAndSettle();
    expect(notifications.markedIds, [
      'quiz-answered:attempt-1',
      'student-joined:class-1:student-1',
    ]);
    expect(find.text('Mark all as read'), findsNothing);
    expect(
      todos.readTaskIds,
      containsAll(['overdue-task', 'today-task', 'tomorrow-task']),
    );
    expect(tester.takeException(), isNull);
  });
}

class _FakeTodoRepository
    implements InstructorTodoRepository, TodoReminderReadRepository {
  _FakeTodoRepository(this.tasks);

  final List<InstructorTodoTask> tasks;
  final Set<String> readTaskIds = {};

  @override
  Future<bool> isReminderRead(int ownerId, String taskId) async =>
      readTaskIds.contains(taskId);

  @override
  Future<List<InstructorTodoTask>> listTasks(int instructorId) async => tasks;

  @override
  Future<void> markReminderRead(int ownerId, String taskId) async {
    readTaskIds.add(taskId);
  }

  @override
  Future<void> saveTasks(
    int instructorId,
    List<InstructorTodoTask> tasks,
  ) async {}
}

class _FakeInstructorNotificationRepository
    implements InstructorNotificationRepository {
  final Set<String> _readIds = {};
  final List<String> markedIds = [];
  final StreamController<List<InstructorNotification>> _updates =
      StreamController<List<InstructorNotification>>.broadcast();

  @override
  Stream<List<InstructorNotification>> watchNotifications() => _updates.stream;

  @override
  Future<void> refreshNotifications() async =>
      _updates.add(await listNotifications());

  final List<InstructorNotification> _items = [
    InstructorNotification(
      id: 'quiz-answered:attempt-1',
      type: InstructorNotificationType.legacy,
      title: 'Quiz completed',
      message:
          'Ari Santos completed "Cell Structure" in Biology and scored 8 out of 10.',
      createdAt: DateTime(2026, 10, 18, 12),
      isRead: false,
      classroomId: 'class-1',
    ),
    InstructorNotification(
      id: 'student-joined:class-1:student-1',
      type: InstructorNotificationType.studentJoined,
      title: 'A student joined your classroom',
      message: 'Ari Santos joined Biology.',
      createdAt: DateTime(2026, 10, 18, 11),
      isRead: false,
      classroomId: 'class-1',
    ),
  ];

  Future<void> addNotification(InstructorNotification notification) async {
    _items.add(notification);
    await refreshNotifications();
  }

  @override
  Future<List<InstructorNotification>> listNotifications() async => _items
      .map(
        (notification) => InstructorNotification(
          id: notification.id,
          type: notification.type,
          title: notification.title,
          message: notification.message,
          createdAt: notification.createdAt,
          isRead: _readIds.contains(notification.id) || notification.isRead,
          classroomId: notification.classroomId,
          todoTaskId: notification.todoTaskId,
        ),
      )
      .toList();

  @override
  Future<void> markNotificationsRead(List<String> notificationIds) async {
    markedIds.addAll(notificationIds);
    _readIds.addAll(notificationIds);
    await refreshNotifications();
  }
}
