import 'dart:async';

import 'package:flutter/material.dart';

import '../services/student_notification_service.dart';

class StudentNotificationsButton extends StatefulWidget {
  const StudentNotificationsButton({
    this.repository,
    this.onNotificationSelected,
    super.key,
  });

  final StudentNotificationRepository? repository;
  final ValueChanged<StudentNotification>? onNotificationSelected;

  @override
  State<StudentNotificationsButton> createState() =>
      _StudentNotificationsButtonState();
}

class _StudentNotificationsButtonState
    extends State<StudentNotificationsButton> {
  late StudentNotificationRepository _repository;
  late Future<List<StudentNotification>> _notifications;
  late Stream<List<StudentNotification>> _notificationUpdates;
  StreamSubscription<List<StudentNotification>>? _notificationSubscription;
  List<StudentNotification>? _latestNotifications;

  @override
  void initState() {
    super.initState();
    _repository = widget.repository ?? StudentNotificationService();
    _startWatching();
  }

  @override
  void didUpdateWidget(covariant StudentNotificationsButton oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.repository != widget.repository) {
      unawaited(_notificationSubscription?.cancel());
      _repository = widget.repository ?? StudentNotificationService();
      _latestNotifications = null;
      _startWatching();
    }
  }

  void _startWatching() {
    _notifications = _repository.listNotifications();
    _notificationUpdates = _repository.watchNotifications();
    _notificationSubscription = _notificationUpdates.listen(
      (notifications) {
        _latestNotifications = notifications;
        if (mounted) {
          setState(() {});
        }
      },
      onError: (Object error, StackTrace stackTrace) {
        if (mounted) setState(() {});
      },
    );
  }

  @override
  void dispose() {
    unawaited(_notificationSubscription?.cancel());
    super.dispose();
  }

  Future<void> _openNotifications() async {
    final selectedNotification =
        await showModalBottomSheet<StudentNotification>(
          context: context,
          isScrollControlled: true,
          useSafeArea: true,
          backgroundColor: Colors.transparent,
          builder: (_) => StudentNotificationsSheet(
            repository: _repository,
            notifications: _notificationUpdates,
            initialNotifications: _latestNotifications,
          ),
        );
    if (mounted) {
      if (selectedNotification != null) {
        widget.onNotificationSelected?.call(selectedNotification);
      }
    }
  }

  @override
  Widget build(BuildContext context) =>
      FutureBuilder<List<StudentNotification>>(
        future: _notifications,
        builder: (context, snapshot) {
          final unreadCount =
              (_latestNotifications ?? snapshot.data)
                  ?.where((notification) => !notification.isRead)
                  .length ??
              0;
          return IconButton(
            tooltip: 'Notifications',
            onPressed: _openNotifications,
            icon: Stack(
              clipBehavior: Clip.none,
              children: [
                const Icon(Icons.notifications_none_rounded),
                if (unreadCount > 0)
                  Positioned(
                    right: -7,
                    top: -6,
                    child: Container(
                      constraints: const BoxConstraints(
                        minWidth: 17,
                        minHeight: 17,
                      ),
                      alignment: Alignment.center,
                      padding: const EdgeInsets.symmetric(horizontal: 4),
                      decoration: const BoxDecoration(
                        color: Color(0xFFE34D3D),
                        shape: BoxShape.circle,
                      ),
                      child: Text(
                        unreadCount > 99 ? '99+' : '$unreadCount',
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 9,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ),
                  ),
              ],
            ),
          );
        },
      );
}

class StudentNotificationsSheet extends StatefulWidget {
  const StudentNotificationsSheet({
    required this.repository,
    required this.notifications,
    this.initialNotifications,
    super.key,
  });

  final StudentNotificationRepository repository;
  final Stream<List<StudentNotification>> notifications;
  final List<StudentNotification>? initialNotifications;

  @override
  State<StudentNotificationsSheet> createState() =>
      _StudentNotificationsSheetState();
}

class _StudentNotificationsSheetState extends State<StudentNotificationsSheet> {
  bool _isMarkingRead = false;
  String? _markingReadId;
  String? _markReadError;

  Future<void> _markAllRead(List<StudentNotification> notifications) async {
    final unreadIds = notifications
        .where((notification) => !notification.isRead)
        .map((notification) => notification.id)
        .toList(growable: false);
    if (unreadIds.isEmpty) return;

    setState(() {
      _isMarkingRead = true;
      _markReadError = null;
    });
    try {
      await widget.repository.markNotificationsRead(unreadIds);
    } on StudentNotificationException catch (error) {
      if (mounted) {
        setState(() => _markReadError = error.message);
      }
    } finally {
      if (mounted) {
        setState(() => _isMarkingRead = false);
      }
    }
  }

