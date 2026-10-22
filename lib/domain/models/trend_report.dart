import 'dart:math' as math;

import 'package:quit_cash_mobile/domain/models/progress.dart';
import 'package:quit_cash_mobile/domain/models/save_entry.dart';

/// Report windows. Week and Month are the last 7 and 30 local days
/// (today included); Year is the last 12 calendar months; All runs from the
/// month of the first record to this month.
enum TrendPeriod {
  week('Week', 'the previous week'),
  month('Month', 'the previous 30 days'),
  year('Year', 'the previous year'),
  all('All', '');

  const TrendPeriod(this.label, this.previousLabel);
  final String label;
  final String previousLabel;
}

/// One chart bar: [start] inclusive, [end] exclusive, local time.
class TrendBucket {
  const TrendBucket(this.start, this.end, this.cents);
  final DateTime start;
  final DateTime end;
  final int cents;
}

/// Local midnight of [t]. Calendar arithmetic (not Duration) keeps days
/// right across daylight-saving changes.
DateTime dayOf(DateTime t) => DateTime(t.year, t.month, t.day);
DateTime addDays(DateTime day, int n) =>
    DateTime(day.year, day.month, day.day + n);
DateTime addMonths(DateTime month, int n) =>
    DateTime(month.year, month.month + n);

/// Whole local days from [a] to [b] (both midnights), DST-safe.
int daysBetween(DateTime a, DateTime b) => DateTime.utc(
  b.year,
  b.month,
  b.day,
).difference(DateTime.utc(a.year, a.month, a.day)).inDays;

/// Percent change from [previous] to [current]; null when [previous] is 0
/// (no baseline to compare with).
double? percentChange(int current, int previous) =>
    previous == 0 ? null : (current - previous) * 100 / previous;

/// Four-hour parts of the day for the craving-time insight.
const daySlots = [
  (0, 'late at night (12–4 am)'),
  (4, 'early morning (4–8 am)'),
  (8, 'in the morning (8 am–12 pm)'),
  (12, 'in the afternoon (12–4 pm)'),
  (16, 'in the evening (4–8 pm)'),
  (20, 'at night (8 pm–12 am)'),
];

/// Pace and milestone projection from recent saving.
class Projection {
  const Projection({
    required this.centsPerDay,
    required this.milestoneDollars,
    required this.milestoneDate,
    required this.yearlyCents,
  });

  final double centsPerDay;
  final int milestoneDollars;

  /// Null when the pace is zero.
  final DateTime? milestoneDate;
  final int yearlyCents;
}

/// Everything the Trends tab shows, computed from history records only.
class TrendReport {
  TrendReport._({
    required this.period,
    required this.buckets,
    required this.totalCents,
    required this.previousCents,
    required this.days,
    required this.records,
    required this.bestDay,
    required this.biggest,
    required this.weekdayCents,
    required this.hourCounts,
    required this.projection,
    required this.progress,
  });

  /// Minimum records before patterns, projections and insights appear.
  static const minRecords = 3;

  factory TrendReport.compute(
    List<SaveEntry> entries,
    TrendPeriod period, {
    required DateTime now,
  }) {
    final today = dayOf(now);
    final sorted = [...entries]..sort((a, b) => a.at.compareTo(b.at));
    final first = sorted.isEmpty ? today : dayOf(sorted.first.at);
    final (start, end, prevStart, buckets) = _window(period, today, first);
    int sumIn(DateTime a, DateTime b) => sorted
        .where((e) => !e.at.isBefore(a) && e.at.isBefore(b))
        .fold(0, (s, e) => s + e.cents);
    final inPeriod = [
      for (final e in sorted)
        if (!e.at.isBefore(start) && e.at.isBefore(end)) e,
    ];
    final byDay = <DateTime, int>{};
    final weekday = List.filled(7, 0);
    final hours = List.filled(24, 0);
    for (final e in inPeriod) {
      byDay.update(dayOf(e.at), (c) => c + e.cents, ifAbsent: () => e.cents);
      weekday[e.at.weekday - 1] += e.cents;
      hours[e.at.hour]++;
    }
    final best = byDay.entries.fold<MapEntry<DateTime, int>?>(
      null,
      (b, e) => b == null || e.value > b.value ? e : b,
    );
    return TrendReport._(
      period: period,
      buckets: [for (final (a, b) in buckets) TrendBucket(a, b, sumIn(a, b))],
      totalCents: inPeriod.fold(0, (s, e) => s + e.cents),
      previousCents: prevStart == null ? null : sumIn(prevStart, start),
      days: math.max(
        1,
        daysBetween(start, end.isAfter(today) ? addDays(today, 1) : end),
      ),
      records: inPeriod.length,
      bestDay: best == null ? null : (best.key, best.value),
      biggest: inPeriod.fold<SaveEntry?>(
        null,
        (b, e) => b == null || e.cents > b.cents ? e : b,
      ),
      weekdayCents: weekday,
      hourCounts: hours,
      projection: _project(sorted, today),
      progress: Progress.from(sorted),
    );
  }

