import 'package:flutter_test/flutter_test.dart';
import 'package:thesis_repo_renew/models/achievement_badge.dart';

void main() {
  test('catalog includes all 21 badges and the nine new badge assets', () {
    expect(AchievementBadge.all, hasLength(21));

    final newBadges = AchievementBadge.all
        .where(
          (badge) => {
            'EarlyBird',
            'NightOwl',
            'PerfectWeek',
            'Marathon',
            'LuckySeven',
            'WeekendScholar',
            'WarmingUp',
            'FortnightFocus',
            'PointCollector',
          }.contains(badge.id),
        )
        .toList(growable: false);

    expect(newBadges, hasLength(9));
    for (final badge in newBadges) {
      expect(badge.assetPath, 'assets/Achievement Badges/${badge.id}.png');
    }
  });
}
