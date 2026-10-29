import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:thesis_repo_renew/models/instructor_report.dart';
import 'package:thesis_repo_renew/screens/instructor_reports_screen.dart';
import 'package:thesis_repo_renew/services/instructor_reports_service.dart';

void main() {
  testWidgets('shows personal student statistics without classroom activity', (
    tester,
  ) async {
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    tester.view.physicalSize = const Size(400, 600);
    tester.view.devicePixelRatio = 1;

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: InstructorReportsScreen(
            reportsRepository: _FakeInstructorReportsRepository(),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Student performance'), findsOneWidget);
    expect(find.text('Grade 11 - STEM A'), findsOneWidget);
    expect(find.text('General Biology 1'), findsNothing);
    expect(find.text('85%'), findsNothing);
    expect(find.text('Report Student'), findsOneWidget);
    expect(find.text('Students with low stats'), findsOneWidget);
    expect(find.text('Improvement -18 pts'), findsOneWidget);
    expect(find.text('Consistency 26%'), findsNothing);

    await tester.ensureVisible(find.text('Report Student').last);
    await tester.tap(find.text('Report Student').last);
    await tester.pumpAndSettle();

    expect(find.text('Improvement'), findsOneWidget);
    expect(find.text('Consistency'), findsNothing);
    expect(find.text('Low stats for Report Student'), findsOneWidget);
    expect(find.text('-18 pts'), findsOneWidget);
    expect(
      find.bySemanticsLabel('Improvement chart for Report Student'),
      findsOneWidget,
    );
    expect(
      find.bySemanticsLabel('Consistency chart for Report Student'),
      findsNothing,
    );
    expect(
      find.text(
        'Shows whether scores tend to rise or fall when you retry quizzes. '
        'For example, 60% to 70% is a 10-point gain. The value is the average '
        'score change between retries; each bar represents a quiz, with bars '
        'above zero indicating improvement and bars below zero indicating a drop.',
      ),
      findsOneWidget,
    );
    expect(find.byType(CustomPaint), findsWidgets);
    expect(find.text('ACCOUNT DETAILS'), findsNothing);
    expect(tester.takeException(), isNull);
  });

  testWidgets('only older accounts receive low-stat insights', (tester) async {
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    tester.view.physicalSize = const Size(400, 800);
    tester.view.devicePixelRatio = 1;
    final now = DateTime.now();
    final students = [
      _student(31, 'Older Low Student', now.subtract(const Duration(days: 8))),
      _student(
        34,
        'At Threshold Student',
        now.subtract(const Duration(days: 9)),
        accuracyPercentage: 20,
        completedActivityCount: 2,
        totalActivityCount: 2,
        averageScore: 20,
        personalAverageScore: 20,
        retentionPercentage: 20,
        improvementPercentage: 20,
        consistencyPercentage: 20,
        focusPercentage: 20,
      ),
      _student(
        35,
        'No Improvement Student',
        now.subtract(const Duration(days: 10)),
        accuracyPercentage: 20,
        completedActivityCount: 2,
        totalActivityCount: 2,
        averageScore: 20,
        personalAverageScore: 20,
        retentionPercentage: 20,
        improvementPercentage: 0,
        consistencyPercentage: 20,
        focusPercentage: 20,
      ),
      _student(
        32,
        'Under Seven Day Student',
        now.subtract(const Duration(days: 6)),
      ),
      _student(
        33,
        'Not Yet Seven Day Student',
        now.subtract(const Duration(days: 7)).add(const Duration(minutes: 1)),
      ),
    ];

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: InstructorReportsScreen(
            reportsRepository: _FakeInstructorReportsRepository(
              students: students,
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(
      find.byKey(const ValueKey('student-insight-class-1-31')),
      findsOneWidget,
    );
    expect(find.text('Accuracy 19%'), findsOneWidget);
    expect(
      find.byKey(const ValueKey('student-insight-class-1-32')),
      findsNothing,
    );
    expect(
      find.byKey(const ValueKey('student-insight-class-1-33')),
      findsNothing,
    );
    expect(
      find.byKey(const ValueKey('student-insight-class-1-34')),
      findsNothing,
    );
    expect(
      find.byKey(const ValueKey('student-insight-class-1-35')),
      findsOneWidget,
    );
    expect(find.text('Improvement 0 pts'), findsOneWidget);
    expect(find.text('Improvement +20 pts'), findsNothing);
    expect(find.text('Accuracy 20%'), findsNothing);

    await tester.tap(find.text('Accuracy 19%'));
    await tester.pumpAndSettle();
    expect(find.text('Accuracy'), findsOneWidget);
    expect(find.text('Retention'), findsOneWidget);
    expect(find.text('Improvement'), findsNothing);
    expect(find.text('Consistency'), findsOneWidget);
    expect(find.text('Focus'), findsOneWidget);
    expect(find.text('Low stats for Older Low Student'), findsOneWidget);
    expect(
      find.bySemanticsLabel('Accuracy chart for Older Low Student'),
      findsOneWidget,
    );
    expect(
      find.bySemanticsLabel('Retention chart for Older Low Student'),
      findsOneWidget,
    );
    expect(
      find.bySemanticsLabel('Improvement chart for Older Low Student'),
      findsNothing,
    );
    expect(
      find.bySemanticsLabel('Consistency chart for Older Low Student'),
      findsOneWidget,
    );
    expect(
      find.bySemanticsLabel('Focus chart for Older Low Student'),
      findsOneWidget,
    );
    expect(
      find.text(
        'Percent correct across quiz attempts in the last 28 days, or since '
        'account creation if newer. The line shows recent attempt scores.',
      ),
      findsOneWidget,
    );
    expect(
      find.text(
        'Average score across each quiz’s two latest attempts. Quizzes with '
        'fewer than two attempts are skipped.',
      ),
      findsOneWidget,
    );
    expect(find.byType(CustomPaint), findsWidgets);
  });
}

class _FakeInstructorReportsRepository implements InstructorReportsRepository {
  _FakeInstructorReportsRepository({this.students});

  final List<InstructorReportStudent>? students;

  @override
  Future<List<InstructorReportClassroom>> loadReports() async => [
    InstructorReportClassroom(
      id: 'class-1',
      name: 'Grade 11 - STEM A',
      subject: 'General Biology 1',
      studentCount: students?.length ?? 1,
      activityCount: 2,
      averageScore: 85,
      students:
          students ??
          [
            InstructorReportStudent(
              id: 24,
              fullName: 'Report Student',
              email: 'student@example.com',
              role: 'student',
              joinedAt: DateTime(2025, 1, 10),
              createdAt: DateTime(2024, 9, 1),
              completedActivityCount: 1,
              totalActivityCount: 2,
              attemptCount: 2,
              averageScore: 85,
              generatedQuizCount: 3,
              personalAttemptCount: 5,
              personalAverageScore: 79,
              metricSamples: const {
                'accuracy': [65, 53, 41],
                'retention': [62, 53],
                'improvement': [-12, 4, 18],
                'consistency': [1, 0, 1, 0],
                'focus': [70, 55, 48],
              },
              accuracyPercentage: 41,
              retentionPercentage: 53,
              improvementPercentage: -18,
              consistencyPercentage: 26,
              focusPercentage: 34,
            ),
          ],
    ),
  ];
}

InstructorReportStudent _student(
  int id,
  String name,
  DateTime createdAt, {
  double accuracyPercentage = 19,
  int completedActivityCount = 0,
  int totalActivityCount = 2,
  double averageScore = 19,
  double personalAverageScore = 19,
  double retentionPercentage = 19,
  double improvementPercentage = 20,
  double consistencyPercentage = 19,
  double focusPercentage = 19,
}) => InstructorReportStudent(
  id: id,
  fullName: name,
  email: '$id@example.com',
  role: 'student',
  joinedAt: createdAt,
  createdAt: createdAt,
  completedActivityCount: completedActivityCount,
  totalActivityCount: totalActivityCount,
  attemptCount: 1,
  averageScore: averageScore,
  generatedQuizCount: 0,
  personalAttemptCount: 1,
  personalAverageScore: personalAverageScore,
  metricSamples: const {
    'accuracy': [40, 35, 30],
    'retention': [25, 20],
    'improvement': [-10, -5],
    'consistency': [1, 0, 0, 0],
    'focus': [30, 20],
  },
  accuracyPercentage: accuracyPercentage,
  retentionPercentage: retentionPercentage,
  improvementPercentage: improvementPercentage,
  consistencyPercentage: consistencyPercentage,
  focusPercentage: focusPercentage,
);
