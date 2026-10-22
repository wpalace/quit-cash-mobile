import 'package:quit_cash_mobile/domain/models/trend_report.dart';
import 'package:quit_cash_mobile/utils/money.dart';

/// One plain-language takeaway.
typedef Insight = ({String emoji, String title, String body});

const weekdayNames = [
  'Monday',
  'Tuesday',
  'Wednesday',
  'Thursday',
  'Friday',
  'Saturday',
  'Sunday',
];

const _months = [
  'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun', //
  'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec',
];

/// Short date such as 'Dec 3' (adds the year when it is not this year).
String shortDate(DateTime d, {DateTime? now}) {
  final s = '${_months[d.month - 1]} ${d.day}';
  return d.year == (now ?? DateTime.now()).year ? s : '$s, ${d.year}';
}

/// 2–4 takeaways derived only from [r]; a single friendly card when there
/// is not enough data yet.
List<Insight> insightsFor(TrendReport r, {required DateTime now}) {
  if (r.lowData) {
    final left = TrendReport.minRecords - r.records;
    return [
      (
        emoji: '🌱',
        title: 'Trends are warming up',
        body: r.records == 0
            ? 'No savings in this period yet. Bank a skipped craving and it will show up here.'
            : 'Bank $left more ${left == 1 ? 'saving' : 'savings'} in this period to unlock patterns and projections.',
      ),
    ];
  }
  final out = <Insight>[];
  final change = r.change;
  final prev = r.previousCents;
  if (change != null) {
    final pct = change.abs().round();
    out.add((
      emoji: change >= 0 ? '📈' : '📉',
      title: pct == 0
          ? 'Same as ${r.period.previousLabel}'
          : 'You saved $pct% ${change > 0 ? 'more' : 'less'} than ${r.period.previousLabel}',
      body: '${moneyCents(r.totalCents)} vs ${moneyCents(prev ?? 0)}.',
    ));
  } else if (prev == 0 && r.totalCents > 0) {
    out.add((
      emoji: '✨',
      title: 'A fresh start',
      body:
          'Nothing saved in ${r.period.previousLabel}, '
          '${moneyCents(r.totalCents)} this time.',
    ));
  }
  final slot = r.cravingSlot;
  if (slot != null) {
    out.add((
      emoji: '🕰️',
      title: 'Most common craving time',
      body: 'Most of your skips happen $slot.',
    ));
  }
  final wd = r.bestWeekday;
  if (wd != null) {
    out.add((
      emoji: '📅',
      title: '${weekdayNames[wd - 1]}s are your strongest day',
      body:
          '${moneyCents(r.weekdayCents[wd - 1])} saved on '
          '${weekdayNames[wd - 1]}s in this period.',
    ));
  }
  final p = r.projection;
  final date = p?.milestoneDate;
  if (p != null && date != null) {
    out.add((
      emoji: '🎯',
      title:
          'At this pace you\'ll hit \$${p.milestoneDollars} by ${shortDate(date, now: now)}',
      body: 'That is about ${moneyCents(p.yearlyCents)} a year.',
    ));
  }
  return out.take(4).toList();
}
