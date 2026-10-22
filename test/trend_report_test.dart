import 'package:flutter_test/flutter_test.dart';
import 'package:quit_cash_mobile/domain/models/save_entry.dart';
import 'package:quit_cash_mobile/domain/models/trend_insights.dart';
import 'package:quit_cash_mobile/domain/models/trend_report.dart';

SaveEntry at(DateTime t, int cents) =>
    SaveEntry(kind: EntryKind.save, cents: cents, at: t);

// Wednesday, 21 Oct 2026, 20:00 local.
final now = DateTime(2026, 10, 21, 20);

TrendReport report(List<SaveEntry> e, TrendPeriod p) =>
    TrendReport.compute(e, p, now: now);

void main() {
  group('percentChange', () {
    test('up, down, flat', () {
      expect(percentChange(123, 100), closeTo(23, 1e-9));
      expect(percentChange(50, 100), closeTo(-50, 1e-9));
      expect(percentChange(100, 100), 0);
    });
    test('divide by zero has no baseline', () {
      expect(percentChange(500, 0), isNull);
      expect(percentChange(0, 0), isNull);
      expect(percentChange(0, 100), -100);
    });
  });

  group('period buckets', () {
    test('week: 7 daily buckets ending today, oldest first', () {
      final r = report(const [], TrendPeriod.week);
      expect(r.buckets, hasLength(7));
      expect(r.buckets.first.start, DateTime(2026, 10, 15));
      expect(r.buckets.last.start, DateTime(2026, 10, 21));
      expect(r.buckets.last.end, DateTime(2026, 10, 22));
      expect(r.days, 7);
    });

    test('month: 30 days; year: 12 calendar months', () {
      expect(report(const [], TrendPeriod.month).buckets, hasLength(30));
      final y = report(const [], TrendPeriod.year);
      expect(y.buckets, hasLength(12));
      expect(y.buckets.first.start, DateTime(2025, 11));
      expect(y.buckets.last.start, DateTime(2026, 10));
      expect(y.buckets.last.end, DateTime(2026, 11));
    });

    test('all: months from the first record; no comparison', () {
      final r = report([at(DateTime(2026, 7, 30, 9), 500)], TrendPeriod.all);
      expect(r.buckets.map((b) => b.start.month), [7, 8, 9, 10]);
      expect(r.buckets.first.cents, 500);
      expect(r.previousCents, isNull);
      expect(r.change, isNull);
      expect(r.days, 84); // Jul 30 .. Oct 21 inclusive
    });

    test('day boundaries: 23:59:59 and 00:00 fall on different days', () {
      final r = report([
        at(DateTime(2026, 10, 20, 23, 59, 59), 100),
        at(DateTime(2026, 10, 21), 200),
      ], TrendPeriod.week);
      expect(r.buckets[5].cents, 100);
      expect(r.buckets[6].cents, 200);
    });

    test('records before the window and in the future are excluded', () {
      final r = report([
        at(DateTime(2026, 10, 14, 23, 59), 100), // just before week
        at(DateTime(2026, 10, 15), 300), // first second of week
        at(DateTime(2026, 10, 22), 999), // tomorrow
      ], TrendPeriod.week);
      expect(r.totalCents, 300);
      expect(r.previousCents, 100);
    });

    test('daylight saving: days stay calendar days (Nov 1 2026 in the US)', () {
      final dstNow = DateTime(2026, 11, 3, 12);
      final r = TrendReport.compute(
        [
          at(DateTime(2026, 11, 1, 0, 30), 100),
          at(DateTime(2026, 11, 1, 23, 30), 200),
          at(DateTime(2026, 11, 2, 0, 10), 400),
        ],
        TrendPeriod.week,
        now: dstNow,
      );
      for (final b in r.buckets) {
        expect((b.start.hour, b.start.minute), (0, 0));
      }
      final nov1 = r.buckets.firstWhere((b) => b.start.day == 1);
      expect(nov1.cents, 300);
      expect(r.buckets.last.start, DateTime(2026, 11, 3));
      expect(daysBetween(DateTime(2026, 3, 7), DateTime(2026, 3, 9)), 2);
    });
  });

  group('stats', () {
    final data = [
      at(DateTime(2026, 10, 19, 19), 500),
      at(DateTime(2026, 10, 19, 21), 700),
      at(DateTime(2026, 10, 21, 18), 2000),
      at(DateTime(2026, 10, 10, 12), 1000), // previous week
    ];

    test('total, previous, % change, average, best day, biggest', () {
      final r = report(data, TrendPeriod.week);
      expect(r.totalCents, 3200);
      expect(r.previousCents, 1000);
      expect(r.change, closeTo(220, 1e-9));
      expect(r.centsPerDay, closeTo(3200 / 7, 1e-9));
      expect(r.bestDay, (DateTime(2026, 10, 21), 2000));
      expect(r.biggest?.cents, 2000);
      expect(r.records, 3);
    });

    test('patterns: weekday dollars and hour counts', () {
      final r = report(data, TrendPeriod.week);
      expect(r.weekdayCents[0], 1200); // Monday
      expect(r.weekdayCents[2], 2000); // Wednesday
      expect(r.hourCounts[19], 1);
      expect(r.hourCounts[21], 1);
      expect(r.cravingSlot, 'in the evening (4–8 pm)');
      expect(r.bestWeekday, 3);
    });

    test('empty and low data', () {
      final r = report(const [], TrendPeriod.week);
      expect(r.totalCents, 0);
      expect(r.bestDay, isNull);
      expect(r.biggest, isNull);
      expect(r.lowData, isTrue);
      expect(r.cravingSlot, isNull);
      expect(r.projection, isNull);
      final cards = insightsFor(r, now: now);
      expect(cards, hasLength(1));
      expect(cards.single.title, 'Trends are warming up');
      final two = report(data.take(2).toList(), TrendPeriod.week);
      expect(insightsFor(two, now: now).single.body, contains('1 more saving'));
    });
  });

  group('projection', () {
    test('pace over the last 30 days to the next milestone', () {
      // $10/day for 30 days = $300 total: level 5 ($200), next $500.
      final e = [
        for (var i = 0; i < 30; i++) at(DateTime(2026, 10, 21 - i, 19), 1000),
      ];
      final p = report(e, TrendPeriod.month).projection;
      expect(p?.centsPerDay, closeTo(1000, 1e-9));
      expect(p?.milestoneDollars, 500);
      expect(p?.milestoneDate, DateTime(2026, 11, 10)); // +20 days
      expect(p?.yearlyCents, 365000);
    });

    test('short history uses days since the first record', () {
      final e = [
        at(DateTime(2026, 10, 20, 9), 1000),
        at(DateTime(2026, 10, 21, 9), 500),
        at(DateTime(2026, 10, 21, 10), 500),
      ];
      final p = report(e, TrendPeriod.week).projection;
      expect(p?.centsPerDay, closeTo(1000, 1e-9)); // $20 over 2 days
      expect(p?.milestoneDollars, 50);
      expect(p?.milestoneDate, DateTime(2026, 10, 24)); // $30 to go: 3 days
    });

    test('no recent saving means no date', () {
      final e = [for (var i = 0; i < 3; i++) at(DateTime(2026, 1, 1 + i), 100)];
      final p = report(e, TrendPeriod.all).projection;
      expect(p?.centsPerDay, 0);
      expect(p?.milestoneDate, isNull);
    });
  });

  group('insights', () {
    test('2–4 data-derived cards', () {
      final e = [
        at(DateTime(2026, 10, 19, 19), 600),
        at(DateTime(2026, 10, 20, 18), 600),
        at(DateTime(2026, 10, 21, 19), 1000),
        at(DateTime(2026, 10, 12, 19), 1000),
        at(DateTime(2026, 10, 13, 19), 800),
      ];
      final cards = insightsFor(report(e, TrendPeriod.week), now: now);
      expect(cards.length, inInclusiveRange(2, 4));
      expect(cards.first.title, 'You saved 22% more than the previous week');
      expect(cards.first.body, r'$22.00 vs $18.00.');
      expect(cards.map((c) => c.title), contains('Most common craving time'));
      expect(cards.last.title, startsWith("At this pace you'll hit \$50 by"));
    });

    test('fresh start when the previous period was empty', () {
      final e = [
        for (var d = 19; d <= 21; d++) at(DateTime(2026, 10, d, 12), 500),
      ];
      final cards = insightsFor(report(e, TrendPeriod.week), now: now);
      expect(cards.first.title, 'A fresh start');
    });

    test('less than before', () {
      final e = [
        at(DateTime(2026, 10, 21, 9), 500),
        at(DateTime(2026, 10, 21, 10), 500),
        at(DateTime(2026, 10, 21, 11), 500),
        at(DateTime(2026, 10, 12, 9), 3000),
      ];
      final cards = insightsFor(report(e, TrendPeriod.week), now: now);
      expect(cards.first.title, 'You saved 50% less than the previous week');
    });

    test('shortDate', () {
      expect(shortDate(DateTime(2026, 12, 3), now: now), 'Dec 3');
      expect(shortDate(DateTime(2027, 1, 5), now: now), 'Jan 5, 2027');
    });
  });
}
