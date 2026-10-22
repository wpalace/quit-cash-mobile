import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:quit_cash_mobile/data/repositories/in_memory_savings_repository.dart';
import 'package:quit_cash_mobile/domain/models/save_entry.dart';

import 'app_widget_test.dart' show pumpApp;

SaveEntry dollars(int d) =>
    SaveEntry(kind: EntryKind.save, cents: d * 100, at: DateTime(2026, 10, 1));

Future<void> settle(WidgetTester tester, [int frames = 8]) async {
  for (var i = 0; i < frames; i++) {
    await tester.pump(const Duration(milliseconds: 100));
  }
}

InMemorySavingsRepository seeded() =>
    InMemorySavingsRepository.withGoal('Smoking', [dollars(20)])
      ..reminder = 'daily';

void main() {
  testWidgets('Goals tab adds a goal with the habit picker', (tester) async {
    final model = await pumpApp(tester, repo: seeded());
    await tester.tap(find.byKey(const Key('tab-goals')));
    await settle(tester);
    expect(find.text('ACTIVE'), findsOneWidget);
    await tester.tap(find.byKey(const Key('add-goal')));
    await settle(tester);
    await tester.tap(find.byKey(const Key('habit-Fancy coffee')));
    await tester.enterText(find.byKey(const Key('goal-label')), 'Lattes');
    await tester.pump();
    await tester.tap(find.byKey(const Key('add-goal-confirm')));
    await settle(tester);
    expect(model.goals, hasLength(2));
    expect(model.activeGoal?.title, 'Lattes');
    expect(model.progress.total, 0);
    expect(find.text('Lattes'), findsOneWidget);
    expect(find.text('ACTIVE'), findsOneWidget);
  });

  testWidgets('tapping a goal on the Goals tab switches to it', (tester) async {
    final repo = seeded();
    final model = await pumpApp(tester, repo: repo);
    await model.addGoal('Vaping');
    await tester.tap(find.byKey(const Key('tab-goals')));
    await settle(tester);
    await tester.tap(find.byKey(const Key('goal-g1')));
    await settle(tester, 2);
    expect(model.activeGoal?.id, 'g1');
    expect(repo.active, 'g1');
  });

  testWidgets('Bank quick switcher sheet switches goals', (tester) async {
    final model = await pumpApp(tester, repo: seeded());
    final vaping = await model.addGoal('Vaping');
    await tester.pump();
    expect(find.textContaining('by skipping vaping'), findsOneWidget);
    await tester.tap(find.byKey(const Key('goal-switcher')));
    await settle(tester);
    expect(find.byKey(const Key('goal-switcher-sheet')), findsOneWidget);
    await tester.tap(find.byKey(const Key('goal-g1')));
    await settle(tester);
    expect(model.activeGoal?.id, 'g1');
    expect(find.byKey(const Key('goal-switcher-sheet')), findsNothing);
    expect(find.textContaining('by skipping smoking'), findsOneWidget);
    expect(find.text('\$20.00'), findsNWidgets(2));
    expect(model.goals.last, vaping);
  });

  testWidgets('delete asks first; deleting the active goal switches', (
    tester,
  ) async {
    final model = await pumpApp(tester, repo: seeded());
    final vaping = await model.addGoal('Vaping');
    await tester.tap(find.byKey(const Key('tab-goals')));
    await settle(tester);
    await tester.tap(find.byKey(Key('delete-${vaping.id}')));
    await settle(tester);
    expect(find.text('Delete "Vaping"?'), findsOneWidget);
    await tester.tap(find.text('Cancel'));
    await settle(tester);
    expect(model.goals, hasLength(2));
    await tester.tap(find.byKey(Key('delete-${vaping.id}')));
    await settle(tester);
    await tester.tap(find.byKey(const Key('confirm-delete')));
    await settle(tester);
    expect(model.goals.map((g) => g.id), ['g1']);
    expect(model.activeGoal?.id, 'g1');
  });

  testWidgets('deleting the last goal goes back to onboarding', (tester) async {
    final repo = seeded()..flags['show100'] = true;
    final model = await pumpApp(tester, repo: repo);
    await tester.tap(find.byKey(const Key('tab-goals')));
    await settle(tester);
    await tester.tap(find.byKey(const Key('delete-g1')));
    await settle(tester);
    expect(find.textContaining('only goal'), findsOneWidget);
    await tester.tap(find.byKey(const Key('confirm-delete')));
    await settle(tester);
    expect(model.goals, isEmpty);
    expect(find.text('What are you quitting?'), findsOneWidget);
    // Global settings survive; the reminder choice is preselected.
    expect(model.reminder?.name, 'daily');
    expect(model.showHundred, isTrue);
    await tester.tap(find.byKey(const Key('habit-Gambling')));
    await tester.pump();
    await tester.ensureVisible(find.byKey(const Key('start')));
    await tester.tap(find.byKey(const Key('start')));
    await settle(tester);
    expect(model.habit, 'Gambling');
    expect(model.progress.total, 0);
  });

  testWidgets('Settings reset names the goal and resets only it', (
    tester,
  ) async {
    final repo = seeded();
    final model = await pumpApp(tester, repo: repo);
    await model.addGoal('Vaping');
    await model.addSavings(5);
    await tester.tap(find.byKey(const Key('settings')));
    await settle(tester);
    await tester.ensureVisible(find.byKey(const Key('reset')));
    await settle(tester, 3);
    expect(find.text('Reset "Vaping" progress'), findsOneWidget);
    await tester.tap(find.byKey(const Key('reset')));
    await settle(tester);
    expect(find.textContaining('of "Vaping" only'), findsOneWidget);
    await tester.tap(find.text('Reset goal'));
    await settle(tester);
    expect(model.progress.total, 0);
    expect(model.progressFor('g1').total, 20);
    expect(repo.entries['g1'], hasLength(1));
  });
}
