import 'package:flutter/material.dart';

import '../widgets/student_side_menu.dart';

class ProfileScreen extends StatelessWidget {
  const ProfileScreen({
    required this.username,
    required this.email,
    this.streakDays = const {},
    super.key,
  });

  final String username;
  final String email;
  final Set<DateTime> streakDays;

  @override
  Widget build(BuildContext context) => StudentScaffold(
    title: 'Profile',
    username: username,
    email: email,
    selectedMenu: StudentMenuItem.profile,
    onMenuSelected: (item) {
      if (item == StudentMenuItem.dashboard) {
        Navigator.of(context).popUntil((route) => route.isFirst);
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
                  'View your student account information.',
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
                              username,
                              textAlign: TextAlign.center,
                              style: Theme.of(context).textTheme.titleLarge
                                  ?.copyWith(
                                    color: const Color(0xFF3B2419),
                                    fontWeight: FontWeight.w600,
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
                        value: username,
                        icon: Icons.person_outline,
                      ),
                      const SizedBox(height: 20),
                      _ProfileDetail(
                        label: 'Email address',
                        value: email,
                        icon: Icons.email_outlined,
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 24),
                _StreakCalendar(streakDays: streakDays),
                const SizedBox(height: 24),
                const _AchievementsSection(),
              ],
            ),
          ),
        ),
      ),
    ),
  );
}

class _StreakCalendar extends StatefulWidget {
  const _StreakCalendar({this.streakDays = const {}});

  final Set<DateTime> streakDays;

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
          const Wrap(
            crossAxisAlignment: WrapCrossAlignment.center,
            spacing: 8,
            children: [
              CircleAvatar(radius: 5, backgroundColor: Color(0xFFF4773C)),
              Text(
                'Streak days will be highlighted here.',
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

class _AchievementsSection extends StatelessWidget {
  const _AchievementsSection();

  @override
  Widget build(BuildContext context) => Container(
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
        Text(
          'Your Achievements',
          style: Theme.of(context).textTheme.titleLarge?.copyWith(
            color: const Color(0xFF3B2419),
            fontWeight: FontWeight.w600,
          ),
        ),
        const SizedBox(height: 20),
        Container(
          width: double.infinity,
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 28),
          decoration: BoxDecoration(
            color: const Color(0xFFFFF8EE),
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: const Color(0xFFE8D7C2)),
          ),
          child: const Column(
            children: [
              Icon(
                Icons.emoji_events_outlined,
                size: 40,
                color: Color(0xFFF4773C),
              ),
              SizedBox(height: 12),
              Text(
                'No achievements yet',
                style: TextStyle(
                  color: Color(0xFF3B2419),
                  fontWeight: FontWeight.w600,
                ),
              ),
              SizedBox(height: 6),
              Text(
                'Your achievements will appear here.',
                textAlign: TextAlign.center,
                style: TextStyle(color: Color(0xFF765C4F)),
              ),
            ],
          ),
        ),
      ],
    ),
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
