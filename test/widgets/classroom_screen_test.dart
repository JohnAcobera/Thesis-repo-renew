import 'package:flutter/services.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:thesis_repo_renew/models/classroom_model.dart';
import 'package:thesis_repo_renew/models/user_model.dart';
import 'package:thesis_repo_renew/screens/classroom/classroom_screen.dart';
import 'package:thesis_repo_renew/services/classroom_service.dart';
import 'package:thesis_repo_renew/services/quiz_service.dart';

void main() {
  testWidgets('instructor can create a classroom and view its saved code', (
    tester,
  ) async {
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    tester.view.physicalSize = const Size(400, 800);
    tester.view.devicePixelRatio = 1;

    final repository = _FakeClassroomRepository();
    await tester.pumpWidget(
      MaterialApp(
        home: ClassroomScreen(
          user: const UserModel(
            id: 1,
            fullName: 'Instructor Name',
            email: 'instructor@example.com',
            role: 'instructor',
          ),
          classroomService: repository,
        ),
      ),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.text('Create classroom'));
    await tester.pumpAndSettle();
    expect(find.text('e.g., Grade 11 - STEM A'), findsOneWidget);
    expect(find.text('e.g., General Biology 1'), findsOneWidget);

    await tester.enterText(
      find.widgetWithText(TextFormField, 'e.g., Grade 11 - STEM A'),
      'Grade 11 - STEM A',
    );
    await tester.enterText(
      find.widgetWithText(TextFormField, 'e.g., General Biology 1'),
      'General Biology 1',
    );
    await tester.tap(find.byTooltip('Use Science icon'));
    await tester.tap(
      find.widgetWithText(FilledButton, 'Create classroom').last,
    );
    await tester.pumpAndSettle();

    expect(repository.createdName, 'Grade 11 - STEM A');
    expect(repository.createdSubject, 'General Biology 1');
    expect(repository.createdIconKey, 'science');
    expect(find.text('Classroom created!'), findsOneWidget);
    expect(find.text('ABCD2345'), findsOneWidget);
    await tester.tap(find.text('Done'));
    await tester.pumpAndSettle();
    expect(find.text('Grade 11 - STEM A'), findsOneWidget);
    expect(find.text('Code: ABCD2345'), findsOneWidget);
    expect(find.byIcon(Icons.science_outlined), findsOneWidget);
    await tester.tap(find.text('Grade 11 - STEM A'));
    await tester.pumpAndSettle();
    expect(find.text('Your classrooms'), findsOneWidget);
    expect(find.text('General Biology 1'), findsOneWidget);
    expect(find.text('0 students'), findsOneWidget);
    expect(find.text('Join code: ABCD2345'), findsOneWidget);
    expect(find.text('Post Activities'), findsOneWidget);
    expect(find.text('Nothing posted here yet'), findsOneWidget);
    await tester.tap(find.text('Your classrooms'));
    await tester.pumpAndSettle();
    expect(find.text('Grade 11 - STEM A'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('classroom code can be copied from its card', (tester) async {
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    tester.view.physicalSize = const Size(400, 800);
    tester.view.devicePixelRatio = 1;

    String? copiedText;
    tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
      SystemChannels.platform,
      (call) async {
        if (call.method == 'Clipboard.setData') {
          copiedText = (call.arguments as Map)['text'] as String;
        }
        return null;
      },
    );
    addTearDown(
      () => tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
        SystemChannels.platform,
        null,
      ),
    );

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: ClassroomScreen(
            user: const UserModel(
              id: 1,
              fullName: 'Instructor Name',
              email: 'instructor@example.com',
              role: 'instructor',
            ),
            classroomService: _FakeClassroomRepository()
              ..classrooms.add(
                ClassroomModel(
                  id: 'test-id',
                  name: 'Grade 11 - STEM A',
                  subject: 'General Biology 1',
                  code: 'ABCD2345',
                  createdAt: DateTime.utc(2026),
                  iconKey: 'science',
                  studentCount: 12,
                  activityCount: 3,
                ),
              ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('12 students'), findsOneWidget);
    expect(find.text('3 activities'), findsOneWidget);
    await tester.tap(find.byTooltip('Copy classroom code'));
    await tester.pumpAndSettle();

    expect(copiedText, 'ABCD2345');
    expect(find.text('Classroom code copied'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('instructors can cancel or confirm classroom deletion', (
    tester,
  ) async {
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    tester.view.physicalSize = const Size(400, 800);
    tester.view.devicePixelRatio = 1;

    final repository = _FakeClassroomRepository()
      ..classrooms.add(
        ClassroomModel(
          id: 'test-id',
          name: 'Grade 11 - STEM A',
          subject: 'General Biology 1',
          code: 'ABCD2345',
          createdAt: DateTime.utc(2026),
        ),
      );
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: ClassroomScreen(
            user: const UserModel(
              id: 1,
              fullName: 'Instructor Name',
              email: 'instructor@example.com',
              role: 'instructor',
            ),
            classroomService: repository,
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.text('Grade 11 - STEM A'));
    await tester.pumpAndSettle();

    await tester.tap(find.text('Delete classroom'));
    await tester.pumpAndSettle();
    expect(find.text('Delete classroom?'), findsOneWidget);
    await tester.tap(find.text('Cancel'));
    await tester.pumpAndSettle();
    expect(repository.classrooms, hasLength(1));
    expect(find.text('Grade 11 - STEM A'), findsOneWidget);

    await tester.tap(find.text('Delete classroom'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Delete classroom').last);
    await tester.pumpAndSettle();
    expect(repository.classrooms, isEmpty);
    expect(find.text('Your classrooms'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('instructors can review and remove classroom students', (
    tester,
  ) async {
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    tester.view.physicalSize = const Size(400, 800);
    tester.view.devicePixelRatio = 1;

    final repository = _FakeClassroomRepository()
      ..classrooms.add(
        ClassroomModel(
          id: 'test-id',
          name: 'Grade 11 - STEM A',
          subject: 'General Biology 1',
          code: 'ABCD2345',
          createdAt: DateTime.utc(2026),
          studentCount: 1,
        ),
      )
      ..students.add(
        ClassroomStudentSummary(
          id: 12,
          fullName: 'Ari Santos',
          email: 'ari@example.com',
          joinedAt: DateTime.utc(2026, 10, 1),
          completedActivityCount: 2,
          totalActivityCount: 3,
          attemptCount: 4,
          averageScore: 82.5,
        ),
      );
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: ClassroomScreen(
            user: const UserModel(
              id: 1,
              fullName: 'Instructor Name',
              email: 'instructor@example.com',
              role: 'instructor',
            ),
            classroomService: repository,
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.text('Grade 11 - STEM A'));
    await tester.pumpAndSettle();

    expect(find.text('Students'), findsOneWidget);
    expect(find.text('Ari Santos'), findsOneWidget);
    expect(find.text('2 of 3 assignments'), findsOneWidget);
    expect(find.text('Average 83%'), findsOneWidget);
    expect(find.text('4 attempts'), findsOneWidget);
    await tester.ensureVisible(find.byTooltip('Remove Ari Santos'));
    await tester.tap(find.byTooltip('Remove Ari Santos'));
    await tester.pumpAndSettle();
    expect(find.text('Remove student?'), findsOneWidget);
    await tester.tap(find.text('Cancel'));
    await tester.pumpAndSettle();
    expect(repository.students, hasLength(1));

    await tester.ensureVisible(find.byTooltip('Remove Ari Santos'));
    await tester.tap(find.byTooltip('Remove Ari Santos'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Remove student'));
    await tester.pumpAndSettle();
    expect(repository.removedStudents, [12]);
    expect(find.text('No students have joined yet'), findsOneWidget);
    expect(find.text('Ari Santos removed from the classroom'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('students can open an available classroom activity', (
    tester,
  ) async {
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    tester.view.physicalSize = const Size(400, 800);
    tester.view.devicePixelRatio = 1;

    final now = DateTime.now();
    final repository = _FakeClassroomRepository()
      ..classrooms.add(
        ClassroomModel(
          id: 'test-id',
          name: 'Grade 11 - STEM A',
          subject: 'General Biology 1',
          code: 'ABCD2345',
          createdAt: DateTime.utc(2026),
          studentCount: 1,
        ),
      )
      ..activities.add(
        ClassroomActivity(
          id: 'activity-id',
          classroomId: 'test-id',
          classroomName: 'Grade 11 - STEM A',
          quizId: 'quiz-id',
          title: 'Cell Structure',
          sourceFile: 'biology.pdf',
          questions: const [
            QuizQuestion(
              question: 'Which organelle stores DNA?',
              options: ['Nucleus', 'Ribosome', 'Cell wall', 'Vacuole'],
              answerIndex: 0,
              explanation: 'The nucleus contains the cell DNA.',
            ),
          ],
          startsAt: now.subtract(const Duration(minutes: 1)),
          deadlineAt: now.add(const Duration(days: 1)),
        ),
      );

    await tester.pumpWidget(
      MaterialApp(
        home: ClassroomScreen(
          user: const UserModel(
            id: 2,
            fullName: 'Student Name',
            email: 'student@example.com',
            role: 'student',
          ),
          classroomService: repository,
        ),
      ),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.text('Grade 11 - STEM A'));
    await tester.pumpAndSettle();

    expect(find.text('Post Activities'), findsOneWidget);
    expect(find.text('Cell Structure'), findsOneWidget);
    expect(find.text('Take activity'), findsOneWidget);
    await tester.tap(find.text('Take activity'));
    await tester.pumpAndSettle();
    expect(find.text('Take your quiz'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('instructors can preview posted quiz questions', (tester) async {
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    tester.view.physicalSize = const Size(400, 800);
    tester.view.devicePixelRatio = 1;

    final now = DateTime.now();
    final repository = _FakeClassroomRepository()
      ..classrooms.add(
        ClassroomModel(
          id: 'test-id',
          name: 'Grade 11 - STEM A',
          subject: 'General Biology 1',
          code: 'ABCD2345',
          createdAt: DateTime.utc(2026),
        ),
      )
      ..activities.add(
        ClassroomActivity(
          id: 'activity-id',
          classroomId: 'test-id',
          classroomName: 'Grade 11 - STEM A',
          quizId: 'quiz-id',
          title: 'Cell Structure',
          sourceFile: 'biology.pdf',
          questions: const [
            QuizQuestion(
              question: 'Which organelle stores DNA?',
              options: ['Nucleus', 'Ribosome', 'Cell wall', 'Vacuole'],
              answerIndex: 0,
              explanation: 'The nucleus contains the cell DNA.',
            ),
          ],
          startsAt: now.add(const Duration(minutes: 1)),
          deadlineAt: now.add(const Duration(days: 1)),
          maxAttempts: 3,
        ),
      );

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: ClassroomScreen(
            user: const UserModel(
              id: 1,
              fullName: 'Instructor Name',
              email: 'instructor@example.com',
              role: 'instructor',
            ),
            classroomService: repository,
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.text('Grade 11 - STEM A'));
    await tester.pumpAndSettle();
    await tester.ensureVisible(find.text('Cell Structure'));
    await tester.tap(find.text('Cell Structure'));
    await tester.pumpAndSettle();

    expect(find.textContaining('3 attempts per student'), findsOneWidget);
    expect(find.text('Which organelle stores DNA?'), findsOneWidget);
    expect(find.text('Nucleus'), findsOneWidget);
    expect(find.text('Correct answer'), findsOneWidget);
    expect(
      find.textContaining('The nucleus contains the cell DNA.'),
      findsOneWidget,
    );
    expect(tester.takeException(), isNull);
  });

  testWidgets('instructors can cancel or confirm deleting a posted quiz', (
    tester,
  ) async {
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    tester.view.physicalSize = const Size(400, 800);
    tester.view.devicePixelRatio = 1;
    final now = DateTime.now();
    final repository = _FakeClassroomRepository()
      ..classrooms.add(
        ClassroomModel(
          id: 'test-id',
          name: 'Grade 11 - STEM A',
          subject: 'General Biology 1',
          code: 'ABCD2345',
          createdAt: DateTime.utc(2026),
        ),
      )
      ..activities.add(
        ClassroomActivity(
          id: 'activity-id',
          classroomId: 'test-id',
          classroomName: 'Grade 11 - STEM A',
          quizId: 'quiz-id',
          title: 'Cell Structure',
          sourceFile: 'biology.pdf',
          questions: const [
            QuizQuestion(
              question: 'Which organelle stores DNA?',
              options: ['Nucleus', 'Ribosome', 'Cell wall', 'Vacuole'],
              answerIndex: 0,
              explanation: 'The nucleus contains the cell DNA.',
            ),
          ],
          startsAt: now,
          deadlineAt: now.add(const Duration(days: 1)),
        ),
      );

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: ClassroomScreen(
            user: const UserModel(
              id: 1,
              fullName: 'Instructor Name',
              email: 'instructor@example.com',
              role: 'instructor',
            ),
            classroomService: repository,
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.text('Grade 11 - STEM A'));
    await tester.pumpAndSettle();

    await tester.ensureVisible(find.byTooltip('Delete posted quiz'));
    await tester.tap(find.byTooltip('Delete posted quiz'));
    await tester.pumpAndSettle();
    expect(find.text('Delete posted quiz?'), findsOneWidget);
    await tester.tap(find.text('Cancel'));
    await tester.pumpAndSettle();
    expect(repository.activities, hasLength(1));

    await tester.ensureVisible(find.byTooltip('Delete posted quiz'));
    await tester.tap(find.byTooltip('Delete posted quiz'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Delete quiz'));
    await tester.pumpAndSettle();
    expect(repository.activities, isEmpty);
    expect(repository.deletedActivities, ['activity-id']);
    expect(find.text('Posted quiz deleted'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
}

class _FakeClassroomRepository implements ClassroomRepository {
  final List<ClassroomModel> classrooms = [];
  final List<ClassroomActivity> activities = [];
  final List<ClassroomStudentSummary> students = [];
  final List<int> removedStudents = [];
  String? createdName;
  String? createdSubject;
  String? createdIconKey;
  final List<String> deletedActivities = [];

  @override
  Future<List<ClassroomStudentSummary>> classroomStudents(
    String classroomId,
  ) async => students;

  @override
  Future<void> removeClassroomStudent({
    required String classroomId,
    required int studentId,
  }) async {
    removedStudents.add(studentId);
    students.removeWhere((student) => student.id == studentId);
  }

  @override
  Future<List<ClassroomActivity>> classroomActivities(
    String classroomId,
  ) async => activities
      .where((activity) => activity.classroomId == classroomId)
      .toList();

  @override
  Future<InstructorDashboardStats> getInstructorDashboardStats() async =>
      const InstructorDashboardStats(studentCount: 0, activeClassCount: 0);

  @override
  Future<ClassroomModel> createClassroom({
    required String name,
    required String subject,
    required String iconKey,
  }) async {
    createdName = name;
    createdSubject = subject;
    createdIconKey = iconKey;
    final classroom = ClassroomModel(
      id: 'test-id',
      name: name,
      subject: subject,
      code: 'ABCD2345',
      createdAt: DateTime.utc(2026),
      iconKey: iconKey,
    );
    classrooms.add(classroom);
    return classroom;
  }

  @override
  Future<List<ClassroomModel>> listClassrooms() async => classrooms.toList();

  @override
  Future<List<ClassroomModel>> listStudentClassrooms() async =>
      classrooms.toList();

  @override
  Future<void> deleteClassroom(String classroomId) async {
    classrooms.removeWhere((classroom) => classroom.id == classroomId);
  }

  @override
  Future<void> deleteClassroomActivity({
    required String classroomId,
    required String activityId,
  }) async {
    deletedActivities.add(activityId);
    activities.removeWhere((activity) => activity.id == activityId);
  }

  @override
  Future<ClassroomModel> joinClassroom({required String code}) async =>
      classrooms.firstWhere(
        (classroom) => classroom.code == code.toUpperCase(),
      );
}
