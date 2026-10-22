import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:quit_cash_mobile/data/repositories/in_memory_savings_repository.dart';
import 'package:quit_cash_mobile/data/repositories/prefs_savings_repository.dart';
import 'package:quit_cash_mobile/domain/models/save_entry.dart';
import 'package:quit_cash_mobile/ui/core/view_models/savings_view_model.dart';
import 'package:shared_preferences_platform_interface/in_memory_shared_preferences_async.dart';
import 'package:shared_preferences_platform_interface/shared_preferences_async_platform_interface.dart';

void main() {
  setUp(() {
    SharedPreferencesAsyncPlatform.instance =
        InMemorySharedPreferencesAsync.empty();
  });

  test('prefs repository round-trips entries and habit', () async {
    final repo = PrefsSavingsRepository();
    final at = DateTime(2026, 1, 2, 3, 4);
    await repo.append(SaveEntry(kind: EntryKind.save, cents: 500, at: at));
    await repo.saveHabit('Vaping');

    final again = PrefsSavingsRepository();
    final rows = (await again.loadAll()).valueOrNull ?? const [];
    expect(rows, hasLength(1));
    expect(rows.first.cents, 500);
    expect(rows.first.at, at);
    expect((await again.loadHabit()).valueOrNull, 'Vaping');

    await again.clear();
    expect((await again.loadAll()).valueOrNull, isEmpty);
  });

  test('model reports level-up and new badges once', () async {
    final model = SavingsViewModel(
      repository: InMemorySavingsRepository(),
      clock: () => DateTime(2026, 10, 19),
    );
    await Future<void>.delayed(Duration.zero);
    final first = await model.addSavings(10);
    expect(first?.newLevel, 1);
    expect(first?.badges.map((b) => b.id), containsAll(['first', 'ten']));
    final second = await model.addSavings(1);
    expect(second?.isEmpty, isTrue);
    expect(model.progress.total, 11);
  });

  test(
    'old data with daily check-ins still loads; check-ins are ignored',
    () async {
      final at = DateTime(2026, 1, 2).millisecondsSinceEpoch;
      SharedPreferencesAsyncPlatform.instance =
          InMemorySharedPreferencesAsync.withData({
            PrefsSavingsRepository.storageKey: jsonEncode([
              {'k': 'save', 'c': 500, 't': at},
              {'k': 'checkIn', 'c': 0, 't': at},
              {'k': 'save', 'c': 2000, 't': at},
            ]),
          });
      final repo = PrefsSavingsRepository();
      final rows = (await repo.loadAll()).valueOrNull ?? const [];
      expect(rows.map((r) => r.cents), [500, 2000]);
      final model = SavingsViewModel(repository: repo);
      await Future<void>.delayed(const Duration(milliseconds: 10));
      expect(model.progress.total, 25);
      expect(model.progress.level, 2);
    },
  );

  test('model rejects invalid amounts', () async {
    final model = SavingsViewModel(repository: InMemorySavingsRepository());
    expect(() => model.addSavings(-1), throwsArgumentError);
    expect(() => model.addSavings(double.nan), throwsArgumentError);
  });
}
