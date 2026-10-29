import 'dart:async';

import 'package:supabase_flutter/supabase_flutter.dart';

import 'auth_service.dart';

abstract interface class StudentNotificationRepository {
  Future<List<StudentNotification>> listNotifications();

  Stream<List<StudentNotification>> watchNotifications();

  Future<void> refreshNotifications();

  Future<void> markNotificationsRead(List<String> notificationIds);
}

enum StudentNotificationType {
  dailyPoints,
  streakEnded,
  quizPoints,
  weeklyRank,
  classroomActivity,
  classroomJoined,
  classroomRemoved,
}

class StudentNotification {
  const StudentNotification({
    required this.id,
    required this.type,
    required this.title,
    required this.message,
    required this.createdAt,
    required this.isRead,
    this.classroomId,
  });

  final String id;
  final StudentNotificationType type;
  final String title;
  final String message;
  final DateTime createdAt;
  final bool isRead;
  final String? classroomId;

  factory StudentNotification.fromJson(Map<String, dynamic> json) {
    final typeName = json['type'] as String;
    final type = StudentNotificationType.values.firstWhere(
      (value) => value.name == typeName,
      orElse: () =>
          throw FormatException('Unknown student notification type: $typeName'),
    );
    return StudentNotification(
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

class StudentNotificationException implements Exception {
  const StudentNotificationException(this.message);

  final String message;

  @override
  String toString() => message;
}

class StudentNotificationService implements StudentNotificationRepository {
  StudentNotificationService({SupabaseClient? client, AuthService? authService})
    : _client = client,
      _authService = authService;

  final SupabaseClient? _client;
  final AuthService? _authService;
  late final StreamController<List<StudentNotification>> _updates =
      StreamController<List<StudentNotification>>.broadcast(
        onListen: _startWatching,
        onCancel: _stopWatching,
      );
  RealtimeChannel? _channel;
  int _refreshRequest = 0;

  SupabaseClient get _supabase => _client ?? Supabase.instance.client;
  AuthService get _auth => _authService ?? AuthService();

  @override
  Stream<List<StudentNotification>> watchNotifications() => _updates.stream;

  void _startWatching() {
    _channel = _supabase
        .channel('student-notifications')
        .onBroadcast(
          event: 'student_notifications_changed',
          callback: (_) => unawaited(_reloadNotifications()),
        )
        .subscribe((status, error) {
          if (status == RealtimeSubscribeStatus.subscribed) {
            unawaited(_reloadNotifications());
          } else if (status == RealtimeSubscribeStatus.channelError ||
              status == RealtimeSubscribeStatus.timedOut) {
            _updates.addError(
              const StudentNotificationException(
                'Live notification updates are temporarily unavailable.',
              ),
              StackTrace.current,
            );
          }
        });
    unawaited(_reloadNotifications());
  }

  void _stopWatching() {
    final channel = _channel;
    _channel = null;
    if (channel != null) {
      unawaited(_supabase.removeChannel(channel));
    }
  }

  Future<void> _reloadNotifications() async {
    final request = ++_refreshRequest;
    try {
      final notifications = await listNotifications();
      if (request == _refreshRequest && _updates.hasListener) {
        _updates.add(notifications);
      }
    } on Object catch (error, stackTrace) {
      if (request == _refreshRequest && _updates.hasListener) {
        _updates.addError(error, stackTrace);
      }
    }
  }

  @override
  Future<void> refreshNotifications() async {
    final request = ++_refreshRequest;
    final notifications = await listNotifications();
    if (request == _refreshRequest) _updates.add(notifications);
  }

  @override
  Future<List<StudentNotification>> listNotifications() async {
    final token = await _requireSessionToken();
    try {
      final response = await _supabase.rpc<List<dynamic>>(
        'list_student_notifications',
        params: {'p_session_token': token},
      );
      return response
          .map(
            (row) => StudentNotification.fromJson(
              Map<String, dynamic>.from(row as Map),
            ),
          )
          .toList(growable: false);
    } on PostgrestException catch (error) {
      throw StudentNotificationException(
        _databaseMessage(
          error,
          fallback: error.code == 'PGRST202' || error.code == '42883'
              ? 'Student notifications are not configured. Run '
                    'supabase/student_notifications.sql in the Supabase SQL '
                    'Editor, then reload the app.'
              : 'Your notifications could not be loaded. Please try again.',
        ),
      );
    } on FormatException {
      throw const StudentNotificationException(
        'Your notifications could not be read. Please try again.',
      );
    } on TypeError {
      throw const StudentNotificationException(
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
        'mark_student_notifications_read',
        params: {
          'p_session_token': token,
          'p_notification_ids': notificationIds,
        },
      );
    } on PostgrestException catch (error) {
      throw StudentNotificationException(
        _databaseMessage(
          error,
          fallback: error.code == 'PGRST202' || error.code == '42883'
              ? 'Student notifications are not configured. Run '
                    'supabase/student_notifications.sql in the Supabase SQL '
                    'Editor, then reload the app.'
              : 'Notifications could not be marked as read. Please try again.',
        ),
      );
    }
  }

  Future<String> _requireSessionToken() async {
    final token = await _auth.getSessionToken();
    if (token == null || token.isEmpty) {
      throw const StudentNotificationException(
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
