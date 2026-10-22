import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:quit_cash_mobile/data/repositories/in_memory_savings_repository.dart';
import 'package:quit_cash_mobile/domain/models/save_entry.dart';
import 'package:quit_cash_mobile/ui/core/view_models/savings_view_model.dart';

import 'app_widget_test.dart' show pumpApp;

final now = DateTime.now();
SaveEntry rec(String id, int cents, DateTime at) =>
    SaveEntry(id: id, kind: EntryKind.save, cents: cents, at: at);

Future<void> settle(WidgetTester tester, [int frames = 8]) async {
  for (var i = 0; i < frames; i++) {
    await tester.pump(const Duration(milliseconds: 100));
  }
}

Future<SavingsViewModel> openHistory(
  WidgetTester tester,
  InMemorySavingsRepository repo,
) async {
  final model = await pumpApp(tester, repo: repo..reminder = 'never');
  await tester.tap(find.byKey(const Key('open-history')));
  await settle(tester);
  return model;
}

InMemorySavingsRepository seeded() =>
    InMemorySavingsRepository.withGoal('Smoking', [
      rec('old', 2000, now.subtract(const Duration(days: 3))),
      rec('a', 700, DateTime(now.year, now.month, now.day, 0, 5)),
      rec('b', 500, DateTime(now.year, now.month, now.day, 0, 30)),
    ]);

void main() {
  testWidgets('empty state', (tester) async {
    await openHistory(tester, InMemorySavingsRepository.withGoal('Vaping'));
    expect(find.text('History · Vaping'), findsOneWidget);
    expect(find.byKey(const Key('history-empty')), findsOneWidget);
    expect(find.text('No savings yet'), findsOneWidget);
  });

  testWidgets('records newest first, grouped by day', (tester) async {
    await openHistory(tester, seeded());
    expect(find.text('Today'), findsOneWidget);
    final ys = [
      for (final id in ['b', 'a', 'old'])
        tester.getTopLeft(find.byKey(Key('record-$id'))).dy,
    ];
    expect(ys, orderedEquals([...ys]..sort()));
    expect(find.text('\$12.00'), findsOneWidget); // today's day total
    expect(find.textContaining('\$32.00 saved'), findsOneWidget);
  });

  testWidgets('edit to \$8.50; invalid input is rejected', (tester) async {
    final repo = seeded();
    final model = await openHistory(tester, repo);
    await tester.tap(find.byKey(const Key('record-a')));
    await settle(tester);
    expect(find.text('Edit saving'), findsOneWidget);
    await tester.enterText(find.byKey(const Key('edit-amount')), '0');
    await tester.tap(find.byKey(const Key('edit-save')));
    await tester.pump();
    expect(find.textContaining('Enter an amount'), findsOneWidget);
    await tester.enterText(find.byKey(const Key('edit-amount')), '8.50');
    await tester.tap(find.byKey(const Key('edit-save')));
    await settle(tester);
    expect(find.text('Edit saving'), findsNothing);
    expect(model.progress.totalCents, 3350);
    expect(repo.entries['g1']?.firstWhere((e) => e.id == 'a').cents, 850);
    expect(find.text('\$8.50'), findsOneWidget);
  });

  testWidgets('delete asks first, then Undo restores', (tester) async {
    final model = await openHistory(tester, seeded());
    await tester.tap(find.byKey(const Key('record-old')));
    await settle(tester);
    await tester.tap(find.byKey(const Key('edit-delete')));
    await settle(tester);
    expect(find.text('Delete \$20.00?'), findsOneWidget);
    await tester.tap(find.byKey(const Key('confirm-delete-record')));
    await settle(tester);
    expect(model.progress.totalCents, 1200);
    expect(model.progress.level, 1);
    expect(find.byKey(const Key('record-old')), findsNothing);
    expect(find.text('Deleted \$20.00'), findsOneWidget);
    await tester.tap(find.byKey(const Key('undo-delete')));
    await settle(tester);
    expect(model.progress.totalCents, 3200);
    expect(model.progress.level, 2);
    expect(find.byKey(const Key('record-old')), findsOneWidget);
  });

  testWidgets('Settings "Group taps within" defaults to 60s and saves', (
    tester,
  ) async {
    final repo = seeded()..reminder = 'never';
    final model = await pumpApp(tester, repo: repo);
    await tester.tap(find.byKey(const Key('settings')));
    await settle(tester);
    final chip = tester.widget<ChoiceChip>(
      find.byKey(const Key('tap-window-60')),
    );
    expect(chip.selected, isTrue);
    await tester.tap(find.byKey(const Key('tap-window-120')));
    await tester.pump();
    expect(model.tapWindowSeconds, 120);
    expect(repo.numbers[SavingsViewModel.tapWindowKey], 120);
  });
}
