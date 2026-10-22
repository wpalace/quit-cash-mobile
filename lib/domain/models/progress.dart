import 'package:quit_cash_mobile/domain/models/save_entry.dart';

/// Pure game rules. Everything is derived from the entry log, so there is
/// no second source of truth to drift.
class Achievement {
  const Achievement(
    this.id,
    this.title,
    this.description,
    this.emoji,
    this.test,
  );
  final String id;
  final String title;
  final String description;
  final String emoji;
  final bool Function(Progress p) test;
}

/// Level thresholds in dollars of total saved. Level n is reached at
/// [levelThresholds][n - 1]; after the last entry every further \$1000 is
/// one more level (\$2000 = L8, \$3000 = L9, ...). Below \$1 is Level 0.
const levelThresholds = [1, 20, 50, 100, 200, 500, 1000];

final List<Achievement> achievements = [
  Achievement(
    'first',
    'First Coin',
    'Save your very first dollar',
    '🪙',
    (p) => p.totalCents >= 100,
  ),
  Achievement(
    'ten',
    'Ten Spot',
    'Save \$10 in total',
    '💵',
    (p) => p.totalCents >= 1000,
  ),
  Achievement(
    'twentyfive',
    'Quarter Stack',
    'Save \$25 in total',
    '⭐',
    (p) => p.totalCents >= 2500,
  ),
  Achievement(
    'fifty',
    'Half Century',
    'Save \$50 in total',
    '💰',
    (p) => p.totalCents >= 5000,
  ),
  Achievement(
    'hundred',
    'Benjamin',
    'Save \$100 in total',
    '🏦',
    (p) => p.totalCents >= 10000,
  ),
  Achievement(
    'lvl5',
    'Level 5',
    'Reach level 5 (\$200 saved)',
    '🏆',
    (p) => p.level >= 5,
  ),
  Achievement(
    'fivehundred',
    'Diamond Hands',
    'Save \$500 in total',
    '💎',
    (p) => p.totalCents >= 50000,
  ),
  Achievement(
    'k',
    'Grand Master',
    'Save \$1,000 in total',
    '👑',
    (p) => p.totalCents >= 100000,
  ),
  Achievement(
    'k2500',
    'High Roller',
    'Save \$2,500 in total',
    '🚀',
    (p) => p.totalCents >= 250000,
  ),
  Achievement(
    'k5000',
    'Fortune Maker',
    'Save \$5,000 in total',
    '🌟',
    (p) => p.totalCents >= 500000,
  ),
];

class Progress {
  const Progress._({required this.totalCents});

  factory Progress.from(List<SaveEntry> entries) =>
      Progress._(totalCents: entries.fold(0, (sum, e) => sum + e.cents));

  final int totalCents;

  double get total => totalCents / 100.0;

  /// Dollars needed to reach [level] (level >= 1).
  static int thresholdFor(int level) {
    assert(level >= 1);
    if (level <= levelThresholds.length) return levelThresholds[level - 1];
    return 1000 * (level - levelThresholds.length + 1);
  }

  /// Level from total dollars saved; 0 before the first \$1.
  static int levelForCents(int cents) {
    var lvl = 0;
    while (cents >= thresholdFor(lvl + 1) * 100) {
      lvl++;
    }
    return lvl;
  }

  int get level => levelForCents(totalCents);

  /// Dollar target of the next level.
  int get nextThreshold => thresholdFor(level + 1);

  /// Dollar floor of the current level (0 for Level 0).
  int get currentThreshold => level == 0 ? 0 : thresholdFor(level);

  /// 0..1 progress from the current milestone toward the next one.
  double get levelFraction =>
      (totalCents / 100 - currentThreshold) /
      (nextThreshold - currentThreshold);

  /// Rank per level: index 0 is Level 0 (before the first \$1).
  String get rankTitle => const [
    'Starter',
    'Rookie Saver',
    'Coin Spotter',
    'Penny Pincher',
    'Habit Breaker',
    'Gold Hunter',
    'Treasure Keeper',
    'Vault Master',
    'Legend',
    'Mythic',
  ][level.clamp(0, 9)];

  Set<String> get unlocked => {
    for (final a in achievements)
      if (a.test(this)) a.id,
  };
}
