import 'dart:async';

import 'package:supabase_flutter/supabase_flutter.dart';

import 'auth_service.dart';

abstract interface class InstructorNotificationRepository {
  Future<List<InstructorNotification>> listNotifications();

  Stream<List<InstructorNotification>> watchNotifications();

  Future<int> unreadCount();

  Future<void> refreshNotifications();

  Future<void> markNotificationsRead(List<String> notificationIds);
}

enum InstructorNotificationType { studentJoined, todoDue, legacy }

class InstructorNotification {
  const InstructorNotification({
    required this.id,
    required this.type,
    required this.title,
    required this.message,
    required this.createdAt,
    required this.isRead,
    this.classroomId,
    this.todoTaskId,
  });

  final String id;
  final InstructorNotificationType type;
  final String title;
  final String message;
  final DateTime createdAt;
  final bool isRead;
  final String? classroomId;
  final String? todoTaskId;

  factory InstructorNotification.fromJson(Map<String, dynamic> json) {
    final typeName = json['type'] as String;
    final type = typeName == 'quizAnswered'
        ? InstructorNotificationType.legacy
        : InstructorNotificationType.values.firstWhere(
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

  late final StreamController<List<InstructorNotification>> _updates =
      StreamController<List<InstructorNotification>>.broadcast(
        onListen: _startWatching,
        onCancel: _stopWatching,
      );
  RealtimeChannel? _channel;
  int _refreshRequest = 0;

  SupabaseClient get _supabase => _client ?? Supabase.instance.client;
  AuthService get _auth => _authService ?? AuthService();

  @override
  Stream<List<InstructorNotification>> watchNotifications() => _updates.stream;

  @override
  Future<int> unreadCount() async {
    final token = await _requireSessionToken();
    try {
      return await _supabase.rpc<int>(
        'get_instructor_notification_unread_count',
        params: {'p_session_token': token},
      );
    } on PostgrestException catch (error) {
      throw InstructorNotificationException(
        _databaseMessage(
          error,
          fallback: 'Your notifications could not be loaded. Please try again.',
        ),
      );
    }
  }

  // Widget tests (and any pre-initialize use) construct the service without a
  // client. Realtime is optional there; the initial list fetch still works.
  SupabaseClient? _tryGetClient() {
    if (_client != null) return _client;
    try {
      return Supabase.instance.client;
    } on Object {
      return null;
    }
  }

  void _startWatching() {
    final client = _tryGetClient();
    if (client == null) return;
    _channel = client
        .channel('instructor-notifications')
        .onBroadcast(
          event: 'instructor_notifications_changed',
          callback: (_) => unawaited(_reloadNotifications()),
        )
        .subscribe((status, error) {
          if (status == RealtimeSubscribeStatus.subscribed) {
            unawaited(_reloadNotifications());
          } else if (status == RealtimeSubscribeStatus.channelError ||
              status == RealtimeSubscribeStatus.timedOut) {
            _updates.addError(
              const InstructorNotificationException(
                'Live notification updates are temporarily unavailable.',
              ),
              StackTrace.current,
            );
          }
        });
    // Don't depend on the `subscribed` callback for the first load; the badge
    // must be populated even when realtime is unavailable.
    unawaited(_reloadNotifications());
  }

  void _stopWatching() {
    final channel = _channel;
    _channel = null;
    if (channel != null) {
      final client = _tryGetClient();
      if (client != null) unawaited(client.removeChannel(channel));
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
