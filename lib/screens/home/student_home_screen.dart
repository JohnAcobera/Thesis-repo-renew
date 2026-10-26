import 'dart:async';

import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../models/user_model.dart';
import '../../services/auth_service.dart';
import '../../services/classroom_service.dart';
import '../../services/instructor_todo_service.dart';
import '../../services/learning_mode_service.dart';
import '../../services/leaderboard_service.dart';
import '../../services/quiz_service.dart';
import '../../services/student_notification_service.dart';
import '../classroom/classroom_screen.dart';
import '../context_content_screen.dart';
import '../import_screen.dart';
import '../inventory_screen.dart';
import '../instructor_todo_section.dart';
import '../leaderboard_screen.dart';
import '../profile_screen.dart';
import '../quiz_screen.dart';
import '../../widgets/student_performance_radar_chart.dart';
import '../../widgets/student_side_menu.dart';

class StudentHomeScreen extends StatefulWidget {
  const StudentHomeScreen({
    required this.user,
    this.showTutorialOnOpen = false,
    this.classroomService,
    this.profileDataService,
    this.todoRepository,
    this.leaderboardRepository,
    this.notificationRepository,
    super.key,
  });

  final UserModel user;
  final bool showTutorialOnOpen;
  final ClassroomRepository? classroomService;
  final ProfileDataService? profileDataService;
  final InstructorTodoRepository? todoRepository;
  final LeaderboardRepository? leaderboardRepository;
  final StudentNotificationRepository? notificationRepository;

  @override
  State<StudentHomeScreen> createState() => _StudentHomeScreenState();
}

