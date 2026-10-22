import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:quit_cash_mobile/domain/models/trend_insights.dart';
import 'package:quit_cash_mobile/domain/models/trend_report.dart';
import 'package:quit_cash_mobile/ui/core/themes/palette.dart';
import 'package:quit_cash_mobile/ui/core/view_models/savings_view_model.dart';
import 'package:quit_cash_mobile/ui/trends/widgets/hour_heat_strip.dart';
import 'package:quit_cash_mobile/ui/trends/widgets/insight_card.dart';
import 'package:quit_cash_mobile/ui/trends/widgets/progress_ring.dart';
import 'package:quit_cash_mobile/ui/trends/widgets/savings_bar_chart.dart';
import 'package:quit_cash_mobile/ui/trends/widgets/stat_tile.dart';
import 'package:quit_cash_mobile/ui/trends/widgets/trend_card.dart';
import 'package:quit_cash_mobile/utils/money.dart';

/// Oura-style reports for dollars saved: ring, period chart, patterns,
/// projections and plain-language insights. Recomputed from history
/// records on every rebuild, so edits show up at once.
class TrendsScreen extends StatefulWidget {
  const TrendsScreen({super.key});

  @override
  State<TrendsScreen> createState() => _TrendsScreenState();
}

class _TrendsScreenState extends State<TrendsScreen> {
  TrendPeriod _period = TrendPeriod.week;
  bool _allGoals = false;

  @override
  Widget build(BuildContext context) {
    final model = context.watch<SavingsViewModel>();
    final now = model.now();
    final r = TrendReport.compute(
      _allGoals ? model.allEntries : model.entries,
      _period,
      now: now,
    );
    final goal = model.activeGoal;
    return SafeArea(
      child: ListView(
        key: const Key('trends-list'),
        padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
        children: [
          _Header(
            scope: _allGoals ? 'All goals' : '${goal?.emoji} ${goal?.title}',
          ),
          const SizedBox(height: 12),
          _Toggles(
            period: _period,
            allGoals: _allGoals,
            showScope: model.goals.length > 1,
            onPeriod: (p) => setState(() => _period = p),
            onScope: (all) => setState(() => _allGoals = all),
          ),
          const SizedBox(height: 16),
          _Hero(report: r),
          _ChartCard(report: r),
          _Stats(report: r),
          _Patterns(report: r),
          _Projection(report: r, now: now),
          const _SectionLabel('Insights'),
          for (final i in insightsFor(r, now: now)) InsightCard(insight: i),
        ],
      ),
    );
  }
}

class _Header extends StatelessWidget {
  const _Header({required this.scope});
  final String scope;

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.end,
      children: [
        Text(
          'Trends',
          style: Theme.of(context).textTheme.headlineMedium
              ?.copyWith(color: Palette.gold, fontWeight: FontWeight.w900),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Text(
            scope,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(color: Colors.white60, fontSize: 15),
          ),
        ),
      ],
    );
  }
}

class _Toggles extends StatelessWidget {
  const _Toggles({
    required this.period,
    required this.allGoals,
    required this.showScope,
    required this.onPeriod,
    required this.onScope,
  });
  final TrendPeriod period;
  final bool allGoals;
  final bool showScope;
  final ValueChanged<TrendPeriod> onPeriod;
  final ValueChanged<bool> onScope;

  static final _style = SegmentedButton.styleFrom(
    selectedBackgroundColor: Palette.gold,
    selectedForegroundColor: Palette.outline,
    foregroundColor: Colors.white70,
    side: const BorderSide(color: Colors.white24),
  );

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        SizedBox(
          width: double.infinity,
          child: SegmentedButton<TrendPeriod>(
            style: _style,
            showSelectedIcon: false,
            segments: [
              for (final p in TrendPeriod.values)
                ButtonSegment(
                  value: p,
                  label: Text(p.label, key: Key('period-${p.name}')),
                ),
            ],
            selected: {period},
            onSelectionChanged: (s) => onPeriod(s.first),
          ),
        ),
        if (showScope) ...[
          const SizedBox(height: 8),
          SizedBox(
            width: double.infinity,
            child: SegmentedButton<bool>(
              style: _style,
              showSelectedIcon: false,
              segments: const [
                ButtonSegment(
                  value: false,
                  label: Text('This goal', key: Key('scope-goal')),
                ),
                ButtonSegment(
                  value: true,
                  label: Text('All goals', key: Key('scope-all')),
                ),
              ],
              selected: {allGoals},
              onSelectionChanged: (s) => onScope(s.first),
            ),
          ),
        ],
      ],
    );
  }
}

String _periodCaption(TrendPeriod p) => switch (p) {
  TrendPeriod.week => 'LAST 7 DAYS',
  TrendPeriod.month => 'LAST 30 DAYS',
  TrendPeriod.year => 'LAST 12 MONTHS',
  TrendPeriod.all => 'ALL TIME',
};

class _Hero extends StatelessWidget {
  const _Hero({required this.report});
  final TrendReport report;

