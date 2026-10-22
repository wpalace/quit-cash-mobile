import 'dart:convert';

import 'package:quit_cash_mobile/data/repositories/savings_repository.dart';
import 'package:quit_cash_mobile/domain/models/goal.dart';
import 'package:quit_cash_mobile/domain/models/save_entry.dart';
import 'package:quit_cash_mobile/domain/models/tap_cluster.dart';
import 'package:quit_cash_mobile/utils/result.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// On-device repository backed by shared_preferences (NSUserDefaults on iOS,
/// SharedPreferences on Android, localStorage on web, a JSON file on
/// desktop). Each goal's history is one JSON list; a heavy user creates a
/// few thousand small rows, which is well inside the limits of every backend.
class PrefsSavingsRepository implements SavingsRepository {
  PrefsSavingsRepository({SharedPreferencesAsync? prefs})
    : _prefs = prefs ?? SharedPreferencesAsync();

  static const goalsKey = 'quitcash.goals.v1';
  static const activeGoalKey = 'quitcash.goal.active.v1';

  /// Clustered history (one record per tap cluster), current format.
  static String entriesKey(String goalId) => 'quitcash.goal.$goalId.entries.v2';

  /// Per-tap history from before tap clustering. Read only by [_read].
  static String legacyGoalEntriesKey(String goalId) =>
      'quitcash.goal.$goalId.entries.v1';
  static String numberKey(String key) => 'quitcash.number.$key';
  static const reminderKey = 'quitcash.reminder.v1';
  static String flagKey(String key) => 'quitcash.flag.$key';

  /// Single-goal keys from before goals existed. Read only by [_migrate].
  static const legacyEntriesKey = 'quitcash.entries.v1';
  static const legacyHabitKey = 'quitcash.habit.v1';

  /// Id given to the goal created from legacy single-goal data.
  static const migratedGoalId = 'g1';

  final SharedPreferencesAsync _prefs;

  Never _corrupt(String what, Object e) =>
      throw FormatException('Unreadable $what: $e');

  Future<List<Goal>> _readGoals() async {
    final raw = await _prefs.getString(goalsKey);
    if (raw == null) return _migrate();
    try {
      return [
        for (final row in jsonDecode(raw) as List<Object?>)
          Goal.fromJson(row as Map<String, Object?>),
      ];
    } on TypeError catch (e) {
      _corrupt('goals', e);
    }
  }

  /// Moves single-goal data into goal [migratedGoalId], losslessly: the
  /// history string is copied verbatim, the goals list is written last (so
  /// an interrupted migration simply runs again), then legacy keys go.
  Future<List<Goal>> _migrate() async {
    final habit = await _prefs.getString(legacyHabitKey);
    final history = await _prefs.getString(legacyEntriesKey);
    if (habit == null && (history == null || history.isEmpty)) return const [];
    final goal = Goal(id: migratedGoalId, habit: habit ?? 'Something else');
    if (history != null) {
      // Per-tap format: [_read] clusters it on first load.
      await _prefs.setString(legacyGoalEntriesKey(goal.id), history);
    }
    await _prefs.setString(activeGoalKey, goal.id);
    await _writeGoals([goal]);
    await _prefs.remove(legacyEntriesKey);
    await _prefs.remove(legacyHabitKey);
    return [goal];
  }

  Future<void> _writeGoals(List<Goal> goals) => _prefs.setString(
    goalsKey,
    jsonEncode([for (final g in goals) g.toJson()]),
  );

  Future<List<SaveEntry>> _read(String goalId) async {
    final raw = await _prefs.getString(entriesKey(goalId));
    if (raw == null) return _migrateTaps(goalId);
    return _decode(raw);
  }

  /// Per-tap history (v1) becomes clustered records (v2) using
  /// [defaultTapWindow]. Totals are unchanged. v2 is written before v1 is
  /// removed, so an interrupted migration re-runs from v1.
  Future<List<SaveEntry>> _migrateTaps(String goalId) async {
    final legacy = await _prefs.getString(legacyGoalEntriesKey(goalId));
    if (legacy == null) return const [];
    final rows = clusterTaps(_decode(legacy));
    await _write(goalId, rows);
    await _prefs.remove(legacyGoalEntriesKey(goalId));
    return rows;
  }

  Future<void> _write(String goalId, List<SaveEntry> rows) => _prefs.setString(
    entriesKey(goalId),
    jsonEncode([for (final r in rows) r.toJson()]),
  );

  List<SaveEntry> _decode(String raw) {
    if (raw.isEmpty) return const [];
    try {
      final list = jsonDecode(raw) as List<Object?>;
      return [
        for (final row in list)
          ?SaveEntry.tryFromJson(row as Map<String, Object?>),
      ];
    } on TypeError catch (e) {
      _corrupt('savings history', e);
    } on ArgumentError catch (e) {
      // Corrupt or foreign data: report as a recoverable format failure.
      _corrupt('savings history', e);
    }
  }

  @override
  Future<Result<List<Goal>>> loadGoals() => guard(_readGoals);

  @override
  Future<Result<void>> saveGoals(List<Goal> goals) =>
      guard(() => _writeGoals(goals));

  @override
  Future<Result<String?>> loadActiveGoal() =>
      guard(() => _prefs.getString(activeGoalKey));

  @override
  Future<Result<void>> saveActiveGoal(String? id) => guard(
    () => id == null
        ? _prefs.remove(activeGoalKey)
        : _prefs.setString(activeGoalKey, id),
  );

  @override
  Future<Result<List<SaveEntry>>> loadAll(String goalId) =>
      guard(() => _read(goalId));

  @override
  Future<Result<void>> append(String goalId, SaveEntry entry) =>
      guard(() async => _write(goalId, [...await _read(goalId), entry]));

  @override
  Future<Result<void>> update(String goalId, SaveEntry entry) =>
      guard(() async {
        await _write(goalId, [
          for (final r in await _read(goalId)) r.id == entry.id ? entry : r,
        ]);
      });

  @override
  Future<Result<void>> remove(String goalId, String entryId) => guard(() async {
    await _write(goalId, [
      for (final r in await _read(goalId))
        if (r.id != entryId) r,
    ]);
  });

  @override
  Future<Result<void>> clear(String goalId) => guard(() async {
    await _prefs.remove(entriesKey(goalId));
    await _prefs.remove(legacyGoalEntriesKey(goalId));
  });

  @override
  Future<Result<String?>> loadReminder() =>
      guard(() => _prefs.getString(reminderKey));

  @override
  Future<Result<void>> saveReminder(String frequency) =>
      guard(() => _prefs.setString(reminderKey, frequency));

  @override
  Future<Result<bool?>> loadFlag(String key) =>
      guard(() => _prefs.getBool(flagKey(key)));

  @override
  Future<Result<void>> saveFlag(String key, bool value) =>
      guard(() => _prefs.setBool(flagKey(key), value));

  @override
  Future<Result<int?>> loadNumber(String key) =>
      guard(() => _prefs.getInt(numberKey(key)));

  @override
  Future<Result<void>> saveNumber(String key, int value) =>
      guard(() => _prefs.setInt(numberKey(key), value));
}
