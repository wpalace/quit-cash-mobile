import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

import 'save_entry.dart';
import 'savings_repository.dart';

/// On-device repository backed by shared_preferences (NSUserDefaults on iOS,
/// SharedPreferences on Android, localStorage on web, a JSON file on
/// desktop). The full history is one JSON list; a heavy user creates a few
/// thousand small rows, which is well inside the limits of every backend.
class PrefsSavingsRepository implements SavingsRepository {
  PrefsSavingsRepository({SharedPreferencesAsync? prefs})
    : _prefs = prefs ?? SharedPreferencesAsync();

  static const storageKey = 'quitcash.entries.v1';
  final SharedPreferencesAsync _prefs;

  @override
  Future<List<SaveEntry>> loadAll() async {
    final raw = await _prefs.getString(storageKey);
    if (raw == null || raw.isEmpty) return const [];
    final list = jsonDecode(raw) as List<dynamic>;
    return [
      for (final row in list) SaveEntry.fromJson(row as Map<String, dynamic>),
    ];
  }

  @override
  Future<void> append(SaveEntry entry) async {
    final rows = [...await loadAll(), entry];
    await _prefs.setString(
      storageKey,
      jsonEncode([for (final r in rows) r.toJson()]),
    );
  }

  @override
  Future<void> clear() => _prefs.remove(storageKey);

  static const habitKey = 'quitcash.habit.v1';

  @override
  Future<String?> loadHabit() => _prefs.getString(habitKey);

  @override
  Future<void> saveHabit(String habit) => _prefs.setString(habitKey, habit);

  static const reminderKey = 'quitcash.reminder.v1';

  @override
  Future<String?> loadReminder() => _prefs.getString(reminderKey);

  @override
  Future<void> saveReminder(String frequency) =>
      _prefs.setString(reminderKey, frequency);
}
