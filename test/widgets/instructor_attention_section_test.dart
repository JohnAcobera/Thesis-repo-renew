import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:thesis_repo_renew/models/instructor_report.dart';
import 'package:thesis_repo_renew/screens/instructor_attention_section.dart';
import 'package:thesis_repo_renew/services/instructor_reports_service.dart';

void main() {
  testWidgets('deduplicates students and shows quiz concerns per classroom', (
    tester,
  ) async {
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    tester.view.physicalSize = const Size(400, 1000);
    tester.view.devicePixelRatio = 1;

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: SingleChildScrollView(
              child: InstructorAttentionSection(
                reportsRepository: _FakeInstructorReportsRepository(),
              ),
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('1 student needs follow-up'), findsOneWidget);
    expect(find.text('Needs Support Student'), findsOneWidget);
    expect(find.text('support@example.com'), findsOneWidget);
    expect(find.byKey(const ValueKey('attention-student-5')), findsOneWidget);
    expect(
      find.byKey(const ValueKey('attention-classroom-5-class-a')),
      findsOneWidget,
    );
    expect(
      find.byKey(const ValueKey('attention-classroom-5-class-b')),
      findsOneWidget,
    );
    expect(
      find.byKey(const ValueKey('attention-classroom-5-class-c')),
      findsOneWidget,
    );
    expect(find.text('No quiz attempts'), findsOneWidget);
    expect(find.text('Low quiz average: 45%'), findsOneWidget);
    expect(find.text('On track'), findsOneWidget);
    expect(find.text('Healthy Student'), findsNothing);
    expect(tester.takeException(), isNull);
  });
}

class _FakeInstructorReportsRepository implements InstructorReportsRepository {
  @override
  Future<List<InstructorReportClassroom>> loadReports() async => [
    InstructorReportClassroom(
      id: 'class-a',
      name: 'Grade 11 - STEM A',
      subject: 'Biology',
      studentCount: 2,
      activityCount: 2,
      averageScore: 75,
      students: [
        _student(
          id: 5,
          fullName: 'Needs Support Student',
          email: 'support@example.com',
          completedActivityCount: 0,
          totalActivityCount: 2,
          averageScore: null,
        ),
        _student(
          id: 6,
          fullName: 'Healthy Student',
          email: 'healthy@example.com',
          completedActivityCount: 2,
          totalActivityCount: 2,
          averageScore: 85,
        ),
      ],
    ),
    InstructorReportClassroom(
      id: 'class-b',
      name: 'Grade 11 - STEM B',
      subject: 'Chemistry',
      studentCount: 1,
      activityCount: 1,
      averageScore: 45,
      students: [
        _student(
          id: 5,
          fullName: 'Needs Support Student',
          email: 'support@example.com',
          completedActivityCount: 1,
          totalActivityCount: 1,
          averageScore: 45,
        ),
      ],
    ),
    InstructorReportClassroom(
      id: 'class-c',
      name: 'Grade 11 - STEM C',
      subject: 'Physics',
      studentCount: 1,
      activityCount: 0,
      averageScore: null,
      students: [
        _student(
          id: 5,
          fullName: 'Needs Support Student',
          email: 'support@example.com',
          completedActivityCount: 0,
          totalActivityCount: 0,
          averageScore: null,
        ),
      ],
    ),
  ];
}

InstructorReportStudent _student({
  required int id,
  required String fullName,
  required String email,
  required int completedActivityCount,
  required int totalActivityCount,
  required double? averageScore,
}) => InstructorReportStudent(
  id: id,
  fullName: fullName,
  email: email,
  role: 'student',
  joinedAt: DateTime(2025),
  createdAt: DateTime(2024),
  completedActivityCount: completedActivityCount,
  totalActivityCount: totalActivityCount,
  attemptCount: completedActivityCount,
  averageScore: averageScore,
  generatedQuizCount: 0,
  personalAttemptCount: completedActivityCount,
  personalAverageScore: averageScore,
);
