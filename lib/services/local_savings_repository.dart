// lib/services/local_savings_repository.dart
//
// Local-only persistence backed by SQLite (sqflite / sqflite_common_ffi),
// user_id = 'local', integer cents (D-04 / D-05), epoch-ms timestamps (D-06).
//
// This file is created in Task 2 as the full implementation. A minimal stub
// lives here so that Task 1's seam compiles; Task 2 replaces it.

import 'savings_repository.dart';

class LocalSavingsRepository extends SavingsRepository {
  LocalSavingsRepository();

  // STUB (Task 1) — replaced by the real SQLite implementation in Task 2.
  @override
  Future<void> add(double amount) async {
    throw UnimplementedError('Local repository (SQLite) lands in Task 2.');
  }

  @override
  Future<double> getTotal() async {
    throw UnimplementedError('Local repository (SQLite) lands in Task 2.');
  }

  @override
  Future<void> clear() async {
    throw UnimplementedError('Local repository (SQLite) lands in Task 2.');
  }
}
