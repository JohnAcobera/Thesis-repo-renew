import 'package:supabase_flutter/supabase_flutter.dart';

import 'auth_service.dart';

abstract interface class InstructorNotificationRepository {
  Future<List<InstructorNotification>> listNotifications();

  Future<void> markNotificationsRead(List<String> notificationIds);
}

enum InstructorNotificationType {
  quizAnswered,
  studentJoined,
  activityDeadline,
}

class InstructorNotification {
  const InstructorNotification({
    required this.id,
    required this.type,
    required this.title,
    required this.message,
    required this.createdAt,
    required this.isRead,
    this.classroomId,
  });

  final String id;
  final InstructorNotificationType type;
  final String title;
  final String message;
  final DateTime createdAt;
  final bool isRead;
  final String? classroomId;

  factory InstructorNotification.fromJson(Map<String, dynamic> json) {
    final typeName = json['type'] as String;
    final type = InstructorNotificationType.values.firstWhere(
      (value) => value.name == typeName,
      orElse: () => throw FormatException(
        'Unknown instructor notification type: $typeName',
      ),
    );
    return InstructorNotification(
      id: json['id'] as String,
      type: type,
      title: json['title'] as String,
      message: json['message'] as String,
      createdAt: DateTime.parse(json['created_at'] as String),
      isRead: json['is_read'] as bool,
      classroomId: json['classroom_id'] as String?,
    );
  }
}

class InstructorNotificationException implements Exception {
  const InstructorNotificationException(this.message);

  final String message;

  @override
  String toString() => message;
}

class InstructorNotificationService
    implements InstructorNotificationRepository {
  InstructorNotificationService({
    SupabaseClient? client,
    AuthService? authService,
  }) : _client = client,
       _authService = authService;

  final SupabaseClient? _client;
  final AuthService? _authService;

  SupabaseClient get _supabase => _client ?? Supabase.instance.client;
  AuthService get _auth => _authService ?? AuthService();

  @override
  Future<List<InstructorNotification>> listNotifications() async {
    final token = await _requireSessionToken();
    try {
      final response = await _supabase.rpc<List<dynamic>>(
        'list_instructor_notifications',
        params: {'p_session_token': token},
      );
      return response
          .map(
            (row) => InstructorNotification.fromJson(
              Map<String, dynamic>.from(row as Map),
            ),
          )
          .toList(growable: false);
    } on PostgrestException catch (error) {
      throw InstructorNotificationException(
        _databaseMessage(
          error,
          fallback: error.code == 'PGRST202' || error.code == '42883'
              ? 'Instructor notifications are not configured. Run '
                    'supabase/instructor_notifications.sql in the Supabase '
                    'SQL Editor, then reload the app.'
              : 'Your notifications could not be loaded. Please try again.',
        ),
      );
    } on FormatException {
      throw const InstructorNotificationException(
        'Your notifications could not be read. Please try again.',
      );
    } on TypeError {
      throw const InstructorNotificationException(
        'Your notifications could not be read. Please try again.',
      );
    }
  }

  @override
  Future<void> markNotificationsRead(List<String> notificationIds) async {
    if (notificationIds.isEmpty) return;
    final token = await _requireSessionToken();
    try {
      await _supabase.rpc<void>(
        'mark_instructor_notifications_read',
        params: {
          'p_session_token': token,
          'p_notification_ids': notificationIds,
        },
      );
    } on PostgrestException catch (error) {
      throw InstructorNotificationException(
        _databaseMessage(
          error,
          fallback: error.code == 'PGRST202' || error.code == '42883'
              ? 'Instructor notifications are not configured. Run '
                    'supabase/instructor_notifications.sql in the Supabase '
                    'SQL Editor, then reload the app.'
              : 'Notifications could not be marked as read. Please try again.',
        ),
      );
    }
  }

  Future<String> _requireSessionToken() async {
    final token = await _auth.getSessionToken();
    if (token == null || token.isEmpty) {
      throw const InstructorNotificationException(
        'Your session has expired. Please log in again.',
      );
    }
    return token;
  }

  String _databaseMessage(
    PostgrestException error, {
    required String fallback,
  }) => error.message.contains('Invalid or expired session')
      ? 'Your session has expired. Please log in again.'
      : fallback;
}
