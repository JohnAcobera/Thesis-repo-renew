import 'dart:math' as math;

import 'package:flutter/material.dart';

import 'auth/login_screen.dart';
import '../services/auth_service.dart';
import '../services/quiz_service.dart';
import '../widgets/app_glass_surface.dart';
import '../widgets/instructor_side_menu.dart';
import '../widgets/learning_metric_chart.dart';
import '../widgets/student_side_menu.dart';
import '../widgets/student_nav_bar.dart';

class ProfileScreen extends StatefulWidget {
  const ProfileScreen({
    required this.username,
    required this.email,
    this.role = 'student',
    this.createdAt,
    this.onMenuSelected,
    this.onInstructorMenuSelected,
    this.streakDays,
    this.authService,
    super.key,
  });

  final String username;
  final String email;
  final String role;
  final DateTime? createdAt;
  final ValueChanged<StudentMenuItem>? onMenuSelected;
  final ValueChanged<InstructorMenuItem>? onInstructorMenuSelected;
  final Set<DateTime>? streakDays;
  final ProfileDataService? authService;

  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen> {
  static const _menuAnimationDuration = Duration(milliseconds: 280);

  late final ProfileDataService _authService =
      widget.authService ?? AuthService();
  late Future<int> _learnerPointsFuture = _loadLearnerPoints();
  late Future<int?> _weeklyRankingFuture = _loadWeeklyRanking();
  late Future<List<QuizActivity>> _quizMetricsFuture = _loadQuizMetrics();
  bool _isInstructorMenuOpen = false;

  Future<int> _loadLearnerPoints() async => await _authService.learnerPoints();

  Future<int?> _loadWeeklyRanking() async => await _authService.weeklyRanking();

  Future<List<QuizActivity>> _loadQuizMetrics() async =>
      await QuizService().recentAttempts();

  @override
  Widget build(BuildContext context) => _isInstructor
      ? _buildInstructorScaffold()
      : StudentScaffold(
          title: 'Profile',
          username: widget.username,
          email: widget.email,
          role: _displayRole,
          selectedMenu: StudentMenuItem.profile,
          onMenuSelected: (item) {
            if (item == StudentMenuItem.dashboard ||
                item == StudentMenuItem.classroom ||
                item == StudentMenuItem.leaderboard ||
                item == StudentMenuItem.inventory) {
              final callback = widget.onMenuSelected;
              Navigator.of(context).popUntil((route) => route.isFirst);
              callback?.call(item);
            }
          },
          body: _buildProfileContent(),
        );

  Widget _buildInstructorScaffold() => Scaffold(
    backgroundColor: Colors.transparent,
    appBar: StudentNavBar(
      title: 'Profile',
      username: widget.username,
      email: widget.email,
      roleLabel: _displayRole,
      onLogoutSelected: _logout,
      leading: IconButton(
        tooltip: _isInstructorMenuOpen ? 'Close menu' : 'Open menu',
        onPressed: () =>
            setState(() => _isInstructorMenuOpen = !_isInstructorMenuOpen),
        icon: const Icon(Icons.menu),
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

        return Stack(
          clipBehavior: Clip.hardEdge,
          children: [
            Positioned.fill(child: _buildProfileContent()),
            Positioned.fill(
              child: IgnorePointer(
                ignoring: !_isInstructorMenuOpen,
                child: AnimatedOpacity(
                  duration: _menuAnimationDuration,
                  curve: Curves.easeInOut,
                  opacity: _isInstructorMenuOpen ? 1 : 0,
                  child: GestureDetector(
                    behavior: HitTestBehavior.opaque,
                    onTap: () => setState(() => _isInstructorMenuOpen = false),
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
                duration: _menuAnimationDuration,
                curve: Curves.easeInOutCubic,
                offset: _isInstructorMenuOpen
                    ? Offset.zero
                    : const Offset(-1, 0),
                child: AnimatedOpacity(
                  duration: _menuAnimationDuration,
                  curve: Curves.easeInOut,
                  opacity: _isInstructorMenuOpen ? 1 : 0,
                  child: IgnorePointer(
                    ignoring: !_isInstructorMenuOpen,
                    child: ExcludeSemantics(
                      excluding: !_isInstructorMenuOpen,
                      child: InstructorSideMenu(
                        username: widget.username,
                        email: widget.email,
                        role: _displayRole,
                        selectedMenu: null,
                        onMenuSelected: _selectInstructorMenuItem,
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

  Widget _buildProfileContent() => SafeArea(
    child: SingleChildScrollView(
      padding: const EdgeInsets.all(24),
      child: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 800),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(
                'Your profile',
                style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                  color: const Color(0xFF3B2419),
                  fontWeight: FontWeight.w600,
                ),
              ),
              const SizedBox(height: 8),
              const Text(
                'View your account information.',
                style: TextStyle(color: Color(0xFF765C4F)),
              ),
              const SizedBox(height: 24),
              AppGlassSurface(
                width: double.infinity,
                borderRadius: 20,
                padding: const EdgeInsets.all(24),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Center(
                      child: Column(
                        children: [
                          const CircleAvatar(
                            radius: 40,
                            backgroundColor: Color(0xFFFFE5D5),
                            child: Icon(
                              Icons.account_circle,
                              size: 56,
                              color: Color(0xFFF4773C),
                            ),
                          ),
                          const SizedBox(height: 16),
                          Text(
                            widget.username,
                            textAlign: TextAlign.center,
                            style: Theme.of(context).textTheme.titleLarge
                                ?.copyWith(
                                  color: const Color(0xFF3B2419),
                                  fontWeight: FontWeight.w600,
                                ),
                          ),
                          const SizedBox(height: 6),
                          Text(
                            _displayRole,
                            style: const TextStyle(
                              color: Color(0xFF765C4F),
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                          const SizedBox(height: 12),
                          if (!_isInstructor) ...[
                            _LearnerPointsBadge(
                              pointsFuture: _learnerPointsFuture,
                              onRetry: () => setState(
                                () =>
                                    _learnerPointsFuture = _loadLearnerPoints(),
                              ),
                            ),
                            const SizedBox(height: 8),
                            _WeeklyRankingLabel(
                              rankingFuture: _weeklyRankingFuture,
                              onRetry: () => setState(
                                () =>
                                    _weeklyRankingFuture = _loadWeeklyRanking(),
                              ),
                            ),
                          ],
                        ],
                      ),
                    ),
                    const SizedBox(height: 28),
                    const Divider(color: Color(0xFFE8D7C2)),
                    const SizedBox(height: 16),
                    _ProfileDetail(
                      label: 'Full name',
                      value: widget.username,
                      icon: Icons.person_outline,
                    ),
                    const SizedBox(height: 20),
                    _ProfileDetail(
                      label: 'Email address',
                      value: widget.email,
                      icon: Icons.email_outlined,
                    ),
                    const SizedBox(height: 20),
                    _ProfileDetail(
                      label: 'Joined',
                      value: widget.createdAt == null
                          ? 'Not available'
                          : _formatDate(widget.createdAt!),
                      icon: Icons.calendar_today_outlined,
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 24),
              if (!_isInstructor) _buildMetricsPanel(),
            ],
          ),
        ),
      ),
    ),
  );

  void _selectInstructorMenuItem(InstructorMenuItem item) {
    final callback = widget.onInstructorMenuSelected;
    setState(() => _isInstructorMenuOpen = false);
    Navigator.of(context).popUntil((route) => route.isFirst);
    callback?.call(item);
  }

  Future<void> _logout() async {
    await AuthService().logout();
    if (!mounted) return;
    Navigator.of(context).pushAndRemoveUntil(
      MaterialPageRoute<void>(builder: (_) => const LoginScreen()),
      (_) => false,
    );
  }

  String get _displayRole => widget.role.isEmpty
      ? widget.role
      : '${widget.role[0].toUpperCase()}'
            '${widget.role.substring(1).toLowerCase()}';

  bool get _isInstructor => widget.role.trim().toLowerCase() == 'instructor';

  String _formatDate(DateTime date) {
    const monthNames = [
      'January',
      'February',
      'March',
      'April',
      'May',
      'June',
      'July',
      'August',
      'September',
      'October',
      'November',
      'December',
    ];
    return '${monthNames[date.month - 1]} ${date.day}, ${date.year}';
  }

  Widget _buildMetricsPanel() => AppGlassSurface(
    width: double.infinity,
    borderRadius: 20,
    padding: const EdgeInsets.all(20),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Your learning stats',
          style: Theme.of(context).textTheme.titleLarge?.copyWith(
            color: const Color(0xFF3B2419),
            fontWeight: FontWeight.w600,
          ),
        ),
        const SizedBox(height: 4),
        const Text(
          'A snapshot of your quiz performance.',
          style: TextStyle(color: Color(0xFF765C4F)),
        ),
        const SizedBox(height: 16),
        FutureBuilder<List<QuizActivity>>(
          future: _quizMetricsFuture,
          builder: (context, snapshot) {
            if (snapshot.hasError) {
              return Wrap(
                crossAxisAlignment: WrapCrossAlignment.center,
                spacing: 8,
                children: [
                  const Text(
                    'Could not load your quiz stats.',
                    style: TextStyle(color: Color(0xFF765C4F)),
                  ),
                  TextButton.icon(
                    onPressed: () =>
                        setState(() => _quizMetricsFuture = _loadQuizMetrics()),
                    icon: const Icon(Icons.refresh),
                    label: const Text('Try again'),
                  ),
                ],
              );
            }
            if (!snapshot.hasData) {
              return const Center(
                child: Padding(
                  padding: EdgeInsets.all(20),
                  child: CircularProgressIndicator(color: Color(0xFFF4773C)),
                ),
              );
            }

            return _LearningMetricsGrid(
              quizzes: snapshot.data!,
              accountCreatedAt: widget.createdAt,
            );
          },
        ),
      ],
    ),
  );
}

class _LearningMetricsGrid extends StatelessWidget {
  const _LearningMetricsGrid({
    required this.quizzes,
    required this.accountCreatedAt,
  });

  final List<QuizActivity> quizzes;
  final DateTime? accountCreatedAt;

  @override
  Widget build(BuildContext context) {
    final now = DateTime.now();
    final today = _calendarDate(now);
    final firstEligibleDate = _firstEligibleDate(accountCreatedAt, today);
    final recentAttempts = [
      for (final quiz in quizzes)
        for (final attempt in quiz.attempts)
          if (firstEligibleDate != null &&
              !_calendarDate(
                attempt.createdAt.toLocal(),
              ).isBefore(firstEligibleDate) &&
              !_calendarDate(attempt.createdAt.toLocal()).isAfter(today))
            attempt,
    ]..sort((first, second) => first.createdAt.compareTo(second.createdAt));

    final accuracy = quizLearningWindowAccuracyPercentage(
      quizzes: quizzes,
      accountCreatedAt: accountCreatedAt,
    );
    final retention = averageQuizRetentionPercentage(quizzes);
    final improvement = averageQuizImprovementPercentage(quizzes);
    final consistency = quizLearningConsistencyPercentage(
      quizzes: quizzes,
      accountCreatedAt: accountCreatedAt,
    );
    final focus = firstQuizAttemptFocusPercentage(quizzes);

    final orderedRetention =
        quizzes.where((quiz) => quiz.retentionPercentage != null).toList()
          ..sort((first, second) {
            return first.latestAttempt!.createdAt.compareTo(
              second.latestAttempt!.createdAt,
            );
          });
    final orderedImprovement =
        quizzes.where((quiz) => quiz.improvementPercentage != null).toList()
          ..sort((first, second) {
            return first.latestAttempt!.createdAt.compareTo(
              second.latestAttempt!.createdAt,
            );
          });
    final orderedFocus =
        quizzes.where((quiz) => quiz.firstAttempt != null).toList()
          ..sort((first, second) {
            return first.firstAttempt!.createdAt.compareTo(
              second.firstAttempt!.createdAt,
            );
          });

    final consistencySamples = <double>[];
    if (firstEligibleDate != null) {
      final activeDays = recentAttempts
          .map((attempt) => _calendarDate(attempt.createdAt.toLocal()))
          .toSet();
      final eligibleDays = today.difference(firstEligibleDate).inDays + 1;
      for (var day = 0; day < eligibleDays; day++) {
        final date = firstEligibleDate.add(Duration(days: day));
        consistencySamples.add(activeDays.contains(date) ? 1 : 0);
      }
    }

    final metrics = [
      _LearningMetric(
        title: 'Accuracy',
        value: _formatPercentage(accuracy),
        description:
            'Percent correct across all quiz attempts in the last 28 days (or since you joined, if newer). The line shows recent attempt scores.',
        samples: _lastSamples(
          recentAttempts.map((attempt) => attempt.percentage),
        ),
        kind: LearningMetricChartKind.line,
        color: const Color(0xFFF4773C),
      ),
      _LearningMetric(
        title: 'Retention',
        value: _formatPercentage(retention),
        description:
            'Average score across the two latest attempts for each quiz. Bars show each quiz; quizzes with fewer than two attempts are skipped.',
        samples: _lastSamples(
          orderedRetention.map((quiz) => quiz.retentionPercentage!),
        ),
        kind: LearningMetricChartKind.bars,
        color: const Color(0xFFF2C230),
      ),
      _LearningMetric(
        title: 'Improvement',
        value: _formatImprovement(improvement),
        description:
            'Average score change between retries. Each bar is one quiz: above the line means scores improved; below means they dropped.',
        samples: _lastSamples(
          orderedImprovement.map((quiz) => quiz.improvementPercentage!),
        ),
        kind: LearningMetricChartKind.diverging,
        color: const Color(0xFF2F8AB9),
      ),
      _LearningMetric(
        title: 'Consistency',
        value: _formatPercentage(consistency),
        description:
            'Percent of days you completed a quiz in the last 28 days (or since you joined, if newer). Green bars mark quiz days.',
        samples: consistencySamples,
        kind: LearningMetricChartKind.activity,
        color: const Color(0xFF42A765),
      ),
      _LearningMetric(
        title: 'Focus',
        value: _formatPercentage(focus),
        description:
            'Percent correct on your first attempt at each quiz. Bars show your first-attempt scores.',
        samples: _lastSamples(
          orderedFocus.map((quiz) => quiz.firstAttempt!.percentage),
        ),
        kind: LearningMetricChartKind.bars,
        color: const Color(0xFFD04FA2),
      ),
    ];

    return LayoutBuilder(
      builder: (context, constraints) {
        final columnCount = constraints.maxWidth >= 560 ? 3 : 2;
        final cardWidth =
            (constraints.maxWidth - 10 * (columnCount - 1)) / columnCount;
        return Wrap(
          spacing: 10,
          runSpacing: 10,
          children: [
            for (final metric in metrics)
              SizedBox(
                width: cardWidth,
                child: _LearningMetricCard(metric: metric),
              ),
          ],
        );
      },
    );
  }

  DateTime? _firstEligibleDate(DateTime? createdAt, DateTime today) {
    if (createdAt == null) return null;
    final creationDate = _calendarDate(createdAt.toLocal());
    if (creationDate.isAfter(today)) return null;
    final windowStart = today.subtract(const Duration(days: 27));
    return creationDate.isAfter(windowStart) ? creationDate : windowStart;
  }

  DateTime _calendarDate(DateTime date) =>
      DateTime(date.year, date.month, date.day);

  List<double> _lastSamples(Iterable<double> samples) {
    final values = samples.toList(growable: false);
    return values.length <= 12 ? values : values.sublist(values.length - 12);
  }

  String _formatPercentage(double? value) =>
      value == null ? '—' : '${value.round()}%';

  String _formatImprovement(double? value) {
    if (value == null) return '—';
    final sign = value > 0 ? '+' : '';
    return '$sign${value.toStringAsFixed(0)} pts';
  }
}

class _LearningMetric {
  const _LearningMetric({
    required this.title,
    required this.value,
    required this.description,
    required this.samples,
    required this.kind,
    required this.color,
  });

  final String title;
  final String value;
  final String description;
  final List<double> samples;
  final LearningMetricChartKind kind;
  final Color color;
}

class _LearningMetricCard extends StatelessWidget {
  const _LearningMetricCard({required this.metric});

  final _LearningMetric metric;

  static const _tooltipBodyStyle = TextStyle(
    color: Color(0xFF1F1A17),
    fontSize: 12,
    height: 1.4,
  );

  @override
  Widget build(BuildContext context) => Semantics(
    label: '${metric.title}: ${metric.value}',
    child: Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: const Color(0xFFFFF8EE),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: const Color(0xFFE8D7C2)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  metric.title,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    color: Color(0xFF765C4F),
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
              Tooltip(
                triggerMode: TooltipTriggerMode.tap,
                preferBelow: false,
                showDuration: const Duration(seconds: 12),
                constraints: const BoxConstraints(maxWidth: 290),
                padding: const EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: 14,
                ),
                decoration: BoxDecoration(
                  color: const Color(0xFFFFF8EB),
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(
                    color: metric.color.withValues(alpha: 0.7),
                  ),
                  boxShadow: const [
                    BoxShadow(
                      color: Color(0x33000000),
                      blurRadius: 18,
                      offset: Offset(0, 8),
                    ),
                  ],
                ),
                richMessage: TextSpan(
                  children: [
                    TextSpan(
                      text: '${metric.title.toUpperCase()}\n',
                      style: TextStyle(
                        color: metric.color,
                        fontSize: 11,
                        fontWeight: FontWeight.w800,
                        letterSpacing: 0.8,
                      ),
                    ),
                    TextSpan(
                      text: metric.description,
                      style: _tooltipBodyStyle,
                    ),
                  ],
                ),
                child: Semantics(
                  button: true,
                  label: 'About ${metric.title}',
                  child: Container(
                    width: 23,
                    height: 23,
                    alignment: Alignment.center,
                    decoration: BoxDecoration(
                      color: metric.color.withValues(alpha: 0.1),
                      shape: BoxShape.circle,
                      border: Border.all(
                        color: metric.color.withValues(alpha: 0.35),
                      ),
                    ),
                    child: Icon(
                      Icons.info_outline_rounded,
                      size: 15,
                      color: metric.color,
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 4),
              Text(
                metric.value,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  color: metric.color,
                  fontSize: 16,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          SizedBox(
            height: 42,
            width: double.infinity,
            child: CustomPaint(
              painter: LearningMetricChartPainter(
                samples: metric.samples,
                kind: metric.kind,
                color: metric.color,
              ),
            ),
          ),
        ],
      ),
    ),
  );
}

class _LearnerPointsBadge extends StatelessWidget {
  const _LearnerPointsBadge({
    required this.pointsFuture,
    required this.onRetry,
  });

  final Future<int> pointsFuture;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
    decoration: BoxDecoration(
      color: const Color(0xFFFFF8EE),
      borderRadius: BorderRadius.circular(24),
      border: Border.all(color: const Color(0xFFE8D7C2)),
    ),
    child: Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(Icons.diamond_outlined, size: 20, color: Color(0xFFF4773C)),
        SizedBox(width: 6),
        Text(
          'LP',
          style: TextStyle(
            color: Color(0xFF3B2419),
            fontWeight: FontWeight.w600,
          ),
        ),
        SizedBox(width: 6),
        FutureBuilder<int>(
          future: pointsFuture,
          builder: (context, snapshot) {
            if (snapshot.hasError) {
              return IconButton(
                tooltip: 'Learner points unavailable. Retry',
                onPressed: onRetry,
                visualDensity: VisualDensity.compact,
                constraints: const BoxConstraints(),
                padding: EdgeInsets.zero,
                icon: const Icon(
                  Icons.error_outline,
                  size: 18,
                  color: Color(0xFFB3261E),
                ),
              );
            }
            if (!snapshot.hasData) {
              return const SizedBox(
                width: 18,
                height: 18,
                child: CircularProgressIndicator(
                  strokeWidth: 2,
                  color: Color(0xFFF4773C),
                ),
              );
            }
            return Text(
              _formatPoints(snapshot.data!),
              style: const TextStyle(
                color: Color(0xFF3B2419),
                fontWeight: FontWeight.w600,
              ),
            );
          },
        ),
        SizedBox(width: 4),
        const _LearnerPointsTooltip(),
      ],
    ),
  );

  String _formatPoints(int points) {
    final value = points.toString();
    final isNegative = value.startsWith('-');
    final digits = isNegative ? value.substring(1) : value;
    final formattedDigits = StringBuffer();
    for (var index = 0; index < digits.length; index++) {
      if (index > 0 && (digits.length - index) % 3 == 0) {
        formattedDigits.write(',');
      }
      formattedDigits.write(digits[index]);
    }
    return '${isNegative ? '-' : ''}$formattedDigits';
  }
}

class _LearnerPointsTooltip extends StatelessWidget {
  const _LearnerPointsTooltip();

  static const _headingStyle = TextStyle(
    color: Color(0xFF8A3B16),
    fontSize: 11,
    fontWeight: FontWeight.w800,
    letterSpacing: 0.8,
  );

  static const _bodyStyle = TextStyle(
    color: Color(0xFF1F1A17),
    fontSize: 12,
    height: 1.4,
  );

  @override
  Widget build(BuildContext context) => Tooltip(
    triggerMode: TooltipTriggerMode.tap,
    preferBelow: false,
    showDuration: const Duration(seconds: 12),
    constraints: const BoxConstraints(maxWidth: 310),
    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
    decoration: BoxDecoration(
      color: const Color(0xFFFFF8EB),
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
        TextSpan(text: 'HOW TO EARN LEARNER POINTS\n\n', style: _headingStyle),
        TextSpan(text: 'DAILY LOGIN STREAK\n', style: _headingStyle),
        TextSpan(
          text:
              'Earn 100 LP on day 1, increasing by 100 LP per consecutive day, up to 700 LP per day. Missing a day resets the streak.\n\n',
          style: _bodyStyle,
        ),
        TextSpan(text: 'QUIZ ATTEMPTS\n', style: _headingStyle),
        TextSpan(
          text:
              'Every attempt earns LP equal to your rounded score percentage. The first attempt on a quiz adds 50 LP; the second adds 25 LP.\n\n',
          style: _bodyStyle,
        ),
        TextSpan(text: 'PERFECT QUIZ\n', style: _headingStyle),
        TextSpan(
          text:
              'Earn a one-time 150 LP bonus the first time you get every question correct on a quiz.\n\n',
          style: _bodyStyle,
        ),
        TextSpan(
          text: 'Quiz score and attempt bonuses can be earned together.',
          style: _bodyStyle,
        ),
      ],
    ),
    child: Semantics(
      button: true,
      label: 'Show how to earn Learner Points',
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

class _WeeklyRankingLabel extends StatelessWidget {
  const _WeeklyRankingLabel({
    required this.rankingFuture,
    required this.onRetry,
  });

  final Future<int?> rankingFuture;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) => FutureBuilder<int?>(
    future: rankingFuture,
    builder: (context, snapshot) {
      if (snapshot.hasError) {
        return TextButton(
          onPressed: onRetry,
          child: const Text('Weekly ranking unavailable. Retry'),
        );
      }
      if (!snapshot.hasData) {
        if (snapshot.connectionState == ConnectionState.done) {
          return const SizedBox.shrink();
        }
        return const SizedBox(
          width: 16,
          height: 16,
          child: CircularProgressIndicator(
            strokeWidth: 2,
            color: Color(0xFFF4773C),
          ),
        );
      }

      final rank = snapshot.data;
      if (rank == null) return const SizedBox.shrink();

      final rankColor = switch (rank) {
        1 => const Color(0xFFFFC107),
        2 => const Color(0xFF9EA7B3),
        3 => const Color(0xFFB76524),
        _ => Theme.of(context).colorScheme.onSurface,
      };

      return AnimatedSwitcher(
        duration: MediaQuery.disableAnimationsOf(context)
            ? Duration.zero
            : const Duration(milliseconds: 350),
        transitionBuilder: (child, animation) => FadeTransition(
          opacity: animation,
          child: SlideTransition(
            position: Tween<Offset>(
              begin: const Offset(0, 0.2),
              end: Offset.zero,
            ).animate(animation),
            child: child,
          ),
        ),
        child: Text(
          'Weekly ranking #$rank',
          key: ValueKey<int>(rank),
          style: TextStyle(color: rankColor, fontWeight: FontWeight.w600),
        ),
      );
    },
  );
}

class _ProfileDetail extends StatelessWidget {
  const _ProfileDetail({
    required this.label,
    required this.value,
    required this.icon,
  });

  final String label;
  final String value;
  final IconData icon;

  @override
  Widget build(BuildContext context) => Row(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      Icon(icon, color: const Color(0xFFF4773C)),
      const SizedBox(width: 12),
      Expanded(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(label, style: const TextStyle(color: Color(0xFF8A7A70))),
            const SizedBox(height: 4),
            SelectableText(
              value,
              style: const TextStyle(
                color: Color(0xFF3B2419),
                fontWeight: FontWeight.w500,
              ),
            ),
          ],
        ),
      ),
    ],
  );
}
