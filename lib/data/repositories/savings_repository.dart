import 'package:quit_cash_mobile/domain/models/save_entry.dart';

/// Persistence seam. The app depends only on this interface.
///
/// Launch build: [PrefsSavingsRepository] (on-device, zero infrastructure).
/// A future cloud implementation (for example the quit-cash-api .NET
/// service) only has to implement these methods; sync/merge can be
/// layered on top without touching the UI.
abstract class SavingsRepository {
  Future<List<SaveEntry>> loadAll();
  Future<void> append(SaveEntry entry);
  Future<void> clear();

  /// The habit the user is quitting (null until onboarding is done).
  Future<String?> loadHabit();
  Future<void> saveHabit(String habit);

  /// Reminder frequency name (see ReminderFrequency); null = never asked.
  Future<String?> loadReminder();
  Future<void> saveReminder(String frequency);

  /// Boolean settings (for example 'show50'); null = never set.
  Future<bool?> loadFlag(String key);
  Future<void> saveFlag(String key, bool value);
}

/// Volatile repository for tests and previews.
class InMemorySavingsRepository implements SavingsRepository {
  InMemorySavingsRepository([List<SaveEntry>? seed]) : _rows = [...?seed];
  final List<SaveEntry> _rows;

  @override
  Future<List<SaveEntry>> loadAll() async => List.unmodifiable(_rows);

  @override
  Future<void> append(SaveEntry entry) async => _rows.add(entry);

  @override
  Future<void> clear() async => _rows.clear();

  String? habit;

  @override
  Future<String?> loadHabit() async => habit;

  @override
  Future<void> saveHabit(String value) async => habit = value;

  String? reminder;

  @override
  Future<String?> loadReminder() async => reminder;

  @override
  Future<void> saveReminder(String value) async => reminder = value;

  final flags = <String, bool>{};

  @override
  Future<bool?> loadFlag(String key) async => flags[key];

  @override
  Future<void> saveFlag(String key, bool value) async => flags[key] = value;
}
