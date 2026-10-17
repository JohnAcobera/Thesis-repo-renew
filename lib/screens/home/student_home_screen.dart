import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../models/user_model.dart';
import '../../services/auth_service.dart';
import '../../services/classroom_service.dart';
import '../../services/leaderboard_service.dart';
import '../../services/quiz_service.dart';
import '../classroom/classroom_screen.dart';
import '../import_screen.dart';
import '../leaderboard_screen.dart';
import '../profile_screen.dart';
import '../quiz_screen.dart';
import '../../widgets/student_side_menu.dart';

class StudentHomeScreen extends StatefulWidget {
  const StudentHomeScreen({
    required this.user,
    this.classroomService,
    this.leaderboardRepository,
    super.key,
  });

  final UserModel user;
  final ClassroomRepository? classroomService;
  final LeaderboardRepository? leaderboardRepository;

  @override
  State<StudentHomeScreen> createState() => _StudentHomeScreenState();
}

class _StudentHomeScreenState extends State<StudentHomeScreen>
    with WidgetsBindingObserver {
  int _activityRevision = 0;
  StudentMenuItem _selectedMenu = StudentMenuItem.dashboard;
  bool _isRecordingActivityDay = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _recordActiveLearningDay();
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
      debugPrint('Active learning day not recorded: ${error.message}');
    } on Exception catch (error, stackTrace) {
      FlutterError.reportError(
        FlutterErrorDetails(
          exception: error,
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

    Future<void> openImportScreen() async {
      final completed = await Navigator.of(context).push<bool>(
        MaterialPageRoute<bool>(
          builder: (_) => ImportScreen(
            username: user.fullName,
            email: user.email,
            role: user.role,
            createdAt: user.createdAt,
            onMenuSelected: _selectMenuItem,
          ),
        ),
      );
      if (completed == true && mounted) {
        setState(() => _activityRevision++);
      }
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
          : 'Student Dashboard',
      username: user.fullName,
      email: user.email,
      role: _displayRole(user.role),
      selectedMenu: _selectedMenu,
      onMenuSelected: onMenuSelected,
      body: _selectedMenu == StudentMenuItem.classroom
          ? ClassroomScreen(
              user: user,
              classroomService: widget.classroomService,
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
                              activityRevision: _activityRevision,
                              onQuizCompleted: () =>
                                  setState(() => _activityRevision++),
                              onMenuSelected: _selectMenuItem,
                            ),
                          const SizedBox(height: 20),
                          SizedBox(
                            height: isWide ? 440 : 1080,
                            child: _StudentClassroomActivitiesSection(
                              key: ValueKey<int>(_activityRevision),
                              user: user,
                              classroomService: widget.classroomService,
                              onQuizCompleted: () =>
                                  setState(() => _activityRevision++),
                              onMenuSelected: _selectMenuItem,
                              sideBySide: isWide,
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
        item == StudentMenuItem.leaderboard) {
      setState(() => _selectedMenu = item);
    }
  }

  String _displayRole(String role) => role.isEmpty
      ? role
      : '${role[0].toUpperCase()}${role.substring(1).toLowerCase()}';
}

class _StudentClassroomActivitiesSection extends StatefulWidget {
  const _StudentClassroomActivitiesSection({
    required this.user,
    required this.classroomService,
    required this.onQuizCompleted,
    required this.onMenuSelected,
    required this.sideBySide,
    super.key,
  });

  final UserModel user;
  final ClassroomRepository? classroomService;
  final VoidCallback onQuizCompleted;
  final ValueChanged<StudentMenuItem> onMenuSelected;
  final bool sideBySide;

  @override
  State<_StudentClassroomActivitiesSection> createState() =>
      _StudentClassroomActivitiesSectionState();
}

class _StudentClassroomActivitiesSectionState
    extends State<_StudentClassroomActivitiesSection> {
  late Future<List<ClassroomActivity>> _activities;
  late final Timer _availabilityTimer;
  DateTime _visibleMonth = DateTime(DateTime.now().year, DateTime.now().month);

  @override
  void initState() {
    super.initState();
    _activities = _loadActivities();
    _availabilityTimer = Timer.periodic(const Duration(seconds: 30), (_) {
      if (mounted) setState(() {});
    });
  }

  @override
  void dispose() {
    _availabilityTimer.cancel();
    super.dispose();
  }

  Future<List<ClassroomActivity>> _loadActivities() async {
    final classroomService = widget.classroomService ?? ClassroomService();
    final classrooms = await classroomService.listStudentClassrooms();
    final activitiesByClassroom = await Future.wait(
      classrooms.map(
        (classroom) => classroomService.classroomActivities(classroom.id),
      ),
    );
    final activities = activitiesByClassroom
        .expand((classroomActivities) => classroomActivities)
        .toList();
    activities.sort(
      (first, second) => first.deadlineAt.compareTo(second.deadlineAt),
    );
    return activities;
  }

  void _retry() {
    setState(() => _activities = _loadActivities());
  }

  Future<void> _takeActivity(ClassroomActivity activity) async {
    final completed = await Navigator.of(context).push<bool>(
      MaterialPageRoute<bool>(
        builder: (_) => QuizScreen(
          username: widget.user.fullName,
          email: widget.user.email,
          role: widget.user.role,
          createdAt: widget.user.createdAt,
          onMenuSelected: widget.onMenuSelected,
          title: activity.title,
          sourceFile: activity.sourceFile,
          questions: activity.questions,
          quizId: activity.quizId,
          classroomActivityId: activity.id,
          previousAttempts: activity.attempts,
        ),
      ),
    );
    if (completed == true && mounted) widget.onQuizCompleted();
  }

  Future<void> _showActivitiesForDate(
    DateTime date,
    List<ClassroomActivity> activities,
  ) async {
    final dueActivities = activities
        .where((activity) {
          final deadline = activity.deadlineAt.toLocal();
          return deadline.year == date.year &&
              deadline.month == date.month &&
              deadline.day == date.day &&
              activity.attemptCount < activity.maxAttempts;
        })
        .toList(growable: false);
    if (dueActivities.isEmpty) return;

    await showDialog<void>(
      context: context,
      builder: (dialogContext) {
        final localizations = MaterialLocalizations.of(dialogContext);
        return AlertDialog(
          backgroundColor: const Color(0xFFFFFCF8),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(18),
          ),
          titlePadding: const EdgeInsets.fromLTRB(24, 24, 24, 8),
          contentPadding: const EdgeInsets.fromLTRB(24, 8, 24, 8),
          title: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'Deadlines',
                style: TextStyle(
                  color: Color(0xFF2F3940),
                  fontSize: 20,
                  fontWeight: FontWeight.w600,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                localizations.formatFullDate(date),
                style: const TextStyle(
                  color: Color(0xFF6C7A89),
                  fontSize: 14,
                  fontWeight: FontWeight.w400,
                ),
              ),
            ],
          ),
          content: ConstrainedBox(
            constraints: BoxConstraints(
              maxHeight: MediaQuery.sizeOf(dialogContext).height * 0.6,
            ),
            child: SizedBox(
              width: 460,
              child: ListView.separated(
                shrinkWrap: true,
                itemCount: dueActivities.length,
                separatorBuilder: (_, _) => const SizedBox(height: 10),
                itemBuilder: (context, index) {
                  final activity = dueActivities[index];
                  final canTakeActivity = activity.isAvailable;
                  final deadline = activity.deadlineAt.toLocal();
                  final deadlineTime = localizations.formatTimeOfDay(
                    TimeOfDay.fromDateTime(deadline),
                  );
                  final startsAt = activity.startsAt.toLocal();
                  final startsAtTime = localizations.formatTimeOfDay(
                    TimeOfDay.fromDateTime(startsAt),
                  );

                  return Container(
                    padding: const EdgeInsets.all(14),
                    decoration: BoxDecoration(
                      color: const Color(0xFFF8FBFC),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: const Color(0xFFDCE5E8)),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          activity.title,
                          style: const TextStyle(
                            color: Color(0xFF3B2419),
                            fontSize: 15,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        const SizedBox(height: 5),
                        Text(
                          'Classroom: ${activity.classroomName}',
                          style: const TextStyle(
                            color: Color(0xFF6C7A89),
                            fontSize: 13,
                          ),
                        ),
                        const SizedBox(height: 3),
                        Text(
                          '${activity.sourceFile} · ${activity.questions.length} questions',
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                            color: Color(0xFF8A7467),
                            fontSize: 12,
                          ),
                        ),
                        const SizedBox(height: 7),
                        Text(
                          canTakeActivity
                              ? 'Due at $deadlineTime'
                              : 'Available from $startsAtTime · Due at $deadlineTime',
                          style: const TextStyle(
                            color: Color(0xFF725F53),
                            fontSize: 12,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ],
                    ),
                  );
                },
              ),
            ),
          ),
          actionsPadding: const EdgeInsets.fromLTRB(16, 4, 16, 12),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(dialogContext).pop(),
              child: const Text('Close'),
            ),
          ],
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) => FutureBuilder<List<ClassroomActivity>>(
    future: _activities,
    builder: (context, snapshot) {
      final activities = snapshot.data ?? const <ClassroomActivity>[];
      final today = DateTime.now();
      final outstandingActivities = activities
          .where(
            (activity) =>
                activity.attemptCount < activity.maxAttempts &&
                !activity.deadlineAt.toLocal().isBefore(today),
          )
          .toList(growable: false);

      return LayoutBuilder(
        builder: (context, constraints) {
          final calendar = _ClassroomDeadlineCalendar(
            activities: outstandingActivities,
            visibleMonth: _visibleMonth,
            onMonthChanged: (month) => setState(() => _visibleMonth = month),
            onDateSelected: (date) =>
                _showActivitiesForDate(date, outstandingActivities),
          );
          final pending = _PendingClassroomActivities(
            isLoading: snapshot.connectionState == ConnectionState.waiting,
            error: snapshot.error,
            activities: outstandingActivities,
            onRetry: _retry,
            onTakeActivity: _takeActivity,
          );

          if (widget.sideBySide) {
            final calendarPanel =
                MediaQuery.orientationOf(context) == Orientation.landscape
                ? Align(
                    alignment: Alignment.center,
                    child: FractionallySizedBox(
                      widthFactor: 0.9,
                      heightFactor: 0.9,
                      child: calendar,
                    ),
                  )
                : calendar;
            return Row(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Expanded(flex: 5, child: calendarPanel),
                const SizedBox(width: 20),
                Expanded(flex: 6, child: pending),
              ],
            );
          }
          return Column(
            children: [
              SizedBox(height: constraints.maxHeight * 0.46, child: calendar),
              const SizedBox(height: 16),
              Expanded(child: pending),
            ],
          );
        },
      );
    },
  );
}

