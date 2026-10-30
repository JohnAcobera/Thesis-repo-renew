import 'package:flutter/services.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:thesis_repo_renew/models/classroom_model.dart';
import 'package:thesis_repo_renew/models/instructor_report.dart';
import 'package:thesis_repo_renew/models/user_model.dart';
import 'package:thesis_repo_renew/screens/classroom/classroom_screen.dart';
import 'package:thesis_repo_renew/services/classroom_service.dart';
import 'package:thesis_repo_renew/services/instructor_reports_service.dart';

void main() {
  testWidgets('instructor classroom screen shows the classroom list', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(1280, 900);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    final repository = _FakeClassroomRepository()
      ..totalStudentCount = 5
      ..classrooms.addAll([
        ClassroomModel(
          id: 'class-1',
          name: 'Biology',
          subject: 'Science',
          code: 'BIO12345',
          createdAt: DateTime.utc(2026),
          studentCount: 3,
        ),
        ClassroomModel(
          id: 'class-2',
          name: 'Chemistry',
          subject: 'Science',
          code: 'CHE12345',
          createdAt: DateTime.utc(2026),
          studentCount: 4,
        ),
      ]);

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

    expect(find.text('Your classrooms'), findsOneWidget);
    expect(
      find.byKey(const ValueKey('instructor-summary-metrics-card')),
      findsNothing,
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
    expect(find.text('Your classrooms'), findsOneWidget);
  });

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
    expect(find.text('Classroom quizzes'), findsNothing);
    expect(find.text('No quizzes yet'), findsNothing);
    expect(find.text('Create quiz'), findsNothing);
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
                ),
              ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('12 students'), findsOneWidget);
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
            reportsRepository: _FakeInstructorReportsRepository(),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.text('Grade 11 - STEM A'));
    await tester.pumpAndSettle();

    expect(find.text('Students'), findsOneWidget);
    expect(find.text('Ari Santos'), findsOneWidget);
    await tester.tap(find.text('Ari Santos'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));
    expect(find.text('Ari Santos'), findsNWidgets(2));
    expect(find.text('PERSONAL STATS'), findsOneWidget);
    expect(find.text('Quizzes generated'), findsOneWidget);
    expect(find.text('All quiz attempts'), findsOneWidget);
    expect(find.text('Overall average score'), findsOneWidget);
    expect(find.text('YOUR STATS'), findsOneWidget);
    expect(find.text('Joined classroom'), findsOneWidget);
    expect(find.text('Assignments completed'), findsNothing);
    expect(find.text('Average quiz score'), findsNothing);
    expect(find.text('Quiz attempts'), findsNothing);
    expect(find.text('Grade 11 - STEM A'), findsOneWidget);
    await tester.tap(find.text('Close'));
    await tester.pumpAndSettle();
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

  testWidgets('students see only their classmates after opening a classroom', (
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

    expect(find.text('Classmates'), findsOneWidget);
    expect(find.text('Ari Santos'), findsOneWidget);
    expect(find.text('ari@example.com'), findsNothing);
    expect(find.text('Grade 11 - STEM A'), findsNothing);
    expect(find.text('General Biology 1'), findsNothing);
    expect(find.text('Join code: ABCD2345'), findsNothing);
    expect(find.byTooltip('Remove Ari Santos'), findsNothing);
    await tester.tap(find.text('Your classrooms'));
    await tester.pumpAndSettle();
    expect(find.text('Grade 11 - STEM A'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
}

class _FakeInstructorReportsRepository implements InstructorReportsRepository {
  @override
  Future<List<InstructorReportClassroom>> loadReports() async => [
    InstructorReportClassroom(
      id: 'test-id',
      name: 'Grade 11 - STEM A',
      subject: 'General Biology 1',
      studentCount: 1,
      activityCount: 0,
      averageScore: null,
      students: [
        InstructorReportStudent(
          id: 12,
          fullName: 'Ari Santos',
          email: 'ari@example.com',
          role: 'student',
          joinedAt: DateTime.utc(2026, 10, 1),
          createdAt: DateTime.utc(2026, 9, 1),
          completedActivityCount: 0,
          totalActivityCount: 0,
          attemptCount: 0,
          averageScore: null,
          generatedQuizCount: 3,
          personalAttemptCount: 7,
          personalAverageScore: 85,
          accuracyPercentage: 81,
          retentionPercentage: 72,
          improvementPercentage: 64,
          consistencyPercentage: 59,
          focusPercentage: 77,
        ),
      ],
    ),
  ];
}

class _FakeClassroomRepository implements ClassroomRepository {
  final List<ClassroomModel> classrooms = [];
  final List<ClassroomStudentSummary> students = [];
  final List<int> removedStudents = [];
  int totalStudentCount = 0;
  String? createdName;
  String? createdSubject;
  String? createdIconKey;

  @override
  Future<List<ClassroomStudentSummary>> classroomStudents(
    String classroomId,
  ) async => students;

  @override
  Future<List<ClassroomStudentSummary>> classroomClassmates(
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
  Future<InstructorDashboardStats> getInstructorDashboardStats() async =>
      InstructorDashboardStats(
        studentCount: totalStudentCount,
        activeClassCount: classrooms.length,
      );

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
  Future<ClassroomModel> joinClassroom({required String code}) async =>
      classrooms.firstWhere(
        (classroom) => classroom.code == code.toUpperCase(),
      );
}
