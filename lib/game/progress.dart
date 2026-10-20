import '../data/save_entry.dart';

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

/// Coins awarded for one daily check-in. Coins are a cosmetic currency:
/// they never add to total saved and never affect level.
const checkInCoins = 5;

final List<Achievement> achievements = [
  Achievement(
    'first',
    'First Coin',
    'Save your very first dollar',
    '🪙',
    (p) => p.saveCount >= 1,
  ),
  Achievement(
    'ten',
    'Ten Spot',
    'Save \$10 in total',
    '💵',
    (p) => p.totalCents >= 1000,
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
    'k',
    'Grand Master',
    'Save \$1,000 in total',
    '👑',
    (p) => p.totalCents >= 100000,
  ),
  Achievement(
    'streak3',
    'On Fire',
    'Keep a 3-day streak',
    '🔥',
    (p) => p.bestStreak >= 3,
  ),
  Achievement(
    'streak7',
    'One Week Strong',
    'Keep a 7-day streak',
    '⚡',
    (p) => p.bestStreak >= 7,
  ),
  Achievement(
    'streak30',
    'Unstoppable',
    'Keep a 30-day streak',
    '🚀',
    (p) => p.bestStreak >= 30,
  ),
  Achievement(
    'taps25',
    'Coin Collector',
    'Collect 25 coins',
    '⭐',
    (p) => p.saveCount >= 25,
  ),
  Achievement(
    'lvl5',
    'Level 5',
    'Reach level 5 (\$200 saved)',
    '🏆',
    (p) => p.level >= 5,
  ),
];

DateTime _day(DateTime t) => DateTime(t.year, t.month, t.day);

class Progress {
  Progress._({
    required this.totalCents,
    required this.saveCount,
    required this.currentStreak,
    required this.bestStreak,
    required this.checkedInToday,
    required this.coins,
  });

  factory Progress.from(List<SaveEntry> entries, {DateTime? now}) {
    final today = _day(now ?? DateTime.now());
    var cents = 0, saves = 0, coins = 0;
    var checkedIn = false;
    final days = <DateTime>{};
    for (final e in entries) {
      days.add(_day(e.at));
      if (e.kind == EntryKind.save) {
        cents += e.cents;
        saves++;
        coins += (e.cents ~/ 100).clamp(1, 1 << 30);
      } else {
        coins += checkInCoins;
        if (_day(e.at) == today) checkedIn = true;
      }
    }
    final sorted = days.toList()..sort();
    var best = 0, run = 0;
    DateTime? prev;
    for (final d in sorted) {
      run = (prev != null && d.difference(prev).inHours.round() == 24)
          ? run + 1
          : 1;
      if (run > best) best = run;
      prev = d;
    }
    // Current streak is alive if the last active day is today or yesterday.
    var current = 0;
    if (prev != null && today.difference(prev).inHours.round() <= 24) {
      current = run;
    }
    return Progress._(
      totalCents: cents,
      saveCount: saves,
      currentStreak: current,
      bestStreak: best,
      checkedInToday: checkedIn,
      coins: coins,
    );
  }

  final int totalCents;
  final int saveCount;
  final int currentStreak;
  final int bestStreak;
  final bool checkedInToday;

  /// Collected coin count shown in the HUD (1 per dollar, min 1 per tap).
  final int coins;

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
