import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../../models/classroom_model.dart';
import '../../models/learning_material_model.dart';
import '../../models/user_model.dart';
import '../../services/auth_service.dart';
import '../../services/classroom_service.dart';
import '../../services/instructor_notification_service.dart';
import '../../services/instructor_learning_materials_service.dart';
import '../../services/instructor_reports_service.dart';
import '../../services/instructor_todo_service.dart';
import '../context_content_screen.dart';
import '../import_screen.dart';
import '../learning_materials_screen.dart';
import '../instructor_reports_screen.dart';
import '../classroom/classroom_screen.dart';
import '../profile_screen.dart';
import '../instructor_todo_section.dart';
import '../../widgets/instructor_side_menu.dart';
import '../../widgets/student_nav_bar.dart';
import '../../widgets/student_side_menu.dart' show StudentMenuItem;
import '../auth/login_screen.dart';

class InstructorHomeScreen extends StatefulWidget {
  const InstructorHomeScreen({
    required this.user,
    this.classroomService,
    this.notificationRepository,
    this.learningMaterialsRepository,
    this.reportsRepository,
    this.todoRepository,
    super.key,
  });

  final UserModel user;
  final ClassroomRepository? classroomService;
  final InstructorNotificationRepository? notificationRepository;
  final InstructorLearningMaterialsRepository? learningMaterialsRepository;
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

  Future<void> _openGenerateContent() async {
    await Navigator.of(context).push<void>(
      MaterialPageRoute<void>(builder: (_) => const ContextContentScreen()),
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
            : _selectedMenu == InstructorMenuItem.learningMaterials
            ? 'Learning Materials'
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
                        onCreateActivity: _openCreateActivity,
                      )
                    : _selectedMenu == InstructorMenuItem.learningMaterials
                    ? LearningMaterialsScreen(
                        classroomService:
                            widget.classroomService ?? ClassroomService(),
                        materialsRepository: widget.learningMaterialsRepository,
                        onCreateActivity: _openCreateActivity,
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
                        onCreateActivity: _openCreateActivity,
                        instructorId: user.id,
                        todoRepository: widget.todoRepository,
                        learningMaterialsRepository:
                            widget.learningMaterialsRepository ??
                            InstructorLearningMaterialsService(),
                        onViewMaterials: () => _selectMenuItem(
                          InstructorMenuItem.learningMaterials,
                        ),
                        onGenerateContent: _openGenerateContent,
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
    required this.onGenerateContent,
    required this.onViewMaterials,
    required this.instructorId,
    required this.learningMaterialsRepository,
    this.todoRepository,
  });

  final ClassroomRepository classroomService;
  final Future<void> Function() onCreateActivity;
  final VoidCallback onGenerateContent;
  final VoidCallback onViewMaterials;
  final int instructorId;
  final InstructorLearningMaterialsRepository learningMaterialsRepository;
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
      final metricColumns = dashboardWidth >= 780
          ? 3
          : dashboardWidth >= 520
          ? 2
          : 1;
      final metricWidth =
          (dashboardWidth - _gap * (metricColumns - 1)) / metricColumns;
      final wideSections = dashboardWidth >= 900;
      final dashboardPanelHeight =
          (wideSections && dashboardWidth < 1008) ||
              (!wideSections && dashboardWidth < 496)
          ? 480.0
          : 420.0;

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
                'A clear view of your classes, learning activities, and student progress.',
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
                            child: _ActivityCreationSection(
                              onCreateQuiz: widget.onCreateActivity,
                              onGenerateContent: widget.onGenerateContent,
                              onViewMaterials: widget.onViewMaterials,
                              repository: widget.learningMaterialsRepository,
                              height: dashboardPanelHeight,
                            ),
                          ),
                          SizedBox(width: _gap),
                          Expanded(
                            child: InstructorTodoSection(
                              instructorId: widget.instructorId,
                              repository: widget.todoRepository,
                              panelHeight: dashboardPanelHeight,
                            ),
                          ),
                        ],
                      )
                    else ...[
                      _ActivityCreationSection(
                        onCreateQuiz: widget.onCreateActivity,
                        onGenerateContent: widget.onGenerateContent,
                        onViewMaterials: widget.onViewMaterials,
                        repository: widget.learningMaterialsRepository,
                        height: dashboardPanelHeight,
                      ),
                      const SizedBox(height: _gap),
                      InstructorTodoSection(
                        instructorId: widget.instructorId,
                        repository: widget.todoRepository,
                        panelHeight: dashboardPanelHeight,
                      ),
                    ],
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

class _ActivityCreationSection extends StatefulWidget {
  const _ActivityCreationSection({
    required this.onCreateQuiz,
    required this.onGenerateContent,
    required this.onViewMaterials,
    required this.repository,
    required this.height,
  });

  final Future<void> Function() onCreateQuiz;
  final VoidCallback onGenerateContent;
  final VoidCallback onViewMaterials;
  final InstructorLearningMaterialsRepository repository;
  final double height;

  @override
  State<_ActivityCreationSection> createState() =>
      _ActivityCreationSectionState();
}

class _ActivityCreationSectionState extends State<_ActivityCreationSection> {
  late Future<List<LearningMaterialModel>> _materials;

  @override
  void initState() {
    super.initState();
    _materials = widget.repository.listMaterials();
  }

  void _reloadMaterials() {
    setState(() => _materials = widget.repository.listMaterials());
  }

  Future<void> _createQuiz() async {
    await widget.onCreateQuiz();
    if (mounted) _reloadMaterials();
  }

