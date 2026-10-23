import 'package:flutter/material.dart';

import '../services/auth_service.dart';
import '../widgets/student_side_menu.dart';

class ProfileScreen extends StatefulWidget {
  const ProfileScreen({
    required this.username,
    required this.email,
    this.role = 'student',
    this.createdAt,
    this.onMenuSelected,
    this.streakDays,
    this.authService,
    super.key,
  });

  final String username;
  final String email;
  final String role;
  final DateTime? createdAt;
  final ValueChanged<StudentMenuItem>? onMenuSelected;
  final Set<DateTime>? streakDays;
  final ProfileDataService? authService;

  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen> {
  late final ProfileDataService _authService =
      widget.authService ?? AuthService();
  late Future<Set<DateTime>> _loginDatesFuture;
  late Future<int> _learnerPointsFuture;
  late Future<int?> _weeklyRankingFuture;

  @override
  void initState() {
    super.initState();
    _learnerPointsFuture = _loadLearnerPoints();
    _weeklyRankingFuture = _loadWeeklyRanking();
    if (widget.streakDays == null) {
      _loginDatesFuture = _loadLoginDates();
    }
  }

  Future<Set<DateTime>> _loadLoginDates() async =>
      await _authService.loginDates();

  Future<int> _loadLearnerPoints() async => await _authService.learnerPoints();

  Future<int?> _loadWeeklyRanking() async => await _authService.weeklyRanking();

  Widget _buildStreakCalendar() {
    final suppliedDates = widget.streakDays;
    if (suppliedDates != null) {
      return _StreakCalendar(
        streakDays: suppliedDates,
        currentStreak: _currentStreak(suppliedDates),
      );
    }

    return FutureBuilder<Set<DateTime>>(
      future: _loginDatesFuture,
      builder: (context, snapshot) {
        final loginDates = snapshot.data ?? const <DateTime>{};
        return _StreakCalendar(
          streakDays: loginDates,
          currentStreak: _currentStreak(loginDates),
          isLoading: !snapshot.hasData && !snapshot.hasError,
          hasError: snapshot.hasError,
          onRetry: () => setState(() => _loginDatesFuture = _loadLoginDates()),
        );
      },
    );
  }

  int _currentStreak(Set<DateTime> loginDates) {
    final normalizedDates = loginDates
        .map((date) => DateTime(date.year, date.month, date.day))
        .toSet();
    final today = DateTime.now();
    final currentDay = DateTime(today.year, today.month, today.day);
    var streakEnd = normalizedDates.contains(currentDay)
        ? currentDay
        : currentDay.subtract(const Duration(days: 1));
    if (!normalizedDates.contains(streakEnd)) return 0;

    var streak = 0;
    while (normalizedDates.contains(streakEnd)) {
      streak++;
      streakEnd = streakEnd.subtract(const Duration(days: 1));
    }
    return streak;
  }

  @override
  Widget build(BuildContext context) => StudentScaffold(
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
    body: SafeArea(
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
                Container(
                  padding: const EdgeInsets.all(24),
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
                _buildStreakCalendar(),
              ],
            ),
          ),
        ),
      ),
    ),
  );

  String get _displayRole => widget.role.isEmpty
      ? widget.role
      : '${widget.role[0].toUpperCase()}'
            '${widget.role.substring(1).toLowerCase()}';

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
}

class _StreakCalendar extends StatefulWidget {
  const _StreakCalendar({
    required this.streakDays,
    required this.currentStreak,
    this.isLoading = false,
    this.hasError = false,
    this.onRetry,
  });

  final Set<DateTime> streakDays;
  final int currentStreak;
  final bool isLoading;
  final bool hasError;
  final VoidCallback? onRetry;

  @override
  State<_StreakCalendar> createState() => _StreakCalendarState();
}

