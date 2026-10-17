import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:thesis_repo_renew/models/classroom_model.dart';
import 'package:thesis_repo_renew/models/user_model.dart';
import 'package:thesis_repo_renew/screens/home/student_home_screen.dart';
import 'package:thesis_repo_renew/services/classroom_service.dart';
import 'package:thesis_repo_renew/services/quiz_service.dart';

void main() {
  testWidgets('dashboard stacks calendar and pending activities on mobile', (
    tester,
  ) async {
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    tester.view.physicalSize = const Size(400, 800);
    tester.view.devicePixelRatio = 1;

    await tester.pumpWidget(
      MaterialApp(
        home: StudentHomeScreen(
          user: const UserModel(
            id: 1,
            fullName: 'Student Name',
            email: 'student@example.com',
            role: 'student',
          ),
          classroomService: _FakeClassroomRepository(),
        ),
      ),
    );
    await tester.pumpAndSettle();
    await tester.drag(
      find.byType(SingleChildScrollView).first,
      const Offset(0, -1800),
    );
    await tester.pumpAndSettle();

    expect(find.text('Classroom deadlines'), findsOneWidget);
    expect(find.text('Pending activities'), findsOneWidget);
    expect(
      tester.getTopLeft(find.text('Classroom deadlines')).dy,
      lessThan(tester.getTopLeft(find.text('Pending activities')).dy),
    );
    expect(tester.takeException(), isNull);
  });

  testWidgets('dashboard shows classroom deadlines and launches an activity', (
    tester,
  ) async {
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    tester.view.physicalSize = const Size(1280, 900);
    tester.view.devicePixelRatio = 1;

    final now = DateTime.now();
    final deadline = now.add(const Duration(days: 2));
    final repository = _FakeClassroomRepository()
      ..activities.add(
        ClassroomActivity(
          id: 'activity-id',
          classroomId: 'classroom-id',
          classroomName: 'Biology',
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
          deadlineAt: deadline,
        ),
      )
      ..activities.add(
        ClassroomActivity(
          id: 'upcoming-activity-id',
          classroomId: 'classroom-id',
          classroomName: 'Biology',
          quizId: 'upcoming-quiz-id',
          title: 'Cell Review',
          sourceFile: 'review.pdf',
          questions: const [
            QuizQuestion(
              question: 'What is a cell?',
              options: [
                'Basic unit of life',
                'A tissue',
                'An organ',
                'A molecule',
              ],
              answerIndex: 0,
              explanation: 'Cells are the basic unit of life.',
            ),
          ],
          startsAt: now.add(const Duration(hours: 1)),
          deadlineAt: deadline,
        ),
      );

    await tester.pumpWidget(
      MaterialApp(
        home: StudentHomeScreen(
          user: const UserModel(
            id: 1,
            fullName: 'Student Name',
            email: 'student@example.com',
            role: 'student',
          ),
          classroomService: repository,
        ),
      ),
    );
    await tester.pumpAndSettle();

    await tester.drag(
      find.byType(SingleChildScrollView).first,
      const Offset(0, -1200),
    );
    await tester.pumpAndSettle();

    expect(find.text('Classroom deadlines'), findsOneWidget);
    expect(find.text('Pending activities'), findsOneWidget);
    expect(find.text('Cell Structure'), findsOneWidget);
    expect(find.text('Classroom: Biology'), findsNWidgets(2));
    expect(
      find.text('biology.pdf · 1 questions · 2 attempts left'),
      findsOneWidget,
    );
    expect(find.text('Cell Review'), findsOneWidget);
    expect(find.text('Available soon'), findsOneWidget);
    expect(
      tester
          .widget<FilledButton>(
            find.widgetWithText(FilledButton, 'Available soon'),
          )
          .onPressed,
      isNull,
    );
    expect(find.text('Take activity'), findsOneWidget);
    expect(
      tester.getTopLeft(find.text('Classroom deadlines')).dx,
      lessThan(tester.getTopLeft(find.text('Pending activities')).dx),
    );

    await tester.tap(find.bySemanticsLabel('${deadline.day}, 2 deadlines'));
    await tester.pumpAndSettle();

    final activitiesDialog = find.byType(AlertDialog);
    expect(
      find.descendant(
        of: activitiesDialog,
        matching: find.text('Cell Structure'),
      ),
      findsOneWidget,
    );
    expect(
      find.descendant(of: activitiesDialog, matching: find.text('Cell Review')),
      findsOneWidget,
    );
    expect(
      find.descendant(
        of: activitiesDialog,
        matching: find.textContaining('Available from'),
      ),
      findsOneWidget,
    );
    expect(
      find.descendant(
        of: activitiesDialog,
        matching: find.text(
          MaterialLocalizations.of(
            tester.element(find.text('Classroom deadlines')),
          ).formatFullDate(deadline.toLocal()),
        ),
      ),
      findsOneWidget,
    );
    expect(
      find.descendant(
        of: activitiesDialog,
        matching: find.text('Take activity'),
      ),
      findsNothing,
    );
    expect(
      find.descendant(
        of: activitiesDialog,
        matching: find.byType(FilledButton),
      ),
      findsNothing,
    );

    await tester.tap(
      find.descendant(of: activitiesDialog, matching: find.text('Close')),
    );
    await tester.pumpAndSettle();
    expect(find.byType(AlertDialog), findsNothing);

    await tester.tap(find.text('Take activity'));
    await tester.pumpAndSettle();

    expect(find.text('Take your quiz'), findsOneWidget);
    expect(find.text('Which organelle stores DNA?'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
}

class _FakeClassroomRepository implements ClassroomRepository {
  final activities = <ClassroomActivity>[];
  final classroom = ClassroomModel(
    id: 'classroom-id',
    name: 'Biology',
    subject: 'General Biology',
    code: 'ABCD2345',
    createdAt: DateTime.utc(2026),
  );

  @override
  Future<List<ClassroomActivity>> classroomActivities(
    String classroomId,
  ) async => activities
      .where((activity) => activity.classroomId == classroomId)
      .toList(growable: false);

  @override
  Future<InstructorDashboardStats> getInstructorDashboardStats() async =>
      const InstructorDashboardStats(studentCount: 0, activeClassCount: 0);

  @override
  Future<ClassroomModel> createClassroom({
    required String name,
    required String subject,
    required String iconKey,
  }) async => throw UnimplementedError();

  @override
  Future<ClassroomModel> joinClassroom({required String code}) async =>
      throw UnimplementedError();

  @override
  Future<List<ClassroomModel>> listClassrooms() async => [classroom];

  @override
  Future<List<ClassroomModel>> listStudentClassrooms() async => [classroom];
}
