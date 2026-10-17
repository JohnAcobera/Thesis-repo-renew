import 'package:flutter/material.dart';

const _primary = Color(0xFFFF7434);
const _heading = Color(0xFF3B2419);
const _subtle = Color(0xFF765C4F);
const _border = Color(0xFFE8D7C2);
const _surface = Color(0xFFFFFCF8);

class LeaderboardScreen extends StatelessWidget {
  const LeaderboardScreen({super.key});

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
                const _WeekSelector(),
              ],
            ),
            const SizedBox(height: 24),
            const _StandingsCard(),
          ],
        ),
      ),
    ),
  );
}

class _WeekSelector extends StatefulWidget {
  const _WeekSelector();

  @override
  State<_WeekSelector> createState() => _WeekSelectorState();
}

class _WeekSelectorState extends State<_WeekSelector> {
  static const _weekLabels = {
    0: 'This week',
    -1: 'Last week (-1)',
    -2: 'Two weeks ago (-2)',
  };

  int _selectedWeek = 0;

  @override
  Widget build(BuildContext context) => PopupMenuButton<int>(
    tooltip: 'Select leaderboard week',
    initialValue: _selectedWeek,
    onSelected: (week) => setState(() => _selectedWeek = week),
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
            _weekLabels[_selectedWeek]!.toUpperCase(),
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
  const _StandingsCard();

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
        Container(
          width: double.infinity,
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 24),
          decoration: BoxDecoration(
            color: const Color(0xFFFFF8EE),
            borderRadius: BorderRadius.circular(18),
          ),
          child: const Column(
            children: [
              Icon(Icons.emoji_events_outlined, size: 34, color: _primary),
              SizedBox(height: 10),
              Text(
                'Rankings are on the way',
                style: TextStyle(color: _heading, fontWeight: FontWeight.w700),
              ),
              SizedBox(height: 5),
              Text(
                'Student standings will appear here once weekly scores are available.',
                textAlign: TextAlign.center,
                style: TextStyle(color: _subtle, fontSize: 13),
              ),
            ],
          ),
        ),
      ],
    ),
  );
}
