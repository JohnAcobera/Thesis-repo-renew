import 'package:flutter/material.dart';

import '../services/leaderboard_service.dart';

const _primary = Color(0xFFFF7434);
const _heading = Color(0xFF3B2419);
const _subtle = Color(0xFF765C4F);
const _border = Color(0xFFE8D7C2);
const _surface = Color(0xFFFFFCF8);

class LeaderboardScreen extends StatefulWidget {
  const LeaderboardScreen({this.repository, super.key});

  final LeaderboardRepository? repository;

  @override
  State<LeaderboardScreen> createState() => _LeaderboardScreenState();
}

class _LeaderboardScreenState extends State<LeaderboardScreen> {
  late final LeaderboardRepository _repository =
      widget.repository ?? LeaderboardService();
  int _selectedWeek = 0;
  late Future<List<WeeklyLeaderboardEntry>> _standingsFuture;

  @override
  void initState() {
    super.initState();
    _standingsFuture = _loadStandings();
  }

  Future<List<WeeklyLeaderboardEntry>> _loadStandings() =>
      _repository.weeklyLeaderboard(weekOffset: _selectedWeek);

  void _selectWeek(int week) {
    setState(() {
      _selectedWeek = week;
      _standingsFuture = _loadStandings();
    });
  }

  @override
  Widget build(BuildContext context) => SingleChildScrollView(
    padding: const EdgeInsets.all(24),
    child: Center(
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 1040),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const SizedBox(height: 8),
            Wrap(
              alignment: WrapAlignment.spaceBetween,
              crossAxisAlignment: WrapCrossAlignment.center,
              spacing: 16,
              runSpacing: 12,
              children: [
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Weekly Leaderboard',
                      style: Theme.of(context).textTheme.headlineMedium
                          ?.copyWith(
                            color: _heading,
                            fontWeight: FontWeight.w800,
                            letterSpacing: -0.8,
                          ),
                    ),
                    const SizedBox(height: 6),
                    const Text(
                      'A little progress each day adds up.',
                      style: TextStyle(color: _subtle, fontSize: 15),
                    ),
                  ],
                ),
                _WeekSelector(
                  selectedWeek: _selectedWeek,
                  onWeekSelected: _selectWeek,
                ),
              ],
            ),
            const SizedBox(height: 24),
            _StandingsCard(
              standingsFuture: _standingsFuture,
              onRetry: () =>
                  setState(() => _standingsFuture = _loadStandings()),
            ),
          ],
        ),
      ),
    ),
  );
}

class _WeekSelector extends StatelessWidget {
  const _WeekSelector({
    required this.selectedWeek,
    required this.onWeekSelected,
  });

  static const _weekLabels = {
    0: 'This week',
    -1: 'Last week (-1)',
    -2: 'Two weeks ago (-2)',
  };

  final int selectedWeek;
  final ValueChanged<int> onWeekSelected;

  @override
  Widget build(BuildContext context) => PopupMenuButton<int>(
    tooltip: 'Select leaderboard week',
    initialValue: selectedWeek,
    onSelected: onWeekSelected,
    color: _surface,
    surfaceTintColor: Colors.transparent,
    elevation: 8,
    shape: RoundedRectangleBorder(
      borderRadius: BorderRadius.circular(14),
      side: const BorderSide(color: _border),
    ),
    itemBuilder: (context) => [
      for (final entry in _weekLabels.entries)
        PopupMenuItem<int>(value: entry.key, child: Text(entry.value)),
    ],
    child: Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 9),
      decoration: BoxDecoration(
        color: const Color(0xFFFFE5D5),
        borderRadius: BorderRadius.circular(24),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(Icons.calendar_today_outlined, size: 15, color: _primary),
          const SizedBox(width: 8),
          Text(
            _weekLabels[selectedWeek]!.toUpperCase(),
            style: const TextStyle(
              color: _heading,
              fontSize: 11,
              fontWeight: FontWeight.w800,
              letterSpacing: 0.9,
            ),
          ),
          const SizedBox(width: 6),
          const Icon(Icons.keyboard_arrow_down, size: 16, color: _heading),
        ],
      ),
    ),
  );
}

class _StandingsCard extends StatelessWidget {
  const _StandingsCard({required this.standingsFuture, required this.onRetry});

