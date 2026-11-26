import 'dart:math' as math;

import 'package:material_ui/material_ui.dart';

import '../models/achievement_badge.dart';

class AchievementBadgeGrid extends StatelessWidget {
  const AchievementBadgeGrid({required this.earnedBadges, super.key});

  final Set<String> earnedBadges;

  @override
  Widget build(BuildContext context) {
    final earned = AchievementBadge.all
        .where((badge) => earnedBadges.contains(badge.id))
        .toList(growable: false);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 11, vertical: 7),
          decoration: BoxDecoration(
            color: const Color(0xFFFFF1E5),
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: const Color(0xFFF2D1B8)),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(
                Icons.verified_rounded,
                size: 15,
                color: Color(0xFFF4773C),
              ),
              const SizedBox(width: 6),
              Text(
                '${earned.length} ${earned.length == 1 ? 'badge' : 'badges'} earned',
                style: const TextStyle(
                  color: Color(0xFF72513E),
                  fontSize: 12,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 14),
        if (earned.isEmpty)
          const _EmptyAchievements()
        else
          _ScrollableAchievementList(badges: earned),
      ],
    );
  }
}

class _ScrollableAchievementList extends StatefulWidget {
  const _ScrollableAchievementList({required this.badges});

  final List<AchievementBadge> badges;

  @override
  State<_ScrollableAchievementList> createState() =>
      _ScrollableAchievementListState();
}

class _ScrollableAchievementListState
    extends State<_ScrollableAchievementList> {
  static const _spacing = 12.0;
  static const _tileHeight = 116.0;
  static const _maxHeight = 420.0;

  final ScrollController _scrollController = ScrollController();

  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => LayoutBuilder(
    builder: (context, constraints) {
      final columns = constraints.maxWidth < 560 ? 1 : 2;
      final rowCount = (widget.badges.length + columns - 1) ~/ columns;
      final contentHeight =
          rowCount * _tileHeight + math.max(0, rowCount - 1) * _spacing;
      final viewportHeight = math.min(contentHeight, _maxHeight);
      final canScroll = contentHeight > viewportHeight;
      final tileWidth =
          (constraints.maxWidth - _spacing * (columns - 1)) / columns;

      return SizedBox(
        key: const ValueKey('achievement-badge-list-viewport'),
        height: viewportHeight,
        child: Scrollbar(
          controller: _scrollController,
          thumbVisibility: canScroll,
          trackVisibility: canScroll,
          child: SingleChildScrollView(
            key: const ValueKey('achievement-badge-list'),
            controller: _scrollController,
            primary: false,
            child: SizedBox(
              width: constraints.maxWidth,
              child: Wrap(
                spacing: _spacing,
                runSpacing: _spacing,
                children: [
                  for (final badge in widget.badges)
                    SizedBox(
                      width: tileWidth,
                      height: _tileHeight,
                      child: _AchievementBadgeTile(badge: badge),
                    ),
                ],
              ),
            ),
          ),
        ),
      );
    },
  );
}

class _EmptyAchievements extends StatelessWidget {
  const _EmptyAchievements();

  @override
  Widget build(BuildContext context) => Container(
    width: double.infinity,
    padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 28),
    decoration: BoxDecoration(
      gradient: const LinearGradient(
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
        colors: [Color(0xFFFFFCF8), Color(0xFFFFF1E5)],
      ),
      borderRadius: BorderRadius.circular(18),
      border: Border.all(color: const Color(0xFFF2D1B8)),
    ),
    child: const Column(
      children: [
        Icon(Icons.emoji_events_outlined, size: 36, color: Color(0xFFF4773C)),
        SizedBox(height: 10),
        Text(
          'No badges earned yet',
          style: TextStyle(
            color: Color(0xFF3B2419),
            fontSize: 15,
            fontWeight: FontWeight.w700,
          ),
        ),
        SizedBox(height: 6),
        Text(
          'Complete learning activities to earn your first badge.',
          textAlign: TextAlign.center,
          style: TextStyle(color: Color(0xFF765C4F), height: 1.4),
        ),
      ],
    ),
  );
}

class _AchievementBadgeTile extends StatelessWidget {
  const _AchievementBadgeTile({required this.badge});

  final AchievementBadge badge;

  @override
  Widget build(BuildContext context) => Semantics(
    label: '${badge.name} badge earned. ${badge.description}',
    child: Container(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: const Color(0xFFF0D7C1)),
        boxShadow: const [
          BoxShadow(
            color: Color(0x123B2419),
            blurRadius: 12,
            offset: Offset(0, 4),
          ),
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(18),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
          decoration: BoxDecoration(
            gradient: const LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [Color(0xFFFFFEFC), Color(0xFFFFF7EF)],
            ),
            borderRadius: BorderRadius.circular(18),
          ),
          child: Row(
            children: [
              Container(
                width: 72,
                height: 72,
                decoration: BoxDecoration(
                  gradient: const LinearGradient(
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                    colors: [Color(0xFFFFF0E2), Color(0xFFFFE6D3)],
                  ),
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: const Color(0xFFF2D1B8)),
                ),
                alignment: Alignment.center,
                child: SizedBox(
                  width: 64,
                  height: 64,
                  child: Image.asset(badge.assetPath, fit: BoxFit.contain),
                ),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      badge.name,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        color: Color(0xFF3B2419),
                        fontSize: 14,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    const SizedBox(height: 5),
                    Text(
                      badge.description,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        color: Color(0xFF765C4F),
                        fontSize: 12,
                        height: 1.3,
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
  );
}
