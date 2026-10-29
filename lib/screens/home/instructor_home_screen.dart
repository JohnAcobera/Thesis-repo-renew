import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../../models/classroom_model.dart';
import '../../models/user_model.dart';
import '../../services/auth_service.dart';
import '../../services/classroom_service.dart';
import '../../services/instructor_notification_service.dart';
import '../../services/instructor_reports_service.dart';
import '../../services/instructor_todo_service.dart';
import '../instructor_reports_screen.dart';
import '../classroom/classroom_screen.dart';
import '../profile_screen.dart';
import '../instructor_todo_section.dart';
import '../../widgets/instructor_side_menu.dart';
import '../../widgets/student_nav_bar.dart';
import '../../widgets/app_glass_surface.dart';
import '../../widgets/student_side_menu.dart' show StudentMenuItem;
import '../auth/login_screen.dart';

class InstructorHomeScreen extends StatefulWidget {
  const InstructorHomeScreen({
    required this.user,
    this.classroomService,
    this.notificationRepository,
    this.reportsRepository,
    this.todoRepository,
    super.key,
  });

  final UserModel user;
  final ClassroomRepository? classroomService;
  final InstructorNotificationRepository? notificationRepository;
  final InstructorReportsRepository? reportsRepository;
  final InstructorTodoRepository? todoRepository;

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
      backgroundColor: Colors.transparent,
      appBar: StudentNavBar(
        roleLabel: _displayRole,
        title: _selectedMenu == InstructorMenuItem.classroom
            ? 'My Classroom'
            : _selectedMenu == InstructorMenuItem.reports
            ? 'Reports'
            : 'Instructor Dashboard',
        username: user.fullName,
        email: user.email,
        instructorNotificationRepository: widget.notificationRepository,
        onProfileSelected: () => Navigator.of(context).push(
          MaterialPageRoute<void>(
            builder: (_) => ProfileScreen(
              username: user.fullName,
              email: user.email,
              role: user.role,
              createdAt: user.createdAt,
              onMenuSelected: (item) => _selectMenuItem(
                item == StudentMenuItem.classroom
                    ? InstructorMenuItem.classroom
                    : InstructorMenuItem.dashboard,
              ),
            ),
          ),
        ),
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
              Positioned.fill(
                child: _selectedMenu == InstructorMenuItem.classroom
                    ? ClassroomScreen(
                        user: user,
                        classroomService: widget.classroomService,
                        reportsRepository: widget.reportsRepository,
                      )
                    : _selectedMenu == InstructorMenuItem.reports
                    ? InstructorReportsScreen(
                        reportsRepository:
                            widget.reportsRepository ??
                            InstructorReportsService(),
                      )
                    : _InstructorDashboard(
                        classroomService:
                            widget.classroomService ?? ClassroomService(),
                        instructorId: user.id,
                        todoRepository: widget.todoRepository,
                      ),
              ),
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
                        child: InstructorSideMenu(
                          username: user.fullName,
                          email: user.email,
                          role: _displayRole,
                          selectedMenu: _selectedMenu,
                          onMenuSelected: _selectMenuItem,
                          onLogoutSelected: _logout,
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            ],
          );
        },
      ),
    );
  }
}

class _InstructorDashboard extends StatefulWidget {
  const _InstructorDashboard({
    required this.classroomService,
    required this.instructorId,
    this.todoRepository,
  });

  final ClassroomRepository classroomService;
  final int instructorId;
  final InstructorTodoRepository? todoRepository;

  @override
  State<_InstructorDashboard> createState() => _InstructorDashboardState();
}

class _InstructorDashboardState extends State<_InstructorDashboard> {
  late Future<InstructorDashboardStats> _stats;

  static const _accent = Color(0xFFF4773C);
  static const _ink = Color(0xFF3B2419);
  static const _muted = Color(0xFF765C4F);
  static const _gap = 16.0;

  @override
  void initState() {
    super.initState();
    _stats = widget.classroomService.getInstructorDashboardStats();
  }

  void _retryLoadingStats() {
    setState(() {
      _stats = widget.classroomService.getInstructorDashboardStats();
    });
  }

