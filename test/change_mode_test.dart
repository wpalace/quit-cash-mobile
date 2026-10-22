import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:quit_cash_mobile/data/repositories/in_memory_savings_repository.dart';
import 'package:quit_cash_mobile/domain/models/progress.dart';
import 'package:quit_cash_mobile/ui/core/themes/denominations.dart';
import 'package:quit_cash_mobile/ui/core/view_models/savings_view_model.dart';
import 'package:quit_cash_mobile/ui/core/widgets/change_coin_painter.dart';
import 'package:quit_cash_mobile/ui/core/widgets/coin_painter.dart';
import 'package:quit_cash_mobile/ui/history/history_screen.dart';

import 'app_widget_test.dart' show pumpApp;

Future<void> settle(WidgetTester tester, [int frames = 8]) async {
  for (var i = 0; i < frames; i++) {
    await tester.pump(const Duration(milliseconds: 100));
  }
}

InMemorySavingsRepository repo() =>
    InMemorySavingsRepository.withGoal('Smoking')..reminder = 'never';

void main() {
  group('change coins', () {
    test('values, labels, ids and distinct looks', () {
      expect(changeDenominations.map((d) => d.cents), [1, 5, 10, 25]);
      expect(changeDenominations.map((d) => d.label), [
        '1¢',
        '5¢',
        '10¢',
        '25¢',
      ]);
      expect(changeDenominations.map((d) => d.id), ['c1', 'c5', 'c10', 'c25']);
      expect(changeDenominations.every((d) => d.isChange && !d.isGem), isTrue);
      expect(denominations.any((d) => d.isChange), isFalse);
      expect(changeDenominations.map((d) => d.shape).toSet(), hasLength(4));
      expect(changeDenominations.every((d) => d.scale < 1), isTrue);
      // The penny is redder and darker than the $1 copper.
      final penny = HSVColor.fromColor(Metals.penny.base);
      final copper = HSVColor.fromColor(Metals.copper.base);
      expect(penny.hue, lessThan(copper.hue));
      expect(penny.value, lessThan(copper.value));
      // Two-tone quarter: brass center.
      expect(changeDenominations.last.inner, Metals.brass);
      expect(denominationFor(5).label, r'$5');
    });

    test('painters draw at many angles', () {
      for (final d in changeDenominations) {
        expect(painterFor(d, angle: 0), isA<ChangeCoinPainter>());
        for (var a = 0.0; a < 6.3; a += 0.35) {
          final rec = ui.PictureRecorder();
          painterFor(
            d,
            angle: a,
            glint: a / 6.3,
          ).paint(Canvas(rec), const Size.square(80));
          rec.endRecording().dispose();
        }
      }
    });

    test('history mini coin picks change coins under \$1', () {
      expect(coinFor(3).cents, 1);
      expect(coinFor(30).cents, 25);
      expect(coinFor(150).cents, 100);
    });
  });

  group('banking cents', () {
    test('exact integer cents; joins the dollar cluster; levels', () async {
      final r = repo();
      final m = SavingsViewModel(
        repository: r,
        clock: () => DateTime(2026, 10, 21, 19),
      );
      await Future<void>.delayed(Duration.zero);
      for (var i = 0; i < 3; i++) {
        await m.addCents(25);
      }
      final c = await m.addCents(25);
      expect(c?.newLevel, 1); // exactly $1.00
      expect(c?.badges.map((b) => b.id), ['first']);
      await m.addCents(10);
      await m.addCents(5);
      await m.addCents(1);
      await m.addSavings(5);
      expect(m.entries.single.cents, 616);
      expect(m.progress.totalCents, 616);
      expect(r.entries['g1']?.single.cents, 616);
      // No float drift over many pennies.
      for (var i = 0; i < 99; i++) {
        await m.addCents(1);
      }
      expect(m.progress.totalCents, 715);
      expect(Progress.levelForCents(1999), 1);
      expect(Progress.levelForCents(2000), 2);
      expect(() => m.addCents(0), throwsArgumentError);
    });
  });

  group('mode', () {
    test('off by default; mode forced to dollars when off; saved', () async {
      final r = repo();
      final m = SavingsViewModel(repository: r);
      await Future<void>.delayed(Duration.zero);
      expect(m.changeEnabled, isFalse);
      expect(m.inChangeMode, isFalse);
      await m.setChangeMode(true);
      expect(m.inChangeMode, isFalse); // toggle still off
      await m.setChangeEnabled(true);
      expect(m.inChangeMode, isTrue);
      expect(m.pickerDenominations, changeDenominations);
      expect(m.denominationForPick(30).cents, 25);
      final again = SavingsViewModel(repository: r);
      await Future<void>.delayed(Duration.zero);
      expect(again.inChangeMode, isTrue);
      await again.setChangeEnabled(false);
      expect(again.inChangeMode, isFalse);
      expect(again.pickerDenominations.first.cents, 100);
      expect(r.flags, containsPair('change', false));
      expect(r.flags, containsPair('changeMode', true));
    });
  });

  testWidgets('Bank toggle hidden when off, switches modes when on', (
    tester,
  ) async {
    final r = repo();
    final model = await pumpApp(tester, repo: r);
    expect(find.byKey(const Key('mode-toggle')), findsNothing);
    expect(find.byKey(const Key('amount-c25')), findsNothing);
    await tester.tap(find.byKey(const Key('settings')));
    await settle(tester);
    await tester.ensureVisible(find.byKey(const Key('toggle-change')));
    await settle(tester, 3);
    await tester.tap(find.byKey(const Key('toggle-change')));
    await tester.pump();
    expect(model.changeEnabled, isTrue);
    await tester.pageBack();
    await settle(tester, 10);
    await tester.tap(find.byKey(const Key('mode-toggle')));
    await tester.pump();
    for (final c in ['c1', 'c5', 'c10', 'c25']) {
      expect(find.byKey(Key('amount-$c')), findsOneWidget);
    }
    expect(find.byKey(const Key('amount-5')), findsNothing);
    expect(find.text('TAP TO BANK 25¢'), findsOneWidget);
    await tester.tap(find.byKey(const Key('amount-c10')));
    await tester.pump();
    await tester.tap(find.byKey(const Key('hero-coin')));
    await settle(tester, 20);
    expect(model.progress.totalCents, 10);
    final hud = tester.widget<Text>(
      find.descendant(
        of: find.byKey(const Key('hud-total')),
        matching: find.byType(Text),
      ),
    );
    expect(hud.data, r'$0.10');
    expect(r.flags['changeMode'], isTrue);
    // Back to dollars; the dollar pick is kept.
    await tester.tap(find.byKey(const Key('mode-toggle')));
    await tester.pump();
    expect(find.byKey(const Key('amount-5')), findsOneWidget);
    expect(find.text(r'TAP TO BANK $5'), findsOneWidget);
    expect(model.inChangeMode, isFalse);
  });
}
