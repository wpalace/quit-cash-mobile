import 'package:quit_cash_mobile/data/repositories/savings_repository.dart';
import 'package:quit_cash_mobile/domain/models/goal.dart';
import 'package:quit_cash_mobile/domain/models/save_entry.dart';
import 'package:quit_cash_mobile/utils/result.dart';

/// Volatile repository for tests and previews.
class InMemorySavingsRepository implements SavingsRepository {
  InMemorySavingsRepository();

  /// One goal ('g1') for [habit], active, seeded with [seed].
  InMemorySavingsRepository.withGoal(String habit, [List<SaveEntry>? seed]) {
    goals.add(Goal(id: 'g1', habit: habit));
    active = 'g1';
    entries['g1'] = [...?seed];
  }

  final goals = <Goal>[];
  String? active;
  final entries = <String, List<SaveEntry>>{};
  String? reminder;
  final flags = <String, bool>{};
  final numbers = <String, int>{};

  @override
  Future<Result<List<Goal>>> loadGoals() async => Ok(List.unmodifiable(goals));

  @override
  Future<Result<void>> saveGoals(List<Goal> value) async {
    goals
      ..clear()
      ..addAll(value);
    return const Ok(null);
  }

  @override
  Future<Result<String?>> loadActiveGoal() async => Ok(active);

  @override
  Future<Result<void>> saveActiveGoal(String? id) async {
    active = id;
    return const Ok(null);
  }

  @override
  Future<Result<List<SaveEntry>>> loadAll(String goalId) async =>
      Ok(List.unmodifiable(entries[goalId] ?? const <SaveEntry>[]));

  @override
  Future<Result<void>> append(String goalId, SaveEntry entry) async {
    (entries[goalId] ??= []).add(entry);
    return const Ok(null);
  }

  @override
  Future<Result<void>> clear(String goalId) async {
    entries.remove(goalId);
    return const Ok(null);
  }

  @override
  Future<Result<void>> update(String goalId, SaveEntry entry) async {
    final rows = entries[goalId];
    final i = rows?.indexWhere((r) => r.id == entry.id) ?? -1;
    if (rows != null && i >= 0) rows[i] = entry;
    return const Ok(null);
  }

  @override
  Future<Result<void>> remove(String goalId, String entryId) async {
    entries[goalId]?.removeWhere((r) => r.id == entryId);
    return const Ok(null);
  }

  @override
  Future<Result<String?>> loadReminder() async => Ok(reminder);

  @override
  Future<Result<void>> saveReminder(String value) async {
    reminder = value;
    return const Ok(null);
  }

  @override
  Future<Result<bool?>> loadFlag(String key) async => Ok(flags[key]);

  @override
  Future<Result<void>> saveFlag(String key, bool value) async {
    flags[key] = value;
    return const Ok(null);
  }

  @override
  Future<Result<int?>> loadNumber(String key) async => Ok(numbers[key]);

  @override
  Future<Result<void>> saveNumber(String key, int value) async {
    numbers[key] = value;
    return const Ok(null);
  }
}
