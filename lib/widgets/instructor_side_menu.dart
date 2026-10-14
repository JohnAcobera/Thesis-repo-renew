import 'package:flutter/material.dart';

enum InstructorMenuItem { dashboard, classroom, learningMaterials, reports }

extension InstructorMenuItemPresentation on InstructorMenuItem {
  String get label => switch (this) {
    InstructorMenuItem.dashboard => 'Dashboard',
    InstructorMenuItem.classroom => 'My Classroom',
    InstructorMenuItem.learningMaterials => 'Learning Materials',
    InstructorMenuItem.reports => 'Reports',
  };

  IconData get icon => switch (this) {
    InstructorMenuItem.dashboard => Icons.dashboard_outlined,
    InstructorMenuItem.classroom => Icons.class_outlined,
    InstructorMenuItem.learningMaterials => Icons.menu_book_outlined,
    InstructorMenuItem.reports => Icons.bar_chart_outlined,
  };
}

class InstructorSideMenu extends StatelessWidget {
  const InstructorSideMenu({
    required this.username,
    required this.email,
    required this.role,
    required this.selectedMenu,
    required this.onMenuSelected,
    required this.onAboutSelected,
    required this.onSettingsSelected,
    required this.onLogoutSelected,
    super.key,
  });

  final String username;
  final String email;
  final String role;
  final InstructorMenuItem selectedMenu;
  final ValueChanged<InstructorMenuItem> onMenuSelected;
  final VoidCallback onAboutSelected;
  final VoidCallback onSettingsSelected;
  final VoidCallback onLogoutSelected;

  @override
  Widget build(BuildContext context) => ColoredBox(
    color: const Color(0xFFFFF8EE),
    child: SafeArea(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 24, 16, 24),
            child: Row(
              children: [
                const CircleAvatar(
                  radius: 25,
                  backgroundColor: Color(0xFFFFE5D5),
                  child: Icon(
                    Icons.account_circle,
                    size: 34,
                    color: Color(0xFFF4773C),
                  ),
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
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        email,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: Theme.of(context).textTheme.bodySmall?.copyWith(
                          color: const Color(0xFF765C4F),
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        role,
                        style: const TextStyle(
                          color: Color(0xFF765C4F),
                          fontSize: 12,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          const Padding(
            padding: EdgeInsets.symmetric(horizontal: 16),
            child: Divider(height: 1, color: Color(0xFFE8D7C2)),
          ),
          Expanded(
            child: ListView(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
              children: [
                for (final item in InstructorMenuItem.values)
                  _InstructorMenuTile(
                    label: item.label,
                    icon: item.icon,
                    selected: item == selectedMenu,
                    onTap: () => onMenuSelected(item),
                  ),
              ],
            ),
          ),
          const Padding(
            padding: EdgeInsets.symmetric(horizontal: 16),
            child: Divider(height: 1, color: Color(0xFFE8D7C2)),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(12, 12, 12, 16),
            child: Column(
              children: [
                _InstructorMenuTile(
                  label: 'About',
                  icon: Icons.info_outline,
                  onTap: onAboutSelected,
                ),
                _InstructorMenuTile(
                  label: 'Settings',
                  icon: Icons.settings_outlined,
                  onTap: onSettingsSelected,
                ),
                _InstructorMenuTile(
                  label: 'Logout',
                  icon: Icons.logout,
                  onTap: onLogoutSelected,
                ),
              ],
            ),
          ),
        ],
      ),
    ),
  );
}

class _InstructorMenuTile extends StatelessWidget {
  const _InstructorMenuTile({
    required this.label,
    required this.icon,
    required this.onTap,
    this.selected = false,
  });

  final String label;
  final IconData icon;
  final VoidCallback onTap;
  final bool selected;

  @override
  Widget build(BuildContext context) {
    final color = selected ? const Color(0xFFF4773C) : const Color(0xFF3B2419);

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 3),
      child: Material(
        color: Colors.transparent,
        child: Stack(
          children: [
            if (selected)
              Positioned.fill(
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 8),
                  child: DecoratedBox(
                    decoration: BoxDecoration(
                      color: const Color(0xFFFFE5D5),
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                ),
              ),
            ListTile(
              leading: Icon(icon, color: const Color(0xFFF4773C)),
              title: Text(
                label,
                style: TextStyle(color: color, fontWeight: FontWeight.w500),
              ),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
              onTap: onTap,
            ),
          ],
        ),
      ),
    );
  }
}
