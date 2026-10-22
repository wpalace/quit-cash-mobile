import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:quit_cash_mobile/data/repositories/in_memory_savings_repository.dart';
import 'package:quit_cash_mobile/domain/models/save_entry.dart';
import 'package:quit_cash_mobile/ui/core/view_models/savings_view_model.dart';
import 'package:quit_cash_mobile/ui/trophies/trophies_screen.dart';

void main() {
  testWidgets('shows totals, unlocked badges and the next goal', (
    tester,
  ) async {
    tester.view.devicePixelRatio = 1;
    tester.view.physicalSize = const Size(430, 1400);
    addTearDown(tester.view.reset);
    final repo = InMemorySavingsRepository.withGoal('Smoking', [
      SaveEntry(kind: EntryKind.save, cents: 2000, at: DateTime.now()),
    ]);
    final model = SavingsViewModel(repository: repo);
    await tester.pumpWidget(
      ChangeNotifierProvider.value(
        value: model,
        child: const MaterialApp(home: Scaffold(body: TrophiesScreen())),
      ),
    );
    await tester.pump();
    expect(find.text('Trophy Room'), findsOneWidget);
    expect(find.text('\$20.00'), findsOneWidget);
    expect(find.text('2/10'), findsOneWidget); // First Coin + Ten Spot
    expect(find.textContaining('Next up:'), findsOneWidget);
  });
}