class _ClassroomDeadlineCalendar extends StatelessWidget {
  const _ClassroomDeadlineCalendar({
    required this.activities,
    required this.visibleMonth,
    required this.onMonthChanged,
    required this.onDateSelected,
  });

  final List<ClassroomActivity> activities;
  final DateTime visibleMonth;
  final ValueChanged<DateTime> onMonthChanged;
  final ValueChanged<DateTime> onDateSelected;

  @override
  Widget build(BuildContext context) {
    final localizations = MaterialLocalizations.of(context);
    final monthLabel = localizations.formatMonthYear(visibleMonth);
    final deadlineCounts = <int, int>{};
    for (final activity in activities) {
      final deadline = activity.deadlineAt.toLocal();
      if (deadline.year == visibleMonth.year &&
          deadline.month == visibleMonth.month) {
        deadlineCounts.update(
          deadline.day,
          (count) => count + 1,
          ifAbsent: () => 1,
        );
      }
    }
    final firstWeekday =
        DateTime(visibleMonth.year, visibleMonth.month).weekday - 1;
    final daysInMonth = DateTime(
      visibleMonth.year,
      visibleMonth.month + 1,
      0,
    ).day;
    final today = DateTime.now();

    return _SchedulePanel(
      icon: Icons.calendar_month_outlined,
      title: 'Classroom deadlines',
      description: 'Highlighted dates mark activity deadlines.',
      child: Column(
        children: [
          Row(
            children: [
              IconButton(
                tooltip: 'Previous month',
                onPressed: () => onMonthChanged(
                  DateTime(visibleMonth.year, visibleMonth.month - 1),
                ),
                icon: const Icon(Icons.chevron_left_rounded),
                color: const Color(0xFFF4773C),
              ),
              Expanded(
                child: Text(
                  monthLabel,
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                    color: Color(0xFF3B2419),
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
              IconButton(
                tooltip: 'Next month',
                onPressed: () => onMonthChanged(
                  DateTime(visibleMonth.year, visibleMonth.month + 1),
                ),
                icon: const Icon(Icons.chevron_right_rounded),
                color: const Color(0xFFF4773C),
              ),
            ],
          ),
          const SizedBox(height: 4),
          Row(
            children: [
              for (final weekday in ['M', 'T', 'W', 'T', 'F', 'S', 'S'])
                Expanded(
                  child: Center(
                    child: Text(
                      weekday,
                      style: const TextStyle(
                        color: Color(0xFF8A7467),
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                ),
            ],
          ),
          const SizedBox(height: 4),
          Expanded(
            child: Column(
              children: List.generate(
                6,
                (week) => Expanded(
                  child: Row(
                    children: List.generate(7, (weekday) {
                      final day = week * 7 + weekday - firstWeekday + 1;
                      if (day < 1 || day > daysInMonth) {
                        return const Expanded(child: SizedBox.shrink());
                      }
                      final isToday =
                          today.year == visibleMonth.year &&
                          today.month == visibleMonth.month &&
                          today.day == day;
                      final deadlineCount = deadlineCounts[day] ?? 0;
                      return Expanded(
                        child: _buildDayCell(
                          day: day,
                          isToday: isToday,
                          deadlineCount: deadlineCount,
                        ),
                      );
                    }),
                  ),
                ),
              ),
            ),
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              Container(
                width: 10,
                height: 10,
                decoration: const BoxDecoration(
                  color: Color(0xFFFFE6D8),
                  shape: BoxShape.circle,
                ),
              ),
              const SizedBox(width: 8),
              const Expanded(
                child: Text(
                  'Activity deadline',
                  style: TextStyle(color: Color(0xFF725F53), fontSize: 12),
                ),
              ),
              Text(
                '${activities.length} upcoming',
                style: const TextStyle(
                  color: Color(0xFF725F53),
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildDayCell({
    required int day,
    required bool isToday,
    required int deadlineCount,
  }) {
    final date = DateTime(visibleMonth.year, visibleMonth.month, day);
    return Semantics(
      label: '$day${deadlineCount > 0 ? ', $deadlineCount deadlines' : ''}',
      button: deadlineCount > 0,
      onTap: deadlineCount > 0 ? () => onDateSelected(date) : null,
      child: InkWell(
        onTap: deadlineCount > 0 ? () => onDateSelected(date) : null,
        borderRadius: BorderRadius.circular(10),
        child: Container(
          margin: const EdgeInsets.all(2),
          decoration: BoxDecoration(
            color: deadlineCount > 0
                ? const Color(0xFFFFE6D8)
                : Colors.transparent,
            border: isToday ? Border.all(color: const Color(0xFFF4773C)) : null,
            borderRadius: BorderRadius.circular(10),
          ),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Text(
                '$day',
                style: TextStyle(
                  color: deadlineCount > 0
                      ? const Color(0xFFB64E20)
                      : const Color(0xFF4B352A),
                  fontSize: 12,
                  fontWeight: deadlineCount > 0 || isToday
                      ? FontWeight.w700
                      : FontWeight.w400,
                ),
              ),
              if (deadlineCount > 0)
                Container(
                  width: 5,
                  height: 5,
                  decoration: const BoxDecoration(
                    color: Color(0xFFF4773C),
                    shape: BoxShape.circle,
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}

class _PendingClassroomActivities extends StatelessWidget {
  const _PendingClassroomActivities({
    required this.isLoading,
    required this.error,
    required this.activities,
    required this.onRetry,
    required this.onTakeActivity,
  });

  final bool isLoading;
  final Object? error;
  final List<ClassroomActivity> activities;
  final VoidCallback onRetry;
  final ValueChanged<ClassroomActivity> onTakeActivity;

  @override
  Widget build(BuildContext context) => _SchedulePanel(
    icon: Icons.assignment_late_outlined,
    title: 'Pending activities',
    description: 'Incomplete classroom activities, sorted by deadline.',
    child: isLoading
        ? const Center(
            child: CircularProgressIndicator(color: Color(0xFFF4773C)),
          )
        : error != null
        ? Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Text(
                'Could not load classroom activities: $error',
                textAlign: TextAlign.center,
                style: const TextStyle(color: Color(0xFF725F53)),
              ),
              TextButton.icon(
                onPressed: onRetry,
                icon: const Icon(Icons.refresh_rounded),
                label: const Text('Try again'),
              ),
            ],
          )
        : activities.isEmpty
        ? const Center(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(Icons.inbox_outlined, color: Color(0xFFC49A7E), size: 32),
                SizedBox(height: 8),
                Text(
                  "You're all caught up!",
                  style: TextStyle(
                    color: Color(0xFF3B2419),
                    fontWeight: FontWeight.w700,
                  ),
                ),
                SizedBox(height: 4),
                Text(
                  'New classroom activities will appear here.',
                  textAlign: TextAlign.center,
                  style: TextStyle(color: Color(0xFF725F53), fontSize: 12),
                ),
              ],
            ),
          )
        : ListView.separated(
            padding: EdgeInsets.zero,
            itemCount: activities.length,
            separatorBuilder: (_, _) => const SizedBox(height: 10),
            itemBuilder: (context, index) => _PendingClassroomActivityTile(
              activity: activities[index],
              onTakeActivity: onTakeActivity,
            ),
          ),
  );
}

class _PendingClassroomActivityTile extends StatelessWidget {
  const _PendingClassroomActivityTile({
    required this.activity,
    required this.onTakeActivity,
  });

  final ClassroomActivity activity;
  final ValueChanged<ClassroomActivity> onTakeActivity;

  @override
  Widget build(BuildContext context) {
    final canTakeActivity = activity.isAvailable;
    final scheduledAt = canTakeActivity
        ? activity.deadlineAt.toLocal()
        : activity.startsAt.toLocal();
    final deadlineDate = MaterialLocalizations.of(
      context,
    ).formatMediumDate(scheduledAt);
    final deadlineTime = MaterialLocalizations.of(
      context,
    ).formatTimeOfDay(TimeOfDay.fromDateTime(scheduledAt));

    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: const Color(0xFFFFFBF6),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: const Color(0xFFE8D7C2)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.quiz_outlined, color: Color(0xFFF4773C)),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  activity.title,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    color: Color(0xFF3B2419),
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 4),
          Text(
            'Classroom: ${activity.classroomName}',
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(color: Color(0xFF725F53), fontSize: 12),
          ),
          Text(
            '${activity.sourceFile} · ${activity.questions.length} questions · '
            '${activity.maxAttempts - activity.attemptCount} attempts left',
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(color: Color(0xFF8A7467), fontSize: 12),
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              const Icon(
                Icons.schedule_rounded,
                size: 16,
                color: Color(0xFFF4773C),
              ),
              const SizedBox(width: 5),
              Expanded(
                child: Text(
                  '${canTakeActivity ? 'Due' : 'Available'} '
                  '$deadlineDate at $deadlineTime',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    color: Color(0xFF725F53),
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          SizedBox(
            width: double.infinity,
            child: FilledButton.icon(
              onPressed: canTakeActivity
                  ? () => onTakeActivity(activity)
                  : null,
              style: FilledButton.styleFrom(
                backgroundColor: const Color(0xFFF4773C),
                foregroundColor: Colors.white,
                visualDensity: VisualDensity.compact,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(10),
                ),
              ),
              icon: const Icon(Icons.play_arrow_rounded),
              label: Text(canTakeActivity ? 'Take activity' : 'Available soon'),
            ),
          ),
        ],
      ),
    );
  }
}

class _SchedulePanel extends StatelessWidget {
  const _SchedulePanel({
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
    required this.activityRevision,
    required this.onQuizCompleted,
    required this.onMenuSelected,
  });

  final UserModel user;
  final VoidCallback onImportSelected;
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
                description: '',
                titleSize: 30,
                centerContent: true,
                titleAtTop: true,
                content: _StudentMetricsChart(
                  activityRevision: activityRevision,
                  accountCreatedAt: user.createdAt,
                ),
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
          description: '',
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
    required this.activityRevision,
    required this.onQuizCompleted,
    required this.onMenuSelected,
  });

  final UserModel user;
  final VoidCallback onImportSelected;
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
        description: '',
        titleSize: 28,
        centerContent: true,
        titleAtTop: true,
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
        centerContent: true,
      ),
      const SizedBox(height: 16),
      _DashboardPanel(
        key: _DashboardPanel.recentActivityPanelKey,
        icon: Icons.history,
        title: 'Recent activity',
        description: '',
        content: _RecentActivityContent(
          key: ValueKey<int>(activityRevision),
          user: user,
          onQuizCompleted: onQuizCompleted,
          onMenuSelected: onMenuSelected,
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
  late Future<List<QuizActivity>> _activities;

  @override
  void initState() {
    super.initState();
    _activities = _loadActivities();
  }

  void _retry() {
    setState(() => _activities = _loadActivities());
  }

  Future<List<QuizActivity>> _loadActivities() {
    try {
      return QuizService().recentAttempts();
    } on Object catch (error, stackTrace) {
      return Future<List<QuizActivity>>.error(error, stackTrace);
    }
  }

  @override
  Widget build(BuildContext context) => FutureBuilder<List<QuizActivity>>(
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
              'Could not load recent activity: ${snapshot.error}',
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

      final activities = snapshot.data ?? const <QuizActivity>[];
      if (activities.isEmpty) {
        return const Padding(
          padding: EdgeInsets.symmetric(vertical: 12),
          child: Text(
            'No quiz activity yet. Complete a quiz and it will appear here.',
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
        separatorBuilder: (_, _) => const Divider(height: 1),
        itemBuilder: (context, index) {
          final activity = activities[index];
          return Padding(
            padding: const EdgeInsets.symmetric(vertical: 8),
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
                                  style: const TextStyle(
                                    color: Color(0xFF3B2419),
                                    fontWeight: FontWeight.w700,
                                  ),
                                ),
                                const SizedBox(height: 3),
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
                                const SizedBox(height: 3),
                                Text(
                                  '${activity.highestPercentage}% · ${activity.attempts.length} ${activity.attempts.length == 1 ? 'attempt' : 'attempts'}',
                                  style: const TextStyle(
                                    color: Color(0xFFF4773C),
                                    fontWeight: FontWeight.w800,
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
    required this.description,
    this.actionLabel,
    this.onAction,
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
  final String description;
  final String? actionLabel;
  final VoidCallback? onAction;
  final bool centerContent;
  final bool titleAtTop;
  final Widget? content;
  final bool expandContent;
  final double titleSize;

  @override
  Widget build(BuildContext context) {
    final hasAction = actionLabel != null && onAction != null;

    return Container(
      width: double.infinity,
      padding: EdgeInsets.all(hasAction || content != null ? 16 : 24),
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
        mainAxisSize: hasAction ? MainAxisSize.min : MainAxisSize.max,
        mainAxisAlignment: centerContent && !titleAtTop
            ? MainAxisAlignment.center
            : MainAxisAlignment.start,
        crossAxisAlignment: centerContent
            ? CrossAxisAlignment.center
            : CrossAxisAlignment.start,
        children: [
          if (icon != null) ...[
            Icon(icon, color: const Color(0xFFF4773C), size: 28),
            SizedBox(
              height: hasAction
                  ? 12
                  : content != null
                  ? 8
                  : 16,
            ),
          ],
          Text(
            title,
            textAlign: centerContent ? TextAlign.center : TextAlign.start,
            style: TextStyle(
              fontSize: titleSize,
              fontWeight: FontWeight.w800,
              color: const Color(0xFF3B2419),
            ),
          ),
          if (description.isNotEmpty) ...[
            SizedBox(
              height: hasAction
                  ? 8
                  : content != null
                  ? 6
                  : 10,
            ),
            Text(
              description,
              textAlign: centerContent ? TextAlign.center : TextAlign.start,
            ),
          ],
          if (content != null) ...[
            const SizedBox(height: 4),
            if (expandContent) Expanded(child: content!) else content!,
          ],
          if (hasAction) ...[
            const SizedBox(height: 12),
            LayoutBuilder(
              builder: (context, constraints) => Align(
                alignment: centerContent
                    ? Alignment.center
                    : Alignment.centerLeft,
                child: SizedBox(
                  width: constraints.maxWidth * 0.6,
                  height: 48,
                  child: FilledButton.icon(
                    onPressed: onAction,
                    style: FilledButton.styleFrom(
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                    icon: const Icon(Icons.upload_file_outlined),
                    label: Text(actionLabel!),
                  ),
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }
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

  static const _metrics = [
    'Accuracy',
    'Retention',
    'Improvement',
    'Consistency',
    'Efficiency',
  ];

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
      final chartHeight = (constraints.maxWidth * 0.52)
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
          final consistencyPercentage = quizLearningConsistencyPercentage(
            quizzes: quizzes,
            accountCreatedAt: widget.accountCreatedAt,
          );

          return Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              SizedBox(
                height: chartHeight,
                width: double.infinity,
                child: CustomPaint(
                  painter: _RadarChartPainter(
                    metrics: _metrics,
                    accuracyPercentage: accuracyPercentage,
                    retentionPercentage: retentionPercentage,
                    improvementPercentage: improvementPercentage,
                    consistencyPercentage: consistencyPercentage,
                    gridColor: const Color(0xFFE9E1D8),
                    accentColor: const Color(0xFFF4773C),
                    labelColor: const Color(0xFF725F53),
                  ),
                ),
              ),
              if (snapshot.hasError)
                Column(
                  children: [
                    Text(
                      'Could not load quiz metrics: ${snapshot.error}',
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
              else if (snapshot.connectionState == ConnectionState.waiting)
                const Padding(
                  padding: EdgeInsets.only(top: 8),
                  child: SizedBox(
                    width: 18,
                    height: 18,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  ),
                ),
            ],
          );
        },
      );
    },
  );
}

class _RadarChartPainter extends CustomPainter {
  const _RadarChartPainter({
    required this.metrics,
    required this.accuracyPercentage,
    required this.retentionPercentage,
    required this.improvementPercentage,
    required this.consistencyPercentage,
    required this.gridColor,
    required this.accentColor,
    required this.labelColor,
  });

  final List<String> metrics;
  final double? accuracyPercentage;
  final double? retentionPercentage;
  final double? improvementPercentage;
  final double? consistencyPercentage;
  final Color gridColor;
  final Color accentColor;
  final Color labelColor;

  @override
  void paint(Canvas canvas, Size size) {
    if (metrics.isEmpty || size.isEmpty) return;

    final center = Offset(size.width / 2, size.height / 2);
    final radius = math.min((size.width - 116) / 2, (size.height - 72) / 2);
    if (radius <= 0) return;

    final angles = List<double>.generate(
      metrics.length,
      (index) => -math.pi / 2 + (2 * math.pi * index / metrics.length),
    );
    final gridPaint = Paint()
      ..color = gridColor
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1;

    for (var level = 1; level <= 4; level++) {
      final levelRadius = radius * level / 4;
      final path = Path();
      for (var index = 0; index < angles.length; index++) {
        final point = Offset(
          center.dx + math.cos(angles[index]) * levelRadius,
          center.dy + math.sin(angles[index]) * levelRadius,
        );
        if (index == 0) {
          path.moveTo(point.dx, point.dy);
        } else {
          path.lineTo(point.dx, point.dy);
        }
      }
      path.close();
      canvas.drawPath(path, gridPaint);
    }

    for (final angle in angles) {
      canvas.drawLine(
        center,
        Offset(
          center.dx + math.cos(angle) * radius,
          center.dy + math.sin(angle) * radius,
        ),
        gridPaint,
      );
    }

    final metricValues = [
      accuracyPercentage,
      retentionPercentage,
      improvementPercentage == null
          ? null
          : (improvementPercentage! + 100).clamp(0.0, 200.0) / 2,
      consistencyPercentage,
      null,
    ];
    final metricPoints = List<Offset>.generate(metrics.length, (index) {
      final value = index < metricValues.length
          ? metricValues[index] ?? 0.0
          : 0.0;
      final normalizedValue = value.clamp(0.0, 100.0) / 100;
      return Offset(
        center.dx + math.cos(angles[index]) * radius * normalizedValue,
        center.dy + math.sin(angles[index]) * radius * normalizedValue,
      );
    });

    if (metricValues.any((value) => value != null)) {
      final dataPath = Path()
        ..moveTo(metricPoints.first.dx, metricPoints.first.dy);
      for (final point in metricPoints.skip(1)) {
        dataPath.lineTo(point.dx, point.dy);
      }
      dataPath.close();
      canvas.drawPath(
        dataPath,
        Paint()
          ..color = accentColor.withValues(alpha: 0.18)
          ..style = PaintingStyle.fill,
      );
      canvas.drawPath(
        dataPath,
        Paint()
          ..color = accentColor
          ..style = PaintingStyle.stroke
          ..strokeWidth = 2,
      );

      for (var index = 0; index < metricPoints.length; index++) {
        if (index >= metricValues.length || metricValues[index] == null) {
          continue;
        }
        canvas.drawCircle(
          metricPoints[index],
          4,
          Paint()
            ..color = accentColor
            ..style = PaintingStyle.fill,
        );
      }
    }

    final centerLabel = TextPainter(
      text: TextSpan(
        text: accuracyPercentage == null
            ? 'No scores yet'
            : '${accuracyPercentage!.round()}%',
        style: TextStyle(
          color: accentColor,
          fontSize: 12,
          fontWeight: FontWeight.w600,
        ),
      ),
      textDirection: TextDirection.ltr,
    )..layout();
    centerLabel.paint(
      canvas,
      Offset(
        center.dx - centerLabel.width / 2,
        center.dy - centerLabel.height / 2,
      ),
    );

    for (var index = 0; index < metrics.length; index++) {
      final angle = angles[index];
      final label = TextPainter(
        text: TextSpan(
          text: metrics[index],
          style: TextStyle(
            color: labelColor,
            fontSize: 12.5,
            fontWeight: FontWeight.w600,
          ),
        ),
        textDirection: TextDirection.ltr,
      )..layout();
      final labelCenter = Offset(
        center.dx + math.cos(angle) * (radius + 22),
        center.dy + math.sin(angle) * (radius + 22),
      );
      label.paint(
        canvas,
        Offset(
          (labelCenter.dx - label.width / 2).clamp(
            8.0,
            size.width - label.width - 8,
          ),
          (labelCenter.dy - label.height / 2).clamp(
            8.0,
            size.height - label.height - 8,
          ),
        ),
      );
    }
  }

  @override
  bool shouldRepaint(covariant _RadarChartPainter oldDelegate) =>
      oldDelegate.metrics != metrics ||
      oldDelegate.accuracyPercentage != accuracyPercentage ||
      oldDelegate.retentionPercentage != retentionPercentage ||
      oldDelegate.improvementPercentage != improvementPercentage ||
      oldDelegate.consistencyPercentage != consistencyPercentage ||
      oldDelegate.gridColor != gridColor ||
      oldDelegate.accentColor != accentColor ||
      oldDelegate.labelColor != labelColor;
}
