import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:quit_cash_mobile/data/repositories/in_memory_savings_repository.dart';
import 'package:quit_cash_mobile/domain/models/save_entry.dart';

import 'app_widget_test.dart' show pumpApp;

final today = DateTime.now();
SaveEntry rec(String id, int cents, int daysAgo, int hour) => SaveEntry(
  id: id,
  kind: EntryKind.save,
  cents: cents,
  at: DateTime(today.year, today.month, today.day - daysAgo, hour),
);

Future<void> settle(WidgetTester tester, [int frames = 10]) async {
  for (var i = 0; i < frames; i++) {
    await tester.pump(const Duration(milliseconds: 100));
  }
}

Future<void> openTrends(WidgetTester tester) async {
  await tester.tap(find.byKey(const Key('tab-trends')));
  await settle(tester);
}

String periodTotal(WidgetTester tester) =>
    tester.widget<Text>(find.byKey(const Key('period-total'))).data ?? '';

void main() {
  testWidgets('low-data state is friendly', (tester) async {
    await pumpApp(
      tester,
      repo: InMemorySavingsRepository.withGoal('Smoking')..reminder = 'never',
    );
    await openTrends(tester);
    expect(find.text('Trends'), findsWidgets); // header + tab
    expect(periodTotal(tester), '\$0.00');
    await tester.scrollUntilVisible(
      find.text('Trends are warming up'),
      300,
      scrollable: find.byType(Scrollable).last,
    );
    expect(find.text('Trends are warming up'), findsOneWidget);
    expect(find.byKey(const Key('scope-all')), findsNothing); // one goal
  });

  testWidgets('periods switch the chart and totals; edits recompute live', (
    tester,
  ) async {
    final repo = InMemorySavingsRepository.withGoal('Smoking', [
      rec('a', 500, 0, 19),
      rec('b', 700, 2, 20),
      rec('c', 1000, 20, 19),
      rec('d', 3000, 200, 12),
    ])..reminder = 'never';
    final model = await pumpApp(tester, repo: repo);
    await openTrends(tester);
    expect(periodTotal(tester), '\$12.00');
    expect(find.byKey(const Key('chart-week')), findsOneWidget);
    expect(find.text('LAST 7 DAYS'), findsOneWidget);
    await tester.tap(find.byKey(const Key('period-month')));
    await settle(tester);
    expect(periodTotal(tester), '\$22.00');
    expect(find.byKey(const Key('chart-month')), findsOneWidget);
    await tester.tap(find.byKey(const Key('period-year')));
    await settle(tester);
    expect(periodTotal(tester), '\$52.00');
    await tester.tap(find.byKey(const Key('period-all')));
    await settle(tester);
    expect(find.text('ALL TIME'), findsOneWidget);
    expect(find.text('Since your first saving'), findsOneWidget);
    await model.editEntry('d', cents: 4050);
    await settle(tester, 2);
    expect(periodTotal(tester), '\$62.50');
  });

  testWidgets('patterns and insights from data', (tester) async {
    final repo = InMemorySavingsRepository.withGoal('Smoking', [
      for (var i = 0; i < 6; i++) rec('w$i', 500, i, 19),
      rec('p', 1000, 9, 19),
    ])..reminder = 'never';
    await pumpApp(tester, repo: repo);
    await openTrends(tester);
    await tester.scrollUntilVisible(
      find.byKey(const Key('craving-time')),
      300,
      scrollable: find.byType(Scrollable).last,
    );
    expect(
      find.text('Most common craving time: in the evening (4–8 pm).'),
      findsOneWidget,
    );
    await tester.scrollUntilVisible(
      find.textContaining('more than the previous week'),
      300,
      scrollable: find.byType(Scrollable).last,
    );
    expect(
      find.text('You saved 200% more than the previous week'),
      findsOneWidget,
    );
  });

  testWidgets('All goals combines every goal', (tester) async {
    final repo = InMemorySavingsRepository.withGoal('Smoking', [
      rec('a', 500, 0, 19),
    ])..reminder = 'never';
    final model = await pumpApp(tester, repo: repo);
    await model.addGoal('Vaping');
    await model.addSavings(3);
    await openTrends(tester);
    expect(periodTotal(tester), '\$3.00');
    await tester.tap(find.byKey(const Key('scope-all')));
    await settle(tester);
    expect(periodTotal(tester), '\$8.00');
    expect(find.text('All goals'), findsWidgets);
  });
}
