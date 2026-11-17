import 'package:flutter/material.dart';

import '../models/achievement_badge.dart';

class AchievementUnlockedDialog extends StatelessWidget {
  const AchievementUnlockedDialog({required this.badges, super.key});

  final List<AchievementBadge> badges;

  @override
  Widget build(BuildContext context) => Dialog(
    backgroundColor: const Color(0xFFFFFCF8),
    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
    child: ConstrainedBox(
      constraints: BoxConstraints(
        maxWidth: 480,
        maxHeight: MediaQuery.sizeOf(context).height * 0.82,
      ),
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 58,
              height: 58,
              decoration: BoxDecoration(
                color: const Color(0xFFFFF1DF),
                borderRadius: BorderRadius.circular(18),
              ),
              child: const Icon(
                Icons.celebration_outlined,
                color: Color(0xFFFF7434),
                size: 32,
              ),
            ),
            const SizedBox(height: 16),
            const Text(
              'Achievement unlocked!',
              textAlign: TextAlign.center,
              style: TextStyle(
                color: Color(0xFF3B2419),
                fontSize: 24,
                fontWeight: FontWeight.w800,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              badges.length == 1
                  ? 'Congratulations on your new badge. Keep up the great work!'
                  : 'Congratulations on earning ${badges.length} new badges. '
                        'Keep up the great work!',
              textAlign: TextAlign.center,
              style: const TextStyle(color: Color(0xFF765C4F), height: 1.4),
            ),
            const SizedBox(height: 20),
            Flexible(
              child: SingleChildScrollView(
                child: Column(
                  children: [
                    for (var index = 0; index < badges.length; index++) ...[
                      if (index > 0) const SizedBox(height: 10),
                      _UnlockedBadgeTile(badge: badges[index]),
                    ],
                  ],
                ),
              ),
            ),
            const SizedBox(height: 20),
            SizedBox(
              width: double.infinity,
              height: 48,
              child: FilledButton(
                onPressed: () => Navigator.of(context).pop(),
                style: FilledButton.styleFrom(
                  backgroundColor: const Color(0xFFFF7434),
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(14),
                  ),
                ),
                child: const Text('Continue to dashboard'),
              ),
            ),
          ],
        ),
      ),
    ),
  );
}

class _UnlockedBadgeTile extends StatelessWidget {
  const _UnlockedBadgeTile({required this.badge});

  final AchievementBadge badge;

  @override
  Widget build(BuildContext context) => Semantics(
    label: '${badge.name} badge earned. ${badge.description}',
    child: Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFFE8D7C2)),
      ),
      child: Row(
        children: [
          SizedBox(
            width: 64,
            height: 64,
            child: Image.asset(badge.assetPath, fit: BoxFit.contain),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  badge.name,
                  style: const TextStyle(
                    color: Color(0xFF3B2419),
                    fontSize: 15,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  badge.description,
                  style: const TextStyle(
                    color: Color(0xFF765C4F),
                    fontSize: 12,
                    height: 1.35,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    ),
  );
}
