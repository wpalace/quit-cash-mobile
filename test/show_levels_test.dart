import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:quit_cash_mobile/data/repositories/in_memory_savings_repository.dart';
import 'package:quit_cash_mobile/domain/models/progress.dart';
import 'package:quit_cash_mobile/ui/core/view_models/savings_view_model.dart';

import 'app_widget_test.dart' show pumpApp;
import 'change_mode_test.dart' show settle;

InMemorySavingsRepository repo() =>
    InMemorySavingsRepository.withGoal('Smoking')..reminder = 'never';

void main() {
  group('show levels', () {
    test('on by default, saved, no level-up while off', () async {
      final r = repo();
      final m = SavingsViewModel(repository: r);
      await Future<void>.delayed(Duration.zero);
      expect(m.showLevels, isTrue);
      await m.setShowLevels(false);
      expect(r.flags, containsPair('showLevels', false));
      final cel = await m.addCents(2500);
      expect(cel!.newLevel, isNull);
      expect(m.progress.level, 2); // still derived from dollars

      final again = SavingsViewModel(repository: r);
      await Future<void>.delayed(Duration.zero);
      expect(again.showLevels, isFalse);
      await again.setShowLevels(true);
      expect(again.progress.level, 2);
      final up = await again.addCents(2500);
      expect(up!.newLevel, 3);
    });

    test('off: new goal crossing badges pops nothing; no backlog', () async {
      final r = repo();
      final m = SavingsViewModel(repository: r);
      await Future<void>.delayed(Duration.zero);
      await m.setShowLevels(false);
      final g = await m.addGoal('coffee');
      expect(m.activeGoal?.id, g.id);
      final cel = await m.addCents(10000);
      expect(cel!.isEmpty, isTrue);
      expect(m.progress.unlocked, contains('hundred')); // earned silently
      await m.setShowLevels(true);
      final next = await m.addCents(1);
      expect(next!.isEmpty, isTrue); // no backlog of badges or levels
    });

    test('Two Hundred Club badge is dollar based', () {
      final a = achievements.firstWhere((a) => a.id == 'lvl5');
      expect(a.title, 'Two Hundred Club');
      expect(a.description, r'Save $200 in total');
    });
  });

  testWidgets('Settings toggle hides the level HUD', (tester) async {
    final model = await pumpApp(tester, repo: repo());
    expect(find.byKey(const Key('level-pill')), findsOneWidget);
    expect(find.byKey(const Key('next-level')), findsOneWidget);
    await tester.tap(find.byKey(const Key('settings')));
    await settle(tester);
    await tester.tap(find.byKey(const Key('toggle-levels')));
    await tester.pump();
    expect(model.showLevels, isFalse);
    await tester.pageBack();
    await settle(tester, 10);
    expect(find.byKey(const Key('level-pill')), findsNothing);
    expect(find.byKey(const Key('next-level')), findsNothing);
    expect(find.byKey(const Key('hud-total')), findsOneWidget);
  });
}
