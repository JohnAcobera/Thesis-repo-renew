import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:thesis_repo_renew/services/instructor_notification_service.dart';
import 'package:thesis_repo_renew/widgets/student_nav_bar.dart';

void main() {
  test('legacy quiz-answer notifications are parsed as generic notices', () {
    final notification = InstructorNotification.fromJson({
      'id': 'legacy-notification',
      'type': 'quizAnswered',
      'title': 'Quiz completed',
      'message': 'A legacy notification.',
      'created_at': DateTime(2026, 10, 17).toIso8601String(),
      'is_read': true,
      'classroom_id': 'classroom-id',
    });

    expect(notification.type, InstructorNotificationType.legacy);
  });

  testWidgets('instructor notifications use the shared navbar bell and panel', (
    tester,
  ) async {
    final notifications = _FakeInstructorNotificationRepository();
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          appBar: StudentNavBar(
            roleLabel: 'Instructor',
            instructorNotificationRepository: notifications,
          ),
          body: const SizedBox.shrink(),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.byTooltip('Notifications'), findsOneWidget);
    expect(find.byIcon(Icons.notifications_none_rounded), findsOneWidget);
    expect(find.text('2'), findsOneWidget);

    await tester.tap(find.byTooltip('Notifications'));
    await tester.pumpAndSettle();

    expect(find.text('Notifications'), findsOneWidget);
    expect(find.text('Quiz completed'), findsOneWidget);
    expect(
      find.text(
        'Ari Santos completed "Cell Structure" in Biology and scored 8 out of 10.',
      ),
      findsOneWidget,
    );
    expect(find.text('A student joined your classroom'), findsOneWidget);
    await tester.tap(find.text('Quiz completed'));
    await tester.pumpAndSettle();
    expect(notifications.markedIds, ['quiz-answered:attempt-1']);
    expect(find.text('Mark all as read'), findsOneWidget);

    await tester.tap(find.text('Mark all as read'));
    await tester.pumpAndSettle();
    expect(notifications.markedIds, [
      'quiz-answered:attempt-1',
      'student-joined:class-1:student-1',
    ]);
    expect(find.text('Mark all as read'), findsNothing);
    expect(tester.takeException(), isNull);
  });
}

class _FakeInstructorNotificationRepository
    implements InstructorNotificationRepository {
  final Set<String> _readIds = {};
  final List<String> markedIds = [];

  @override
  Future<List<InstructorNotification>> listNotifications() async => [
    InstructorNotification(
      id: 'quiz-answered:attempt-1',
      type: InstructorNotificationType.legacy,
      title: 'Quiz completed',
      message:
          'Ari Santos completed "Cell Structure" in Biology and scored 8 out of 10.',
      createdAt: DateTime(2026, 10, 18, 12),
      isRead: _readIds.contains('quiz-answered:attempt-1'),
      classroomId: 'class-1',
    ),
    InstructorNotification(
      id: 'student-joined:class-1:student-1',
      type: InstructorNotificationType.studentJoined,
      title: 'A student joined your classroom',
      message: 'Ari Santos joined Biology.',
      createdAt: DateTime(2026, 10, 18, 11),
      isRead: _readIds.contains('student-joined:class-1:student-1'),
      classroomId: 'class-1',
    ),
  ];

  @override
  Future<void> markNotificationsRead(List<String> notificationIds) async {
    markedIds.addAll(notificationIds);
    _readIds.addAll(notificationIds);
  }
}
