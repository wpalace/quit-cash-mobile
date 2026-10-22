import 'dart:convert';

import 'package:quit_cash_mobile/data/repositories/savings_repository.dart';
import 'package:quit_cash_mobile/domain/models/save_entry.dart';
import 'package:quit_cash_mobile/utils/result.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// On-device repository backed by shared_preferences (NSUserDefaults on iOS,
/// SharedPreferences on Android, localStorage on web, a JSON file on
/// desktop). The full history is one JSON list; a heavy user creates a few
/// thousand small rows, which is well inside the limits of every backend.
class PrefsSavingsRepository implements SavingsRepository {
  PrefsSavingsRepository({SharedPreferencesAsync? prefs})
    : _prefs = prefs ?? SharedPreferencesAsync();

  static const storageKey = 'quitcash.entries.v1';
  static const habitKey = 'quitcash.habit.v1';
  static const reminderKey = 'quitcash.reminder.v1';
  static String flagKey(String key) => 'quitcash.flag.$key';

  final SharedPreferencesAsync _prefs;

  Future<List<SaveEntry>> _read() async {
    final raw = await _prefs.getString(storageKey);
    if (raw == null || raw.isEmpty) return const [];
    try {
      final list = jsonDecode(raw) as List<Object?>;
      return [
        for (final row in list)
          SaveEntry.fromJson(row as Map<String, Object?>),
      ];
    } on TypeError catch (e) {
      throw FormatException('Unreadable savings history: $e');
    } on ArgumentError catch (e) {
      // Corrupt or foreign data: report as a recoverable format failure.
      throw FormatException('Unreadable savings history: $e');
    }
  }

  @override
  Future<Result<List<SaveEntry>>> loadAll() => guard(_read);

  @override
  Future<Result<void>> append(SaveEntry entry) => guard(() async {
    final rows = [...await _read(), entry];
    await _prefs.setString(
      storageKey,
      jsonEncode([for (final r in rows) r.toJson()]),
    );
  });

  @override
  Future<Result<void>> clear() => guard(() => _prefs.remove(storageKey));

  @override
  Future<Result<String?>> loadHabit() =>
      guard(() => _prefs.getString(habitKey));

  @override
  Future<Result<void>> saveHabit(String habit) =>
      guard(() => _prefs.setString(habitKey, habit));

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