  @override
  Widget build(BuildContext context) {
    final p = report.progress;
    final toGo = p.nextThreshold * 100 - p.totalCents;
    return TrendCard(
      child: Center(
        child: Column(
          children: [
            ProgressRing(
              key: const Key('trend-ring'),
              fraction: p.levelFraction,
              center: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    moneyCents(report.totalCents),
                    key: const Key('period-total'),
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 38,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                  Text(
                    _periodCaption(report.period),
                    style: const TextStyle(
                      color: Palette.gold,
                      fontSize: 12,
                      letterSpacing: 1.6,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 14),
            Text(
              'LV ${p.level} · ${moneyCents(toGo)} to \$${p.nextThreshold}',
              style: const TextStyle(color: Colors.white70, fontSize: 15),
            ),
          ],
        ),
      ),
    );
  }
}

const _wd = ['M', 'T', 'W', 'T', 'F', 'S', 'S'];
const _mo = ['J', 'F', 'M', 'A', 'M', 'J', 'J', 'A', 'S', 'O', 'N', 'D'];

List<String> _labels(TrendReport r) => [
  for (final (i, b) in r.buckets.indexed)
    switch (r.period) {
      TrendPeriod.week => _wd[b.start.weekday - 1],
      TrendPeriod.month => i % 5 == 4 ? '${b.start.day}' : '',
      TrendPeriod.year || TrendPeriod.all =>
        r.buckets.length > 12 && i % 3 != 0 ? '' : _mo[b.start.month - 1],
    },
];

class _ChartCard extends StatelessWidget {
  const _ChartCard({required this.report});
  final TrendReport report;

  @override
  Widget build(BuildContext context) {
    final change = report.change;
    final prev = report.previousCents;
    final chip = change != null
        ? '${change >= 0 ? '+' : '−'}${change.abs().round()}% vs ${report.period.previousLabel}'
        : prev == null
        ? 'Since your first saving'
        : 'No savings in ${report.period.previousLabel}';
    return TrendCard(
      title:
          report.period == TrendPeriod.week ||
              report.period == TrendPeriod.month
          ? 'Dollars saved per day'
          : 'Dollars saved per month',
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            chip,
            key: const Key('change-chip'),
            style: TextStyle(
              color: (change ?? 0) < 0 ? Colors.white60 : Palette.mint,
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 12),
          SavingsBarChart(
            key: Key('chart-${report.period.name}'),
            values: [for (final b in report.buckets) b.cents],
            labels: _labels(report),
          ),
        ],
      ),
    );
  }
}

class _Stats extends StatelessWidget {
  const _Stats({required this.report});
  final TrendReport report;

  @override
  Widget build(BuildContext context) {
    final best = report.bestDay;
    final big = report.biggest;
    final l10n = MaterialLocalizations.of(context);
    return TrendCard(
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(
            child: StatTile(
              label: 'Avg per day',
              value: moneyCents(report.centsPerDay.round()),
            ),
          ),
          Expanded(
            child: StatTile(
              label: 'Best day',
              value: best == null ? '—' : moneyCents(best.$2),
              detail: best == null ? null : l10n.formatShortMonthDay(best.$1),
            ),
          ),
          Expanded(
            child: StatTile(
              label: 'Biggest save',
              value: big == null ? '—' : moneyCents(big.cents),
              detail: big == null ? null : l10n.formatShortMonthDay(big.at),
            ),
          ),
        ],
      ),
    );
  }
}

class _Patterns extends StatelessWidget {
  const _Patterns({required this.report});
  final TrendReport report;

  @override
  Widget build(BuildContext context) {
    final slot = report.cravingSlot;
    return TrendCard(
      title: 'Patterns',
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('By day of week', style: _sub),
          const SizedBox(height: 8),
          SavingsBarChart(
            key: const Key('weekday-chart'),
            height: 90,
            values: report.weekdayCents,
            labels: _wd,
          ),
          const SizedBox(height: 16),
          const Text('By time of day', style: _sub),
          const SizedBox(height: 8),
          HourHeatStrip(counts: report.hourCounts),
          const SizedBox(height: 12),
          Text(
            slot == null
                ? 'A few more savings and your craving pattern shows up here.'
                : 'Most common craving time: $slot.',
            key: const Key('craving-time'),
            style: const TextStyle(color: Colors.white70),
          ),
        ],
      ),
    );
  }
}

const _sub = TextStyle(color: Colors.white60, fontSize: 13);

class _Projection extends StatelessWidget {
  const _Projection({required this.report, required this.now});
  final TrendReport report;
  final DateTime now;

  @override
  Widget build(BuildContext context) {
    final p = report.projection;
    final date = p?.milestoneDate;
    return TrendCard(
      title: 'Projection',
      child: p == null
          ? const Text(
              'Bank a few savings and we will estimate when you reach your '
              'next milestone.',
              style: TextStyle(color: Colors.white70),
            )
          : Row(
              children: [
                Expanded(
                  child: StatTile(
                    label: 'Next milestone',
                    value: '\$${p.milestoneDollars}',
                    detail: date == null
                        ? 'Save to set a pace'
                        : 'by ${shortDate(date, now: now)}',
                  ),
                ),
                Expanded(
                  child: StatTile(
                    label: 'Pace',
                    value: '${moneyCents(p.centsPerDay.round())}/day',
                  ),
                ),
                Expanded(
                  child: StatTile(
                    label: 'Yearly',
                    value: moneyCents(p.yearlyCents),
                  ),
                ),
              ],
            ),
    );
  }
}

class _SectionLabel extends StatelessWidget {
  const _SectionLabel(this.text);
  final String text;

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.fromLTRB(4, 8, 4, 10),
    child: Text(
      text,
      style: const TextStyle(
        color: Colors.white,
        fontSize: 20,
        fontWeight: FontWeight.w800,
      ),
    ),
  );
}
