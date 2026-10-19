import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:thesis_repo_renew/models/instructor_report.dart';
import 'package:thesis_repo_renew/screens/instructor_reports_screen.dart';
import 'package:thesis_repo_renew/services/instructor_reports_service.dart';

void main() {
  testWidgets('shows classroom scores and student account statistics', (
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
    expect(find.text('85%'), findsNWidgets(2));
    expect(find.text('Report Student'), findsOneWidget);

    await tester.ensureVisible(find.text('Report Student'));
    await tester.tap(find.text('Report Student'));
    await tester.pumpAndSettle();

    expect(find.text('ACCOUNT DETAILS'), findsOneWidget);
    expect(find.text('Role'), findsOneWidget);
    expect(find.text('Student'), findsOneWidget);
    expect(find.text('PERSONAL STATS'), findsOneWidget);
    expect(find.text('Quizzes generated'), findsOneWidget);
    expect(find.text('3'), findsOneWidget);
    expect(find.text('Overall average score'), findsOneWidget);
    expect(find.text('79.0%'), findsOneWidget);
    expect(find.text('Activities completed'), findsOneWidget);
    await tester.ensureVisible(find.text('YOUR STATS'));
    await tester.pumpAndSettle();
    expect(find.text('YOUR STATS'), findsOneWidget);
    expect(find.byType(CustomPaint), findsWidgets);
    expect(
      find.bySemanticsLabel(
        'Student dashboard stats. Accuracy 41 percent, '
        'Retention 53 percent, Improvement 18 percent, '
        'Consistency 26 percent, Focus 34 percent.',
      ),
      findsOneWidget,
    );
    expect(tester.takeException(), isNull);
  });
}

class _FakeInstructorReportsRepository implements InstructorReportsRepository {
  @override
  Future<List<InstructorReportClassroom>> loadReports() async => [
    InstructorReportClassroom(
      id: 'class-1',
      name: 'Grade 11 - STEM A',
      subject: 'General Biology 1',
      studentCount: 1,
      activityCount: 2,
      averageScore: 85,
      students: [
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
          accuracyPercentage: 41,
          retentionPercentage: 53,
          improvementPercentage: 18,
          consistencyPercentage: 26,
          focusPercentage: 34,
        ),
      ],
    ),
  ];
}
