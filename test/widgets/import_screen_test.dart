import 'package:material_ui/material_ui.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:thesis_repo_renew/models/instructor_todo_task.dart';
import 'package:thesis_repo_renew/screens/import_screen.dart';
import 'package:thesis_repo_renew/services/instructor_todo_service.dart';
import 'package:thesis_repo_renew/services/student_notification_service.dart';

void main() {
  testWidgets('import screen notifications include to-do reminders', (
    tester,
  ) async {
    SharedPreferences.setMockInitialValues({});
    final notifications = _FakeStudentNotificationRepository();
    final todos = _FakeTodoRepository([
      InstructorTodoTask(
        id: 'todo-due-tomorrow',
        title: 'Review chapter notes',
        dueDate: DateTime.now().add(const Duration(days: 1)),
        priority: InstructorTodoPriority.high,
      ),
    ]);

    await tester.pumpWidget(
      MaterialApp(
        home: ImportScreen(
          username: 'Student',
          email: 'student@example.com',
          notificationRepository: notifications,
          todoRepository: todos,
          todoOwnerId: 23,
        ),
      ),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.byTooltip('Notifications'));
    await tester.pumpAndSettle();

    expect(find.text('Task due tomorrow'), findsOneWidget);
    expect(
      find.text('"Review chapter notes" is due tomorrow.'),
      findsOneWidget,
    );
    expect(tester.takeException(), isNull);
  });
}

class _FakeStudentNotificationRepository
    implements StudentNotificationRepository {
  final notification = StudentNotification(
    id: 'quiz-update',
    type: StudentNotificationType.quizPoints,
    title: 'Quiz update',
    message: 'A quiz notification.',
    createdAt: DateTime(2026, 10, 19),
    isRead: false,
  );

  @override
  Future<List<StudentNotification>> listNotifications() async => [
    notification,
  ];

  @override
  Stream<List<StudentNotification>> watchNotifications() =>
      Stream.value([notification]).asBroadcastStream();

  @override
  Future<int> unreadCount() async => 1;

  @override
  Future<void> refreshNotifications() async {}

  @override
  Future<void> markNotificationsRead(List<String> notificationIds) async {}
}

class _FakeTodoRepository implements InstructorTodoRepository {
  _FakeTodoRepository(this.tasks);

  final List<InstructorTodoTask> tasks;

  @override
  Future<List<InstructorTodoTask>> listTasks(int instructorId) async => tasks;

  @override
  Future<void> saveTasks(
    int instructorId,
    List<InstructorTodoTask> tasks,
  ) async {}
}
