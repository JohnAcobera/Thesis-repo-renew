import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../../models/classroom_model.dart';
import '../../models/user_model.dart';
import '../../services/auth_service.dart';
import '../../services/classroom_service.dart';
import '../../services/instructor_notification_service.dart';
import '../import_screen.dart';
import '../classroom/classroom_screen.dart';
import '../profile_screen.dart';
import '../../widgets/instructor_side_menu.dart';
import '../../widgets/student_nav_bar.dart';
import '../../widgets/student_side_menu.dart' show StudentMenuItem;
import '../auth/login_screen.dart';

class InstructorHomeScreen extends StatefulWidget {
  const InstructorHomeScreen({
    required this.user,
    this.classroomService,
    this.notificationRepository,
    super.key,
  });

  final UserModel user;
  final ClassroomRepository? classroomService;
  final InstructorNotificationRepository? notificationRepository;

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

  Future<void> _openCreateActivity() async {
    final user = widget.user;
    await Navigator.of(context).push<bool>(
      MaterialPageRoute<bool>(
        builder: (_) => ImportScreen(
          username: user.fullName,
          email: user.email,
          role: user.role,
          createdAt: user.createdAt,
          classroomService: widget.classroomService,
          onMenuSelected: (item) => _selectMenuItem(
            item == StudentMenuItem.classroom
                ? InstructorMenuItem.classroom
                : InstructorMenuItem.dashboard,
          ),
        ),
      ),
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
        roleLabel: _displayRole,
        title: _selectedMenu == InstructorMenuItem.classroom
            ? 'My Classroom'
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
              Positioned.fill(
                child: _selectedMenu == InstructorMenuItem.classroom
                    ? ClassroomScreen(
                        user: user,
                        classroomService: widget.classroomService,
                      )
                    : _InstructorDashboard(
                        classroomService:
                            widget.classroomService ?? ClassroomService(),
                        onCreateActivity: _openCreateActivity,
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
                          onAboutSelected: _closeMenu,
                          onSettingsSelected: _closeMenu,
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
    required this.onCreateActivity,
  });

  final ClassroomRepository classroomService;
  final VoidCallback onCreateActivity;

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
      final metricColumns = dashboardWidth >= 780
          ? 3
          : dashboardWidth >= 520
          ? 2
          : 1;
      final metricWidth =
          (dashboardWidth - _gap * (metricColumns - 1)) / metricColumns;
      final wideSections = dashboardWidth >= 900;

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
                'A clear view of your classes, assessments, and student progress.',
                style: TextStyle(color: _muted, fontSize: 14, height: 1.5),
              ),
            ],
          );
          final createButton = FilledButton.icon(
            onPressed: widget.onCreateActivity,
            icon: const Icon(Icons.add_rounded, size: 20),
            label: const Text('Create activity'),
            style: FilledButton.styleFrom(
              backgroundColor: _accent,
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
              elevation: 1,
              shadowColor: const Color(0x33A94E22),
            ),
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
                    if (contentWidth < 480) ...[
                      heading,
                      const SizedBox(height: 16),
                      Align(
                        alignment: Alignment.centerRight,
                        child: createButton,
                      ),
                    ] else
                      Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Expanded(child: heading),
                          const SizedBox(width: 16),
                          createButton,
                        ],
                      ),
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
                        SizedBox(
                          width: metricWidth,
                          child: _MetricCard(
                            label: 'Quizzes created',
                            caption: 'Quizzes posted to your classrooms',
                            icon: Icons.assignment_outlined,
                            tint: Color(0xFFFFE5D5),
                            iconColor: _accent,
                            value: stats?.quizzesCreatedCount.toString(),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 24),
                    if (wideSections)
                      Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Expanded(
                            flex: 6,
                            child: _ClassPerformanceSection(
                              classrooms:
                                  stats?.classroomPerformance ??
                                  const <ClassroomPerformance>[],
                            ),
                          ),
                          SizedBox(width: _gap),
                          Expanded(
                            flex: 5,
                            child: const _DashboardSection(
                              title: 'Recent quizzes',
                              icon: Icons.quiz_outlined,
                              message: 'No quizzes yet',
                              description:
                                  'Quizzes you create will appear here for a '
                                  'quick overview.',
                              height: 440,
                            ),
                          ),
                        ],
                      )
                    else ...[
                      _ClassPerformanceSection(
                        classrooms:
                            stats?.classroomPerformance ??
                            const <ClassroomPerformance>[],
                      ),
                      const SizedBox(height: _gap),
                      const _DashboardSection(
                        title: 'Recent quizzes',
                        icon: Icons.quiz_outlined,
                        message: 'No quizzes yet',
                        description:
                            'Quizzes you create will appear here for a quick '
                            'overview.',
                        height: 440,
                      ),
                    ],
                    const SizedBox(height: _gap),
                    const _DashboardSection(
                      title: 'Students needing attention',
                      icon: Icons.support_agent_outlined,
                      message: 'Student insights will appear here',
                      description:
                          'See who may need extra support as class activity grows.',
                      compact: true,
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
  Widget build(BuildContext context) => Container(
    height: 156,
    padding: const EdgeInsets.all(18),
    decoration: BoxDecoration(
      color: Colors.white,
      borderRadius: BorderRadius.circular(16),
      border: Border.all(color: const Color(0xFFE8D7C2)),
      boxShadow: const [
        BoxShadow(
          color: Color(0x0A3B2419),
          blurRadius: 18,
          offset: Offset(0, 6),
        ),
      ],
    ),
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

class _ClassPerformanceSection extends StatefulWidget {
  const _ClassPerformanceSection({required this.classrooms});

  final List<ClassroomPerformance> classrooms;

  @override
  State<_ClassPerformanceSection> createState() =>
      _ClassPerformanceSectionState();
}

class _ClassPerformanceSectionState extends State<_ClassPerformanceSection> {
  final ScrollController _scrollController = ScrollController();

  static const _accent = Color(0xFFFF7434);
  static const _ink = Color(0xFF3B2419);
  static const _muted = Color(0xFF765C4F);
  static const _border = Color(0xFFE8D7C2);
  static const _surface = Color(0xFFFFFBF7);

  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => SizedBox(
    height: 440,
    child: Container(
      width: double.infinity,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: _border),
        boxShadow: const [
          BoxShadow(
            color: Color(0x0A3B2419),
            blurRadius: 18,
            offset: Offset(0, 6),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 40,
                height: 40,
                decoration: BoxDecoration(
                  color: const Color(0xFFFFE9DC),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: const Icon(
                  Icons.insights_rounded,
                  color: _accent,
                  size: 21,
                ),
              ),
              const SizedBox(width: 12),
              const Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Class performance',
                      style: TextStyle(
                        color: _ink,
                        fontSize: 16,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    SizedBox(height: 3),
                    Text(
                      'Progress across your classrooms',
                      style: TextStyle(color: _muted, fontSize: 12),
                    ),
                  ],
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 10,
                  vertical: 6,
                ),
                decoration: BoxDecoration(
                  color: _surface,
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(color: _border),
                ),
                child: Text(
                  '${widget.classrooms.length} '
                  '${widget.classrooms.length == 1 ? 'class' : 'classes'}',
                  style: const TextStyle(
                    color: _muted,
                    fontSize: 11,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ],
          ),
          const Padding(
            padding: EdgeInsets.symmetric(vertical: 16),
            child: Divider(height: 1, color: _border),
          ),
          Expanded(
            child: widget.classrooms.isEmpty
                ? const Center(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(Icons.insights_outlined, color: _accent, size: 26),
                        SizedBox(height: 8),
                        Text(
                          'No classrooms yet',
                          style: TextStyle(
                            color: _ink,
                            fontSize: 13,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        SizedBox(height: 4),
                        Text(
                          'Create a classroom to see student and quiz progress.',
                          textAlign: TextAlign.center,
                          style: TextStyle(color: _muted, fontSize: 12),
                        ),
                      ],
                    ),
                  )
                : Scrollbar(
                    controller: _scrollController,
                    child: SingleChildScrollView(
                      controller: _scrollController,
                      primary: false,
                      child: Column(
                        children: [
                          for (
                            var index = 0;
                            index < widget.classrooms.length;
                            index++
                          ) ...[
                            if (index > 0) const SizedBox(height: 12),
                            _ClassPerformanceRow(
                              classroom: widget.classrooms[index],
                            ),
                          ],
                        ],
                      ),
                    ),
                  ),
          ),
        ],
      ),
    ),
  );
}

