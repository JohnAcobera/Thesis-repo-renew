import 'instructor_notification_service.dart';
import 'student_notification_service.dart';

/// One notification service per app session, shared by every screen.
///
/// Without this, each screen's nav bar created its own service (and its own
/// realtime channel), so navigating to Profile could show an empty badge until
/// the sheet was opened and that instance loaded its data.
class NotificationRepositories {
  NotificationRepositories._();

  static StudentNotificationRepository? _student;
  static InstructorNotificationRepository? _instructor;

  static StudentNotificationRepository get student =>
      _student ??= StudentNotificationService();

  static InstructorNotificationRepository get instructor =>
      _instructor ??= InstructorNotificationService();

  /// Call on logout so the next account does not reuse cached notification
  /// state from the previous one.
  static void reset() {
    _student = null;
    _instructor = null;
  }
}
