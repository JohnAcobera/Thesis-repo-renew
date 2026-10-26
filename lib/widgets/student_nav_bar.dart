import 'package:flutter/material.dart';

import '../services/auth_service.dart';
import '../services/instructor_notification_service.dart';
import '../services/student_notification_service.dart';
import '../screens/auth/login_screen.dart';
import 'instructor_notifications_sheet.dart';
import 'student_notifications_sheet.dart';

class StudentNavBar extends StatelessWidget implements PreferredSizeWidget {
  const StudentNavBar({
    this.title = 'Student Dashboard',
    this.roleLabel = 'Student',
    this.username = '',
    this.email = '',
    this.onProfileSelected,
    this.onSettingsSelected,
    this.onLogoutSelected,
    this.trailingAction,
    this.notificationRepository,
    this.instructorNotificationRepository,
    this.onNotificationSelected,
    this.leading,
    this.leadingWidth,
    super.key,
  });

  final String title;
  final String roleLabel;
  final String username;
  final String email;
  final VoidCallback? onProfileSelected;
  final VoidCallback? onSettingsSelected;
  final VoidCallback? onLogoutSelected;
  final Widget? trailingAction;
  final StudentNotificationRepository? notificationRepository;
  final InstructorNotificationRepository? instructorNotificationRepository;
  final ValueChanged<StudentNotification>? onNotificationSelected;
  final Widget? leading;
  final double? leadingWidth;

  @override
  Size get preferredSize => const Size.fromHeight(76);

