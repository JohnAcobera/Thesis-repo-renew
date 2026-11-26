import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:thesis_repo_renew/models/instructor_report.dart';
import 'package:thesis_repo_renew/screens/instructor_attention_section.dart';
import 'package:thesis_repo_renew/services/instructor_reports_service.dart';
import 'package:thesis_repo_renew/services/instructor_student_feedback_service.dart';

void main() {
  testWidgets('shows the same low-stat students and metrics as reports', (
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

    expect(find.text('Students with low stats'), findsOneWidget);
    expect(find.text('Needs Support Student'), findsOneWidget);
    expect(
      find.byKey(const ValueKey('student-insight-class-a-5')),
      findsOneWidget,
    );
    expect(find.text('Classroom completion 0%'), findsOneWidget);
    expect(find.text('Low quiz average: 45%'), findsNothing);
    expect(find.text('Healthy Student'), findsNothing);
    expect(tester.takeException(), isNull);
  });

  testWidgets('sends editable encouragement from a dashboard insight', (
    tester,
  ) async {
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    tester.view.physicalSize = const Size(400, 1000);
    tester.view.devicePixelRatio = 1;
    final feedbackRepository = _FakeInstructorStudentFeedbackRepository();

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: SingleChildScrollView(
              child: InstructorAttentionSection(
                reportsRepository: _FakeInstructorReportsRepository(),
                feedbackRepository: feedbackRepository,
              ),
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.byKey(const ValueKey('student-insight-class-a-5')));
    await tester.pumpAndSettle();

    final messageField = find.byKey(const ValueKey('student-feedback-message'));
    expect(messageField, findsOneWidget);
    expect(find.text('Send encouragement'), findsOneWidget);
    await tester.enterText(messageField, 'Hi Sam! You can do this.');
    await tester.tap(find.text('Send encouragement'));
    await tester.pumpAndSettle();

    expect(feedbackRepository.studentId, 5);
    expect(feedbackRepository.classroomId, 'class-a');
    expect(feedbackRepository.metric, 'Classroom completion');
    expect(feedbackRepository.message, 'Hi Sam! You can do this.');
    expect(find.text('Encouragement sent to the student.'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('limits the flagged-student list and lets it scroll', (
    tester,
  ) async {
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    tester.view.physicalSize = const Size(400, 700);
    tester.view.devicePixelRatio = 1;

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: SingleChildScrollView(
              child: InstructorAttentionSection(
                reportsRepository: _ManyLowStatsRepository(),
                panelHeight: 420,
              ),
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    final list = find.byKey(const ValueKey('instructor-low-stats-list'));
    final panel = find.byKey(const ValueKey('instructor-low-stats-panel'));
    expect(list, findsOneWidget);
    expect(tester.getSize(panel).height, 420);
    expect(tester.getSize(list).height, lessThanOrEqualTo(360));

    await tester.drag(list, const Offset(0, -1200));
    await tester.pumpAndSettle();

    final lastStudent = find.byKey(
      const ValueKey('student-insight-class-scroll-111'),
    );
    expect(lastStudent, findsOneWidget);
    expect(
      tester.getRect(lastStudent).bottom,
      lessThanOrEqualTo(tester.getRect(list).bottom),
    );
    expect(tester.takeException(), isNull);
  });
}

class _FakeInstructorStudentFeedbackRepository
    implements InstructorStudentFeedbackRepository {
  int? studentId;
  String? classroomId;
  String? metric;
  String? message;

  @override
  Future<void> sendStudentFeedback({
    required int studentId,
    required String classroomId,
    required String metric,
    required String message,
  }) async {
    this.studentId = studentId;
    this.classroomId = classroomId;
    this.metric = metric;
    this.message = message;
  }
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

class _ManyLowStatsRepository implements InstructorReportsRepository {
  @override
  Future<List<InstructorReportClassroom>> loadReports() async => [
    InstructorReportClassroom(
      id: 'class-scroll',
      name: 'Demo classroom',
      subject: 'Demo subject',
      studentCount: 12,
      activityCount: 0,
      averageScore: null,
      students: List.generate(
        12,
        (index) => _student(
          id: 100 + index,
          fullName: 'Low Student $index',
          email: 'low$index@example.test',
          completedActivityCount: 0,
          totalActivityCount: 1,
          averageScore: null,
        ),
      ),
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
