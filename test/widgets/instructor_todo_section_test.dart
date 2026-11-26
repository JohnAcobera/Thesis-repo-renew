import 'package:material_ui/material_ui.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:thesis_repo_renew/models/instructor_todo_task.dart';
import 'package:thesis_repo_renew/screens/instructor_todo_section.dart';
import 'package:thesis_repo_renew/services/instructor_todo_service.dart';

void main() {
  testWidgets('tasks can be completed, removed, and added with due alerts', (
    tester,
  ) async {
    final repository = _FakeInstructorTodoRepository([
      InstructorTodoTask(
        id: 'tomorrow',
        title: 'Prepare biology quiz',
        dueDate: DateTime.now().add(const Duration(days: 1)),
        priority: InstructorTodoPriority.high,
      ),
    ]);
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    tester.view.physicalSize = const Size(420, 900);
    tester.view.devicePixelRatio = 1;

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: SingleChildScrollView(
            child: InstructorTodoSection(
              instructorId: 17,
              repository: repository,
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('My tasks'), findsOneWidget);
    expect(find.text('1 task due today or tomorrow'), findsOneWidget);
    expect(find.text('Prepare biology quiz'), findsOneWidget);
    expect(find.text('To do 1'), findsOneWidget);
    expect(repository.lastInstructorId, 17);

    await tester.tap(find.byKey(const ValueKey('task-check-tomorrow')));
    await tester.pumpAndSettle();
    expect(find.text('1 of 1 done'), findsOneWidget);
    expect(find.text('1 task due today or tomorrow'), findsNothing);
    expect(find.text('Prepare biology quiz'), findsNothing);

    await tester.tap(find.text('Done 1'));
    await tester.pumpAndSettle();
    expect(find.text('Prepare biology quiz'), findsOneWidget);
    await tester.tap(find.byTooltip('Remove Prepare biology quiz'));
    await tester.pumpAndSettle();
    expect(find.text('Prepare biology quiz'), findsNothing);
    expect(repository.tasks, isEmpty);

    await tester.tap(find.byTooltip('Add task'));
    await tester.pumpAndSettle();
    await tester.enterText(
      find.byKey(const ValueKey('instructor-task-title')),
      'Publish review guide',
    );
    await tester.tap(find.byKey(const ValueKey('instructor-task-due-time')));
    await tester.pumpAndSettle();
    expect(find.byType(TimePickerDialog), findsOneWidget);
    await tester.tap(find.text('Cancel').last);
    await tester.pumpAndSettle();
    await tester.ensureVisible(
      find.byKey(const ValueKey('save-instructor-task')),
    );
    await tester.tap(find.byKey(const ValueKey('save-instructor-task')));
    await tester.pumpAndSettle();

    expect(find.text('Publish review guide'), findsOneWidget);
    expect(repository.tasks, hasLength(1));
    expect(repository.tasks.single.title, 'Publish review guide');
    expect(repository.tasks.single.dueDate, isA<DateTime>());
    expect(repository.tasks.single.dueDate.hour, 9);
    expect(tester.takeException(), isNull);
  });

  testWidgets('tasks are grouped by date and ranked by priority', (
    tester,
  ) async {
    final today = DateTime.now();
    final tomorrow = today.add(const Duration(days: 1));
    final repository = _FakeInstructorTodoRepository([
      InstructorTodoTask(
        id: 'low-today',
        title: 'Low priority today',
        dueDate: DateTime(today.year, today.month, today.day, 17),
        priority: InstructorTodoPriority.low,
      ),
      InstructorTodoTask(
        id: 'high-tomorrow',
        title: 'High priority tomorrow',
        dueDate: DateTime(tomorrow.year, tomorrow.month, tomorrow.day, 9),
        priority: InstructorTodoPriority.high,
      ),
      InstructorTodoTask(
        id: 'high-today',
        title: 'High priority today',
        dueDate: DateTime(today.year, today.month, today.day, 10),
        priority: InstructorTodoPriority.high,
      ),
    ]);

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: SizedBox(
            height: 700,
            child: InstructorTodoSection(
              instructorId: 17,
              repository: repository,
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.byKey(const ValueKey('instructor-task-list')), findsOneWidget);
    expect(
      find.byKey(
        ValueKey(
          'task-date-${DateTime.utc(today.year, today.month, today.day).toIso8601String()}',
        ),
      ),
      findsOneWidget,
    );
    expect(
      find.byKey(
        ValueKey(
          'task-date-${DateTime.utc(tomorrow.year, tomorrow.month, tomorrow.day).toIso8601String()}',
        ),
      ),
      findsOneWidget,
    );

    final highToday = tester.getTopLeft(find.text('High priority today'));
    final lowToday = tester.getTopLeft(find.text('Low priority today'));
    expect(highToday.dy, lessThan(lowToday.dy));
  });
}

class _FakeInstructorTodoRepository implements InstructorTodoRepository {
  _FakeInstructorTodoRepository(this.tasks);

  List<InstructorTodoTask> tasks;
  int? lastInstructorId;

  @override
  Future<List<InstructorTodoTask>> listTasks(int instructorId) async {
    lastInstructorId = instructorId;
    return List.unmodifiable(tasks);
  }

  @override
  Future<void> saveTasks(
    int instructorId,
    List<InstructorTodoTask> updatedTasks,
  ) async {
    lastInstructorId = instructorId;
    tasks = List.unmodifiable(updatedTasks);
  }
}
