import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:thesis_repo_renew/models/instructor_todo_task.dart';
import 'package:thesis_repo_renew/services/instructor_todo_service.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('tasks persist independently for each instructor', () async {
    SharedPreferences.setMockInitialValues({});
    const service = InstructorTodoService();
    final task = InstructorTodoTask(
      id: 'task-1',
      title: 'Review submissions',
      notes: 'Focus on chapter two',
      dueDate: DateTime(2026, 10, 21, 14, 30),
      priority: InstructorTodoPriority.high,
    );

    await service.saveTasks(12, [task]);

    final restored = await service.listTasks(12);
    expect(restored, hasLength(1));
    expect(restored.single.toJson(), task.toJson());
    expect(await service.listTasks(13), isEmpty);
  });

  test('student tasks use storage separate from instructor tasks', () async {
    SharedPreferences.setMockInitialValues({});
    const instructorService = InstructorTodoService();
    const studentService = StudentTodoService();
    final task = InstructorTodoTask(
      id: 'task-1',
      title: 'Review a topic',
      dueDate: DateTime(2026, 10, 21),
      priority: InstructorTodoPriority.normal,
    );

    await instructorService.saveTasks(12, [task]);
    expect(await studentService.listTasks(12), isEmpty);

    await studentService.saveTasks(12, [task]);
    expect(await instructorService.listTasks(12), hasLength(1));
    expect(await studentService.listTasks(12), hasLength(1));
  });

  test('date-only tasks from existing storage remain readable', () async {
    SharedPreferences.setMockInitialValues({
      'instructor_todos_12':
          '[{"id":"task-1","title":"Review submissions",'
          '"due_date":"2026-10-21","priority":"normal","notes":"",'
          '"is_completed":false}]',
    });

    final tasks = await const InstructorTodoService().listTasks(12);

    expect(tasks.single.dueDate, DateTime(2026, 10, 21));
  });

  test(
    'reminders become overdue at timed deadline but date-only stays due today',
    () async {
      final now = DateTime(2026, 11, 16, 16, 27);
      final repository = _FakeTodoRepository([
        InstructorTodoTask(
          id: 'deadline-now',
          title: 'Send report',
          dueDate: now,
          priority: InstructorTodoPriority.high,
        ),
        InstructorTodoTask(
          id: 'deadline-later',
          title: 'Finish notes',
          dueDate: now.add(const Duration(minutes: 1)),
          priority: InstructorTodoPriority.normal,
        ),
        InstructorTodoTask(
          id: 'date-only',
          title: 'Review material',
          dueDate: DateTime(now.year, now.month, now.day),
          priority: InstructorTodoPriority.low,
        ),
      ]);

      final reminders = await listTodoReminders(repository, 12, now: now);
      final byTaskId = {
        for (final reminder in reminders) reminder.taskId: reminder,
      };

      expect(byTaskId['deadline-now']?.title, 'Task overdue');
      expect(
        byTaskId['deadline-now']?.message,
        '"Send report" was due 11/16 at 4:27 PM.',
      );
      expect(byTaskId['deadline-later']?.title, 'Task due today');
      expect(byTaskId['date-only']?.title, 'Task due today');
    },
  );

  test('reminder refresh aligns with the next minute boundary', () {
    expect(
      durationUntilNextMinute(DateTime(2026, 11, 16, 16, 27, 0)),
      const Duration(minutes: 1),
    );
    expect(
      durationUntilNextMinute(DateTime(2026, 11, 16, 16, 27, 30)),
      const Duration(seconds: 30),
    );
  });
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
