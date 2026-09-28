import 'package:flutter/material.dart';

import '../services/auth_service.dart';
import '../screens/auth/login_screen.dart';

class StudentNavBar extends StatelessWidget implements PreferredSizeWidget {
  const StudentNavBar({
    this.title = 'Student Dashboard',
    this.username = '',
    this.email = '',
    this.onImportSelected,
    this.onProfileSelected,
    this.onSettingsSelected,
    this.onLogoutSelected,
    super.key,
  });

  final String title;
  final String username;
  final String email;
  final VoidCallback? onImportSelected;
  final VoidCallback? onProfileSelected;
  final VoidCallback? onSettingsSelected;
  final VoidCallback? onLogoutSelected;

  @override
  Size get preferredSize => const Size.fromHeight(kToolbarHeight + 2);

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
  Widget build(BuildContext context) => AppBar(
    automaticallyImplyLeading: false,
    backgroundColor: const Color(0xFFFFF8F3),
    surfaceTintColor: Colors.transparent,
    bottom: PreferredSize(
      preferredSize: const Size.fromHeight(2),
      child: Container(height: 2, color: const Color(0xFFF4773C)),
    ),
    title: Text(title),
    actions: [
      IconButton(
        tooltip: 'Import',
        onPressed: onImportSelected,
        icon: const Icon(Icons.add),
      ),
      PopupMenuButton<_StudentNavAction>(
        tooltip: 'Open profile menu',
        icon: const CircleAvatar(
          radius: 22,
          backgroundColor: Color(0xFFFFE5D5),
          child: Icon(
            Icons.account_circle,
            size: 38,
            color: Color(0xFFF4773C),
          ),
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
            ),
          ),
          const PopupMenuDivider(),
          const PopupMenuItem(
            value: _StudentNavAction.profile,
            child: _StudentNavMenuItem(
              icon: Icons.person_outline,
              label: 'Profile',
            ),
          ),
          const PopupMenuItem(
            value: _StudentNavAction.settings,
            child: _StudentNavMenuItem(
              icon: Icons.settings_outlined,
              label: 'Settings',
            ),
          ),
          const PopupMenuItem(
            value: _StudentNavAction.logout,
            child: _StudentNavMenuItem(
              icon: Icons.logout,
              label: 'Logout',
            ),
          ),
        ],
      ),
    ],
  );
}

class _StudentNavProfileHeader extends StatelessWidget {
  const _StudentNavProfileHeader({
    required this.username,
    required this.email,
  });

  final String username;
  final String email;

  @override
  Widget build(BuildContext context) => SizedBox(
    width: 220,
    child: Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            username,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(
              color: Color(0xFF3B2419),
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            email,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(color: Color(0xFF765C4F)),
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
    width: 132,
    child: Row(
      children: [
        Icon(icon, color: const Color(0xFFF4773C)),
        const SizedBox(width: 12),
        Text(label),
      ],
    ),
  );
}

enum _StudentNavAction { profile, settings, logout }
