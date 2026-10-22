import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:quit_cash_mobile/domain/models/save_entry.dart';
import 'package:quit_cash_mobile/ui/core/themes/denominations.dart';
import 'package:quit_cash_mobile/ui/core/themes/palette.dart';
import 'package:quit_cash_mobile/ui/core/view_models/savings_view_model.dart';
import 'package:quit_cash_mobile/ui/core/widgets/backdrop.dart';
import 'package:quit_cash_mobile/ui/core/widgets/spinning_coin.dart';
import 'package:quit_cash_mobile/ui/history/edit_entry_dialog.dart';
import 'package:quit_cash_mobile/utils/money.dart';

/// Savings records of the active goal, newest first, grouped by day.
/// Tap a record to edit or delete it.
class HistoryScreen extends StatelessWidget {
  const HistoryScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final model = context.watch<SavingsViewModel>();
    final goal = model.activeGoal;
    final rows = [...model.entries]..sort((a, b) => b.at.compareTo(a.at));
    return Scaffold(
      appBar: AppBar(
        title: Text(goal == null ? 'History' : 'History · ${goal.title}'),
        backgroundColor: Colors.transparent,
        foregroundColor: Colors.white,
      ),
      body: Backdrop(
        child: SafeArea(
          child: rows.isEmpty
              ? const _Empty()
              : ListView(
                  key: const Key('history-list'),
                  padding: const EdgeInsets.fromLTRB(16, 0, 16, 24),
                  children: [
                    _Total(cents: model.progress.totalCents),
                    for (final day in groupByDay(rows)) ...[
                      _DayHeader(day: day.first.at, rows: day),
                      for (final e in day) _Row(entry: e),
                    ],
                  ],
                ),
        ),
      ),
    );
  }
}

/// Splits records (already newest first) into runs of the same local day.
List<List<SaveEntry>> groupByDay(List<SaveEntry> newestFirst) {
  final out = <List<SaveEntry>>[];
  for (final e in newestFirst) {
    final last = out.lastOrNull;
    if (last != null && DateUtils.isSameDay(last.first.at, e.at)) {
      last.add(e);
    } else {
      out.add([e]);
    }
  }
  return out;
}

/// Largest denomination at or below [cents], for the mini coin.
Denomination coinFor(int cents) => denominations.lastWhere(
  (d) => d.dollars * 100 <= cents,
  orElse: () => denominations.first,
);

class _Total extends StatelessWidget {
  const _Total({required this.cents});
  final int cents;

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.only(bottom: 8),
    child: Text(
      '${moneyCents(cents)} saved · tap a record to edit',
      style: const TextStyle(color: Colors.white70),
    ),
  );
}

class _DayHeader extends StatelessWidget {
  const _DayHeader({required this.day, required this.rows});
  final DateTime day;
  final List<SaveEntry> rows;

  @override
  Widget build(BuildContext context) {
    final today = DateTime.now();
    final label = DateUtils.isSameDay(day, today)
        ? 'Today'
        : DateUtils.isSameDay(day, today.subtract(const Duration(days: 1)))
        ? 'Yesterday'
        : MaterialLocalizations.of(context).formatMediumDate(day);
    final total = rows.fold(0, (s, e) => s + e.cents);
    return Padding(
      padding: const EdgeInsets.fromLTRB(4, 16, 4, 6),
      child: Row(
        children: [
          Text(
            label,
            style: const TextStyle(
              color: Palette.gold,
              fontWeight: FontWeight.w900,
              fontSize: 16,
            ),
          ),
          const Spacer(),
          Text(
            moneyCents(total),
            style: const TextStyle(color: Colors.white60),
          ),
        ],
      ),
    );
  }
}

class _Row extends StatelessWidget {
  const _Row({required this.entry});
  final SaveEntry entry;

  @override
  Widget build(BuildContext context) {
    final time = MaterialLocalizations.of(context)
        .formatTimeOfDay(TimeOfDay.fromDateTime(entry.at));
    return Card(
      color: Palette.card,
      elevation: 0,
      margin: const EdgeInsets.only(bottom: 8),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: ListTile(
        key: Key('record-${entry.id}'),
        onTap: () => showEditEntryDialog(context, entry),
        leading: SpinningCoin(
          size: 32,
          spin: false,
          denomination: coinFor(entry.cents),
        ),
        title: Text(
          moneyCents(entry.cents),
          style: const TextStyle(
            color: Colors.white,
            fontWeight: FontWeight.w900,
            fontSize: 18,
          ),
        ),
        subtitle: Text(time, style: const TextStyle(color: Colors.white60)),
        trailing: const Icon(Icons.edit_outlined, color: Colors.white54),
      ),
    );
  }
}

class _Empty extends StatelessWidget {
  const _Empty();

  @override
  Widget build(BuildContext context) {
    return const Center(
      key: Key('history-empty'),
      child: Padding(
        padding: EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            SpinningCoin(size: 90, sparkles: true),
            SizedBox(height: 16),
            Text(
              'No savings yet',
              style: TextStyle(
                color: Colors.white,
                fontSize: 22,
                fontWeight: FontWeight.w900,
              ),
            ),
            SizedBox(height: 8),
            Text(
              'Tap the coin on the Bank tab each time you skip a craving. '
              'Your savings show up here.',
              textAlign: TextAlign.center,
              style: TextStyle(color: Colors.white70),
            ),
          ],
        ),
      ),
    );
  }
}
