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
import '../../widgets/instructor_summary_metrics.dart';
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

  late final ClassroomRepository _classroomService =
      widget.classroomService ?? ClassroomService();
  late Future<InstructorDashboardStats> _instructorStats = _classroomService
      .getInstructorDashboardStats();
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

  void _reloadInstructorStats() {
    setState(() {
      _instructorStats = _classroomService.getInstructorDashboardStats();
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
              onInstructorMenuSelected: _selectMenuItem,
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
                child: Column(
                  children: [
                    Expanded(
                      child: FutureBuilder<InstructorDashboardStats>(
                        future: _instructorStats,
                        builder: (context, snapshot) {
                          final summaryMetrics = InstructorSummaryMetrics(
                            classroomCount: snapshot.data?.activeClassCount,
                            studentCount: snapshot.data?.studentCount,
                            studentsUnavailable: snapshot.hasError,
                            onRetryStudents: _reloadInstructorStats,
                          );
                          return _selectedMenu == InstructorMenuItem.classroom
                              ? ClassroomScreen(
                                  user: user,
                                  classroomService: _classroomService,
                                  reportsRepository: widget.reportsRepository,
                                  onInstructorStatsChanged:
                                      _reloadInstructorStats,
                                  header: summaryMetrics,
                                )
                              : _selectedMenu == InstructorMenuItem.reports
                              ? InstructorReportsScreen(
                                  reportsRepository:
                                      widget.reportsRepository ??
                                      InstructorReportsService(),
                                  header: summaryMetrics,
                                )
                              : _InstructorDashboard(
                                  instructorId: user.id,
                                  todoRepository: widget.todoRepository,
                                  header: summaryMetrics,
                                );
                        },
                      ),
                    ),
                  ],
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
    required this.instructorId,
    required this.header,
    this.todoRepository,
  });

  final int instructorId;
  final Widget header;
  final InstructorTodoRepository? todoRepository;

  @override
  State<_InstructorDashboard> createState() => _InstructorDashboardState();
}

class _InstructorDashboardState extends State<_InstructorDashboard> {
  static const _accent = Color(0xFFF4773C);
  static const _ink = Color(0xFF3B2419);
  static const _muted = Color(0xFF765C4F);

  @override
  Widget build(BuildContext context) => LayoutBuilder(
    builder: (context, constraints) {
      final horizontalPadding = constraints.maxWidth < 600 ? 16.0 : 32.0;
      final contentWidth = constraints.maxWidth - horizontalPadding * 2;
      final dashboardWidth = math.min(contentWidth, 1160.0);
      final dashboardPanelHeight = dashboardWidth < 496 ? 480.0 : 420.0;

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
          vertical: 24,
        ),
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 1160),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                widget.header,
                const SizedBox(height: 24),
                heading,
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
}