  static (DateTime, DateTime, DateTime?, List<(DateTime, DateTime)>) _window(
    TrendPeriod period,
    DateTime today,
    DateTime first,
  ) {
    List<(DateTime, DateTime)> daily(DateTime s, int n) => [
      for (var i = 0; i < n; i++) (addDays(s, i), addDays(s, i + 1)),
    ];
    List<(DateTime, DateTime)> monthly(DateTime s, int n) => [
      for (var i = 0; i < n; i++) (addMonths(s, i), addMonths(s, i + 1)),
    ];
    final tomorrow = addDays(today, 1);
    final thisMonth = DateTime(today.year, today.month);
    switch (period) {
      case TrendPeriod.week:
        final s = addDays(today, -6);
        return (s, tomorrow, addDays(s, -7), daily(s, 7));
      case TrendPeriod.month:
        final s = addDays(today, -29);
        return (s, tomorrow, addDays(s, -30), daily(s, 30));
      case TrendPeriod.year:
        final s = addMonths(thisMonth, -11);
        return (s, addMonths(thisMonth, 1), addMonths(s, -12), monthly(s, 12));
      case TrendPeriod.all:
        final s = DateTime(first.year, first.month);
        final n =
            (thisMonth.year - s.year) * 12 + thisMonth.month - s.month + 1;
        return (dayOf(first), addMonths(thisMonth, 1), null, monthly(s, n));
    }
  }

  /// Pace = cents per day over the last 30 days, or since the first
  /// record when history is shorter. Needs [minRecords] records.
  static Projection? _project(List<SaveEntry> sorted, DateTime today) {
    if (sorted.length < minRecords) return null;
    final first = dayOf(sorted.first.at);
    final span = math.min(30, daysBetween(first, today) + 1);
    final from = addDays(today, 1 - span);
    final recent = sorted
        .where((e) => !e.at.isBefore(from))
        .fold(0, (s, e) => s + e.cents);
    final pace = recent / span;
    final p = Progress.from(sorted);
    final target = p.nextThreshold;
    final remaining = target * 100 - p.totalCents;
    return Projection(
      centsPerDay: pace,
      milestoneDollars: target,
      milestoneDate: pace <= 0
          ? null
          : addDays(today, (remaining / pace).ceil()),
      yearlyCents: (pace * 365).round(),
    );
  }

  final TrendPeriod period;
  final List<TrendBucket> buckets;
  final int totalCents;

  /// Total of the previous window of the same length; null for All.
  final int? previousCents;

  /// Days covered so far (for the average); at least 1.
  final int days;
  final int records;
  final (DateTime, int)? bestDay;
  final SaveEntry? biggest;

  /// Cents per weekday, Monday first.
  final List<int> weekdayCents;

  /// Number of records per hour of day (craving times).
  final List<int> hourCounts;
  final Projection? projection;

  /// All-time progress of the scope (ring: progress to the next level).
  final Progress progress;

  double get centsPerDay => totalCents / days;

  double? get change => previousCents == null
      ? null
      : percentChange(totalCents, previousCents ?? 0);

  bool get lowData => records < minRecords;

  /// Most common 4-hour slot by number of records, or null.
  String? get cravingSlot {
    if (lowData) return null;
    var best = -1, bestCount = 0;
    for (var i = 0; i < daySlots.length; i++) {
      final h = daySlots[i].$1;
      final n = hourCounts.sublist(h, h + 4).fold(0, (s, c) => s + c);
      if (n > bestCount) (best, bestCount) = (i, n);
    }
    return best < 0 ? null : daySlots[best].$2;
  }

  /// Weekday (1 = Monday) with the most dollars, if it stands out.
  int? get bestWeekday {
    if (lowData || weekdayCents.where((c) => c > 0).length < 2) return null;
    var best = 0;
    for (var i = 1; i < 7; i++) {
      if (weekdayCents[i] > weekdayCents[best]) best = i;
    }
    return best + 1;
  }
}
