import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:provider/provider.dart';
import 'package:quit_cash_mobile/data/repositories/in_memory_savings_repository.dart';
import 'package:quit_cash_mobile/ui/app/quit_cash_app.dart';
import 'package:quit_cash_mobile/ui/core/view_models/savings_view_model.dart';

/// End-to-end: onboarding -> bank a coin -> see the total -> open Settings.
void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('first run: onboard, bank \$20, open settings', (tester) async {
    final model = SavingsViewModel(repository: InMemorySavingsRepository());
    await tester.pumpWidget(
      ChangeNotifierProvider.value(value: model, child: const QuitCashApp()),
    );
    await tester.pump(const Duration(milliseconds: 300));

    await tester.tap(find.textContaining('Vaping'));
    await tester.pump();
    await tester.ensureVisible(find.byKey(const Key('start')));
    await tester.tap(find.byKey(const Key('start')));
    await tester.pump(const Duration(milliseconds: 500));

    await tester.tap(find.byKey(const Key('amount-20')));
    await tester.pump();
    await tester.tap(find.byKey(const Key('hero-coin')));
    for (var i = 0; i < 25; i++) {
      await tester.pump(const Duration(milliseconds: 100));
    }
    expect(model.progress.total, 20);
    await tester.tap(find.text('AWESOME'));
    for (var i = 0; i < 6; i++) {
      await tester.pump(const Duration(milliseconds: 100));
    }

    await tester.tap(find.byKey(const Key('settings')));
    for (var i = 0; i < 6; i++) {
      await tester.pump(const Duration(milliseconds: 100));
    }
    expect(find.text('Settings'), findsOneWidget);
  });
}
