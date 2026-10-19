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
      dueDate: DateTime(2026, 10, 21),
      priority: InstructorTodoPriority.high,
    );

    await service.saveTasks(12, [task]);

    final restored = await service.listTasks(12);
    expect(restored, hasLength(1));
    expect(restored.single.toJson(), task.toJson());
    expect(await service.listTasks(13), isEmpty);
  });
}