class _ClassPerformanceRow extends StatelessWidget {
  const _ClassPerformanceRow({required this.classroom});

  final ClassroomPerformance classroom;

  static const _accent = Color(0xFFFF7434);
  static const _ink = Color(0xFF3B2419);
  static const _muted = Color(0xFF765C4F);
  static const _border = Color(0xFFF0E1D4);

  @override
  Widget build(BuildContext context) {
    final percentage = classroom.averageScore?.clamp(0.0, 100.0);
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: const Color(0xFFFFFBF7),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: _border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                width: 38,
                height: 38,
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(11),
                  border: Border.all(color: _border),
                ),
                child: const Icon(
                  Icons.menu_book_rounded,
                  color: _accent,
                  size: 19,
                ),
              ),
              const SizedBox(width: 11),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      classroom.name,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        color: _ink,
                        fontSize: 14,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    const SizedBox(height: 3),
                    Text(
                      classroom.subject,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(color: _muted, fontSize: 11),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 10),
              Text(
                percentage == null ? '—' : '${percentage.toStringAsFixed(0)}%',
                style: const TextStyle(
                  color: _ink,
                  fontSize: 17,
                  fontWeight: FontWeight.w800,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          ClipRRect(
            borderRadius: BorderRadius.circular(20),
            child: LinearProgressIndicator(
              value: (percentage ?? 0) / 100,
              minHeight: 7,
              backgroundColor: const Color(0xFFF1E4D9),
              valueColor: const AlwaysStoppedAnimation<Color>(_accent),
            ),
          ),
          const SizedBox(height: 11),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              _ClassDetailChip(
                icon: Icons.people_alt_outlined,
                text:
                    '${classroom.studentCount} '
                    '${classroom.studentCount == 1 ? 'student' : 'students'}',
              ),
              _ClassDetailChip(
                icon: Icons.assignment_outlined,
                text:
                    '${classroom.activityCount} '
                    '${classroom.activityCount == 1 ? 'activity' : 'activities'} posted',
              ),
              if (percentage == null)
                const _ClassDetailChip(
                  icon: Icons.info_outline_rounded,
                  text: 'No scores yet',
                ),
            ],
          ),
        ],
      ),
    );
  }
}

