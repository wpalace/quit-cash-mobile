import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:quit_cash_mobile/data/savings_repository.dart';
import 'package:quit_cash_mobile/reminders/reminder_plan.dart';
import 'package:quit_cash_mobile/state/savings_model.dart';
import 'package:quit_cash_mobile/ui/app.dart';

Future<SavingsModel> pumpApp(
  WidgetTester tester, {
  InMemorySavingsRepository? repo,
}) async {
  tester.view.devicePixelRatio = 1;
  tester.view.physicalSize = const Size(430, 932);
  addTearDown(tester.view.reset);
  final model = SavingsModel(repository: repo ?? InMemorySavingsRepository());
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
    expect(find.text('\$0.00'), findsOneWidget);
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
    expect(find.text('\$20.00'), findsOneWidget);
    expect(find.text('LEVEL UP!'), findsOneWidget);
    await tester.tap(find.text('AWESOME'));
    for (var i = 0; i < 6; i++) {
      await tester.pump(const Duration(milliseconds: 100));
    }
    expect(find.text('LEVEL UP!'), findsNothing);
  });

  testWidgets('daily bonus can be claimed once', (tester) async {
    final repo = InMemorySavingsRepository()
      ..habit = 'Smoking'
      ..reminder = 'daily';
    final model = await pumpApp(tester, repo: repo);
    await tester.tap(find.byKey(const Key('daily-bonus')));
    await tester.pump(const Duration(milliseconds: 600));
    expect(model.progress.checkedInToday, isTrue);
    expect(find.text('DAILY BONUS!'), findsOneWidget);
  });
}
