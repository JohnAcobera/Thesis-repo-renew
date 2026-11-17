class AchievementBadge {
  const AchievementBadge({
    required this.id,
    required this.name,
    required this.description,
    required this.assetPath,
  });

  final String id;
  final String name;
  final String description;
  final String assetPath;

  static const all = [
    AchievementBadge(
      id: 'FirstPerfect',
      name: 'First Perfect',
      description: 'Score 100% on any quiz.',
      assetPath: 'assets/Achievement Badges/FirstPerfect.png',
    ),
    AchievementBadge(
      id: 'FirstStep',
      name: 'First Step',
      description: 'Complete your first quiz attempt.',
      assetPath: 'assets/Achievement Badges/FirstStep.png',
    ),
    AchievementBadge(
      id: 'FlashcardStarter',
      name: 'Flashcard Starter',
      description: 'Complete your first flashcard session.',
      assetPath: 'assets/Achievement Badges/FlashcardStarter.png',
    ),
    AchievementBadge(
      id: 'FlawlessFive',
      name: 'Flawless Five',
      description: 'Score 100% on five different quizzes.',
      assetPath: 'assets/Achievement Badges/FlawlessFive.png',
    ),
    AchievementBadge(
      id: 'MatchMaker',
      name: 'Match Maker',
      description: 'Complete your first matching-pairs session.',
      assetPath: 'assets/Achievement Badges/MatchMaker.png',
    ),
    AchievementBadge(
      id: 'Podium',
      name: 'Podium',
      description: 'Reach the weekly top 3.',
      assetPath: 'assets/Achievement Badges/Podium.png',
    ),
    AchievementBadge(
      id: 'QuizLegend',
      name: 'Quiz Legend',
      description: 'Answer 300 quiz questions.',
      assetPath: 'assets/Achievement Badges/QuizLegend.png',
    ),
    AchievementBadge(
      id: 'QuizMaster',
      name: 'Quiz Master',
      description: 'Answer 250 quiz questions.',
      assetPath: 'assets/Achievement Badges/QuizMaster.png',
    ),
    AchievementBadge(
      id: 'QuizRegular',
      name: 'Quiz Regular',
      description: 'Answer 100 quiz questions.',
      assetPath: 'assets/Achievement Badges/QuizRegular.png',
    ),
    AchievementBadge(
      id: 'QuizRookie',
      name: 'Quiz Rookie',
      description: 'Answer 50 quiz questions.',
      assetPath: 'assets/Achievement Badges/QuizRookie.png',
    ),
    AchievementBadge(
      id: 'QuizVeteran',
      name: 'Quiz Veteran',
      description: 'Answer 150 quiz questions.',
      assetPath: 'assets/Achievement Badges/QuizVeteran.png',
    ),
    AchievementBadge(
      id: 'StudyMixer',
      name: 'Study Mixer',
      description: 'Use every learning mode in a single week.',
      assetPath: 'assets/Achievement Badges/StudyMixer.png',
    ),
    AchievementBadge(
      id: 'EarlyBird',
      name: 'Early Bird',
      description: 'Complete a quiz before 8:00 AM.',
      assetPath: 'assets/Achievement Badges/EarlyBird.png',
    ),
    AchievementBadge(
      id: 'NightOwl',
      name: 'Night Owl',
      description: 'Complete a quiz after 10:00 PM.',
      assetPath: 'assets/Achievement Badges/NightOwl.png',
    ),
    AchievementBadge(
      id: 'PerfectWeek',
      name: 'Perfect Week',
      description: 'Maintain a 7-day learning streak.',
      assetPath: 'assets/Achievement Badges/PerfectWeek.png',
    ),
    AchievementBadge(
      id: 'Marathon',
      name: 'Marathon',
      description: 'Complete 5 quiz attempts in one day.',
      assetPath: 'assets/Achievement Badges/Marathon.png',
    ),
    AchievementBadge(
      id: 'LuckySeven',
      name: 'Lucky Seven',
      description: 'Score exactly 7 on a quiz.',
      assetPath: 'assets/Achievement Badges/LuckySeven.png',
    ),
    AchievementBadge(
      id: 'WeekendScholar',
      name: 'Weekend Scholar',
      description: 'Complete a quiz on both Saturday and Sunday.',
      assetPath: 'assets/Achievement Badges/WeekendScholar.png',
    ),
    AchievementBadge(
      id: 'WarmingUp',
      name: 'Warming Up',
      description: 'Maintain a 3-day learning streak.',
      assetPath: 'assets/Achievement Badges/WarmingUp.png',
    ),
    AchievementBadge(
      id: 'FortnightFocus',
      name: 'Fortnight Focus',
      description: 'Maintain a 14-day learning streak.',
      assetPath: 'assets/Achievement Badges/FortnightFocus.png',
    ),
    AchievementBadge(
      id: 'PointCollector',
      name: 'Point Collector',
      description: 'Earn 10,000 learner points in total.',
      assetPath: 'assets/Achievement Badges/PointCollector.png',
    ),
  ];
}
