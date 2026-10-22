import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:quit_cash_mobile/data/repositories/in_memory_savings_repository.dart';
import 'package:quit_cash_mobile/data/repositories/prefs_savings_repository.dart';
import 'package:quit_cash_mobile/ui/core/themes/denominations.dart';
import 'package:quit_cash_mobile/ui/core/view_models/savings_view_model.dart';
import 'package:quit_cash_mobile/ui/core/widgets/coin_painter.dart';
import 'package:quit_cash_mobile/ui/core/widgets/diamond_painter.dart';
import 'package:shared_preferences_platform_interface/in_memory_shared_preferences_async.dart';
import 'package:shared_preferences_platform_interface/shared_preferences_async_platform_interface.dart';

void main() {
  group('denominations', () {
    test('seven denominations in ascending order', () {
      expect(denominations.map((d) => d.dollars), [1, 5, 10, 20, 50, 100, 500]);
      expect(denominations.map((d) => d.label).last, '\$500');
    });

    test('each denomination has its own color', () {
      final bases = denominations.map((d) => d.metal.base).toSet();
      expect(bases, hasLength(denominations.length));
      expect(denominationFor(1).metal, Metals.copper);
      expect(denominationFor(5).metal, Metals.silver);
      expect(denominationFor(10).metal, Metals.gold);
      expect(denominationFor(20).metal, Metals.emerald);
      expect(denominationFor(50).metal, Metals.sapphire);
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

    test('the \$100 ruby and \$500 diamond are the only gems', () {
      expect(denominations.where((d) => d.isGem).map((d) => d.dollars), [
        100,
        500,
      ]);
      expect(painterFor(denominationFor(100), angle: 0), isA<GemPainter>());
      expect(painterFor(denominationFor(500), angle: 0), isA<DiamondPainter>());
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
    List<int> vis(bool f, bool h, [bool d5 = false]) => [
      for (final d in visibleDenominations(
        showFifty: f,
        showHundred: h,
        showFiveHundred: d5,
      ))
        d.dollars,
    ];

    test('all on', () {
      expect(vis(true, true, true), [1, 5, 10, 20, 50, 100, 500]);
    });
    test('hide 500', () => expect(vis(true, true), [1, 5, 10, 20, 50, 100]));
    test('hide 50', () => expect(vis(false, true), [1, 5, 10, 20, 100]));
    test('hide 100', () => expect(vis(true, false), [1, 5, 10, 20, 50]));
    test('hide all', () => expect(vis(false, false), [1, 5, 10, 20]));
    test('only 500', () {
      expect(vis(false, false, true), [1, 5, 10, 20, 500]);
    });
  });

  group('settings persistence', () {
    setUp(() {
      SharedPreferencesAsyncPlatform.instance =
          InMemorySharedPreferencesAsync.empty();
    });

    test('prefs repository stores flags', () async {
      final repo = PrefsSavingsRepository();
      expect((await repo.loadFlag('show50')).valueOrNull, isNull);
      await repo.saveFlag('show50', false);
      expect(
        (await PrefsSavingsRepository().loadFlag('show50')).valueOrNull,
        isFalse,
      );
    });

    test('model defaults all off and reloads saved toggles', () async {
      final repo = PrefsSavingsRepository();
      final m1 = SavingsViewModel(repository: repo);
      await Future<void>.delayed(Duration.zero);
      expect(m1.showFifty, isFalse);
      expect(m1.showHundred, isFalse);
      expect(m1.showFiveHundred, isFalse);
      await m1.setShowFifty(true);
      await m1.setShowHundred(true);
      await m1.setShowFiveHundred(true);

      final m2 = SavingsViewModel(repository: PrefsSavingsRepository());
      await Future<void>.delayed(const Duration(milliseconds: 10));
      expect(m2.showFifty, isTrue);
      expect(m2.showHundred, isTrue);
      expect(m2.showFiveHundred, isTrue);
    });

    test('hiding a denomination keeps history', () async {
      final repo = InMemorySavingsRepository.withGoal('Smoking');
      final m = SavingsViewModel(repository: repo);
      await Future<void>.delayed(Duration.zero);
      await m.setShowHundred(true);
      await m.addSavings(100);
      await m.setShowHundred(false);
      expect(m.progress.total, 100);
      expect((await repo.loadAll('g1')).valueOrNull, hasLength(1));
    });
  });

  test('diamond is icy white-blue', () {
    final hsv = HSVColor.fromColor(Metals.diamond.base);
    expect(hsv.hue, inInclusiveRange(180, 220));
    expect(hsv.saturation, lessThan(0.3));
    expect(hsv.value, greaterThan(0.9));
  });
}
