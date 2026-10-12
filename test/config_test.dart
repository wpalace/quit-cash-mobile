// test/config_test.dart
//
// Tests the compile-time build-flag seam ([AppConfig]) in isolation.
//
// These tests deliberately do NOT import the app entrypoint (lib/main.dart),
// because the top-level `CONFIG` const is only defined under
// `flutter build`/`run --dart-define CONFIG=...` and is unavailable to
// `flutter test`. [AppConfig.fromDefine] is a pure function, which is exactly
// why the seam is split this way (D-10 tree-shakeable local/cloud).
//
// Phase 3 (QUA-01/QUA-02) adds the real UI / GUI E2E tests on top of this.

import 'package:flutter_test/flutter_test.dart';
import 'package:quit_cash_mobile/services/config.dart';

void main() {
  group('AppConfig.fromDefine (build-flag seam)', () {
    test('empty string defaults to local (D-09)', () {
      final config = AppConfig.fromDefine('');
      expect(config.isLocal, isTrue);
      expect(config.isCloud, isFalse);
    });

    test('"local" -> local', () {
      final config = AppConfig.fromDefine('local');
      expect(config.isLocal, isTrue);
      expect(config.isCloud, isFalse);
    });

    test('"cloud" -> cloud', () {
      final config = AppConfig.fromDefine('cloud');
      expect(config.isLocal, isFalse);
      expect(config.isCloud, isTrue);
    });

    test('case-insensitive keywords still resolve', () {
      expect(AppConfig.fromDefine('LOCAL').isLocal, isTrue);
      expect(AppConfig.fromDefine('CLOUD').isCloud, isTrue);
    });

    test('unknown / typoed value -> fail-fast (D-10), never falls to local',
        () {
      for (final value in ['cloud2', 'typo', 'cloud ', 'local 2']) {
        bool threw = false;
        try {
          AppConfig.fromDefine(value);
        } on ArgumentError catch (_) {
          threw = true;
        }
        expect(threw, isTrue, reason: 'CONFIG="$value" must throw');
      }
    });
  });
}
