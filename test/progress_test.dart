import 'package:flutter_test/flutter_test.dart';
import 'package:quit_cash_mobile/domain/models/progress.dart';
import 'package:quit_cash_mobile/domain/models/save_entry.dart';

SaveEntry save(int dollars, DateTime at) =>
    SaveEntry(kind: EntryKind.save, cents: dollars * 100, at: at);

void main() {
  final now = DateTime(2026, 10, 19, 12);

  test('empty log is level 1 with nothing unlocked', () {
    final p = Progress.from(const []);
    expect(p.total, 0);
    expect(p.level, 0);
    expect(p.rankTitle, 'Starter');
    expect(p.unlocked, isEmpty);
  });

  test('totals and badges derive from dollars saved', () {
    final p = Progress.from([save(5, now), save(20, now)]);
    expect(p.totalCents, 2500);
    expect(p.level, 2); // $20 reached, $50 next
    expect(p.nextThreshold, 50);
    expect(p.levelFraction, closeTo(5 / 30, 1e-9));
    expect(p.unlocked, {'first', 'ten', 'twentyfive'});
  });

  test('a cents-only save below \$1 unlocks nothing', () {
    final p = Progress.from([
      SaveEntry(kind: EntryKind.save, cents: 50, at: now),
    ]);
    expect(p.unlocked, isEmpty);
  });

  test('badges are dollar milestones only', () {
    expect(achievements.map((a) => a.id), [
      'first',
      'ten',
      'twentyfive',
      'fifty',
      'hundred',
      'lvl5',
      'fivehundred',
      'k',
      'k2500',
      'k5000',
    ]);
    final p = Progress.from([save(5000, now)]);
    expect(p.unlocked, hasLength(achievements.length));
    expect(
      Progress.from([save(499, now)]).unlocked,
      isNot(contains('fivehundred')),
    );
    expect(Progress.from([save(500, now)]).unlocked, contains('fivehundred'));
  });

  group('dollar milestone levels', () {
    const table = {
      0: 0,
      99: 0,
      100: 1,
      1999: 1,
      2000: 2,
      4999: 2,
      5000: 3,
      9999: 3,
      10000: 4,
      20000: 5,
      49999: 5,
      50000: 6,
      99999: 6,
      100000: 7,
      199999: 7,
      200000: 8,
      300000: 9,
      999999: 15,
      1000000: 16,
    };
    table.forEach((cents, level) {
      test('$cents cents is level $level', () {
        expect(Progress.levelForCents(cents), level);
      });
    });

    test('fixed thresholds then every \$1000', () {
      expect(
        [for (var l = 1; l <= 10; l++) Progress.thresholdFor(l)],
        [1, 20, 50, 100, 200, 500, 1000, 2000, 3000, 4000],
      );
      for (var l = 7; l < 50; l++) {
        expect(Progress.thresholdFor(l + 1) - Progress.thresholdFor(l), 1000);
      }
    });

    test('progress bar spans current to next milestone', () {
      final p = Progress.from([save(1500, now)]);
      expect(p.level, 7);
      expect(p.currentThreshold, 1000);
      expect(p.nextThreshold, 2000);
      expect(p.levelFraction, closeTo(0.5, 1e-9));
      expect(p.rankTitle, 'Vault Master');
    });
  });
}