class _ClassDetailChip extends StatelessWidget {
  const _ClassDetailChip({required this.icon, required this.text});

  final IconData icon;
  final String text;

  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 6),
    decoration: BoxDecoration(
      color: Colors.white,
      borderRadius: BorderRadius.circular(20),
      border: Border.all(color: const Color(0xFFF0E1D4)),
    ),
    child: Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, size: 14, color: const Color(0xFF8A6D5E)),
        const SizedBox(width: 5),
        Text(
          text,
          style: const TextStyle(
            color: Color(0xFF765C4F),
            fontSize: 11,
            fontWeight: FontWeight.w600,
          ),
        ),
      ],
    ),
  );
}

class _DashboardSection extends StatelessWidget {
  const _DashboardSection({
    required this.title,
    required this.icon,
    required this.message,
    required this.description,
    this.compact = false,
    this.height = 272,
  });

  final String title;
  final IconData icon;
  final String message;
  final String description;
  final bool compact;
  final double height;

  @override
  Widget build(BuildContext context) => Container(
    height: compact ? 260 : height,
    padding: const EdgeInsets.all(20),
    decoration: BoxDecoration(
      color: Colors.white,
      borderRadius: BorderRadius.circular(16),
      border: Border.all(color: const Color(0xFFE8D7C2)),
      boxShadow: const [
        BoxShadow(
          color: Color(0x0A3B2419),
          blurRadius: 18,
          offset: Offset(0, 6),
        ),
      ],
    ),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Expanded(
              child: Text(
                title,
                style: const TextStyle(
                  color: Color(0xFF3B2419),
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
          ],
        ),
        const Divider(height: 24, color: Color(0xFFE8D7C2)),
        Expanded(
          child: Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                Container(
                  width: 44,
                  height: 44,
                  decoration: BoxDecoration(
                    color: const Color(0xFFFFF1DF),
                    borderRadius: BorderRadius.circular(14),
                  ),
                  child: Icon(icon, color: const Color(0xFFF4773C), size: 22),
                ),
                const SizedBox(height: 10),
                Text(
                  message,
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                    color: Color(0xFF3B2419),
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  description,
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                    color: Color(0xFF765C4F),
                    fontSize: 12,
                    height: 1.4,
                  ),
                ),
              ],
            ),
          ),
        ),
      ],
    ),
  );
}