  @override
  Widget build(BuildContext context) => LayoutBuilder(
    builder: (context, constraints) {
      final horizontalPadding = constraints.maxWidth < 600 ? 16.0 : 32.0;
      final contentWidth = constraints.maxWidth - horizontalPadding * 2;
      final dashboardWidth = math.min(contentWidth, 1280.0);
      final metricColumns = dashboardWidth >= 520 ? 2 : 1;
      final metricWidth =
          (dashboardWidth - _gap * (metricColumns - 1)) / metricColumns;
      final dashboardPanelHeight = dashboardWidth < 496 ? 480.0 : 420.0;

      return FutureBuilder<InstructorDashboardStats>(
        future: _stats,
        builder: (context, snapshot) {
          final stats = snapshot.data;
          const heading = Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'INSTRUCTOR OVERVIEW',
                style: TextStyle(
                  color: _accent,
                  fontSize: 11,
                  fontWeight: FontWeight.w700,
                  letterSpacing: 1.4,
                ),
              ),
              SizedBox(height: 8),
              Text(
                'Your teaching overview',
                style: TextStyle(
                  color: _ink,
                  fontSize: 28,
                  fontWeight: FontWeight.w700,
                  letterSpacing: -0.5,
                ),
              ),
              SizedBox(height: 6),
              Text(
                'A clear view of your classes and student progress.',
                style: TextStyle(color: _muted, fontSize: 14, height: 1.5),
              ),
            ],
          );
          return SingleChildScrollView(
            padding: EdgeInsets.symmetric(
              horizontal: horizontalPadding,
              vertical: 32,
            ),
            child: Center(
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 1280),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    heading,
                    if (snapshot.hasError) ...[
                      const SizedBox(height: 16),
                      _DashboardLoadError(onRetry: _retryLoadingStats),
                    ],
                    const SizedBox(height: 24),
                    Wrap(
                      spacing: _gap,
                      runSpacing: _gap,
                      children: [
                        SizedBox(
                          width: metricWidth,
                          child: _MetricCard(
                            label: 'Total students',
                            caption: 'Across all your classes',
                            icon: Icons.groups_outlined,
                            tint: Color(0xFFFFE5D5),
                            iconColor: _accent,
                            value: stats?.studentCount.toString(),
                          ),
                        ),
                        SizedBox(
                          width: metricWidth,
                          child: _MetricCard(
                            label: 'Active classes',
                            caption: 'Classes you are teaching',
                            icon: Icons.menu_book_outlined,
                            tint: Color(0xFFFFE5D5),
                            iconColor: _accent,
                            value: stats?.activeClassCount.toString(),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 24),
                    InstructorTodoSection(
                      instructorId: widget.instructorId,
                      repository: widget.todoRepository,
                      panelHeight: dashboardPanelHeight,
                    ),
                  ],
                ),
              ),
            ),
          );
        },
      );
    },
  );
}

class _MetricCard extends StatelessWidget {
  const _MetricCard({
    required this.label,
    required this.caption,
    required this.icon,
    required this.tint,
    required this.iconColor,
    this.value,
  });

  final String label;
  final String caption;
  final IconData icon;
  final Color tint;
  final Color iconColor;
  final String? value;

  @override
  Widget build(BuildContext context) => AppGlassSurface(
    borderRadius: 16,
    padding: const EdgeInsets.all(18),
    child: SizedBox(
      height: 156,
      width: double.infinity,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 38,
                height: 38,
                decoration: BoxDecoration(
                  color: tint,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(icon, color: iconColor, size: 21),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  label,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    color: Color(0xFF765C4F),
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 18),
          Text(
            value ?? '—',
            style: const TextStyle(
              color: Color(0xFF3B2419),
              fontSize: 30,
              fontWeight: FontWeight.w700,
              height: 1,
            ),
          ),
          const SizedBox(height: 7),
          Text(
            caption,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(color: Color(0xFF765C4F), fontSize: 11),
          ),
        ],
      ),
    ),
  );
}

class _DashboardLoadError extends StatelessWidget {
  const _DashboardLoadError({required this.onRetry});

  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) => Container(
    width: double.infinity,
    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
    decoration: BoxDecoration(
      color: const Color(0xFFFFE5D5),
      borderRadius: BorderRadius.circular(12),
      border: Border.all(color: const Color(0xFFF2C4A7)),
    ),
    child: Row(
      children: [
        const Icon(Icons.error_outline, color: Color(0xFFB84E25), size: 20),
        const SizedBox(width: 10),
        Expanded(
          child: Text(
            'Could not load classroom statistics. Please try again.',
            style: const TextStyle(color: Color(0xFF6C3C28), fontSize: 12),
          ),
        ),
        TextButton.icon(
          onPressed: onRetry,
          icon: const Icon(Icons.refresh_rounded, size: 18),
          label: const Text('Retry'),
        ),
      ],
    ),
  );
}
