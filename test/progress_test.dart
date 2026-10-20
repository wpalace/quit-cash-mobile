import 'package:flutter_test/flutter_test.dart';
import 'package:quit_cash_mobile/data/save_entry.dart';
import 'package:quit_cash_mobile/game/progress.dart';

SaveEntry save(int dollars, DateTime at) =>
    SaveEntry(kind: EntryKind.save, cents: dollars * 100, at: at);

void main() {
  final now = DateTime(2026, 10, 19, 12);

  test('empty log is level 1 with nothing unlocked', () {
    final p = Progress.from(const [], now: now);
    expect(p.total, 0);
    expect(p.level, 1);
    expect(p.currentStreak, 0);
    expect(p.unlocked, isEmpty);
  });

  test('totals, coins and xp derive from saves', () {
    final p = Progress.from([save(5, now), save(20, now)], now: now);
    expect(p.totalCents, 2500);
    expect(p.coins, 25);
    expect(p.xp, 250);
    expect(p.level, 3); // 100 to reach L2 + 150 to reach L3
    expect(p.xpIntoLevel, 0);
    expect(p.unlocked, containsAll(['first', 'ten']));
  });

  test('streak counts consecutive days and survives until tomorrow', () {
    final days = [for (var i = 3; i >= 1; i--) now.subtract(Duration(days: i))];
    final p = Progress.from([for (final d in days) save(1, d)], now: now);
    expect(p.currentStreak, 3);
    expect(p.bestStreak, 3);
    expect(p.unlocked, contains('streak3'));
  });

  test('streak breaks after a missed day', () {
    final p = Progress.from([
      save(1, now.subtract(const Duration(days: 3))),
    ], now: now);
    expect(p.currentStreak, 0);
    expect(p.bestStreak, 1);
  });

  test('check-in grants coins and xp once per day', () {
    final p = Progress.from([
      SaveEntry(kind: EntryKind.checkIn, cents: 0, at: now),
    ], now: now);
    expect(p.checkedInToday, isTrue);
    expect(p.coins, checkInCoins);
    expect(p.xp, checkInXp);
    expect(p.total, 0);
  });
}
