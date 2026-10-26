import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:thesis_repo_renew/models/instructor_todo_task.dart';
import 'package:thesis_repo_renew/models/user_model.dart';
import 'package:thesis_repo_renew/screens/home/student_home_screen.dart';
import 'package:thesis_repo_renew/services/auth_service.dart';
import 'package:thesis_repo_renew/services/instructor_todo_service.dart';

void main() {
  testWidgets('dashboard omits the practice section on mobile', (tester) async {
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    tester.view.physicalSize = const Size(400, 800);
    tester.view.devicePixelRatio = 1;

    await tester.pumpWidget(
      MaterialApp(
        home: StudentHomeScreen(
          user: _student,
          profileDataService: _FakeProfileDataService(),
          todoRepository: _FakeTodoRepository(),
        ),
      ),
    );
    await tester.pumpAndSettle();
    await tester.drag(
      find.byType(SingleChildScrollView).first,
      const Offset(0, -1800),
    );
    await tester.pumpAndSettle();

    expect(find.text('Come back and practice'), findsNothing);
    expect(find.text('Pending activities'), findsNothing);
    expect(find.text('Classroom deadlines'), findsNothing);
    expect(tester.takeException(), isNull);
  });

  testWidgets('wide dashboard fits the stats panel in a short viewport', (
    tester,
  ) async {
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    tester.view.physicalSize = const Size(1280, 700);
    tester.view.devicePixelRatio = 1;

    await tester.pumpWidget(
      MaterialApp(
        home: StudentHomeScreen(
          user: _student,
          profileDataService: _FakeProfileDataService(),
          todoRepository: _FakeTodoRepository(),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(tester.takeException(), isNull);
  });

  testWidgets('dashboard omits generated quiz practice section', (
    tester,
  ) async {
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    tester.view.physicalSize = const Size(1280, 900);
    tester.view.devicePixelRatio = 1;

    await tester.pumpWidget(
      MaterialApp(
        home: StudentHomeScreen(
          user: _student,
          profileDataService: _FakeProfileDataService(),
          todoRepository: _FakeTodoRepository(),
        ),
      ),
    );
    await tester.pumpAndSettle();
    await tester.drag(
      find.byType(SingleChildScrollView).first,
      const Offset(0, -1200),
    );
    await tester.pumpAndSettle();

    expect(find.text('Come back and practice'), findsNothing);
    expect(find.text('Practice quiz'), findsNothing);
    expect(tester.takeException(), isNull);
  });

  testWidgets('streak calendar and todo list appear on dashboard', (
    tester,
  ) async {
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    tester.view.physicalSize = const Size(1280, 900);
    tester.view.devicePixelRatio = 1;

    final todoRepository = _FakeTodoRepository([
      InstructorTodoTask(
        id: 'review',
        title: 'Review a topic',
        dueDate: DateTime.now().add(const Duration(days: 5)),
        priority: InstructorTodoPriority.normal,
      ),
    ]);
    await tester.pumpWidget(
      MaterialApp(
        home: StudentHomeScreen(
          user: _student,
          profileDataService: _FakeProfileDataService(),
          todoRepository: todoRepository,
        ),
      ),
    );
    await tester.pumpAndSettle();
    await tester.drag(
      find.byType(SingleChildScrollView).first,
      const Offset(0, -1200),
    );
    await tester.pumpAndSettle();

    expect(find.text('Your learning streak'), findsOneWidget);
    expect(find.text('2 days in a row'), findsOneWidget);
    expect(find.byKey(const ValueKey('streak-calendar-grid')), findsOneWidget);
    final lastDayOfMonth = DateTime(
      DateTime.now().year,
      DateTime.now().month + 1,
      0,
    ).day;
    expect(
      find.byKey(ValueKey<String>('streak-day-$lastDayOfMonth')),
      findsOneWidget,
    );
    final localizations = MaterialLocalizations.of(
      tester.element(find.text('Your learning streak')),
    );
    await tester.tap(find.byTooltip('Previous month'));
    await tester.pumpAndSettle();
    expect(
      find.text(
        localizations.formatMonthYear(
          DateTime(DateTime.now().year, DateTime.now().month - 1),
        ),
      ),
      findsOneWidget,
    );
    await tester.tap(find.byTooltip('Next month'));
    await tester.pumpAndSettle();
    expect(
      find.text(
        localizations.formatMonthYear(
          DateTime(DateTime.now().year, DateTime.now().month),
        ),
      ),
      findsOneWidget,
    );
    expect(find.text('Learning day'), findsOneWidget);
    expect(find.text('Today'), findsOneWidget);
    expect(find.text('My tasks'), findsOneWidget);
    expect(find.text('Review a topic'), findsOneWidget);
    expect(find.text('Come back and practice'), findsNothing);
    expect(find.text('Classroom deadlines'), findsNothing);
    expect(tester.takeException(), isNull);
  });
}

const _student = UserModel(
  id: 1,
  fullName: 'Student Name',
  email: 'student@example.com',
  role: 'student',
);

class _FakeProfileDataService implements ProfileDataService {
  @override
  Future<Set<DateTime>> loginDates() async {
    final today = DateTime.now();
    return {
      DateTime(today.year, today.month, today.day),
      DateTime(today.year, today.month, today.day - 1),
    };
  }

  @override
  Future<int> learnerPoints() async => 0;

  @override
  Future<int?> weeklyRanking() async => null;
}

class _FakeTodoRepository implements InstructorTodoRepository {
  _FakeTodoRepository([this.tasks = const []]);

  List<InstructorTodoTask> tasks;

  @override
  Future<List<InstructorTodoTask>> listTasks(int instructorId) async =>
      List.unmodifiable(tasks);

  @override
  Future<void> saveTasks(
    int instructorId,
    List<InstructorTodoTask> updatedTasks,
  ) async {
    tasks = List.unmodifiable(updatedTasks);
  }
}
