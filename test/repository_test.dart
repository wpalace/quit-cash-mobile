import 'package:flutter_test/flutter_test.dart';
import 'package:quit_cash_mobile/data/prefs_savings_repository.dart';
import 'package:quit_cash_mobile/data/save_entry.dart';
import 'package:quit_cash_mobile/data/savings_repository.dart';
import 'package:quit_cash_mobile/state/savings_model.dart';
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
    await repo.append(SaveEntry(kind: EntryKind.checkIn, cents: 0, at: at));
    await repo.saveHabit('Vaping');

    final again = PrefsSavingsRepository();
    final rows = await again.loadAll();
    expect(rows, hasLength(2));
    expect(rows.first.cents, 500);
    expect(rows.first.at, at);
    expect(rows.last.kind, EntryKind.checkIn);
    expect(await again.loadHabit(), 'Vaping');

    await again.clear();
    expect(await again.loadAll(), isEmpty);
  });

  test('model reports level-up and new badges once', () async {
    final model = SavingsModel(
      repository: InMemorySavingsRepository(),
      clock: () => DateTime(2026, 10, 19),
    );
    await Future<void>.delayed(Duration.zero);
    final first = await model.addSavings(10);
    expect(first!.newLevel, 1);
    expect(first.badges.map((b) => b.id), containsAll(['first', 'ten']));
    final second = await model.addSavings(1);
    expect(second!.isEmpty, isTrue);
    expect(model.progress.total, 11);
    expect(await model.checkIn(), isNotNull);
    expect(await model.checkIn(), isNull);
  });

  test('model rejects invalid amounts', () async {
    final model = SavingsModel(repository: InMemorySavingsRepository());
    expect(() => model.addSavings(-1), throwsArgumentError);
    expect(() => model.addSavings(double.nan), throwsArgumentError);
  });
}
