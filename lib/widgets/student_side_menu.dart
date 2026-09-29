import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../screens/auth/login_screen.dart';
import '../services/auth_service.dart';
import 'student_nav_bar.dart';

enum StudentMenuItem {
  dashboard,
  profile,
  achievements,
  quiz,
  summarizer,
  flashcard,
  reviewer,
}

extension StudentMenuItemPresentation on StudentMenuItem {
  String get label => switch (this) {
    StudentMenuItem.dashboard => 'Dashboard',
    StudentMenuItem.profile => 'Profile',
    StudentMenuItem.achievements => 'Achievements',
    StudentMenuItem.quiz => 'Quiz',
    StudentMenuItem.summarizer => 'Summarizer',
    StudentMenuItem.flashcard => 'Flashcard',
    StudentMenuItem.reviewer => 'Reviewer',
  };

  IconData get icon => switch (this) {
    StudentMenuItem.dashboard => Icons.dashboard_outlined,
    StudentMenuItem.profile => Icons.person_outline,
    StudentMenuItem.achievements => Icons.emoji_events_outlined,
    StudentMenuItem.quiz => Icons.quiz_outlined,
    StudentMenuItem.summarizer => Icons.summarize_outlined,
    StudentMenuItem.flashcard => Icons.style_outlined,
    StudentMenuItem.reviewer => Icons.rate_review_outlined,
  };
}

class StudentScaffold extends StatefulWidget {
  const StudentScaffold({
    required this.title,
    required this.username,
    required this.email,
    required this.body,
    this.selectedMenu,
    this.onMenuSelected,
    this.onSettingsSelected,
    this.onBack,
    super.key,
  });

  final String title;
  final String username;
  final String email;
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
              Positioned(
                left: 0,
                top: 0,
                bottom: 0,
                width: drawerWidth,
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
                        selectedMenu: _selectedMenu,
                        onMenuSelected: _selectMenuItem,
                        onSettingsSelected: widget.onSettingsSelected,
                        onLogoutSelected: _logout,
                      ),
                    ),
                  ),
                ),
              ),
              AnimatedPositioned(
                duration: _animationDuration,
                curve: Curves.easeInOut,
                left: _isMenuOpen ? drawerWidth : 0,
                top: 0,
                bottom: 0,
                width: constraints.maxWidth,
                child: Stack(
                  children: [
                    Positioned.fill(child: widget.body),
                    if (_isMenuOpen)
                      Positioned.fill(
                        child: GestureDetector(
                          behavior: HitTestBehavior.opaque,
                          onTap: _closeMenu,
                          child: const SizedBox.expand(),
                        ),
                      ),
                  ],
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
    required this.selectedMenu,
    required this.onMenuSelected,
    required this.onSettingsSelected,
    required this.onLogoutSelected,
  });

  final String username;
  final String email;
  final StudentMenuItem? selectedMenu;
  final ValueChanged<StudentMenuItem> onMenuSelected;
  final VoidCallback? onSettingsSelected;
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
                        style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                          color: const Color(0xFF765C4F),
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
            padding: EdgeInsets.symmetric(horizontal: 16),
            child: Divider(height: 1, color: Color(0xFFE8D7C2)),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(12, 12, 12, 16),
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
              leading: Icon(item.icon, color: const Color(0xFFF4773C)),
              title: Text(
                item.label,
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
  Widget build(BuildContext context) => Material(
    color: Colors.transparent,
    borderRadius: BorderRadius.circular(12),
    child: ListTile(
      leading: Icon(icon, color: const Color(0xFFF4773C)),
      title: Text(label, style: const TextStyle(color: Color(0xFF3B2419))),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      onTap: onTap,
    ),
  );
}
