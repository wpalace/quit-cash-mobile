import 'dart:convert';

import 'package:quit_cash_mobile/data/repositories/savings_repository.dart';
import 'package:quit_cash_mobile/domain/models/goal.dart';
import 'package:quit_cash_mobile/domain/models/save_entry.dart';
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
  static String entriesKey(String goalId) => 'quitcash.goal.$goalId.entries.v1';
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
      await _prefs.setString(entriesKey(goal.id), history);
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
    if (raw == null || raw.isEmpty) return const [];
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
      guard(() async {
        final rows = [...await _read(goalId), entry];
        await _prefs.setString(
          entriesKey(goalId),
          jsonEncode([for (final r in rows) r.toJson()]),
        );
      });

  @override
  Future<Result<void>> clear(String goalId) =>
      guard(() => _prefs.remove(entriesKey(goalId)));

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
}
