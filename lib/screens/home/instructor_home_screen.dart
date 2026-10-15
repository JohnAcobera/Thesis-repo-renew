import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../../models/user_model.dart';
import '../../services/auth_service.dart';
import '../../services/classroom_service.dart';
import '../classroom/classroom_screen.dart';
import '../../widgets/instructor_side_menu.dart';
import '../../widgets/student_nav_bar.dart';
import '../auth/login_screen.dart';

class InstructorHomeScreen extends StatefulWidget {
  const InstructorHomeScreen({
    required this.user,
    this.classroomService,
    super.key,
  });

  final UserModel user;
  final ClassroomRepository? classroomService;

  @override
  State<InstructorHomeScreen> createState() => _InstructorHomeScreenState();
}

class _InstructorHomeScreenState extends State<InstructorHomeScreen> {
  static const _animationDuration = Duration(milliseconds: 280);

  bool _isMenuOpen = false;
  InstructorMenuItem _selectedMenu = InstructorMenuItem.dashboard;

  void _toggleMenu() {
    setState(() => _isMenuOpen = !_isMenuOpen);
  }

  void _closeMenu() {
    if (_isMenuOpen) {
      setState(() => _isMenuOpen = false);
    }
  }

  void _selectMenuItem(InstructorMenuItem item) {
    setState(() {
      _selectedMenu = item;
      _isMenuOpen = false;
    });
  }

  Future<void> _logout() async {
    await AuthService().logout();
    if (!mounted) return;
    Navigator.of(context).pushAndRemoveUntil(
      MaterialPageRoute<void>(builder: (_) => const LoginScreen()),
      (_) => false,
    );
  }

  String get _displayRole {
    final role = widget.user.role;
    if (role.isEmpty) return role;
    return '${role[0].toUpperCase()}${role.substring(1).toLowerCase()}';
  }

  @override
  Widget build(BuildContext context) {
    final user = widget.user;

    return Scaffold(
      backgroundColor: const Color(0xFFFFF8EE),
      appBar: StudentNavBar(
        title: _selectedMenu == InstructorMenuItem.classroom
            ? 'My Classroom'
            : 'Instructor Dashboard',
        username: user.fullName,
        email: user.email,
        onSettingsSelected: () {},
        onLogoutSelected: _logout,
        leading: IconButton(
          tooltip: _isMenuOpen ? 'Close menu' : 'Open menu',
          onPressed: _toggleMenu,
          icon: const Icon(Icons.menu),
        ),
      ),
      body: LayoutBuilder(
        builder: (context, constraints) {
          final emailStyle = Theme.of(
            context,
          ).textTheme.bodyMedium?.copyWith(color: const Color(0xFF765C4F));
          final emailPainter = TextPainter(
            text: TextSpan(text: user.email, style: emailStyle),
            textDirection: Directionality.of(context),
            textScaler: MediaQuery.textScalerOf(context),
            maxLines: 1,
          )..layout();
          final drawerWidth = math.min(
            math.max(220.0, emailPainter.width + 98),
            constraints.maxWidth * 0.82,
          );

          return Stack(
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
                      child: InstructorSideMenu(
                        username: user.fullName,
                        email: user.email,
                        role: _displayRole,
                        selectedMenu: _selectedMenu,
                        onMenuSelected: _selectMenuItem,
                        onAboutSelected: _closeMenu,
                        onSettingsSelected: _closeMenu,
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
                    Positioned.fill(
                      child: _selectedMenu == InstructorMenuItem.classroom
                          ? ClassroomScreen(
                              user: user,
                              classroomService: widget.classroomService,
                            )
                          : const _InstructorDashboard(),
                    ),
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
          );
        },
      ),
    );
  }
}

class _InstructorDashboard extends StatelessWidget {
  const _InstructorDashboard();

  static const _gap = 20.0;

  @override
  Widget build(BuildContext context) => SingleChildScrollView(
    padding: const EdgeInsets.all(24),
    child: Center(
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 1280),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: _MetricCard(
                    label: 'Total students',
                    icon: Icons.groups_outlined,
                  ),
                ),
                const SizedBox(width: _gap),
                Expanded(
                  child: _MetricCard(
                    label: 'Active classes',
                    icon: Icons.menu_book_outlined,
                  ),
                ),
              ],
            ),
            const SizedBox(height: _gap),
            Row(
              children: [
                Expanded(
                  child: _MetricCard(
                    label: 'Quizzes created',
                    icon: Icons.assignment_outlined,
                  ),
                ),
                const SizedBox(width: _gap),
                Expanded(
                  child: _MetricCard(
                    label: 'Average score',
                    icon: Icons.bar_chart_outlined,
                  ),
                ),
              ],
            ),
            const SizedBox(height: _gap),
            const _DashboardSection(title: 'Class performance', height: 260),
            const SizedBox(height: _gap),
            const _DashboardSection(title: 'Recent quizzes', height: 300),
            const SizedBox(height: _gap),
            const _DashboardSection(
              title: 'Students needing attention',
              height: 220,
            ),
          ],
        ),
      ),
    ),
  );
}

class _MetricCard extends StatelessWidget {
  const _MetricCard({required this.label, required this.icon});

  final String label;
  final IconData icon;

  @override
  Widget build(BuildContext context) => Container(
    height: 150,
    padding: const EdgeInsets.all(16),
    decoration: BoxDecoration(
      color: Colors.white,
      borderRadius: BorderRadius.circular(8),
    ),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(icon, color: const Color(0xFFF4773C), size: 20),
        const SizedBox(height: 8),
        Text(
          label,
          style: const TextStyle(fontSize: 14, color: Color(0xFF765C4F)),
        ),
        const Expanded(child: SizedBox()),
      ],
    ),
  );
}

class _DashboardSection extends StatelessWidget {
  const _DashboardSection({required this.title, required this.height});

  final String title;
  final double height;

  @override
  Widget build(BuildContext context) => Container(
    width: double.infinity,
    height: height,
    padding: const EdgeInsets.all(20),
    decoration: BoxDecoration(
      color: Colors.white,
      borderRadius: BorderRadius.circular(8),
    ),
    child: Text(
      title,
      style: const TextStyle(
        fontSize: 18,
        fontWeight: FontWeight.w600,
        color: Color(0xFF3B2419),
      ),
    ),
  );
}