  Future<void> _retry() async {
    try {
      setState(() => _markReadError = null);
      await widget.repository.refreshNotifications();
    } on StudentNotificationException catch (error) {
      if (mounted) {
        setState(() => _markReadError = error.message);
      }
    }
  }

  Future<void> _onNotificationTap(
    BuildContext context,
    StudentNotification notification,
  ) async {
    if (_isMarkingRead) return;
    setState(() {
      _isMarkingRead = true;
      _markingReadId = notification.id;
      _markReadError = null;
    });
    try {
      if (!notification.isRead) {
        await widget.repository.markNotificationsRead([notification.id]);
      }
      if (!context.mounted) return;
      if (notification.type == StudentNotificationType.classroomActivity &&
          notification.classroomId != null) {
        Navigator.of(context).pop(notification);
      }
    } on StudentNotificationException catch (error) {
      if (mounted) {
        setState(() => _markReadError = error.message);
      }
    } finally {
      if (mounted) {
        setState(() {
          _isMarkingRead = false;
          _markingReadId = null;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) => FractionallySizedBox(
    heightFactor: 0.82,
    child: DecoratedBox(
      decoration: const BoxDecoration(
        color: Color(0xFFFFFCF8),
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      child: Column(
        children: [
          const SizedBox(height: 10),
          Container(
            width: 38,
            height: 4,
            decoration: BoxDecoration(
              color: const Color(0xFFD9C6B5),
              borderRadius: BorderRadius.circular(8),
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 16, 12, 12),
            child: Row(
              children: [
                const Expanded(
                  child: Text(
                    'Notifications',
                    style: TextStyle(
                      color: Color(0xFF3B2419),
                      fontSize: 20,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
                IconButton(
                  tooltip: 'Refresh notifications',
                  onPressed: _retry,
                  icon: const Icon(Icons.refresh_rounded),
                ),
              ],
            ),
          ),
          Expanded(
            child: StreamBuilder<List<StudentNotification>>(
              stream: widget.notifications,
              initialData: widget.initialNotifications,
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting &&
                    !snapshot.hasData) {
                  return const Center(
                    child: CircularProgressIndicator(color: Color(0xFFF4773C)),
                  );
                }
                if (snapshot.hasError) {
                  return _NotificationLoadError(
                    message: snapshot.error is StudentNotificationException
                        ? (snapshot.error! as StudentNotificationException)
                              .message
                        : 'Your notifications could not be loaded.',
                    onRetry: () => _retry(),
                  );
                }
                final notifications = snapshot.data ?? const [];
                if (notifications.isEmpty) {
                  return const _NotificationEmptyState();
                }
                final unreadCount = notifications
                    .where((notification) => !notification.isRead)
                    .length;
                return Column(
                  children: [
                    if (unreadCount > 0)
                      Align(
                        alignment: Alignment.centerRight,
                        child: Padding(
                          padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
                          child: TextButton(
                            onPressed: _isMarkingRead
                                ? null
                                : () => _markAllRead(notifications),
                            child: _isMarkingRead
                                ? const SizedBox.square(
                                    dimension: 16,
                                    child: CircularProgressIndicator(
                                      strokeWidth: 2,
                                    ),
                                  )
                                : const Text('Mark all as read'),
                          ),
                        ),
                      ),
                    if (_markReadError case final error?)
                      Padding(
                        padding: const EdgeInsets.fromLTRB(20, 0, 20, 8),
                        child: Text(
                          error,
                          style: const TextStyle(color: Color(0xFFB3261E)),
                        ),
                      ),
                    Expanded(
                      child: ListView.separated(
                        padding: const EdgeInsets.fromLTRB(16, 0, 16, 24),
                        itemCount: notifications.length,
                        separatorBuilder: (_, _) => const SizedBox(height: 8),
                        itemBuilder: (context, index) {
                          final notification = notifications[index];
                          final canOpenReadClassroomActivity =
                              notification.type ==
                                  StudentNotificationType.classroomActivity &&
                              notification.classroomId != null;
                          return _NotificationTile(
                            notification: notification,
                            onTap:
                                _isMarkingRead ||
                                    (notification.isRead &&
                                        !canOpenReadClassroomActivity)
                                ? null
                                : () =>
                                      _onNotificationTap(context, notification),
                            isMarkingRead: _markingReadId == notification.id,
                          );
                        },
                      ),
                    ),
                  ],
                );
              },
            ),
          ),
        ],
      ),
    ),
  );
}

class _NotificationTile extends StatelessWidget {
  const _NotificationTile({
    required this.notification,
    required this.onTap,
    required this.isMarkingRead,
  });

  final StudentNotification notification;
  final VoidCallback? onTap;
  final bool isMarkingRead;

  @override
  Widget build(BuildContext context) => Material(
    color: Colors.transparent,
    child: InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(16),
      child: Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: notification.isRead
              ? const Color(0xFFFFFCF8)
              : const Color(0xFFFFF2E6),
          border: Border.all(
            color: notification.isRead
                ? const Color(0xFFE8D7C2)
                : const Color(0xFFFFD2B4),
          ),
          borderRadius: BorderRadius.circular(16),
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              width: 38,
              height: 38,
              decoration: const BoxDecoration(
                color: Color(0xFFFFE5D5),
                shape: BoxShape.circle,
              ),
              child: Icon(
                _iconFor(notification.type),
                size: 19,
                color: const Color(0xFFF4773C),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          notification.title,
                          style: const TextStyle(
                            color: Color(0xFF3B2419),
                            fontSize: 14,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ),
                      if (!notification.isRead)
                        const Padding(
                          padding: EdgeInsets.only(left: 8),
                          child: CircleAvatar(
                            radius: 4,
                            backgroundColor: Color(0xFFF4773C),
                          ),
                        ),
                      if (isMarkingRead)
                        const Padding(
                          padding: EdgeInsets.only(left: 8),
                          child: SizedBox.square(
                            dimension: 16,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          ),
                        )
                      else if (notification.type ==
                              StudentNotificationType.classroomActivity &&
                          notification.classroomId != null)
                        const Padding(
                          padding: EdgeInsets.only(left: 8),
                          child: Icon(
                            Icons.open_in_new_rounded,
                            size: 16,
                            color: Color(0xFFF4773C),
                          ),
                        ),
                    ],
                  ),
                  const SizedBox(height: 4),
                  Text(
                    notification.message,
                    style: const TextStyle(
                      color: Color(0xFF765C4F),
                      fontSize: 13,
                      height: 1.35,
                    ),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    _formatDate(notification.createdAt),
                    style: const TextStyle(
                      color: Color(0xFF9A8071),
                      fontSize: 11,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    ),
  );

  IconData _iconFor(StudentNotificationType type) => switch (type) {
    StudentNotificationType.dailyPoints => Icons.local_fire_department_outlined,
    StudentNotificationType.streakEnded => Icons.heart_broken_outlined,
    StudentNotificationType.quizPoints => Icons.quiz_outlined,
    StudentNotificationType.weeklyRank => Icons.emoji_events_outlined,
    StudentNotificationType.classroomActivity => Icons.campaign_outlined,
    StudentNotificationType.classroomJoined => Icons.group_add_outlined,
    StudentNotificationType.classroomRemoved => Icons.person_remove_outlined,
  };

  String _formatDate(DateTime date) {
    final localDate = date.toLocal();
    final difference = DateTime.now().difference(localDate);
    if (difference.inMinutes < 1) return 'Just now';
    if (difference.inHours < 1) return '${difference.inMinutes}m ago';
    if (difference.inDays < 1) return '${difference.inHours}h ago';
    if (difference.inDays < 7) return '${difference.inDays}d ago';
    return '${localDate.month}/${localDate.day}/${localDate.year}';
  }
}

class _NotificationEmptyState extends StatelessWidget {
  const _NotificationEmptyState();

  @override
  Widget build(BuildContext context) => const Center(
    child: Padding(
      padding: EdgeInsets.all(32),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            Icons.notifications_none_rounded,
            size: 42,
            color: Color(0xFFB89A86),
          ),
          SizedBox(height: 12),
          Text(
            "You're all caught up",
            style: TextStyle(
              color: Color(0xFF3B2419),
              fontWeight: FontWeight.w700,
            ),
          ),
          SizedBox(height: 4),
          Text(
            'Your learning and classroom updates will appear here.',
            textAlign: TextAlign.center,
            style: TextStyle(color: Color(0xFF765C4F)),
          ),
        ],
      ),
    ),
  );
}

class _NotificationLoadError extends StatelessWidget {
  const _NotificationLoadError({required this.message, required this.onRetry});

  final String message;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) => Center(
    child: Padding(
      padding: const EdgeInsets.all(24),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(message, textAlign: TextAlign.center),
          const SizedBox(height: 12),
          OutlinedButton.icon(
            onPressed: onRetry,
            icon: const Icon(Icons.refresh_rounded),
            label: const Text('Try again'),
          ),
        ],
      ),
    ),
  );
}
