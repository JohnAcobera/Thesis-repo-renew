import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../models/user_model.dart';
import '../../services/auth_service.dart';
import '../../services/classroom_service.dart';
import '../../services/quiz_service.dart';
import '../classroom/classroom_screen.dart';
import '../import_screen.dart';
import '../profile_screen.dart';
import '../quiz_screen.dart';
import '../../widgets/student_side_menu.dart';

class StudentHomeScreen extends StatefulWidget {
  const StudentHomeScreen({
    required this.user,
    this.classroomService,
    super.key,
  });

  final UserModel user;
  final ClassroomRepository? classroomService;

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
          : LayoutBuilder(
              builder: (context, viewport) {
                final isWide = viewport.maxWidth >= 800;
                final dashboardHeight = (viewport.maxHeight - 48)
                    .clamp(520.0, 720.0)
                    .toDouble();

                return SingleChildScrollView(
                  padding: const EdgeInsets.all(24),
                  child: Center(
                    child: ConstrainedBox(
                      constraints: const BoxConstraints(maxWidth: 1280),
                      child: isWide
                          ? SizedBox(
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
                          : _StackedStudentDashboard(
                              user: user,
                              onImportSelected: openImportScreen,
                              activityRevision: _activityRevision,
                              onQuizCompleted: () =>
                                  setState(() => _activityRevision++),
                              onMenuSelected: _selectMenuItem,
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
        item == StudentMenuItem.classroom) {
      setState(() => _selectedMenu = item);
    }
  }

  String _displayRole(String role) => role.isEmpty
      ? role
      : '${role[0].toUpperCase()}${role.substring(1).toLowerCase()}';
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
                ),
              ),
            ),
            const SizedBox(height: 20),
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
        content: _StudentMetricsChart(activityRevision: activityRevision),
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
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: const TextStyle(
                                    color: Color(0xFF3B2419),
                                    fontWeight: FontWeight.w700,
                                  ),
                                ),
                                const SizedBox(height: 3),
                                Text(
                                  '${activity.sourceFile} · ${_formatActivityDate(activity.createdAt)}',
                                  maxLines: 1,
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
                              ],
                            ),
                          ),
                          const SizedBox(width: 8),
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
  const _StudentMetricsChart({required this.activityRevision});

  final int activityRevision;

  @override
  State<_StudentMetricsChart> createState() => _StudentMetricsChartState();
}

class _StudentMetricsChartState extends State<_StudentMetricsChart> {
  late Future<(List<QuizScore>, List<QuizActivity>)> _metricsData;

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

  Future<(List<QuizScore>, List<QuizActivity>)> _loadMetrics() async {
    try {
      final quizService = QuizService();
      return await (
        quizService.recentQuizScores(),
        quizService.recentAttempts(),
      ).wait;
    } on Object catch (error, stackTrace) {
      Error.throwWithStackTrace(error, stackTrace);
    }
  }

  double? _accuracyPercentage(List<QuizScore> attempts) {
    if (attempts.isEmpty) return null;

    final totalScore = attempts.fold<int>(
      0,
      (total, attempt) => total + attempt.score,
    );
    final totalQuestions = attempts.fold<int>(
      0,
      (total, attempt) => total + attempt.totalQuestions,
    );
    return totalScore / totalQuestions * 100;
  }

  void _retry() {
    setState(() => _metricsData = _loadMetrics());
  }

  @override
  Widget build(BuildContext context) => LayoutBuilder(
    builder: (context, constraints) {
      final chartHeight =
          (constraints.maxWidth * 0.4).clamp(140.0, 175.0).toDouble() * 1.2;

      return FutureBuilder<(List<QuizScore>, List<QuizActivity>)>(
        future: _metricsData,
        builder: (context, snapshot) {
          final attempts = snapshot.data?.$1 ?? const <QuizScore>[];
          final quizzes = snapshot.data?.$2 ?? const <QuizActivity>[];
          final accuracyPercentage = _accuracyPercentage(attempts);
          final retentionPercentage = averageQuizRetentionPercentage(quizzes);

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
                )
              else
                Text(
                  accuracyPercentage == null
                      ? 'Your metrics will appear as you complete learning activities.'
                      : 'Accuracy: ${accuracyPercentage.round()}% across ${attempts.length} ${attempts.length == 1 ? 'attempt' : 'attempts'}${retentionPercentage == null ? '' : ' · Retention: ${retentionPercentage.round()}%'}',
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                    fontSize: 11,
                    color: Color(0xFF8A7A70),
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
    required this.gridColor,
    required this.accentColor,
    required this.labelColor,
  });

  final List<String> metrics;
  final double? accuracyPercentage;
  final double? retentionPercentage;
  final Color gridColor;
  final Color accentColor;
  final Color labelColor;

  @override
  void paint(Canvas canvas, Size size) {
    if (metrics.isEmpty || size.isEmpty) return;

    final center = Offset(size.width / 2, size.height / 2);
    final radius = math.min((size.width - 112) / 2, (size.height - 48) / 2);
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

    final centerPaint = Paint()
      ..color = accentColor.withValues(alpha: 0.12)
      ..style = PaintingStyle.fill;
    canvas.drawCircle(center, 31, centerPaint);

    if (accuracyPercentage != null) {
      final accuracyPoint = Offset(
        center.dx + math.cos(angles.first) * radius * accuracyPercentage! / 100,
        center.dy + math.sin(angles.first) * radius * accuracyPercentage! / 100,
      );
      final accuracyPaint = Paint()
        ..color = accentColor
        ..strokeWidth = 2;
      canvas.drawLine(center, accuracyPoint, accuracyPaint);
      canvas.drawCircle(
        accuracyPoint,
        4,
        Paint()
          ..color = accentColor
          ..style = PaintingStyle.fill,
      );
    }
    if (retentionPercentage != null) {
      final retentionPoint = Offset(
        center.dx + math.cos(angles[1]) * radius * retentionPercentage! / 100,
        center.dy + math.sin(angles[1]) * radius * retentionPercentage! / 100,
      );
      canvas.drawLine(
        center,
        retentionPoint,
        Paint()
          ..color = accentColor.withValues(alpha: 0.7)
          ..strokeWidth = 2,
      );
      canvas.drawCircle(
        retentionPoint,
        4,
        Paint()
          ..color = accentColor.withValues(alpha: 0.7)
          ..style = PaintingStyle.fill,
      );
    }

    final centerLabel = TextPainter(
      text: TextSpan(
        text: accuracyPercentage == null
            ? 'No scores yet'
            : '${accuracyPercentage!.round()}%',
        style: TextStyle(
          color: accentColor,
          fontSize: 11,
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
            fontSize: 14.3,
            fontWeight: FontWeight.w600,
          ),
        ),
        textDirection: TextDirection.ltr,
      )..layout();
      final labelCenter = Offset(
        center.dx + math.cos(angle) * (radius + 20),
        center.dy + math.sin(angle) * (radius + 20),
      );
      label.paint(
        canvas,
        Offset(
          (labelCenter.dx - label.width / 2).clamp(
            0.0,
            size.width - label.width,
          ),
          (labelCenter.dy - label.height / 2).clamp(
            0.0,
            size.height - label.height,
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
      oldDelegate.gridColor != gridColor ||
      oldDelegate.accentColor != accentColor ||
      oldDelegate.labelColor != labelColor;
}
