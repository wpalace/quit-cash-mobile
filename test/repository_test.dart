import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:quit_cash_mobile/data/repositories/in_memory_savings_repository.dart';
import 'package:quit_cash_mobile/data/repositories/prefs_savings_repository.dart';
import 'package:quit_cash_mobile/domain/models/goal.dart';
import 'package:quit_cash_mobile/domain/models/save_entry.dart';
import 'package:quit_cash_mobile/ui/core/view_models/savings_view_model.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:shared_preferences_platform_interface/in_memory_shared_preferences_async.dart';
import 'package:shared_preferences_platform_interface/shared_preferences_async_platform_interface.dart';

void main() {
  setUp(() {
    SharedPreferencesAsyncPlatform.instance =
        InMemorySharedPreferencesAsync.empty();
  });

  test('prefs repository round-trips goals and per-goal entries', () async {
    final repo = PrefsSavingsRepository();
    final at = DateTime(2026, 1, 2, 3, 4);
    const a = Goal(id: 'a', habit: 'Vaping');
    const b = Goal(id: 'b', habit: 'Drinking', label: 'Weekend beers');
    await repo.saveGoals([a, b]);
    await repo.saveActiveGoal('b');
    await repo.append('a', SaveEntry(kind: EntryKind.save, cents: 500, at: at));
    await repo.append('b', SaveEntry(kind: EntryKind.save, cents: 700, at: at));

    final again = PrefsSavingsRepository();
    expect((await again.loadGoals()).valueOrNull, [a, b]);
    expect((await again.loadActiveGoal()).valueOrNull, 'b');
    final rows = (await again.loadAll('a')).valueOrNull ?? const [];
    expect(rows.map((r) => (r.cents, r.at)), [(500, at)]);
    expect((await again.loadAll('b')).valueOrNull?.map((r) => r.cents), [700]);

    await again.clear('a');
    expect((await again.loadAll('a')).valueOrNull, isEmpty);
    expect((await again.loadAll('b')).valueOrNull, hasLength(1));
  });

  test('model reports level-up and new badges once', () async {
    final model = SavingsViewModel(
      repository: InMemorySavingsRepository.withGoal('Smoking'),
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

  group('migration from single-goal data', () {
    final at = DateTime(2026, 1, 2).millisecondsSinceEpoch;
    final legacyRows = [
      {'k': 'save', 'c': 500, 't': at},
      {'k': 'checkIn', 'c': 0, 't': at},
      {'k': 'save', 'c': 2000, 't': at + 1},
    ];

    void seedLegacy() {
      SharedPreferencesAsyncPlatform.instance =
          InMemorySharedPreferencesAsync.withData({
            PrefsSavingsRepository.legacyHabitKey: 'Fancy coffee',
            PrefsSavingsRepository.legacyEntriesKey: jsonEncode(legacyRows),
            PrefsSavingsRepository.reminderKey: 'weekly',
            PrefsSavingsRepository.flagKey('show100'): true,
          });
    }

    test('becomes one active goal with the same history, losslessly', () async {
      seedLegacy();
      final prefs = SharedPreferencesAsync();
      final repo = PrefsSavingsRepository(prefs: prefs);
      final goals = (await repo.loadGoals()).valueOrNull ?? const [];
      expect(goals, [
        const Goal(
          id: PrefsSavingsRepository.migratedGoalId,
          habit: 'Fancy coffee',
        ),
      ]);
      expect(
        (await repo.loadActiveGoal()).valueOrNull,
        PrefsSavingsRepository.migratedGoalId,
      );
      // The per-tap history is copied byte for byte (legacy rows included).
      const goalId = PrefsSavingsRepository.migratedGoalId;
      expect(
        await prefs.getString(
          PrefsSavingsRepository.legacyGoalEntriesKey(goalId),
        ),
        jsonEncode(legacyRows),
      );
      // First load clusters the taps (1 ms apart, so one record).
      final rows = (await repo.loadAll(goalId)).valueOrNull ?? const [];
      expect(rows.map((r) => (r.cents, r.at.millisecondsSinceEpoch)), [
        (2500, at),
      ]);
      expect(
        await prefs.getString(
          PrefsSavingsRepository.legacyGoalEntriesKey(goalId),
        ),
        isNull,
      );
      // Legacy keys are gone; global settings are untouched.
      expect(
        await prefs.getString(PrefsSavingsRepository.legacyHabitKey),
        isNull,
      );
      expect(
        await prefs.getString(PrefsSavingsRepository.legacyEntriesKey),
        isNull,
      );
      expect((await repo.loadReminder()).valueOrNull, 'weekly');
      expect((await repo.loadFlag('show100')).valueOrNull, isTrue);
      // Runs once: a second load reads the migrated goal.
      expect((await PrefsSavingsRepository().loadGoals()).valueOrNull, goals);
    });

    test('the view model sees the old total, level and habit', () async {
      seedLegacy();
      final model = SavingsViewModel(repository: PrefsSavingsRepository());
      await Future<void>.delayed(const Duration(milliseconds: 20));
      expect(model.loadError, isFalse);
      expect(model.goals, hasLength(1));
      expect(model.habit, 'Fancy coffee');
      expect(model.progress.total, 25);
      expect(model.progress.level, 2);
      expect(model.reminder?.name, 'weekly');
    });

    test('a fresh install has no goals', () async {
      final repo = PrefsSavingsRepository();
      expect((await repo.loadGoals()).valueOrNull, isEmpty);
    });
  });

  test('model rejects invalid amounts', () async {
    final model = SavingsViewModel(repository: InMemorySavingsRepository());
    expect(() => model.addSavings(-1), throwsArgumentError);
    expect(() => model.addSavings(double.nan), throwsArgumentError);
  });
}
