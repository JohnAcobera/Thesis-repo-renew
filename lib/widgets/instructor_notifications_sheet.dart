import 'package:flutter/material.dart';

import '../services/instructor_notification_service.dart';

class InstructorNotificationsButton extends StatefulWidget {
  const InstructorNotificationsButton({required this.repository, super.key});

  final InstructorNotificationRepository repository;

  @override
  State<InstructorNotificationsButton> createState() =>
      _InstructorNotificationsButtonState();
}

class _InstructorNotificationsButtonState
    extends State<InstructorNotificationsButton> {
  late Future<List<InstructorNotification>> _notifications;

  @override
  void initState() {
    super.initState();
    _refresh();
  }

  void _refresh() {
    _notifications = widget.repository.listNotifications();
  }

  Future<void> _openNotifications() async {
    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      backgroundColor: Colors.transparent,
      builder: (_) =>
          InstructorNotificationsSheet(repository: widget.repository),
    );
    if (mounted) setState(_refresh);
  }

  @override
  Widget build(BuildContext context) =>
      FutureBuilder<List<InstructorNotification>>(
        future: _notifications,
        builder: (context, snapshot) {
          final unreadCount =
              snapshot.data
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

class InstructorNotificationsSheet extends StatefulWidget {
  const InstructorNotificationsSheet({required this.repository, super.key});

  final InstructorNotificationRepository repository;

  @override
  State<InstructorNotificationsSheet> createState() =>
      _InstructorNotificationsSheetState();
}

class _InstructorNotificationsSheetState
    extends State<InstructorNotificationsSheet> {
  late Future<List<InstructorNotification>> _notifications;
  bool _isMarkingRead = false;
  String? _markingReadId;
  String? _markReadError;

  @override
  void initState() {
    super.initState();
    _load();
  }

  void _load() {
    _notifications = widget.repository.listNotifications();
  }

  Future<void> _markRead(List<InstructorNotification> notifications) async {
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
      if (mounted) setState(_load);
    } on InstructorNotificationException catch (error) {
      if (mounted) setState(() => _markReadError = error.message);
    } finally {
      if (mounted) setState(() => _isMarkingRead = false);
    }
  }

  Future<void> _markOneRead(InstructorNotification notification) async {
    if (_isMarkingRead || notification.isRead) return;
    setState(() {
      _isMarkingRead = true;
      _markingReadId = notification.id;
      _markReadError = null;
    });
    try {
      await widget.repository.markNotificationsRead([notification.id]);
      if (mounted) setState(_load);
    } on InstructorNotificationException catch (error) {
      if (mounted) setState(() => _markReadError = error.message);
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
                  onPressed: () => setState(_load),
                  icon: const Icon(Icons.refresh_rounded),
                ),
              ],
            ),
          ),
          Expanded(
            child: FutureBuilder<List<InstructorNotification>>(
              future: _notifications,
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return const Center(
                    child: CircularProgressIndicator(color: Color(0xFFF4773C)),
                  );
                }
                if (snapshot.hasError) {
                  final message =
                      snapshot.error is InstructorNotificationException
                      ? (snapshot.error! as InstructorNotificationException)
                            .message
                      : 'Your notifications could not be loaded.';
                  return Center(
                    child: Padding(
                      padding: const EdgeInsets.all(24),
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text(
                            message,
                            textAlign: TextAlign.center,
                            style: const TextStyle(color: Color(0xFF765C4F)),
                          ),
                          const SizedBox(height: 12),
                          OutlinedButton(
                            onPressed: () => setState(_load),
                            child: const Text('Try again'),
                          ),
                        ],
                      ),
                    ),
                  );
                }

                final notifications = snapshot.data ?? const [];
                if (notifications.isEmpty) {
                  return const _InstructorNotificationsEmptyState();
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
                                : () => _markRead(notifications),
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
                          return _InstructorNotificationTile(
                            notification: notification,
                            isMarkingRead: _markingReadId == notification.id,
                            onTap: _isMarkingRead || notification.isRead
                                ? null
                                : () => _markOneRead(notification),
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

class _InstructorNotificationTile extends StatelessWidget {
  const _InstructorNotificationTile({
    required this.notification,
    required this.isMarkingRead,
    required this.onTap,
  });

  final InstructorNotification notification;
  final bool isMarkingRead;
  final VoidCallback? onTap;

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
                switch (notification.type) {
                  InstructorNotificationType.quizAnswered =>
                    Icons.quiz_outlined,
                  InstructorNotificationType.studentJoined =>
                    Icons.group_add_outlined,
                },
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

  String _formatDate(DateTime date) {
    final localDate = date.toLocal();
    final difference = DateTime.now().difference(localDate);
    final relative = difference.isNegative || difference.inMinutes < 1
        ? 'Just now'
        : difference.inHours < 1
        ? '${difference.inMinutes}m ago'
        : difference.inDays < 1
        ? '${difference.inHours}h ago'
        : difference.inDays < 7
        ? '${difference.inDays}d ago'
        : null;
    final hour = localDate.hour % 12 == 0 ? 12 : localDate.hour % 12;
    final minute = localDate.minute.toString().padLeft(2, '0');
    final period = localDate.hour < 12 ? 'AM' : 'PM';
    final timestamp =
        '${localDate.month}/${localDate.day}/${localDate.year} '
        '$hour:$minute $period';
    return relative == null ? timestamp : '$relative · $timestamp';
  }
}

class _InstructorNotificationsEmptyState extends StatelessWidget {
  const _InstructorNotificationsEmptyState();

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
            'Classroom updates and deadline reminders will appear here.',
            textAlign: TextAlign.center,
            style: TextStyle(color: Color(0xFF765C4F)),
          ),
        ],
      ),
    ),
  );
}
