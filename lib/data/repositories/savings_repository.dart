import 'package:quit_cash_mobile/domain/models/goal.dart';
import 'package:quit_cash_mobile/domain/models/save_entry.dart';
import 'package:quit_cash_mobile/utils/result.dart';

/// Persistence seam and source of truth. The app depends only on this
/// interface. Every method returns a [Result] instead of throwing.
///
/// Launch build: PrefsSavingsRepository (on-device, zero infrastructure).
/// A future cloud implementation (for example the quit-cash-api .NET
/// service) only has to implement these methods.
abstract interface class SavingsRepository {
  /// All goals in creation order (empty until onboarding is done).
  Future<Result<List<Goal>>> loadGoals();
  Future<Result<void>> saveGoals(List<Goal> goals);

  /// Id of the goal shown on Bank and Trophies; null = none.
  Future<Result<String?>> loadActiveGoal();
  Future<Result<void>> saveActiveGoal(String? id);

  /// Savings history of one goal.
  Future<Result<List<SaveEntry>>> loadAll(String goalId);
  Future<Result<void>> append(String goalId, SaveEntry entry);
  Future<Result<void>> clear(String goalId);

  /// Replaces the record with the same id (no-op if it is gone).
  Future<Result<void>> update(String goalId, SaveEntry entry);

  /// Removes the record with [entryId].
  Future<Result<void>> remove(String goalId, String entryId);

  /// Reminder frequency name (see ReminderFrequency); null = never asked.
  Future<Result<String?>> loadReminder();
  Future<Result<void>> saveReminder(String frequency);

  /// Boolean settings (for example 'show50'); null = never set.
  Future<Result<bool?>> loadFlag(String key);
  Future<Result<void>> saveFlag(String key, bool value);

  /// Integer settings (for example the tap window in seconds).
  Future<Result<int?>> loadNumber(String key);
  Future<Result<void>> saveNumber(String key, int value);
}