class _StreakCalendarState extends State<_StreakCalendar> {
  static const _monthNames = [
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

  late DateTime _displayedMonth;

  @override
  void initState() {
    super.initState();
    final now = DateTime.now();
    _displayedMonth = DateTime(now.year, now.month);
  }

  void _changeMonth(int offset) {
    setState(() {
      _displayedMonth = DateTime(
        _displayedMonth.year,
        _displayedMonth.month + offset,
      );
    });
  }

  bool _isStreakDay(DateTime date) => widget.streakDays.any(
    (streakDay) =>
        streakDay.year == date.year &&
        streakDay.month == date.month &&
        streakDay.day == date.day,
  );

  @override
  Widget build(BuildContext context) {
    final firstDay = DateTime(_displayedMonth.year, _displayedMonth.month);
    final daysInMonth = DateTime(
      _displayedMonth.year,
      _displayedMonth.month + 1,
      0,
    ).day;
    final leadingDays = firstDay.weekday % 7;
    final weekCount = ((leadingDays + daysInMonth) / 7).ceil();
    final today = DateTime.now();

    return Container(
      padding: const EdgeInsets.all(24),
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
              const CircleAvatar(
                radius: 22,
                backgroundColor: Color(0xFFFFE5D5),
                child: Icon(
                  Icons.local_fire_department,
                  color: Color(0xFFF4773C),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Learning streak',
                      style: Theme.of(context).textTheme.titleLarge?.copyWith(
                        color: const Color(0xFF3B2419),
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    const SizedBox(height: 2),
                    const Text(
                      'Your learning activity, day by day.',
                      style: TextStyle(color: Color(0xFF765C4F)),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      widget.isLoading
                          ? 'Loading streak...'
                          : widget.hasError
                          ? 'Streak unavailable'
                          : '${widget.currentStreak} '
                                '${widget.currentStreak == 1 ? 'day' : 'days'} in a row',
                      style: const TextStyle(
                        color: Color(0xFFF4773C),
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 24),
          Row(
            children: [
              Expanded(
                child: Text(
                  '${_monthNames[_displayedMonth.month - 1]} '
                  '${_displayedMonth.year}',
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    color: const Color(0xFF3B2419),
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
              IconButton(
                tooltip: 'Previous month',
                onPressed: () => _changeMonth(-1),
                visualDensity: VisualDensity.compact,
                icon: const Icon(Icons.chevron_left),
                color: const Color(0xFF765C4F),
              ),
              IconButton(
                tooltip: 'Next month',
                onPressed: () => _changeMonth(1),
                visualDensity: VisualDensity.compact,
                icon: const Icon(Icons.chevron_right),
                color: const Color(0xFF765C4F),
              ),
            ],
          ),
          const SizedBox(height: 8),
          const Row(
            children: [
              _WeekdayLabel('S'),
              _WeekdayLabel('M'),
              _WeekdayLabel('T'),
              _WeekdayLabel('W'),
              _WeekdayLabel('T'),
              _WeekdayLabel('F'),
              _WeekdayLabel('S'),
            ],
          ),
          const SizedBox(height: 8),
          for (var week = 0; week < weekCount; week++)
            Row(
              children: [
                for (var weekday = 0; weekday < 7; weekday++)
                  _CalendarDay(
                    date: DateTime(
                      _displayedMonth.year,
                      _displayedMonth.month,
                      week * 7 + weekday - leadingDays + 1,
                    ),
                    displayedMonth: _displayedMonth,
                    today: today,
                    isStreakDay: _isStreakDay(
                      DateTime(
                        _displayedMonth.year,
                        _displayedMonth.month,
                        week * 7 + weekday - leadingDays + 1,
                      ),
                    ),
                  ),
              ],
            ),
          const SizedBox(height: 12),
          const Divider(color: Color(0xFFE8D7C2)),
          const SizedBox(height: 4),
          if (widget.isLoading)
            const Wrap(
              crossAxisAlignment: WrapCrossAlignment.center,
              spacing: 8,
              children: [
                SizedBox(
                  width: 16,
                  height: 16,
                  child: CircularProgressIndicator(
                    strokeWidth: 2,
                    color: Color(0xFFF4773C),
                  ),
                ),
                SizedBox(width: 8),
                Text(
                  'Loading login history...',
                  style: TextStyle(color: Color(0xFF765C4F)),
                ),
              ],
            )
          else if (widget.hasError)
            Wrap(
              crossAxisAlignment: WrapCrossAlignment.center,
              spacing: 8,
              children: [
                const Text(
                  'Unable to load login history.',
                  style: TextStyle(color: Color(0xFF765C4F)),
                ),
                TextButton.icon(
                  onPressed: widget.onRetry,
                  icon: const Icon(Icons.refresh),
                  label: const Text('Try again'),
                ),
              ],
            )
          else
            const Wrap(
              crossAxisAlignment: WrapCrossAlignment.center,
              spacing: 8,
              children: [
                CircleAvatar(radius: 5, backgroundColor: Color(0xFFF4773C)),
                Text(
                  'Days you log in will be highlighted here.',
                  style: TextStyle(color: Color(0xFF765C4F)),
                ),
              ],
            ),
        ],
      ),
    );
  }
}

class _WeekdayLabel extends StatelessWidget {
  const _WeekdayLabel(this.label);

  final String label;

  @override
  Widget build(BuildContext context) => Expanded(
    child: Center(
      child: Text(
        label,
        style: const TextStyle(
          color: Color(0xFF8A7A70),
          fontWeight: FontWeight.w600,
        ),
      ),
    ),
  );
}

class _CalendarDay extends StatelessWidget {
  const _CalendarDay({
    required this.date,
    required this.displayedMonth,
    required this.today,
    required this.isStreakDay,
  });

  final DateTime date;
  final DateTime displayedMonth;
  final DateTime today;
  final bool isStreakDay;

  @override
  Widget build(BuildContext context) {
    final isDisplayedMonth =
        date.year == displayedMonth.year && date.month == displayedMonth.month;
    final isToday =
        date.year == today.year &&
        date.month == today.month &&
        date.day == today.day;

    return Expanded(
      child: SizedBox(
        height: 44,
        child: Center(
          child: Container(
            width: 34,
            height: 34,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              color: isStreakDay ? const Color(0xFFF4773C) : null,
              shape: BoxShape.circle,
              border: isToday && !isStreakDay
                  ? Border.all(color: const Color(0xFFF4773C))
                  : null,
            ),
            child: Text(
              '${date.day}',
              style: TextStyle(
                color: isStreakDay
                    ? Colors.white
                    : isDisplayedMonth
                    ? const Color(0xFF3B2419)
                    : const Color(0xFFB8A99D),
                fontWeight: isStreakDay || isToday
                    ? FontWeight.w600
                    : FontWeight.normal,
              ),
            ),
          ),
        ),
      ),
    );
  }
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
    constraints: const BoxConstraints(maxWidth: 310),
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