class _StudentHomeScreenState extends State<StudentHomeScreen>
    with WidgetsBindingObserver {
  int _activityRevision = 0;
  StudentMenuItem _selectedMenu = StudentMenuItem.dashboard;
  bool _isRecordingActivityDay = false;
  bool _hasOpenedFirstLoginTutorial = false;
  String? _notificationClassroomId;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _recordActiveLearningDay();
    if (widget.showTutorialOnOpen) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) _openFirstLoginTutorial();
      });
    }
  }

  void _openFirstLoginTutorial() {
    if (_hasOpenedFirstLoginTutorial) return;
    _hasOpenedFirstLoginTutorial = true;
    final user = widget.user;
    Navigator.of(context).push<void>(
      MaterialPageRoute<void>(
        builder: (_) => ImportScreen(
          username: user.fullName,
          email: user.email,
          role: user.role,
          createdAt: user.createdAt,
          onMenuSelected: _selectMenuItem,
          showTutorialOnOpen: true,
        ),
      ),
    );
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      _recordActiveLearningDay();
    }
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  Future<void> _recordActiveLearningDay() async {
    if (_isRecordingActivityDay) return;
    _isRecordingActivityDay = true;

    try {
      final token = await AuthService().getSessionToken();
      if (!mounted || token == null || token.isEmpty) return;

      await Supabase.instance.client.rpc<void>(
        'record_user_activity_day',
        params: {'p_session_token': token},
      );
      if (mounted) {
        setState(() => _activityRevision++);
      }
    } on AssertionError catch (error) {
      if (!error.message.toString().contains(
        'initialize the supabase instance',
      )) {
        rethrow;
      }
      debugPrint('Active learning day could not be recorded.');
    } on Exception catch (_, stackTrace) {
      FlutterError.reportError(
        FlutterErrorDetails(
          exception: Exception('Active learning day could not be recorded.'),
          stack: stackTrace,
          library: 'student home screen',
          context: ErrorDescription('while recording an active learning day'),
        ),
      );
    } finally {
      _isRecordingActivityDay = false;
    }
  }

  @override
  Widget build(BuildContext context) {
    final user = widget.user;

    Future<void> openImportScreen({bool previewTutorial = false}) async {
      final completed = await Navigator.of(context).push<bool>(
        MaterialPageRoute<bool>(
          builder: (_) => ImportScreen(
            username: user.fullName,
            email: user.email,
            role: user.role,
            createdAt: user.createdAt,
            onMenuSelected: _selectMenuItem,
            showTutorialOnOpen: previewTutorial,
          ),
        ),
      );
      if (completed == true && mounted) {
        setState(() => _activityRevision++);
      }
    }

    void openContextContentScreen() {
      Navigator.of(context).push(
        MaterialPageRoute<void>(builder: (_) => const ContextContentScreen()),
      );
    }

    void openProfileScreen() {
      Navigator.of(context).push(
        MaterialPageRoute<void>(
          builder: (_) => ProfileScreen(
            username: user.fullName,
            email: user.email,
            role: user.role,
            createdAt: user.createdAt,
            onMenuSelected: _selectMenuItem,
          ),
        ),
      );
    }

    void onMenuSelected(StudentMenuItem item) {
      _selectMenuItem(item);
      if (item == StudentMenuItem.profile) openProfileScreen();
    }

    return StudentScaffold(
      title: _selectedMenu == StudentMenuItem.classroom
          ? 'My Classroom'
          : _selectedMenu == StudentMenuItem.leaderboard
          ? 'Weekly Leaderboard'
          : _selectedMenu == StudentMenuItem.inventory
          ? 'Inventory'
          : 'Student Dashboard',
      username: user.fullName,
      email: user.email,
      role: _displayRole(user.role),
      selectedMenu: _selectedMenu,
      onMenuSelected: onMenuSelected,
      trailingAction: _selectedMenu == StudentMenuItem.dashboard
          ? IconButton(
              tooltip: 'Preview tutorial',
              onPressed: () => openImportScreen(previewTutorial: true),
              icon: const Icon(Icons.tips_and_updates_outlined),
            )
          : null,
      notificationRepository: widget.notificationRepository,
      onNotificationSelected: _openNotificationClassroom,
      body: _selectedMenu == StudentMenuItem.inventory
          ? InventoryScreen(user: user, onMenuSelected: onMenuSelected)
          : _selectedMenu == StudentMenuItem.classroom
          ? ClassroomScreen(
              key: ValueKey<String?>(_notificationClassroomId),
              user: user,
              classroomService: widget.classroomService,
              initialClassroomId: _notificationClassroomId,
            )
          : _selectedMenu == StudentMenuItem.leaderboard
          ? LeaderboardScreen(repository: widget.leaderboardRepository)
          : LayoutBuilder(
              builder: (context, viewport) {
                final isWide = viewport.maxWidth >= 800;
                final dashboardHeight = (viewport.maxHeight - 48)
                    .clamp(520.0, 770.0)
                    .toDouble();

                return SingleChildScrollView(
                  padding: const EdgeInsets.all(24),
                  child: Center(
                    child: ConstrainedBox(
                      constraints: const BoxConstraints(maxWidth: 1280),
                      child: Column(
                        children: [
                          if (isWide)
                            SizedBox(
                              height: dashboardHeight,
                              child: _WideStudentDashboard(
                                user: user,
                                onImportSelected: openImportScreen,
                                onContentSelected: openContextContentScreen,
                                activityRevision: _activityRevision,
                                onQuizCompleted: () =>
                                    setState(() => _activityRevision++),
                                onMenuSelected: _selectMenuItem,
                              ),
                            )
                          else
                            _StackedStudentDashboard(
                              user: user,
                              onImportSelected: openImportScreen,
                              onContentSelected: openContextContentScreen,
                              activityRevision: _activityRevision,
                              onQuizCompleted: () =>
                                  setState(() => _activityRevision++),
                              onMenuSelected: _selectMenuItem,
                            ),
                          const SizedBox(height: 20),
                          SizedBox(
                            height: isWide ? 440 : 870,
                            child: _StreakAndTodoSection(
                              sideBySide: isWide,
                              studentId: user.id,
                              activityRevision: _activityRevision,
                              profileDataService: widget.profileDataService,
                              todoRepository: widget.todoRepository,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                );
              },
            ),
    );
  }

  void _selectMenuItem(StudentMenuItem item) {
    if (item == StudentMenuItem.dashboard ||
        item == StudentMenuItem.classroom ||
        item == StudentMenuItem.leaderboard ||
        item == StudentMenuItem.inventory) {
      setState(() {
        _selectedMenu = item;
        _notificationClassroomId = null;
      });
    }
  }

  void _openNotificationClassroom(StudentNotification notification) {
    final classroomId = notification.classroomId;
    if (notification.type != StudentNotificationType.classroomActivity ||
        classroomId == null) {
      return;
    }
    Navigator.of(context).popUntil((route) => route.isFirst);
    setState(() {
      _selectedMenu = StudentMenuItem.classroom;
      _notificationClassroomId = classroomId;
    });
  }

  String _displayRole(String role) => role.isEmpty
      ? role
      : '${role[0].toUpperCase()}${role.substring(1).toLowerCase()}';
}

class _StreakAndTodoSection extends StatelessWidget {
  const _StreakAndTodoSection({
    required this.sideBySide,
    required this.studentId,
    required this.activityRevision,
    required this.profileDataService,
    required this.todoRepository,
  });

  final bool sideBySide;
  final int studentId;
  final int activityRevision;
  final ProfileDataService? profileDataService;
  final InstructorTodoRepository? todoRepository;

  @override
  Widget build(BuildContext context) {
    final streakCalendar = _LearningStreakCalendar(
      profileDataService: profileDataService,
      activityRevision: activityRevision,
    );
    final todoList = StudentTodoSection(
      studentId: studentId,
      repository: todoRepository,
    );
    if (sideBySide) {
      return Row(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Expanded(flex: 6, child: streakCalendar),
          const SizedBox(width: 20),
          Expanded(flex: 5, child: todoList),
        ],
      );
    }
    return Column(
      children: [
        SizedBox(height: 400, child: streakCalendar),
        const SizedBox(height: 16),
        Expanded(child: todoList),
      ],
    );
  }
}

class _LearningStreakCalendar extends StatefulWidget {
  const _LearningStreakCalendar({
    required this.profileDataService,
    required this.activityRevision,
  });

  final ProfileDataService? profileDataService;
  final int activityRevision;

  @override
  State<_LearningStreakCalendar> createState() =>
      _LearningStreakCalendarState();
}

class _LearningStreakCalendarState extends State<_LearningStreakCalendar> {
  late Future<Set<DateTime>> _loginDates;
  late DateTime _visibleMonth;

  @override
  void initState() {
    super.initState();
    final now = DateTime.now();
    _visibleMonth = DateTime(now.year, now.month);
    _loginDates = _loadLoginDates();
  }

  @override
  void didUpdateWidget(covariant _LearningStreakCalendar oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.activityRevision != widget.activityRevision) {
      _loginDates = _loadLoginDates();
    }
  }

  Future<Set<DateTime>> _loadLoginDates() {
    try {
      final service = widget.profileDataService ?? AuthService();
      return service.loginDates();
    } on Object catch (error, stackTrace) {
      return Future<Set<DateTime>>.error(error, stackTrace);
    }
  }

  void _retry() {
    setState(() => _loginDates = _loadLoginDates());
  }

  DateTime _dateOnly(DateTime date) =>
      DateTime(date.year, date.month, date.day);

  int _currentStreak(Set<DateTime> dates) {
    final activeDays = dates.map(_dateOnly).toSet();
    final today = _dateOnly(DateTime.now());
    var streakDay = activeDays.contains(today)
        ? today
        : today.subtract(const Duration(days: 1));
    if (!activeDays.contains(streakDay)) return 0;

    var streak = 0;
    while (activeDays.contains(streakDay)) {
      streak++;
      streakDay = streakDay.subtract(const Duration(days: 1));
    }
    return streak;
  }

  @override
  Widget build(BuildContext context) => _DashboardSectionPanel(
    icon: Icons.local_fire_department_outlined,
    title: 'Your learning streak',
    description: 'Celebrate the days you make time to learn.',
    child: FutureBuilder<Set<DateTime>>(
      future: _loginDates,
      builder: (context, snapshot) {
        if (snapshot.hasError) {
          return Center(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Text(
                  'Could not load your learning days.',
                  textAlign: TextAlign.center,
                  style: TextStyle(color: Color(0xFF725F53)),
                ),
                TextButton.icon(
                  onPressed: _retry,
                  icon: const Icon(Icons.refresh_rounded),
                  label: const Text('Try again'),
                ),
              ],
            ),
          );
        }
        if (!snapshot.hasData) {
          return const Center(
            child: CircularProgressIndicator(color: Color(0xFFF4773C)),
          );
        }

        final dates = snapshot.data!;
        final activeDays = dates.map(_dateOnly).toSet();
        final streak = _currentStreak(dates);
        final localizations = MaterialLocalizations.of(context);
        final monthName = localizations.formatMonthYear(_visibleMonth);
        final firstWeekday =
            DateTime(_visibleMonth.year, _visibleMonth.month).weekday - 1;
        final daysInMonth = DateTime(
          _visibleMonth.year,
          _visibleMonth.month + 1,
          0,
        ).day;
        final cellCount = ((firstWeekday + daysInMonth + 6) ~/ 7) * 7;
        final daysThisMonth = activeDays
            .where(
              (date) =>
                  date.year == _visibleMonth.year &&
                  date.month == _visibleMonth.month,
            )
            .length;
        final today = DateTime.now();
        final canNavigateForward =
            _visibleMonth.year < today.year ||
            (_visibleMonth.year == today.year &&
                _visibleMonth.month < today.month);

        return Column(
          children: [
            Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
              decoration: BoxDecoration(
                color: const Color(0xFFFFF4E9),
                border: Border.all(color: const Color(0xFFF4DDC9)),
                borderRadius: BorderRadius.circular(14),
              ),
              child: Row(
                children: [
                  Container(
                    width: 38,
                    height: 38,
                    decoration: const BoxDecoration(
                      color: Color(0xFFFFE5D5),
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(
                      Icons.local_fire_department_rounded,
                      color: Color(0xFFF4773C),
                      size: 21,
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          '$streak ${streak == 1 ? 'day' : 'days'} in a row',
                          style: const TextStyle(
                            color: Color(0xFF3B2419),
                            fontSize: 16,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                        const SizedBox(height: 2),
                        const Text(
                          'Small steps add up.',
                          style: TextStyle(
                            color: Color(0xFF765C4F),
                            fontSize: 11,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 8),
            Container(
              height: 40,
              padding: const EdgeInsets.symmetric(horizontal: 4),
              decoration: BoxDecoration(
                color: const Color(0xFFFFFCF8),
                border: Border.all(color: const Color(0xFFEFE4D9)),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Row(
                children: [
                  IconButton(
                    tooltip: 'Previous month',
                    visualDensity: VisualDensity.compact,
                    onPressed: () => setState(
                      () => _visibleMonth = DateTime(
                        _visibleMonth.year,
                        _visibleMonth.month - 1,
                      ),
                    ),
                    icon: const Icon(Icons.chevron_left_rounded),
                    color: const Color(0xFFF4773C),
                  ),
                  Expanded(
                    child: Text(
                      monthName,
                      textAlign: TextAlign.center,
                      style: const TextStyle(
                        color: Color(0xFF3B2419),
                        fontSize: 13,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                  IconButton(
                    tooltip: 'Next month',
                    visualDensity: VisualDensity.compact,
                    onPressed: canNavigateForward
                        ? () => setState(
                            () => _visibleMonth = DateTime(
                              _visibleMonth.year,
                              _visibleMonth.month + 1,
                            ),
                          )
                        : null,
                    icon: const Icon(Icons.chevron_right_rounded),
                    color: const Color(0xFFF4773C),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 10),
            Expanded(
              child: Column(
                children: [
                  Row(
                    children: [
                      for (final weekday in const [
                        'Monday',
                        'Tuesday',
                        'Wednesday',
                        'Thursday',
                        'Friday',
                        'Saturday',
                        'Sunday',
                      ])
                        Expanded(
                          child: Center(
                            child: Semantics(
                              label: weekday,
                              child: Text(
                                weekday.substring(0, 1),
                                style: const TextStyle(
                                  color: Color(0xFF8A7467),
                                  fontSize: 10,
                                  fontWeight: FontWeight.w700,
                                ),
                              ),
                            ),
                          ),
                        ),
                    ],
                  ),
                  const SizedBox(height: 4),
                  Expanded(
                    child: LayoutBuilder(
                      builder: (context, constraints) {
                        final rowCount = cellCount ~/ 7;
                        final cellWidth = constraints.maxWidth / 7;
                        final cellHeight = constraints.maxHeight / rowCount;
                        final childAspectRatio = cellWidth / cellHeight;

                        return GridView.builder(
                          key: const ValueKey('streak-calendar-grid'),
                          physics: const NeverScrollableScrollPhysics(),
                          padding: EdgeInsets.zero,
                          gridDelegate:
                              SliverGridDelegateWithFixedCrossAxisCount(
                                crossAxisCount: 7,
                                childAspectRatio: childAspectRatio,
                              ),
                          itemCount: cellCount,
                          itemBuilder: (context, index) {
                            final day = index - firstWeekday + 1;
                            if (day < 1 || day > daysInMonth) {
                              return const SizedBox.shrink();
                            }
                            final date = DateTime(
                              _visibleMonth.year,
                              _visibleMonth.month,
                              day,
                            );
                            final isActive = activeDays.contains(date);
                            final isToday =
                                date.year == today.year &&
                                date.month == today.month &&
                                date.day == today.day;
                            return Semantics(
                              key: ValueKey<String>('streak-day-$day'),
                              label:
                                  '${localizations.formatFullDate(date)}'
                                  '${isActive ? ', learning day' : ''}'
                                  '${isToday ? ', today' : ''}',
                              child: Center(
                                child: Container(
                                  width: 32,
                                  height: 32,
                                  alignment: Alignment.center,
                                  decoration: BoxDecoration(
                                    color: isActive
                                        ? const Color(0xFFFFE5D5)
                                        : Colors.transparent,
                                    shape: BoxShape.circle,
                                    border: isToday
                                        ? Border.all(
                                            color: const Color(0xFFF4773C),
                                            width: 1.5,
                                          )
                                        : null,
                                  ),
                                  child: Text(
                                    '$day',
                                    style: TextStyle(
                                      color: isActive
                                          ? const Color(0xFFB64E20)
                                          : const Color(0xFF4B352A),
                                      fontSize: 11,
                                      fontWeight: isActive || isToday
                                          ? FontWeight.w700
                                          : FontWeight.w500,
                                    ),
                                  ),
                                ),
                              ),
                            );
                          },
                        );
                      },
                    ),
                  ),
                  const SizedBox(height: 6),
                  Wrap(
                    spacing: 12,
                    runSpacing: 6,
                    crossAxisAlignment: WrapCrossAlignment.center,
                    children: [
                      const _CalendarLegendDot(
                        color: Color(0xFFFFE5D5),
                        borderColor: Color(0xFFFFE5D5),
                        label: 'Learning day',
                      ),
                      const _CalendarLegendDot(
                        color: Colors.transparent,
                        borderColor: Color(0xFFF4773C),
                        label: 'Today',
                      ),
                      Text(
                        '$daysThisMonth ${daysThisMonth == 1 ? 'day' : 'days'} this month',
                        style: const TextStyle(
                          color: Color(0xFF765C4F),
                          fontSize: 10,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ],
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

class _CalendarLegendDot extends StatelessWidget {
  const _CalendarLegendDot({
    required this.color,
    required this.borderColor,
    required this.label,
  });

  final Color color;
  final Color borderColor;
  final String label;

  @override
  Widget build(BuildContext context) => Row(
    mainAxisSize: MainAxisSize.min,
    children: [
      Container(
        width: 10,
        height: 10,
        decoration: BoxDecoration(
          color: color,
          shape: BoxShape.circle,
          border: Border.all(color: borderColor),
        ),
      ),
      const SizedBox(width: 5),
      Text(
        label,
        style: const TextStyle(color: Color(0xFF765C4F), fontSize: 10),
      ),
    ],
  );
}

class _DashboardSectionPanel extends StatelessWidget {
  const _DashboardSectionPanel({
    required this.icon,
    required this.title,
    required this.description,
    required this.child,
  });

  final IconData icon;
  final String title;
  final String description;
  final Widget child;

  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.all(18),
    decoration: BoxDecoration(
      color: Colors.white,
      borderRadius: BorderRadius.circular(20),
      border: Border.all(color: const Color(0xFFE8D7C2)),
      boxShadow: const [
        BoxShadow(
          color: Color(0x12000000),
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
            Icon(icon, color: const Color(0xFFF4773C), size: 24),
            const SizedBox(width: 10),
            Expanded(
              child: Text(
                title,
                style: const TextStyle(
                  color: Color(0xFF3B2419),
                  fontSize: 19,
                  fontWeight: FontWeight.w800,
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 4),
        Text(
          description,
          style: const TextStyle(color: Color(0xFF725F53), fontSize: 12),
        ),
        const SizedBox(height: 8),
        Expanded(child: child),
      ],
    ),
  );
}

class _WideStudentDashboard extends StatelessWidget {
  const _WideStudentDashboard({
    required this.user,
    required this.onImportSelected,
    required this.onContentSelected,
    required this.activityRevision,
    required this.onQuizCompleted,
    required this.onMenuSelected,
  });

  final UserModel user;
  final VoidCallback onImportSelected;
  final VoidCallback onContentSelected;
  final int activityRevision;
  final VoidCallback onQuizCompleted;
  final ValueChanged<StudentMenuItem> onMenuSelected;

  @override
  Widget build(BuildContext context) => Row(
    crossAxisAlignment: CrossAxisAlignment.stretch,
    children: [
      Expanded(
        flex: 6,
        child: Column(
          children: [
            Expanded(
              flex: 3,
              child: _DashboardPanel(
                key: _DashboardPanel.greetingPanelKey,
                icon: null,
                title: 'Your Stats',
                description:
                    'A snapshot of your quiz performance and study habits.',
                titleSize: 30,
                centerContent: true,
                titleAtTop: true,
                titleTooltip: const _StatsMetricTooltip(),
                content: _StudentMetricsChart(
                  activityRevision: activityRevision,
                  accountCreatedAt: user.createdAt,
                ),
                expandContent: true,
              ),
            ),
            const SizedBox(height: 20),
            Expanded(
              flex: 2,
              child: _DashboardPanel(
                key: _DashboardPanel.quizCreationPanelKey,
                icon: Icons.quiz_outlined,
                title: 'Create your own quiz',
                description:
                    'Turn your study materials into a personalized practice quiz.',
                actionLabel: 'Generate a quiz',
                onAction: onImportSelected,
                secondaryActionLabel: 'Generate content',
                onSecondaryAction: onContentSelected,
                centerContent: true,
              ),
            ),
          ],
        ),
      ),
      const SizedBox(width: 20),
      Expanded(
        flex: 4,
        child: _DashboardPanel(
          key: _DashboardPanel.recentActivityPanelKey,
          icon: Icons.history,
          title: 'Recent activity',
          description: 'Your latest quizzes and study sessions.',
          content: _RecentActivityContent(
            key: ValueKey<int>(activityRevision),
            user: user,
            onQuizCompleted: onQuizCompleted,
            onMenuSelected: onMenuSelected,
            scrollable: true,
          ),
          expandContent: true,
        ),
      ),
    ],
  );
}

class _StackedStudentDashboard extends StatelessWidget {
  const _StackedStudentDashboard({
    required this.user,
    required this.onImportSelected,
    required this.onContentSelected,
    required this.activityRevision,
    required this.onQuizCompleted,
    required this.onMenuSelected,
  });

  final UserModel user;
  final VoidCallback onImportSelected;
  final VoidCallback onContentSelected;
  final int activityRevision;
  final VoidCallback onQuizCompleted;
  final ValueChanged<StudentMenuItem> onMenuSelected;

  @override
  Widget build(BuildContext context) => Column(
    children: [
      _DashboardPanel(
        key: _DashboardPanel.greetingPanelKey,
        icon: null,
        title: 'Your Stats',
        description: 'A snapshot of your quiz performance and study habits.',
        titleSize: 28,
        centerContent: true,
        titleAtTop: true,
        titleTooltip: const _StatsMetricTooltip(),
        content: _StudentMetricsChart(
          activityRevision: activityRevision,
          accountCreatedAt: user.createdAt,
        ),
      ),
      const SizedBox(height: 16),
      _DashboardPanel(
        key: _DashboardPanel.quizCreationPanelKey,
        icon: Icons.quiz_outlined,
        title: 'Create your own quiz',
        description:
            'Turn your study materials into a personalized practice quiz.',
        actionLabel: 'Generate a quiz',
        onAction: onImportSelected,
        secondaryActionLabel: 'Generate content',
        onSecondaryAction: onContentSelected,
        centerContent: true,
      ),
      const SizedBox(height: 16),
      SizedBox(
        height: 500,
        child: _DashboardPanel(
          key: _DashboardPanel.recentActivityPanelKey,
          icon: Icons.history,
          title: 'Recent activity',
          description: 'Your latest quizzes and study sessions.',
          content: _RecentActivityContent(
            key: ValueKey<int>(activityRevision),
            user: user,
            onQuizCompleted: onQuizCompleted,
            onMenuSelected: onMenuSelected,
            scrollable: true,
          ),
          expandContent: true,
        ),
      ),
    ],
  );
}

class _RecentActivityContent extends StatefulWidget {
  const _RecentActivityContent({
    required this.user,
    required this.onQuizCompleted,
    required this.onMenuSelected,
    this.scrollable = false,
    super.key,
  });

  final UserModel user;
  final VoidCallback onQuizCompleted;
  final ValueChanged<StudentMenuItem> onMenuSelected;
  final bool scrollable;

  @override
  State<_RecentActivityContent> createState() => _RecentActivityContentState();
}

class _RecentActivityContentState extends State<_RecentActivityContent> {
  late Future<(List<QuizActivity>, List<LearningInventoryItem>)> _activities;

  @override
  void initState() {
    super.initState();
    _activities = _loadActivities();
  }

  void _retry() {
    setState(() => _activities = _loadActivities());
  }

  Future<(List<QuizActivity>, List<LearningInventoryItem>)>
  _loadActivities() async {
    final results = await Future.wait<Object>([
      QuizService().recentAttempts(),
      LearningModeService().inventoryItems(),
    ]);
    return (
      results[0] as List<QuizActivity>,
      results[1] as List<LearningInventoryItem>,
    );
  }

  @override
  Widget build(
    BuildContext context,
  ) => FutureBuilder<(List<QuizActivity>, List<LearningInventoryItem>)>(
    future: _activities,
    builder: (context, snapshot) {
      if (snapshot.connectionState == ConnectionState.waiting) {
        return const Padding(
          padding: EdgeInsets.symmetric(vertical: 24),
          child: Center(
            child: CircularProgressIndicator(color: Color(0xFFF4773C)),
          ),
        );
      }
      if (snapshot.hasError) {
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Could not load recent activity. Please try again.',
              style: const TextStyle(color: Color(0xFF725F53), height: 1.4),
            ),
            TextButton.icon(
              onPressed: _retry,
              icon: const Icon(Icons.refresh_rounded),
              label: const Text('Try again'),
            ),
          ],
        );
      }

      final quizzes = snapshot.data?.$1 ?? const <QuizActivity>[];
      final studyItems =
          snapshot.data?.$2
              .where((item) => item.attempts.isNotEmpty)
              .toList(growable: false) ??
          const <LearningInventoryItem>[];
      final activities = <Object>[...quizzes, ...studyItems]
        ..sort((first, second) {
          final firstDate = first is QuizActivity
              ? first.latestAttempt?.createdAt ?? first.createdAt
              : (first as LearningInventoryItem).lastActivity;
          final secondDate = second is QuizActivity
              ? second.latestAttempt?.createdAt ?? second.createdAt
              : (second as LearningInventoryItem).lastActivity;
          return secondDate.compareTo(firstDate);
        });
      if (activities.isEmpty) {
        return const Padding(
          padding: EdgeInsets.symmetric(vertical: 12),
          child: Text(
            'No learning activity yet. Complete a quiz or study session and it will appear here.',
            style: TextStyle(color: Color(0xFF725F53)),
          ),
        );
      }

      return ListView.separated(
        shrinkWrap: !widget.scrollable,
        physics: widget.scrollable
            ? null
            : const NeverScrollableScrollPhysics(),
        padding: EdgeInsets.zero,
        itemCount: activities.length,
        separatorBuilder: (_, _) =>
            const Divider(height: 1, color: Color(0xFFE8D7C2)),
        itemBuilder: (context, index) {
          final entry = activities[index];
          if (entry is LearningInventoryItem) {
            return _buildStudyModeActivity(entry);
          }
          final activity = entry as QuizActivity;
          return Padding(
            padding: const EdgeInsets.symmetric(vertical: 10),
            child: Row(
              children: [
                Expanded(
                  child: InkWell(
                    onTap: () => _showQuizDetails(activity),
                    borderRadius: BorderRadius.circular(12),
                    child: Padding(
                      padding: const EdgeInsets.symmetric(vertical: 6),
                      child: Row(
                        children: [
                          Container(
                            width: 40,
                            height: 40,
                            decoration: BoxDecoration(
                              color: const Color(0xFFFFF1DF),
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: const Icon(
                              Icons.quiz_outlined,
                              color: Color(0xFFF4773C),
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  activity.title,
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: const TextStyle(
                                    color: Color(0xFF3B2419),
                                    fontWeight: FontWeight.w700,
                                  ),
                                ),
                                const SizedBox(height: 5),
                                Text(
                                  '${activity.sourceFile} · ${_formatActivityDate(activity.createdAt)}',
                                  maxLines: 2,
                                  overflow: TextOverflow.ellipsis,
                                  style: const TextStyle(
                                    color: Color(0xFF725F53),
                                    fontSize: 12,
                                  ),
                                ),
                                if (activity.classroomName != null) ...[
                                  const SizedBox(height: 3),
                                  Text(
                                    'Classroom: ${activity.classroomName}',
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                    style: const TextStyle(
                                      color: Color(0xFF8A6B58),
                                      fontSize: 12,
                                      fontWeight: FontWeight.w600,
                                    ),
                                  ),
                                ],
                                const SizedBox(height: 6),
                                Container(
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 9,
                                    vertical: 4,
                                  ),
                                  decoration: BoxDecoration(
                                    color: const Color(0xFFFFF1E5),
                                    borderRadius: BorderRadius.circular(20),
                                  ),
                                  child: Text(
                                    '${activity.highestPercentage}% · ${activity.attempts.length} ${activity.attempts.length == 1 ? 'attempt' : 'attempts'}',
                                    style: const TextStyle(
                                      color: Color(0xFFB84E25),
                                      fontSize: 12,
                                      fontWeight: FontWeight.w700,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                if (_canRetake(activity))
                  FilledButton(
                    onPressed: () => _retakeQuiz(activity),
                    style: FilledButton.styleFrom(
                      padding: const EdgeInsets.symmetric(horizontal: 12),
                      visualDensity: VisualDensity.compact,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                    child: const Text('Retake'),
                  )
                else if (activity.classroomActivityId != null &&
                    activity.maxAttempts != null &&
                    activity.attempts.length >= activity.maxAttempts!)
                  const Icon(
                    Icons.check_circle_outline_rounded,
                    color: Color(0xFF578258),
                    semanticLabel: 'Attempt limit reached',
                  ),
              ],
            ),
          );
        },
      );
    },
  );

  Widget _buildStudyModeActivity(LearningInventoryItem activity) {
    final latestAttempt = activity.attempts.first;
    final isFlashcards = activity.type == LearningActivityType.flashcards;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 10),
      child: InkWell(
        onTap: () => widget.onMenuSelected(StudentMenuItem.inventory),
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 6),
          child: Row(
            children: [
              Container(
                width: 40,
                height: 40,
                decoration: BoxDecoration(
                  color: const Color(0xFFFFF1DF),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(
                  isFlashcards
                      ? Icons.style_outlined
                      : Icons.extension_outlined,
                  color: const Color(0xFFF4773C),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      activity.title,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        color: Color(0xFF3B2419),
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    const SizedBox(height: 5),
                    Text(
                      '${isFlashcards ? 'Flashcards' : 'Matching'} · ${_formatActivityDate(latestAttempt.createdAt)}',
                      style: const TextStyle(
                        color: Color(0xFF725F53),
                        fontSize: 12,
                      ),
                    ),
                    const SizedBox(height: 6),
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 9,
                        vertical: 4,
                      ),
                      decoration: BoxDecoration(
                        color: const Color(0xFFFFF1E5),
                        borderRadius: BorderRadius.circular(20),
                      ),
                      child: Text(
                        '${latestAttempt.percentage.round()}% · ${activity.attemptCount} ${activity.attemptCount == 1 ? 'attempt' : 'attempts'}',
                        style: const TextStyle(
                          color: Color(0xFFB84E25),
                          fontSize: 12,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              const Icon(Icons.chevron_right_rounded, color: Color(0xFF725F53)),
            ],
          ),
        ),
      ),
    );
  }

  String _formatActivityDate(DateTime date) {
    const months = [
      'Jan',
      'Feb',
      'Mar',
      'Apr',
      'May',
      'Jun',
      'Jul',
      'Aug',
      'Sep',
      'Oct',
      'Nov',
      'Dec',
    ];
    final localDate = date.toLocal();
    return '${months[localDate.month - 1]} ${localDate.day}';
  }

  Future<void> _showQuizDetails(QuizActivity activity) async {
    await showDialog<void>(
      context: context,
      builder: (dialogContext) => Dialog(
        backgroundColor: Colors.transparent,
        insetPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 24),
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 500, maxHeight: 620),
          child: Container(
            padding: const EdgeInsets.all(24),
            decoration: BoxDecoration(
              color: const Color(0xFFFFFCF8),
              borderRadius: BorderRadius.circular(24),
              border: Border.all(color: const Color(0xFFE8D7C2)),
              boxShadow: const [
                BoxShadow(
                  color: Color(0x26000000),
                  blurRadius: 32,
                  offset: Offset(0, 16),
                ),
              ],
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Container(
                      width: 48,
                      height: 48,
                      decoration: BoxDecoration(
                        color: const Color(0xFFFFF1DF),
                        borderRadius: BorderRadius.circular(16),
                      ),
                      child: const Icon(
                        Icons.quiz_outlined,
                        color: Color(0xFFF4773C),
                      ),
                    ),
                    const SizedBox(width: 14),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            activity.title,
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(
                              color: Color(0xFF3B2419),
                              fontSize: 21,
                              height: 1.2,
                              fontWeight: FontWeight.w800,
                            ),
                          ),
                          const SizedBox(height: 6),
                          Text(
                            activity.classroomName == null
                                ? 'Saved quiz · ${activity.totalQuestions} questions'
                                : '${activity.classroomName} · '
                                      '${activity.totalQuestions} questions',
                            style: const TextStyle(
                              color: Color(0xFF725F53),
                              fontSize: 13,
                            ),
                          ),
                        ],
                      ),
                    ),
                    IconButton(
                      tooltip: 'Close',
                      onPressed: () => Navigator.of(dialogContext).pop(),
                      icon: const Icon(Icons.close_rounded),
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.symmetric(
                    horizontal: 14,
                    vertical: 12,
                  ),
                  decoration: BoxDecoration(
                    color: const Color(0xFFF8F1E9),
                    borderRadius: BorderRadius.circular(14),
                  ),
                  child: Row(
                    children: [
                      const Icon(
                        Icons.insert_drive_file_outlined,
                        size: 18,
                        color: Color(0xFF8A6B58),
                      ),
                      const SizedBox(width: 9),
                      Expanded(
                        child: Text(
                          activity.sourceFile,
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                            color: Color(0xFF725F53),
                            fontSize: 13,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 20),
                Row(
                  children: [
                    const Expanded(
                      child: Text(
                        'Attempt history',
                        style: TextStyle(
                          color: Color(0xFF3B2419),
                          fontSize: 16,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                    ),
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 10,
                        vertical: 5,
                      ),
                      decoration: BoxDecoration(
                        color: const Color(0xFFFFF1DF),
                        borderRadius: BorderRadius.circular(20),
                      ),
                      child: Text(
                        activity.maxAttempts == null
                            ? '${activity.attempts.length} ${activity.attempts.length == 1 ? 'attempt' : 'attempts'}'
                            : '${activity.attempts.length} of ${activity.maxAttempts} attempts',
                        style: const TextStyle(
                          color: Color(0xFF9A512F),
                          fontSize: 12,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 10),
                Flexible(
                  child: ListView.separated(
                    shrinkWrap: true,
                    itemCount: activity.attempts.length,
                    separatorBuilder: (_, _) => const SizedBox(height: 8),
                    itemBuilder: (context, index) {
                      final attempt = activity.attempts[index];
                      final percent =
                          (attempt.score / attempt.totalQuestions * 100)
                              .round();
                      return Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 14,
                          vertical: 12,
                        ),
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(14),
                          border: Border.all(color: const Color(0xFFEFE4D8)),
                        ),
                        child: Row(
                          children: [
                            Container(
                              width: 34,
                              height: 34,
                              alignment: Alignment.center,
                              decoration: BoxDecoration(
                                color: const Color(0xFFFFF1DF),
                                borderRadius: BorderRadius.circular(11),
                              ),
                              child: Text(
                                '${index + 1}',
                                style: const TextStyle(
                                  color: Color(0xFF9A512F),
                                  fontWeight: FontWeight.w800,
                                ),
                              ),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    '${attempt.score} / ${attempt.totalQuestions} correct',
                                    style: const TextStyle(
                                      color: Color(0xFF3B2419),
                                      fontWeight: FontWeight.w700,
                                    ),
                                  ),
                                  const SizedBox(height: 3),
                                  Text(
                                    _formatActivityDate(attempt.createdAt),
                                    style: const TextStyle(
                                      color: Color(0xFF8A7A70),
                                      fontSize: 12,
                                    ),
                                  ),
                                  if (attempt.classroomName != null) ...[
                                    const SizedBox(height: 3),
                                    Text(
                                      'Classroom: ${attempt.classroomName}',
                                      style: const TextStyle(
                                        color: Color(0xFF8A6B58),
                                        fontSize: 12,
                                      ),
                                    ),
                                  ],
                                ],
                              ),
                            ),
                            Text(
                              '$percent%',
                              style: const TextStyle(
                                color: Color(0xFF9A512F),
                                fontSize: 16,
                                fontWeight: FontWeight.w800,
                              ),
                            ),
                          ],
                        ),
                      );
                    },
                  ),
                ),
                const SizedBox(height: 20),
                Row(
                  mainAxisAlignment: MainAxisAlignment.end,
                  children: [
                    TextButton(
                      onPressed: () => Navigator.of(dialogContext).pop(),
                      child: const Text('Close'),
                    ),
                    const SizedBox(width: 8),
                    if (_canRetake(activity))
                      FilledButton.icon(
                        onPressed: () {
                          Navigator.of(dialogContext).pop();
                          _retakeQuiz(activity);
                        },
                        style: FilledButton.styleFrom(
                          backgroundColor: const Color(0xFFFF7434),
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(
                            horizontal: 18,
                            vertical: 13,
                          ),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(14),
                          ),
                        ),
                        icon: const Icon(Icons.replay_rounded, size: 19),
                        label: const Text('Retake'),
                      )
                    else if (activity.classroomActivityId != null)
                      const Padding(
                        padding: EdgeInsets.only(left: 8),
                        child: Text(
                          'Retake from the classroom while it is open.',
                          style: TextStyle(
                            color: Color(0xFF725F53),
                            fontSize: 12,
                          ),
                        ),
                      ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Future<void> _retakeQuiz(QuizActivity activity) async {
    final user = widget.user;
    final completed = await Navigator.of(context).push<bool>(
      MaterialPageRoute<bool>(
        builder: (_) => QuizScreen(
          username: user.fullName,
          email: user.email,
          role: user.role,
          createdAt: user.createdAt,
          onMenuSelected: widget.onMenuSelected,
          title: activity.title,
          sourceFile: activity.sourceFile,
          questions: activity.questions,
          quizId: activity.id,
          previousAttempts: activity.attempts,
          classroomActivityId: activity.classroomActivityId,
        ),
      ),
    );
    if (completed == true && mounted) widget.onQuizCompleted();
  }

  bool _canRetake(QuizActivity activity) =>
      activity.classroomActivityId == null;
}

class _DashboardPanel extends StatelessWidget {
  const _DashboardPanel({
    super.key,
    this.icon,
    required this.title,
    this.titleTooltip,
    required this.description,
    this.actionLabel,
    this.onAction,
    this.secondaryActionLabel,
    this.onSecondaryAction,
    this.centerContent = false,
    this.titleAtTop = false,
    this.content,
    this.expandContent = false,
    this.titleSize = 22,
  });

  static const greetingPanelKey = ValueKey<String>('dashboard_panel_1');
  static const quizCreationPanelKey = ValueKey<String>('dashboard_panel_2');
  static const recentActivityPanelKey = ValueKey<String>('dashboard_panel_3');

  final IconData? icon;
  final String title;
  final Widget? titleTooltip;
  final String description;
  final String? actionLabel;
  final VoidCallback? onAction;
  final String? secondaryActionLabel;
  final VoidCallback? onSecondaryAction;
  final bool centerContent;
  final bool titleAtTop;
  final Widget? content;
  final bool expandContent;
  final double titleSize;

  @override
  Widget build(BuildContext context) {
    final hasPrimaryAction = actionLabel != null && onAction != null;
    final hasSecondaryAction =
        secondaryActionLabel != null && onSecondaryAction != null;
    final hasAction = hasPrimaryAction || hasSecondaryAction;

    return Container(
      width: double.infinity,
      padding: EdgeInsets.all(hasAction || content != null ? 18 : 24),
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
        mainAxisSize: hasAction ? MainAxisSize.min : MainAxisSize.max,
        mainAxisAlignment: centerContent && !titleAtTop
            ? MainAxisAlignment.center
            : MainAxisAlignment.start,
        crossAxisAlignment: centerContent
            ? CrossAxisAlignment.center
            : CrossAxisAlignment.start,
        children: [
          if (icon != null && !centerContent)
            Row(
              children: [
                Container(
                  width: 40,
                  height: 40,
                  decoration: BoxDecoration(
                    color: const Color(0xFFFFE9DC),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Icon(icon, color: const Color(0xFFF4773C), size: 21),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      _buildTitle(TextAlign.start, 17),
                      if (description.isNotEmpty) ...[
                        const SizedBox(height: 3),
                        Text(
                          description,
                          style: const TextStyle(
                            color: Color(0xFF765C4F),
                            fontSize: 12,
                            height: 1.35,
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
              ],
            )
          else if (icon != null) ...[
            Container(
              width: 40,
              height: 40,
              decoration: BoxDecoration(
                color: const Color(0xFFFFE9DC),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Icon(icon, color: const Color(0xFFF4773C), size: 21),
            ),
            SizedBox(height: hasAction ? 8 : 12),
            _buildTitle(
              centerContent ? TextAlign.center : TextAlign.start,
              titleSize,
            ),
          ] else
            _buildTitle(
              centerContent ? TextAlign.center : TextAlign.start,
              titleSize,
            ),
          if (description.isNotEmpty && !(icon != null && !centerContent)) ...[
            SizedBox(
              height: hasAction
                  ? 6
                  : content != null
                  ? 8
                  : 10,
            ),
            Text(
              description,
              textAlign: centerContent ? TextAlign.center : TextAlign.start,
              style: const TextStyle(
                color: Color(0xFF765C4F),
                fontSize: 13,
                height: 1.45,
              ),
            ),
          ],
          if (content != null) ...[
            if (icon != null && !centerContent)
              const Padding(
                padding: EdgeInsets.symmetric(vertical: 14),
                child: Divider(height: 1, color: Color(0xFFE8D7C2)),
              ),
            if (titleAtTop && description.isEmpty) const SizedBox(height: 8),
            if (!titleAtTop) const SizedBox(height: 8),
            if (expandContent) Expanded(child: content!) else content!,
          ],
          if (hasAction) ...[
            const SizedBox(height: 10),
            LayoutBuilder(
              builder: (context, constraints) {
                final primaryButton = FilledButton.icon(
                  onPressed: onAction,
                  style: FilledButton.styleFrom(
                    backgroundColor: const Color(0xFFF4773C),
                    foregroundColor: Colors.white,
                    minimumSize: const Size(0, 44),
                    padding: const EdgeInsets.symmetric(horizontal: 12),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                  icon: const Icon(Icons.upload_file_outlined, size: 18),
                  label: Text(actionLabel ?? ''),
                );
                final secondaryButton = OutlinedButton.icon(
                  onPressed: onSecondaryAction,
                  style: OutlinedButton.styleFrom(
                    foregroundColor: const Color(0xFFF4773C),
                    minimumSize: const Size(0, 44),
                    padding: const EdgeInsets.symmetric(horizontal: 12),
                    side: const BorderSide(color: Color(0xFFF4773C)),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                  icon: const Icon(Icons.auto_awesome_outlined, size: 18),
                  label: Text(secondaryActionLabel ?? ''),
                );

                if (hasPrimaryAction && hasSecondaryAction) {
                  final buttons = constraints.maxWidth >= 370
                      ? Row(
                          children: [
                            Expanded(child: primaryButton),
                            const SizedBox(width: 12),
                            Expanded(child: secondaryButton),
                          ],
                        )
                      : Column(
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                            primaryButton,
                            const SizedBox(height: 8),
                            secondaryButton,
                          ],
                        );
                  return SizedBox(width: constraints.maxWidth, child: buttons);
                }

                final isPrimary = hasPrimaryAction;
                return SizedBox(
                  width: constraints.maxWidth * 0.6,
                  height: 44,
                  child: isPrimary ? primaryButton : secondaryButton,
                );
              },
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildTitle(TextAlign alignment, double size) {
    final text = Text(
      title,
      textAlign: alignment,
      style: TextStyle(
        fontSize: size,
        fontWeight: FontWeight.w700,
        color: const Color(0xFF3B2419),
        letterSpacing: -0.2,
      ),
    );
    if (titleTooltip == null) return text;
    return Row(
      mainAxisSize: alignment == TextAlign.center
          ? MainAxisSize.min
          : MainAxisSize.max,
      mainAxisAlignment: alignment == TextAlign.center
          ? MainAxisAlignment.center
          : MainAxisAlignment.start,
      children: [
        Flexible(child: text),
        const SizedBox(width: 6),
        titleTooltip!,
      ],
    );
  }
}

class _StatsMetricTooltip extends StatelessWidget {
  const _StatsMetricTooltip();

  static const _headingStyle = TextStyle(
    color: Color(0xFFFFC18F),
    fontSize: 11,
    fontWeight: FontWeight.w800,
    letterSpacing: 0.8,
  );

  static const _bodyStyle = TextStyle(
    color: Color(0xFFFFF8F1),
    fontSize: 12,
    height: 1.4,
  );

  @override
  Widget build(BuildContext context) => Tooltip(
    triggerMode: TooltipTriggerMode.tap,
    preferBelow: false,
    showDuration: const Duration(seconds: 12),
    constraints: const BoxConstraints(maxWidth: 300),
    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
    decoration: BoxDecoration(
      color: const Color(0xFF3B2419),
      borderRadius: BorderRadius.circular(16),
      border: Border.all(color: const Color(0xFFF4773C).withValues(alpha: 0.6)),
      boxShadow: const [
        BoxShadow(
          color: Color(0x33000000),
          blurRadius: 18,
          offset: Offset(0, 8),
        ),
      ],
    ),
    richMessage: const TextSpan(
      children: [
        TextSpan(
          text: 'HOW YOUR STATS ARE CALCULATED\n\n',
          style: _headingStyle,
        ),
        TextSpan(text: 'ACCURACY\n', style: _headingStyle),
        TextSpan(
          text:
              'Correct answers across each quiz’s latest attempt ÷ questions on those attempts × 100.\n\n',
          style: _bodyStyle,
        ),
        TextSpan(text: 'RETENTION\n', style: _headingStyle),
        TextSpan(
          text:
              'Average each quiz’s latest two attempt accuracies, then average those quiz values. Requires two attempts per quiz.\n\n',
          style: _bodyStyle,
        ),
        TextSpan(text: 'IMPROVEMENT\n', style: _headingStyle),
        TextSpan(
          text:
              'Average the chronological accuracy changes per quiz, then across quizzes. Shown in percentage points; drops count as negative.\n\n',
          style: _bodyStyle,
        ),
        TextSpan(text: 'CONSISTENCY\n', style: _headingStyle),
        TextSpan(
          text:
              'Unique days with a completed quiz ÷ eligible days × 100. Uses the last 28 days, or days since account creation for newer accounts.\n\n',
          style: _bodyStyle,
        ),
        TextSpan(text: 'FOCUS\n', style: _headingStyle),
        TextSpan(
          text:
              'Correct answers across each quiz’s first attempt ÷ questions on those attempts × 100.',
          style: _bodyStyle,
        ),
      ],
    ),
    child: Semantics(
      button: true,
      label: 'Show how student stats are calculated',
      child: Container(
        width: 32,
        height: 32,
        decoration: BoxDecoration(
          color: const Color(0xFFFFF1E5),
          shape: BoxShape.circle,
          border: Border.all(color: const Color(0xFFF2D8C2)),
        ),
        child: const Icon(
          Icons.info_outline_rounded,
          size: 19,
          color: Color(0xFFF4773C),
        ),
      ),
    ),
  );
}

class _StudentMetricsChart extends StatefulWidget {
  const _StudentMetricsChart({
    required this.activityRevision,
    required this.accountCreatedAt,
  });

  final int activityRevision;
  final DateTime? accountCreatedAt;

  @override
  State<_StudentMetricsChart> createState() => _StudentMetricsChartState();
}

class _StudentMetricsChartState extends State<_StudentMetricsChart> {
  late Future<List<QuizActivity>> _metricsData;

  @override
  void initState() {
    super.initState();
    _metricsData = _loadMetrics();
  }

  @override
  void didUpdateWidget(covariant _StudentMetricsChart oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.activityRevision != widget.activityRevision) {
      _metricsData = _loadMetrics();
    }
  }

  Future<List<QuizActivity>> _loadMetrics() {
    try {
      return QuizService().recentAttempts();
    } on Object catch (error, stackTrace) {
      return Future<List<QuizActivity>>.error(error, stackTrace);
    }
  }

  void _retry() {
    setState(() => _metricsData = _loadMetrics());
  }

  @override
  Widget build(BuildContext context) => LayoutBuilder(
    builder: (context, constraints) {
      final preferredChartHeight = (constraints.maxWidth * 0.52)
          .clamp(200.0, 260.0)
          .toDouble();

      return FutureBuilder<List<QuizActivity>>(
        future: _metricsData,
        builder: (context, snapshot) {
          final quizzes = snapshot.data ?? const <QuizActivity>[];
          final accuracyPercentage = latestQuizAccuracyPercentage(quizzes);
          final retentionPercentage = averageQuizRetentionPercentage(quizzes);
          final improvementPercentage = averageQuizImprovementPercentage(
            quizzes,
          );
          final focusPercentage = firstQuizAttemptFocusPercentage(quizzes);
          final consistencyPercentage = quizLearningConsistencyPercentage(
            quizzes: quizzes,
            accountCreatedAt: widget.accountCreatedAt,
          );
          final status = snapshot.hasError
              ? Column(
                  children: [
                    Text(
                      'Could not load quiz metrics. Please try again.',
                      textAlign: TextAlign.center,
                      style: const TextStyle(
                        fontSize: 11,
                        color: Color(0xFF8A7A70),
                      ),
                    ),
                    TextButton(
                      onPressed: _retry,
                      child: const Text('Try again'),
                    ),
                  ],
                )
              : snapshot.connectionState == ConnectionState.waiting
              ? const Padding(
                  padding: EdgeInsets.only(top: 8),
                  child: SizedBox(
                    width: 18,
                    height: 18,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  ),
                )
              : null;

          final chart = StudentPerformanceRadarChart(
            accuracyPercentage: accuracyPercentage,
            retentionPercentage: retentionPercentage,
            improvementPercentage: improvementPercentage,
            consistencyPercentage: consistencyPercentage,
            focusPercentage: focusPercentage,
          );

          if (constraints.hasBoundedHeight) {
            return Column(
              children: [
                Expanded(
                  child: SizedBox(width: double.infinity, child: chart),
                ),
                ?status,
              ],
            );
          }

          return Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              SizedBox(
                height: preferredChartHeight,
                width: double.infinity,
                child: chart,
              ),
              ?status,
            ],
          );
        },
      );
    },
  );
}
