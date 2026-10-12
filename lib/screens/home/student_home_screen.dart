import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../../models/user_model.dart';
import '../../services/quiz_service.dart';
import '../import_screen.dart';
import '../profile_screen.dart';
import '../../widgets/student_side_menu.dart';

class StudentHomeScreen extends StatefulWidget {
  const StudentHomeScreen({required this.user, super.key});

  final UserModel user;

  @override
  State<StudentHomeScreen> createState() => _StudentHomeScreenState();
}

class _StudentHomeScreenState extends State<StudentHomeScreen> {
  int _activityRevision = 0;

  @override
  Widget build(BuildContext context) {
    final user = widget.user;

    Future<void> openImportScreen() async {
      final completed = await Navigator.of(context).push<bool>(
        MaterialPageRoute<bool>(
          builder: (_) =>
              ImportScreen(username: user.fullName, email: user.email),
        ),
      );
      if (completed == true && mounted) {
        setState(() => _activityRevision++);
      }
    }

    void openProfileScreen() {
      Navigator.of(context).push(
        MaterialPageRoute<void>(
          builder: (_) =>
              ProfileScreen(username: user.fullName, email: user.email),
        ),
      );
    }

    return StudentScaffold(
      title: 'Student Dashboard',
      username: user.fullName,
      email: user.email,
      selectedMenu: StudentMenuItem.dashboard,
      onMenuSelected: (item) {
        if (item == StudentMenuItem.profile) {
          openProfileScreen();
        }
      },
      body: LayoutBuilder(
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
                        ),
                      )
                    : _StackedStudentDashboard(
                        user: user,
                        onImportSelected: openImportScreen,
                        activityRevision: _activityRevision,
                      ),
              ),
            ),
          );
        },
      ),
    );
  }
}

class _WideStudentDashboard extends StatelessWidget {
  const _WideStudentDashboard({
    required this.user,
    required this.onImportSelected,
    required this.activityRevision,
  });

  final UserModel user;
  final VoidCallback onImportSelected;
  final int activityRevision;

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
                content: const _StudentMetricsChart(),
              ),
            ),
            const SizedBox(height: 20),
            _DashboardPanel(
              key: _DashboardPanel.learningOverviewPanelKey,
              icon: Icons.auto_stories_outlined,
              title: 'Learning overview',
              description: 'Your learning progress will appear here.',
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
          description: 'Your completed quizzes',
          content: _RecentActivityContent(key: ValueKey<int>(activityRevision)),
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
  });

  final UserModel user;
  final VoidCallback onImportSelected;
  final int activityRevision;

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
        content: const _StudentMetricsChart(),
      ),
      const SizedBox(height: 16),
      _DashboardPanel(
        key: _DashboardPanel.learningOverviewPanelKey,
        icon: Icons.auto_stories_outlined,
        title: 'Learning overview',
        description: 'Your learning progress will appear here.',
        actionLabel: 'Generate a quiz',
        onAction: onImportSelected,
        centerContent: true,
      ),
      const SizedBox(height: 16),
      _DashboardPanel(
        key: _DashboardPanel.recentActivityPanelKey,
        icon: Icons.history,
        title: 'Recent activity',
        description: 'Your completed quizzes',
        content: _RecentActivityContent(key: ValueKey<int>(activityRevision)),
      ),
    ],
  );
}

class _RecentActivityContent extends StatefulWidget {
  const _RecentActivityContent({super.key});

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
            'Your completed quizzes will appear here.',
            style: TextStyle(color: Color(0xFF725F53)),
          ),
        );
      }

      return ListView.separated(
        shrinkWrap: true,
        physics: const NeverScrollableScrollPhysics(),
        padding: EdgeInsets.zero,
        itemCount: activities.length,
        separatorBuilder: (_, _) => const Divider(height: 1),
        itemBuilder: (context, index) {
          final activity = activities[index];
          final percentage = (activity.score / activity.totalQuestions * 100)
              .round();
          return Padding(
            padding: const EdgeInsets.symmetric(vertical: 12),
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
                    ],
                  ),
                ),
                const SizedBox(width: 8),
                Text(
                  '$percentage%',
                  style: const TextStyle(
                    color: Color(0xFFF4773C),
                    fontWeight: FontWeight.w800,
                  ),
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
    this.titleSize = 22,
  });

  static const greetingPanelKey = ValueKey<String>('dashboard_panel_1');
  static const learningOverviewPanelKey = ValueKey<String>('dashboard_panel_2');
  static const recentActivityPanelKey = ValueKey<String>('dashboard_panel_3');

  final IconData? icon;
  final String title;
  final String description;
  final String? actionLabel;
  final VoidCallback? onAction;
  final bool centerContent;
  final bool titleAtTop;
  final Widget? content;
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
          if (content != null) ...[const SizedBox(height: 4), content!],
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

class _StudentMetricsChart extends StatelessWidget {
  const _StudentMetricsChart();

  static const _metrics = [
    'Accuracy',
    'Retention',
    'Improvement',
    'Consistency',
    'Efficiency',
  ];

  @override
  Widget build(BuildContext context) => LayoutBuilder(
    builder: (context, constraints) {
      final chartHeight =
          (constraints.maxWidth * 0.4).clamp(140.0, 175.0).toDouble() * 1.2;

      return Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          SizedBox(
            height: chartHeight,
            width: double.infinity,
            child: CustomPaint(
              painter: _RadarChartPainter(
                metrics: _metrics,
                gridColor: const Color(0xFFE9E1D8),
                accentColor: const Color(0xFFF4773C),
                labelColor: const Color(0xFF725F53),
              ),
            ),
          ),
          const Text(
            'Your metrics will appear as you complete learning activities.',
            textAlign: TextAlign.center,
            style: TextStyle(fontSize: 11, color: Color(0xFF8A7A70)),
          ),
        ],
      );
    },
  );
}

class _RadarChartPainter extends CustomPainter {
  const _RadarChartPainter({
    required this.metrics,
    required this.gridColor,
    required this.accentColor,
    required this.labelColor,
  });

  final List<String> metrics;
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

    final emptyLabel = TextPainter(
      text: TextSpan(
        text: 'No scores yet',
        style: TextStyle(
          color: accentColor,
          fontSize: 11,
          fontWeight: FontWeight.w600,
        ),
      ),
      textDirection: TextDirection.ltr,
    )..layout();
    emptyLabel.paint(
      canvas,
      Offset(
        center.dx - emptyLabel.width / 2,
        center.dy - emptyLabel.height / 2,
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
      oldDelegate.gridColor != gridColor ||
      oldDelegate.accentColor != accentColor ||
      oldDelegate.labelColor != labelColor;
}
