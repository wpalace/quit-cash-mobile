import 'package:quit_cash_mobile/data/repositories/savings_repository.dart';
import 'package:quit_cash_mobile/domain/models/save_entry.dart';
import 'package:quit_cash_mobile/utils/result.dart';

/// Volatile repository for tests and previews.
class InMemorySavingsRepository implements SavingsRepository {
  InMemorySavingsRepository([List<SaveEntry>? seed]) : _rows = [...?seed];
  final List<SaveEntry> _rows;

  String? habit;
  String? reminder;
  final flags = <String, bool>{};

  @override
  Future<Result<List<SaveEntry>>> loadAll() async =>
      Ok(List.unmodifiable(_rows));

  @override
  Future<Result<void>> append(SaveEntry entry) async {
    _rows.add(entry);
    return const Ok(null);
  }

  @override
  Future<Result<void>> clear() async {
    _rows.clear();
    return const Ok(null);
  }

  @override
  Future<Result<String?>> loadHabit() async => Ok(habit);

  @override
  Future<Result<void>> saveHabit(String value) async {
    habit = value;
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
}
