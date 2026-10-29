import 'package:flutter/material.dart';

enum InstructorMenuItem { dashboard, classroom, reports }

extension InstructorMenuItemPresentation on InstructorMenuItem {
  String get label => switch (this) {
    InstructorMenuItem.dashboard => 'Dashboard',
    InstructorMenuItem.classroom => 'My Classroom',
    InstructorMenuItem.reports => 'Reports',
  };

  IconData get icon => switch (this) {
    InstructorMenuItem.dashboard => Icons.dashboard_outlined,
    InstructorMenuItem.classroom => Icons.class_outlined,
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
    required this.onLogoutSelected,
    super.key,
  });

  final String username;
  final String email;
  final String role;
  final InstructorMenuItem selectedMenu;
  final ValueChanged<InstructorMenuItem> onMenuSelected;
  final VoidCallback onLogoutSelected;

  @override
  Widget build(BuildContext context) => Container(
    decoration: BoxDecoration(
      color: const Color(0xFFFFFCF8).withValues(alpha: 0.8),
      border: Border(
        right: BorderSide(color: Colors.white.withValues(alpha: 0.8)),
      ),
    ),
    child: SafeArea(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          _InstructorMenuProfile(username: username, email: email, role: role),
          const Padding(
            padding: EdgeInsets.fromLTRB(20, 4, 20, 8),
            child: Text(
              'WORKSPACE',
              style: TextStyle(
                color: Color(0xFF9A725A),
                fontSize: 10,
                fontWeight: FontWeight.w700,
                letterSpacing: 1.1,
              ),
            ),
          ),
          Expanded(
            child: ListView(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
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
            padding: EdgeInsets.fromLTRB(20, 8, 20, 8),
            child: Divider(height: 1, color: Color(0xFFE8D7C2)),
          ),
          const Padding(
            padding: EdgeInsets.fromLTRB(20, 4, 20, 4),
            child: Text(
              'ACCOUNT',
              style: TextStyle(
                color: Color(0xFF9A725A),
                fontSize: 10,
                fontWeight: FontWeight.w700,
                letterSpacing: 1.1,
              ),
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(10, 0, 10, 12),
            child: Column(
              children: [
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

class _InstructorMenuProfile extends StatelessWidget {
  const _InstructorMenuProfile({
    required this.username,
    required this.email,
    required this.role,
  });

  final String username;
  final String email;
  final String role;

  @override
  Widget build(BuildContext context) => Container(
    margin: const EdgeInsets.fromLTRB(14, 16, 14, 16),
    padding: const EdgeInsets.all(14),
    decoration: BoxDecoration(
      color: const Color(0xFFFFF4E9),
      border: Border.all(color: const Color(0xFFF0DFCF)),
      borderRadius: BorderRadius.circular(16),
    ),
    child: Row(
      children: [
        Container(
          padding: const EdgeInsets.all(3),
          decoration: const BoxDecoration(
            color: Colors.white,
            shape: BoxShape.circle,
          ),
          child: const CircleAvatar(
            radius: 20,
            backgroundColor: Color(0xFFFFE5D5),
            child: Icon(Icons.person, color: Color(0xFFF4773C), size: 22),
          ),
        ),
        const SizedBox(width: 11),
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
                  fontSize: 13,
                  fontWeight: FontWeight.w700,
                ),
              ),
              const SizedBox(height: 3),
              Text(
                email,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(color: Color(0xFF765C4F), fontSize: 11),
              ),
              const SizedBox(height: 8),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(
                  color: const Color(0xFFFFE5D5),
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Text(
                  role.toUpperCase(),
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
        borderRadius: BorderRadius.circular(12),
        child: InkWell(
          borderRadius: BorderRadius.circular(12),
          onTap: onTap,
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 180),
            curve: Curves.easeOut,
            height: 48,
            padding: const EdgeInsets.symmetric(horizontal: 10),
            decoration: BoxDecoration(
              color: selected ? const Color(0xFFFFE9DA) : Colors.transparent,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(
                color: selected ? const Color(0xFFF5D0B8) : Colors.transparent,
              ),
            ),
            child: Row(
              children: [
                Container(
                  width: 30,
                  height: 30,
                  decoration: BoxDecoration(
                    color: selected
                        ? const Color(0xFFF4773C)
                        : const Color(0xFFFFF1DF),
                    borderRadius: BorderRadius.circular(9),
                  ),
                  child: Icon(
                    icon,
                    size: 18,
                    color: selected ? Colors.white : const Color(0xFFF4773C),
                  ),
                ),
                const SizedBox(width: 11),
                Expanded(
                  child: Text(
                    label,
                    style: TextStyle(
                      color: color,
                      fontSize: 13,
                      fontWeight: selected ? FontWeight.w700 : FontWeight.w500,
                    ),
                  ),
                ),
                if (selected)
                  const Icon(
                    Icons.chevron_right,
                    size: 18,
                    color: Color(0xFFF4773C),
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