  @override
  Widget build(BuildContext context) => Container(
    key: const ValueKey('instructor-activity-creation-panel'),
    height: widget.height,
    width: double.infinity,
    padding: const EdgeInsets.all(22),
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
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              width: 42,
              height: 42,
              decoration: BoxDecoration(
                color: const Color(0xFFFFE9DC),
                borderRadius: BorderRadius.circular(12),
              ),
              child: const Icon(
                Icons.auto_awesome_outlined,
                color: Color(0xFFF4773C),
                size: 21,
              ),
            ),
            const SizedBox(width: 12),
            const Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Create learning materials',
                    style: TextStyle(
                      color: Color(0xFF3B2419),
                      fontSize: 17,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  SizedBox(height: 5),
                  Text(
                    'Build a quiz or generate study content for your students.',
                    style: TextStyle(
                      color: Color(0xFF765C4F),
                      fontSize: 12,
                      height: 1.4,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
        const Padding(
          padding: EdgeInsets.symmetric(vertical: 10),
          child: Divider(height: 1, color: Color(0xFFE8D7C2)),
        ),
        LayoutBuilder(
          builder: (context, constraints) {
            final quizButton = FilledButton.icon(
              onPressed: _createQuiz,
              style: FilledButton.styleFrom(
                backgroundColor: const Color(0xFFF4773C),
                foregroundColor: Colors.white,
                minimumSize: const Size.fromHeight(48),
                padding: const EdgeInsets.symmetric(horizontal: 16),
                textStyle: const TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                ),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(10),
                ),
              ),
              icon: const Icon(Icons.quiz_outlined, size: 18),
              label: const Text('Generate a quiz'),
            );
            final contentButton = OutlinedButton.icon(
              onPressed: widget.onGenerateContent,
              style: OutlinedButton.styleFrom(
                foregroundColor: const Color(0xFF5F4538),
                backgroundColor: const Color(0xFFFFFBF7),
                minimumSize: const Size.fromHeight(48),
                padding: const EdgeInsets.symmetric(horizontal: 16),
                textStyle: const TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                ),
                side: const BorderSide(color: Color(0xFFE8D7C2)),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(10),
                ),
              ),
              icon: const Icon(
                Icons.auto_awesome_outlined,
                color: Color(0xFFF4773C),
                size: 18,
              ),
              label: const Text('Generate content'),
            );

            if (constraints.maxWidth >= 452) {
              return Row(
                children: [
                  Expanded(child: quizButton),
                  const SizedBox(width: 12),
                  Expanded(child: contentButton),
                ],
              );
            }
            return Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [quizButton, const SizedBox(height: 10), contentButton],
            );
          },
        ),
        const SizedBox(height: 14),
        Row(
          children: [
            const Expanded(
              child: Text(
                'Recent generated materials',
                style: TextStyle(
                  color: Color(0xFF3B2419),
                  fontSize: 14,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
            TextButton(
              onPressed: widget.onViewMaterials,
              style: TextButton.styleFrom(
                foregroundColor: const Color(0xFFF4773C),
                visualDensity: VisualDensity.compact,
                padding: const EdgeInsets.symmetric(horizontal: 8),
              ),
              child: const Text('View all'),
            ),
          ],
        ),
        const SizedBox(height: 2),
        Expanded(
          child: FutureBuilder<List<LearningMaterialModel>>(
            future: _materials,
            builder: (context, snapshot) {
              if (snapshot.connectionState == ConnectionState.waiting) {
                return const Center(
                  child: CircularProgressIndicator(
                    color: Color(0xFFF4773C),
                    strokeWidth: 2,
                  ),
                );
              }
              if (snapshot.hasError) {
                return Row(
                  children: [
                    const Expanded(
                      child: Text(
                        'Recent materials could not be loaded.',
                        style: TextStyle(
                          color: Color(0xFF765C4F),
                          fontSize: 12,
                        ),
                      ),
                    ),
                    TextButton(
                      onPressed: _reloadMaterials,
                      child: const Text('Retry'),
                    ),
                  ],
                );
              }

              final materials = [...snapshot.data!]
                ..sort((first, second) {
                  return second.createdAt.compareTo(first.createdAt);
                });
              final recentMaterials = materials.take(3).toList(growable: false);
              if (recentMaterials.isEmpty) {
                return const Align(
                  alignment: Alignment.topLeft,
                  child: Padding(
                    padding: EdgeInsets.only(top: 4),
                    child: Text(
                      'Saved quizzes will appear here after you generate them.',
                      style: TextStyle(color: Color(0xFF765C4F), fontSize: 12),
                    ),
                  ),
                );
              }

              return ListView.separated(
                padding: EdgeInsets.zero,
                itemCount: recentMaterials.length,
                separatorBuilder: (_, _) => const SizedBox(height: 6),
                itemBuilder: (context, index) {
                  final material = recentMaterials[index];
                  return _RecentMaterialTile(
                    material: material,
                    onTap: widget.onViewMaterials,
                  );
                },
              );
            },
          ),
        ),
      ],
    ),
  );
}

class _RecentMaterialTile extends StatelessWidget {
  const _RecentMaterialTile({required this.material, required this.onTap});

  final LearningMaterialModel material;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) => Material(
    color: const Color(0xFFFFFBF7),
    borderRadius: BorderRadius.circular(10),
    child: InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(10),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
        child: Row(
          children: [
            const Icon(Icons.quiz_outlined, color: Color(0xFFF4773C), size: 18),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    material.title,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      color: Color(0xFF3B2419),
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    '${material.questionCount} questions · ${material.sourceFile}',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      color: Color(0xFF765C4F),
                      fontSize: 11,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 6),
            const Icon(
              Icons.chevron_right_rounded,
              color: Color(0xFF9C806F),
              size: 18,
            ),
          ],
        ),
      ),
    ),
  );
}
