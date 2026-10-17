import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../screens/auth/login_screen.dart';
import '../services/auth_service.dart';
import 'student_nav_bar.dart';

enum StudentMenuItem { dashboard, profile, classroom, leaderboard }

extension StudentMenuItemPresentation on StudentMenuItem {
  String get label => switch (this) {
    StudentMenuItem.dashboard => 'Dashboard',
    StudentMenuItem.profile => 'Profile',
    StudentMenuItem.classroom => 'My Classroom',
    StudentMenuItem.leaderboard => 'Leaderboard',
  };

  IconData get icon => switch (this) {
    StudentMenuItem.dashboard => Icons.dashboard_outlined,
    StudentMenuItem.profile => Icons.person_outline,
    StudentMenuItem.classroom => Icons.class_outlined,
    StudentMenuItem.leaderboard => Icons.emoji_events_outlined,
  };
}

class StudentScaffold extends StatefulWidget {
  const StudentScaffold({
    required this.title,
    required this.username,
    required this.email,
    required this.body,
    this.role = 'Student',
    this.selectedMenu,
    this.onMenuSelected,
    this.onSettingsSelected,
    this.onBack,
    super.key,
  });

  final String title;
  final String username;
  final String email;
  final String role;
  final Widget body;
  final StudentMenuItem? selectedMenu;
  final ValueChanged<StudentMenuItem>? onMenuSelected;
  final VoidCallback? onSettingsSelected;
  final VoidCallback? onBack;

  @override
  State<StudentScaffold> createState() => _StudentScaffoldState();
}

class _StudentScaffoldState extends State<StudentScaffold> {
  static const _animationDuration = Duration(milliseconds: 280);

  bool _isMenuOpen = false;
  double? _dragStartX;
  double _dragDistanceX = 0;
  StudentMenuItem? _selectedMenu;

  @override
  void initState() {
    super.initState();
    _selectedMenu = widget.selectedMenu;
  }

