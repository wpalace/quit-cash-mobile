import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:quit_cash_mobile/data/repositories/in_memory_savings_repository.dart';
import 'package:quit_cash_mobile/domain/models/reminder_plan.dart';
import 'package:quit_cash_mobile/ui/app/quit_cash_app.dart';
import 'package:quit_cash_mobile/ui/core/view_models/savings_view_model.dart';

Future<SavingsViewModel> pumpApp(
  WidgetTester tester, {
  InMemorySavingsRepository? repo,
}) async {
  tester.view.devicePixelRatio = 1;
  tester.view.physicalSize = const Size(430, 932);
  addTearDown(tester.view.reset);
  final model = SavingsViewModel(
    repository: repo ?? InMemorySavingsRepository(),
  );
  await tester.pumpWidget(
    ChangeNotifierProvider.value(value: model, child: const QuitCashApp()),
  );
  await tester.pump();
  return model;
}

void main() {
  testWidgets('onboarding can choose Never', (tester) async {
    final model = await pumpApp(tester);
    await tester.tap(find.textContaining('Takeout'));
    await tester.ensureVisible(find.byKey(const Key('reminder-never')));
    await tester.tap(find.byKey(const Key('reminder-never')));
    await tester.pump();
    await tester.ensureVisible(find.byKey(const Key('start')));
    await tester.tap(find.byKey(const Key('start')));
    await tester.pump(const Duration(milliseconds: 100));
    expect(model.reminder, ReminderFrequency.never);
  });

  testWidgets('existing user gets a one-time reminder prompt', (tester) async {
    final repo = InMemorySavingsRepository()..habit = 'Smoking';
    final model = await pumpApp(tester, repo: repo);
    await tester.pump(const Duration(milliseconds: 500));
    expect(find.text('⏰ Want a nudge?'), findsOneWidget);
    await tester.tap(find.byKey(const Key('reminder-weekly')).last);
    for (var i = 0; i < 10; i++) {
      await tester.pump(const Duration(milliseconds: 100));
    }
    expect(model.reminder, ReminderFrequency.weekly);
    expect(repo.reminder, 'weekly');
    expect(find.text('⏰ Want a nudge?'), findsNothing);
  });

  testWidgets('onboarding picks a habit and opens the bank', (tester) async {
    final model = await pumpApp(tester);
    expect(find.text('What are you quitting?'), findsOneWidget);
    await tester.tap(find.textContaining('Vaping'));
    await tester.pump();
    await tester.ensureVisible(find.byKey(const Key('start')));
    await tester.tap(find.byKey(const Key('start')));
    await tester.pump(const Duration(milliseconds: 100));
    expect(model.habit, 'Vaping');
    expect(model.reminder, ReminderFrequency.daily);
    expect(find.text('TOTAL SAVED'), findsOneWidget);
    expect(find.text('\$0.00'), findsNWidgets(2)); // header + top bar
    expect(find.byKey(const Key('daily-bonus')), findsNothing);
  });

  testWidgets('tapping the coin banks money, flies coins, celebrates', (
    tester,
  ) async {
    final repo = InMemorySavingsRepository()
      ..habit = 'Smoking'
      ..reminder = 'daily';
    final model = await pumpApp(tester, repo: repo);
    await tester.tap(find.byKey(const Key('amount-20')));
    await tester.pump();
    await tester.tap(find.byKey(const Key('hero-coin')));
    await tester.pump(const Duration(milliseconds: 50));
    expect(model.progress.total, 20);
    for (var i = 0; i < 20; i++) {
      await tester.pump(const Duration(milliseconds: 100));
    }
    expect(
      tester
          .widget<Text>(
            find.descendant(
              of: find.byKey(const Key('hud-total')),
              matching: find.byType(Text),
            ),
          )
          .data,
      '\$20.00',
    );
    expect(find.text('LEVEL UP!'), findsOneWidget);
    await tester.tap(find.text('AWESOME'));
    for (var i = 0; i < 6; i++) {
      await tester.pump(const Duration(milliseconds: 100));
    }
    expect(find.text('LEVEL UP!'), findsNothing);
  });

  testWidgets('default picker hides \$50 and \$100', (tester) async {
    final repo = InMemorySavingsRepository()
      ..habit = 'Smoking'
      ..reminder = 'never';
    await pumpApp(tester, repo: repo);
    for (final d in [1, 5, 10, 20]) {
      expect(find.byKey(Key('amount-$d')), findsOneWidget);
    }
    expect(find.byKey(const Key('amount-50')), findsNothing);
    expect(find.byKey(const Key('amount-100')), findsNothing);
  });

  testWidgets('all seven denominations when all enabled', (tester) async {
    final repo = InMemorySavingsRepository()
      ..habit = 'Smoking'
      ..reminder = 'never';
    repo.flags.addAll({'show50': true, 'show100': true, 'show500': true});
    await pumpApp(tester, repo: repo);
    for (final d in [1, 5, 10, 20, 50, 100, 500]) {
      expect(find.byKey(Key('amount-$d')), findsOneWidget);
    }
  });

  testWidgets('ruby banks \$100 and flies to the counter', (tester) async {
    final repo = InMemorySavingsRepository()
      ..habit = 'Smoking'
      ..reminder = 'never';
    repo.flags['show100'] = true;
    final model = await pumpApp(tester, repo: repo);
    await tester.tap(find.byKey(const Key('amount-100')));
    await tester.pump();
    expect(find.text('TAP TO BANK \$100'), findsOneWidget);
    await tester.tap(find.byKey(const Key('hero-coin')));
    for (var i = 0; i < 20; i++) {
      await tester.pump(const Duration(milliseconds: 100));
    }
    expect(model.progress.total, 100);
  });

  testWidgets('diamond is off by default and banks \$500', (tester) async {
    final repo = InMemorySavingsRepository()
      ..habit = 'Smoking'
      ..reminder = 'never';
    final model = await pumpApp(tester, repo: repo);
    expect(find.byKey(const Key('amount-500')), findsNothing);
    await tester.tap(find.byKey(const Key('settings')));
    for (var i = 0; i < 5; i++) {
      await tester.pump(const Duration(milliseconds: 100));
    }
    await tester.ensureVisible(find.byKey(const Key('toggle-500')));
    await tester.tap(find.byKey(const Key('toggle-500')));
    await tester.pump();
    expect(model.showFiveHundred, isTrue);
    expect(repo.flags['show500'], isTrue);
    await tester.pageBack();
    for (var i = 0; i < 5; i++) {
      await tester.pump(const Duration(milliseconds: 100));
    }
    for (var i = 0; i < 10; i++) {
      await tester.pump(const Duration(milliseconds: 100));
    }
    await tester.tap(find.byKey(const Key('amount-500')));
    await tester.pump();
    expect(find.text('TAP TO BANK \$500'), findsOneWidget);
    await tester.tap(find.byKey(const Key('hero-coin')));
    for (var i = 0; i < 20; i++) {
      await tester.pump(const Duration(milliseconds: 100));
    }
    expect(model.progress.total, 500);
  });

  testWidgets('settings toggles hide \$50 and \$100 from the picker', (
    tester,
  ) async {
    final repo = InMemorySavingsRepository()
      ..habit = 'Smoking'
      ..reminder = 'never';
    repo.flags.addAll({'show50': true, 'show100': true});
    final model = await pumpApp(tester, repo: repo);
    await tester.tap(find.byKey(const Key('amount-50')));
    await tester.pump();
    await tester.tap(find.byKey(const Key('settings')));
    for (var i = 0; i < 5; i++) {
      await tester.pump(const Duration(milliseconds: 100));
    }
    expect(find.text('Settings'), findsOneWidget);
    expect(find.text('⏰ Reminders (7 pm)'), findsOneWidget);
    await tester.tap(find.byKey(const Key('toggle-50')));
    await tester.tap(find.byKey(const Key('toggle-100')));
    await tester.pump();
    expect(model.showFifty, isFalse);
    expect(model.showHundred, isFalse);
    expect(repo.flags, {'show50': false, 'show100': false});
    await tester.pageBack();
    for (var i = 0; i < 5; i++) {
      await tester.pump(const Duration(milliseconds: 100));
    }
    expect(find.byKey(const Key('amount-50')), findsNothing);
    expect(find.byKey(const Key('amount-100')), findsNothing);
    expect(find.byKey(const Key('amount-20')), findsOneWidget);
    // Selection falls back to the largest visible coin.
    expect(find.text('TAP TO BANK \$20'), findsOneWidget);
  });
}