  final Future<List<WeeklyLeaderboardEntry>> standingsFuture;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.all(22),
    decoration: BoxDecoration(
      color: _surface,
      borderRadius: BorderRadius.circular(24),
      border: Border.all(color: _border),
    ),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Student rankings',
          style: Theme.of(context).textTheme.titleLarge?.copyWith(
            color: _heading,
            fontWeight: FontWeight.w700,
          ),
        ),
        const SizedBox(height: 16),
        FutureBuilder<List<WeeklyLeaderboardEntry>>(
          future: standingsFuture,
          builder: (context, snapshot) {
            if (snapshot.hasError) {
              return _StatusMessage(
                icon: Icons.error_outline,
                message: snapshot.error.toString(),
                action: TextButton.icon(
                  onPressed: onRetry,
                  icon: const Icon(Icons.refresh),
                  label: const Text('Try again'),
                ),
              );
            }
            if (!snapshot.hasData) {
              return const _StatusMessage(
                icon: null,
                message: 'Loading weekly rankings...',
                action: CircularProgressIndicator(color: _primary),
              );
            }
            if (snapshot.data!.isEmpty) {
              return const _StatusMessage(
                icon: Icons.emoji_events_outlined,
                message: 'No students found.',
              );
            }
            return Align(
              alignment: Alignment.topCenter,
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 680),
                child: Column(
                  children: [
                    for (final entry in snapshot.data!)
                      _LeaderboardRow(entry: entry),
                  ],
                ),
              ),
            );
          },
        ),
      ],
    ),
  );
}

class _StatusMessage extends StatelessWidget {
  const _StatusMessage({
    required this.icon,
    required this.message,
    this.action,
  });

  final IconData? icon;
  final String message;
  final Widget? action;

  @override
  Widget build(BuildContext context) => Container(
    width: double.infinity,
    padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 24),
    decoration: BoxDecoration(
      color: const Color(0xFFFFF8EE),
      borderRadius: BorderRadius.circular(18),
    ),
    child: Column(
      children: [
        if (icon != null) ...[
          Icon(icon, size: 34, color: _primary),
          const SizedBox(height: 10),
        ],
        Text(
          message,
          textAlign: TextAlign.center,
          style: const TextStyle(color: _heading, fontWeight: FontWeight.w700),
        ),
        if (action != null) ...[const SizedBox(height: 12), action!],
      ],
    ),
  );
}

class _LeaderboardRow extends StatelessWidget {
  const _LeaderboardRow({required this.entry});

  final WeeklyLeaderboardEntry entry;

  @override
  Widget build(BuildContext context) {
    final podiumStyle = switch (entry.rank) {
      1 => (
        color: const Color(0xFFFFC107),
        fill: const Color(0xFFFFF3C4),
        borderWidth: 5.0,
      ),
      2 => (
        color: const Color(0xFF9EA7B3),
        fill: const Color(0xFFF0F2F5),
        borderWidth: 4.0,
      ),
      3 => (
        color: const Color(0xFFB76524),
        fill: const Color(0xFFFFE8D2),
        borderWidth: 3.0,
      ),
      _ => (color: _border, fill: const Color(0xFFFFF8EE), borderWidth: 1.0),
    };

    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      decoration: BoxDecoration(
        color: podiumStyle.fill,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: podiumStyle.color,
          width: podiumStyle.borderWidth,
        ),
      ),
      child: Row(
        children: [
          SizedBox(
            width: 42,
            child: Text(
              '#${entry.rank}',
              style: const TextStyle(
                color: _primary,
                fontWeight: FontWeight.w800,
                fontSize: 16,
              ),
            ),
          ),
          Expanded(
            child: Text(
              entry.fullName,
              style: const TextStyle(
                color: _heading,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
          const Icon(Icons.diamond_outlined, size: 18, color: _primary),
          const SizedBox(width: 6),
          Text(
            '${_formatPoints(entry.points)} LP',
            style: const TextStyle(
              color: _heading,
              fontWeight: FontWeight.w800,
            ),
          ),
        ],
      ),
    );
  }
}

String _formatPoints(int points) {
  final digits = points.toString();
  final formatted = StringBuffer();
  for (var index = 0; index < digits.length; index++) {
    if (index > 0 && (digits.length - index) % 3 == 0) {
      formatted.write(',');
    }
    formatted.write(digits[index]);
  }
  return formatted.toString();
}