  @override
  void didUpdateWidget(covariant StudentScaffold oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.selectedMenu != widget.selectedMenu) {
      _selectedMenu = widget.selectedMenu;
    }
  }

  void _toggleMenu() {
    setState(() => _isMenuOpen = !_isMenuOpen);
  }

  void _closeMenu() {
    if (_isMenuOpen) {
      setState(() => _isMenuOpen = false);
    }
  }

  void _selectMenuItem(StudentMenuItem item) {
    setState(() {
      _selectedMenu = widget.selectedMenu ?? item;
      _isMenuOpen = false;
    });
    widget.onMenuSelected?.call(item);
  }

  Future<void> _logout() async {
    await AuthService().logout();
    if (!mounted) return;
    Navigator.of(context).pushAndRemoveUntil(
      MaterialPageRoute<void>(builder: (_) => const LoginScreen()),
      (_) => false,
    );
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    backgroundColor: const Color(0xFFFFF8EE),
    appBar: StudentNavBar(
      title: widget.title,
      roleLabel: widget.role,
      username: widget.username,
      email: widget.email,
      onProfileSelected: () => _selectMenuItem(StudentMenuItem.profile),
      onSettingsSelected: widget.onSettingsSelected,
      leadingWidth: widget.onBack == null ? null : 112,
      leading: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          IconButton(
            tooltip: _isMenuOpen ? 'Close menu' : 'Open menu',
            onPressed: _toggleMenu,
            icon: const Icon(Icons.menu),
          ),
          if (widget.onBack case final onBack?)
            IconButton(
              tooltip: 'Back',
              onPressed: onBack,
              icon: const Icon(Icons.arrow_back),
            ),
        ],
      ),
    ),
    body: LayoutBuilder(
      builder: (context, constraints) {
        final emailStyle = Theme.of(
          context,
        ).textTheme.bodyMedium?.copyWith(color: const Color(0xFF765C4F));
        final emailPainter = TextPainter(
          text: TextSpan(text: widget.email, style: emailStyle),
          textDirection: Directionality.of(context),
          textScaler: MediaQuery.textScalerOf(context),
          maxLines: 1,
        )..layout();
        final drawerWidth = math.min(
          math.max(220.0, emailPainter.width + 98),
          constraints.maxWidth * 0.82,
        );

        return GestureDetector(
          behavior: HitTestBehavior.translucent,
          onHorizontalDragStart: (details) {
            _dragStartX = details.localPosition.dx;
            _dragDistanceX = 0;
          },
          onHorizontalDragUpdate: (details) {
            _dragDistanceX += details.primaryDelta ?? 0;
          },
          onHorizontalDragEnd: (details) {
            final startX = _dragStartX;
            final distanceX = _dragDistanceX;
            _dragStartX = null;
            _dragDistanceX = 0;
            final velocity = details.primaryVelocity ?? 0;
            if (_isMenuOpen && (distanceX < -60 || velocity < -250)) {
              _closeMenu();
            } else if (!_isMenuOpen &&
                startX != null &&
                startX <= 32 &&
                (distanceX > 60 || velocity > 250)) {
              setState(() => _isMenuOpen = true);
            }
          },
          child: Stack(
            clipBehavior: Clip.hardEdge,
            children: [
              Positioned.fill(child: widget.body),
              Positioned.fill(
                child: IgnorePointer(
                  ignoring: !_isMenuOpen,
                  child: AnimatedOpacity(
                    duration: _animationDuration,
                    curve: Curves.easeInOut,
                    opacity: _isMenuOpen ? 1 : 0,
                    child: GestureDetector(
                      behavior: HitTestBehavior.opaque,
                      onTap: _closeMenu,
                      child: const ColoredBox(color: Color(0x26000000)),
                    ),
                  ),
                ),
              ),
              Positioned(
                left: 0,
                top: 0,
                bottom: 0,
                width: drawerWidth,
                child: AnimatedSlide(
                  duration: _animationDuration,
                  curve: Curves.easeInOutCubic,
                  offset: _isMenuOpen ? Offset.zero : const Offset(-1, 0),
                  child: AnimatedOpacity(
                    duration: _animationDuration,
                    curve: Curves.easeInOut,
                    opacity: _isMenuOpen ? 1 : 0,
                    child: IgnorePointer(
                      ignoring: !_isMenuOpen,
                      child: ExcludeSemantics(
                        excluding: !_isMenuOpen,
                        child: _StudentSideMenu(
                          username: widget.username,
                          email: widget.email,
                          role: widget.role,
                          selectedMenu: _selectedMenu,
                          onMenuSelected: _selectMenuItem,
                          onSettingsSelected: widget.onSettingsSelected,
                          onLogoutSelected: _logout,
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            ],
          ),
        );
      },
    ),
  );
}

class _StudentSideMenu extends StatelessWidget {
  const _StudentSideMenu({
    required this.username,
    required this.email,
    required this.role,
    required this.selectedMenu,
    required this.onMenuSelected,
    required this.onSettingsSelected,
    required this.onLogoutSelected,
  });

  final String username;
  final String email;
  final String role;
  final StudentMenuItem? selectedMenu;
  final ValueChanged<StudentMenuItem> onMenuSelected;
  final VoidCallback? onSettingsSelected;
  final VoidCallback onLogoutSelected;

  @override
  Widget build(BuildContext context) => Container(
    decoration: const BoxDecoration(
      color: Color(0xFFFFFCF8),
      border: Border(right: BorderSide(color: Color(0xFFE8D7C2))),
    ),
    child: SafeArea(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          _StudentMenuProfile(username: username, email: email, role: role),
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
                for (final item in StudentMenuItem.values)
                  _MenuItemTile(
                    item: item,
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
                _MenuFooterAction(
                  icon: Icons.settings_outlined,
                  label: 'Settings',
                  onTap: onSettingsSelected,
                ),
                _MenuFooterAction(
                  icon: Icons.logout,
                  label: 'Logout',
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

class _StudentMenuProfile extends StatelessWidget {
  const _StudentMenuProfile({
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
              const SizedBox(height: 6),
              Text(
                role,
                style: const TextStyle(
                  color: Color(0xFF9A512F),
                  fontSize: 10,
                  fontWeight: FontWeight.w700,
                  letterSpacing: 0.3,
                ),
              ),
              const SizedBox(height: 6),
              _StudentRoleBadge(role: role),
            ],
          ),
        ),
      ],
    ),
  );
}

class _StudentRoleBadge extends StatelessWidget {
  const _StudentRoleBadge({required this.role});

  final String role;

  @override
  Widget build(BuildContext context) => Container(
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
  );
}

class _MenuItemTile extends StatelessWidget {
  const _MenuItemTile({
    required this.item,
    required this.selected,
    required this.onTap,
  });

  final StudentMenuItem item;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final color = selected ? const Color(0xFFF4773C) : const Color(0xFF3B2419);

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 3),
      child: Material(
        color: selected ? const Color(0xFFFFE9DA) : Colors.transparent,
        borderRadius: BorderRadius.circular(12),
        child: ListTile(
          contentPadding: const EdgeInsets.symmetric(horizontal: 12),
          leading: Container(
            width: 30,
            height: 30,
            decoration: BoxDecoration(
              color: selected ? const Color(0xFFF4773C) : const Color(0xFFFFF1DF),
              borderRadius: BorderRadius.circular(9),
            ),
            child: Icon(
              item.icon,
              size: 18,
              color: selected ? Colors.white : const Color(0xFFF4773C),
            ),
          ),
          title: Text(
            item.label,
            style: TextStyle(
              color: color,
              fontSize: 13,
              fontWeight: selected ? FontWeight.w700 : FontWeight.w500,
            ),
          ),
          trailing: selected
              ? const Icon(Icons.chevron_right, size: 18, color: Color(0xFFF4773C))
              : null,
          shape: RoundedRectangleBorder(
            side: BorderSide(
              color: selected ? const Color(0xFFF5D0B8) : Colors.transparent,
            ),
            borderRadius: BorderRadius.circular(12),
          ),
          onTap: onTap,
        ),
      ),
    );
  }
}

class _MenuFooterAction extends StatelessWidget {
  const _MenuFooterAction({
    required this.icon,
    required this.label,
    required this.onTap,
  });

  final IconData icon;
  final String label;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.symmetric(vertical: 2),
    child: Material(
      color: Colors.transparent,
      borderRadius: BorderRadius.circular(12),
      child: InkWell(
        borderRadius: BorderRadius.circular(12),
        onTap: onTap,
        child: SizedBox(
          height: 44,
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 10),
            child: Row(
              children: [
                Icon(icon, size: 19, color: const Color(0xFF8A6B58)),
                const SizedBox(width: 14),
                Text(
                  label,
                  style: const TextStyle(
                    color: Color(0xFF5B4336),
                    fontSize: 13,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    ),
  );
}
