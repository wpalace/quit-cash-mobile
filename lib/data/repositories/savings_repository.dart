import 'package:quit_cash_mobile/domain/models/save_entry.dart';
import 'package:quit_cash_mobile/utils/result.dart';

/// Persistence seam and source of truth. The app depends only on this
/// interface. Every method returns a [Result] instead of throwing.
///
/// Launch build: PrefsSavingsRepository (on-device, zero infrastructure).
/// A future cloud implementation (for example the quit-cash-api .NET
/// service) only has to implement these methods.
abstract interface class SavingsRepository {
  Future<Result<List<SaveEntry>>> loadAll();
  Future<Result<void>> append(SaveEntry entry);
  Future<Result<void>> clear();

  /// The habit the user is quitting (null until onboarding is done).
  Future<Result<String?>> loadHabit();
  Future<Result<void>> saveHabit(String habit);

  /// Reminder frequency name (see ReminderFrequency); null = never asked.
  Future<Result<String?>> loadReminder();
  Future<Result<void>> saveReminder(String frequency);

  /// Boolean settings (for example 'show50'); null = never set.
  Future<Result<bool?>> loadFlag(String key);
  Future<Result<void>> saveFlag(String key, bool value);
}
