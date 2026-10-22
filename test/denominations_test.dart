import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:quit_cash_mobile/data/prefs_savings_repository.dart';
import 'package:quit_cash_mobile/data/savings_repository.dart';
import 'package:quit_cash_mobile/state/savings_model.dart';
import 'package:quit_cash_mobile/ui/denominations.dart';
import 'package:quit_cash_mobile/ui/widgets/coin_painter.dart';
import 'package:shared_preferences_platform_interface/in_memory_shared_preferences_async.dart';
import 'package:shared_preferences_platform_interface/shared_preferences_async_platform_interface.dart';

void main() {
  group('denominations', () {
    test('six denominations in ascending order', () {
      expect(denominations.map((d) => d.dollars), [1, 5, 10, 20, 50, 100]);
      expect(denominations.map((d) => d.label).last, '\$100');
    });

    test('each denomination has its own color', () {
      final bases = denominations.map((d) => d.metal.base).toSet();
      expect(bases, hasLength(denominations.length));
      expect(denominationFor(1).metal, Metals.copper);
      expect(denominationFor(5).metal, Metals.silver);
      expect(denominationFor(10).metal, Metals.sapphire);
      expect(denominationFor(20).metal, Metals.emerald);
      expect(denominationFor(50).metal, Metals.gold);
      expect(denominationFor(100).metal, Metals.ruby);
    });

    test('hue families match the brief', () {
      double hue(Color c) => HSVColor.fromColor(c).hue;
      expect(hue(Metals.emerald.base), inInclusiveRange(120, 160)); // green
      expect(hue(Metals.sapphire.base), inInclusiveRange(200, 240)); // blue
      expect(hue(Metals.gold.base), inInclusiveRange(40, 55)); // gold
      expect(hue(Metals.copper.base), inInclusiveRange(15, 35)); // copper
      final ruby = hue(Metals.ruby.base);
      expect(ruby > 330 || ruby < 10, isTrue); // red
      expect(HSVColor.fromColor(Metals.silver.base).saturation, lessThan(0.15));
    });

    test('outline is the darkest stop for every metal', () {
      for (final d in denominations) {
        final m = d.metal;
        expect(
          m.outline.computeLuminance(),
          lessThan(m.edge.computeLuminance()),
        );
        expect(
          m.light.computeLuminance(),
          greaterThan(m.base.computeLuminance()),
        );
      }
    });

    test('only the \$100 is a gem', () {
      expect(denominations.where((d) => d.isGem).map((d) => d.dollars), [100]);
      expect(painterFor(denominationFor(100), angle: 0), isA<GemPainter>());
      expect(painterFor(denominationFor(20), angle: 0), isA<CoinPainter>());
    });

    test('every painter renders at many angles', () {
      for (final d in denominations) {
        for (var a = 0.0; a < 6.3; a += 0.7) {
          final rec = ui.PictureRecorder();
          painterFor(
            d,
            angle: a,
            glint: a / 6.3,
          ).paint(Canvas(rec), const Size.square(100));
          rec.endRecording().dispose();
        }
      }
    });
  });

  group('picker filtering', () {
    List<int> vis(bool f, bool h) => [
      for (final d in visibleDenominations(showFifty: f, showHundred: h))
        d.dollars,
    ];

    test('both on', () => expect(vis(true, true), [1, 5, 10, 20, 50, 100]));
    test('hide 50', () => expect(vis(false, true), [1, 5, 10, 20, 100]));
    test('hide 100', () => expect(vis(true, false), [1, 5, 10, 20, 50]));
    test('hide both', () => expect(vis(false, false), [1, 5, 10, 20]));
  });

  group('settings persistence', () {
    setUp(() {
      SharedPreferencesAsyncPlatform.instance =
          InMemorySharedPreferencesAsync.empty();
    });

    test('prefs repository stores flags', () async {
      final repo = PrefsSavingsRepository();
      expect(await repo.loadFlag('show50'), isNull);
      await repo.saveFlag('show50', false);
      expect(await PrefsSavingsRepository().loadFlag('show50'), isFalse);
    });

    test('model defaults both on and reloads saved toggles', () async {
      final repo = PrefsSavingsRepository();
      final m1 = SavingsModel(repository: repo);
      await Future<void>.delayed(Duration.zero);
      expect(m1.showFifty, isTrue);
      expect(m1.showHundred, isTrue);
      await m1.setShowFifty(false);
      await m1.setShowHundred(false);

      final m2 = SavingsModel(repository: PrefsSavingsRepository());
      await Future<void>.delayed(const Duration(milliseconds: 10));
      expect(m2.showFifty, isFalse);
      expect(m2.showHundred, isFalse);
    });

    test('hiding a denomination keeps history', () async {
      final repo = InMemorySavingsRepository();
      final m = SavingsModel(repository: repo);
      await Future<void>.delayed(Duration.zero);
      await m.addSavings(100);
      await m.setShowHundred(false);
      expect(m.progress.total, 100);
      expect(await repo.loadAll(), hasLength(1));
    });
  });
}