  Future<void> _logout(BuildContext context) async {
    await AuthService().logout();
    if (context.mounted) {
      Navigator.of(context).pushAndRemoveUntil(
        MaterialPageRoute<void>(builder: (_) => const LoginScreen()),
        (_) => false,
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final isWide = MediaQuery.sizeOf(context).width >= 600;

    return AppBar(
      automaticallyImplyLeading: false,
      toolbarHeight: 73,
      backgroundColor: const Color(0xFFFFFCF8),
      surfaceTintColor: Colors.transparent,
      elevation: 2,
      shadowColor: const Color(0x1F3B2419),
      iconTheme: const IconThemeData(color: Color(0xFFF4773C)),
      titleSpacing: 12,
      bottom: PreferredSize(
        preferredSize: const Size.fromHeight(3),
        child: Container(
          height: 3,
          decoration: const BoxDecoration(
            gradient: LinearGradient(
              colors: [Color(0xFFF4773C), Color(0xFFFFB36B)],
            ),
          ),
        ),
      ),
      leading: leading,
      leadingWidth: leadingWidth,
      title: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            '$roleLabel WORKSPACE'.toUpperCase(),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(
              color: Color(0xFF9A725A),
              fontSize: 10,
              fontWeight: FontWeight.w700,
              letterSpacing: 1.15,
              height: 1.2,
            ),
          ),
          const SizedBox(height: 3),
          Text(
            title,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(
              color: Color(0xFF3B2419),
              fontSize: 18,
              fontWeight: FontWeight.w700,
              letterSpacing: -0.25,
              height: 1.2,
            ),
          ),
        ],
      ),
      actions: [
        ?trailingAction,
        if (roleLabel.trim().toLowerCase() == 'student')
          StudentNotificationsButton(
            repository: notificationRepository ?? StudentNotificationService(),
            onNotificationSelected: onNotificationSelected,
          ),
        if (roleLabel.trim().toLowerCase() == 'instructor')
          InstructorNotificationsButton(
            repository:
                instructorNotificationRepository ??
                InstructorNotificationService(),
          ),
        Padding(
          padding: const EdgeInsets.only(right: 16),
          child: PopupMenuButton<_StudentNavAction>(
            tooltip: 'Open profile menu',
            padding: EdgeInsets.zero,
            offset: const Offset(0, 12),
            color: const Color(0xFFFFFCF8),
            surfaceTintColor: Colors.transparent,
            elevation: 10,
            shadowColor: const Color(0x263B2419),
            menuPadding: const EdgeInsets.symmetric(vertical: 8),
            constraints: const BoxConstraints(minWidth: 260, maxWidth: 300),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(16),
              side: const BorderSide(color: Color(0xFFE8D7C2)),
            ),
            child: _StudentNavProfileButton(
              username: username,
              email: email,
              isWide: isWide,
            ),
            onSelected: (action) {
              switch (action) {
                case _StudentNavAction.profile:
                  onProfileSelected?.call();
                case _StudentNavAction.settings:
                  onSettingsSelected?.call();
                case _StudentNavAction.logout:
                  if (onLogoutSelected case final onLogoutSelected?) {
                    onLogoutSelected();
                  } else {
                    _logout(context);
                  }
              }
            },
            itemBuilder: (context) => [
              PopupMenuItem<_StudentNavAction>(
                enabled: false,
                child: _StudentNavProfileHeader(
                  username: username,
                  email: email,
                  roleLabel: roleLabel,
                ),
              ),
              const PopupMenuDivider(height: 1),
              const PopupMenuItem(
                value: _StudentNavAction.profile,
                height: 48,
                padding: EdgeInsets.symmetric(horizontal: 16),
                child: _StudentNavMenuItem(
                  icon: Icons.person_outline,
                  label: 'Profile',
                ),
              ),
              const PopupMenuItem(
                value: _StudentNavAction.settings,
                height: 48,
                padding: EdgeInsets.symmetric(horizontal: 16),
                child: _StudentNavMenuItem(
                  icon: Icons.settings_outlined,
                  label: 'Settings',
                ),
              ),
              const PopupMenuItem(
                value: _StudentNavAction.logout,
                height: 48,
                padding: EdgeInsets.symmetric(horizontal: 16),
                child: _StudentNavMenuItem(icon: Icons.logout, label: 'Logout'),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _StudentNavProfileButton extends StatelessWidget {
  const _StudentNavProfileButton({
    required this.username,
    required this.email,
    required this.isWide,
  });

  final String username;
  final String email;
  final bool isWide;

  @override
  Widget build(BuildContext context) => Container(
    constraints: BoxConstraints(maxWidth: isWide ? 230 : 48),
    padding: EdgeInsets.symmetric(horizontal: isWide ? 10 : 3, vertical: 5),
    decoration: BoxDecoration(
      color: const Color(0xFFFFF7EF),
      border: Border.all(color: const Color(0xFFF0DFCF)),
      borderRadius: BorderRadius.circular(28),
    ),
    child: Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        const CircleAvatar(
          radius: 17,
          backgroundColor: Color(0xFFFFE5D5),
          child: Icon(Icons.person, size: 20, color: Color(0xFFF4773C)),
        ),
        if (isWide) ...[
          const SizedBox(width: 9),
          Flexible(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  username,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    color: Color(0xFF3B2419),
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                    height: 1.25,
                  ),
                ),
                Text(
                  email,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    color: Color(0xFF8A6B58),
                    fontSize: 10,
                    height: 1.25,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 6),
          const Icon(
            Icons.keyboard_arrow_down,
            size: 18,
            color: Color(0xFF8A6B58),
          ),
        ],
      ],
    ),
  );
}

class _StudentNavProfileHeader extends StatelessWidget {
  const _StudentNavProfileHeader({
    required this.username,
    required this.email,
    required this.roleLabel,
  });

  final String username;
  final String email;
  final String roleLabel;

  @override
  Widget build(BuildContext context) => SizedBox(
    width: 268,
    child: Padding(
      padding: const EdgeInsets.fromLTRB(8, 8, 8, 12),
      child: Row(
        children: [
          const CircleAvatar(
            radius: 21,
            backgroundColor: Color(0xFFFFE5D5),
            child: Icon(Icons.person, color: Color(0xFFF4773C), size: 23),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  username,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    color: Color(0xFF3B2419),
                    fontSize: 14,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 3),
                Text(
                  email,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    color: Color(0xFF765C4F),
                    fontSize: 12,
                  ),
                ),
                const SizedBox(height: 7),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 8,
                    vertical: 3,
                  ),
                  decoration: BoxDecoration(
                    color: const Color(0xFFFFF1DF),
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Text(
                    roleLabel.toUpperCase(),
                    style: const TextStyle(
                      color: Color(0xFF9A512F),
                      fontSize: 9,
                      fontWeight: FontWeight.w700,
                      letterSpacing: 0.7,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    ),
  );
}

class _StudentNavMenuItem extends StatelessWidget {
  const _StudentNavMenuItem({required this.icon, required this.label});

  final IconData icon;
  final String label;

  @override
  Widget build(BuildContext context) => SizedBox(
    width: 244,
    child: Row(
      children: [
        Container(
          width: 32,
          height: 32,
          decoration: BoxDecoration(
            color: const Color(0xFFFFF1DF),
            borderRadius: BorderRadius.circular(10),
          ),
          child: Icon(icon, color: const Color(0xFFF4773C), size: 19),
        ),
        const SizedBox(width: 12),
        Text(
          label,
          style: const TextStyle(
            color: Color(0xFF3B2419),
            fontSize: 14,
            fontWeight: FontWeight.w500,
          ),
        ),
      ],
    ),
  );
}

enum _StudentNavAction { profile, settings, logout }
