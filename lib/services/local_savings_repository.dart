// lib/services/local_savings_repository.dart
//
// Local-only persistence backed by SQLite (FFI), user_id = 'local', integer
// cents (D-04/D-05), epoch-ms timestamps (D-06).
//
// On Linux the sqflite package falls back to the sqflite_common_ffi backend
// (added as a dependency), so `openDatabase` / `getDatabasesPath` run locally.
//
//
// Database file: `quitcash_local.db` (SQLite), schema v1:
//
//   CREATE TABLE IF NOT EXISTS savings (
//     id         INTEGER PRIMARY KEY AUTOINCREMENT,
//     user_id    TEXT NOT NULL,
//     amount     INTEGER NOT NULL,   -- cents
//     created_at INTEGER NOT NULL    -- epoch ms
//
// Total-savings source of truth is always `SELECT SUM(amount)` from local
// SQLite (D-04) — no cached value.
import 'package:sqflite_common_ffi/sqflite_common_ffi.dart';

import 'savings_repository.dart';

class LocalSavingsRepository extends SavingsRepository {
  // The database is opened lazily, once, and kept for the lifetime of the app.
  late final Database _db;
  bool _opened = false;

  LocalSavingsRepository();

  Future<void> _open() async {
    if (_opened) {
      return;
    }
    final path = getDatabasesPath();
    final dbPath = '$path/quitcash_local.db';
    _db = await openDatabase(dbPath);
    await _ensureSchema();
    _opened = true;
  }

  Future<void> _ensureSchema() async {
    await _db.execute("""
      CREATE TABLE IF NOT EXISTS savings (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        user_id TEXT NOT NULL,
        amount INTEGER NOT NULL,
        created_at INTEGER NOT NULL
      );
    """);
  }

  /// Validate a savings amount at the seam (D-09):
  ///   - must be finite
  ///   - must be non-negative
  ///   - must not exceed $9999.00
  /// Throws [ArgumentError] on violation.
  static void _validateAmount(double amount) {
    if (!amount.isFinite) {
      throw ArgumentError('Saving amount must be finite.');
    }
    if (amount < 0) {
      throw ArgumentError('Saving amount must be non-negative.');
    }
    if (amount > 9999.0) {
      throw ArgumentError('Saving amount must not exceed 9999.00.');
    }
  }

  /// Convert dollars to integer cents (D-05). Rounding avoids binary-float
  /// drift (e.g. 1.1 * 100 != 110 exactly).
  static int _dollarsToCents(double amount) => (amount * 100).round();

  @override
  Future<void> add(double amount) async {
    _validateAmount(amount);
    await _open();
    final cents = _dollarsToCents(amount);
    final nowMs = DateTime.now().millisecondsSinceEpoch;
    await _db.insert('savings', {
      'user_id': 'local',
      'amount': cents,
      'created_at': nowMs,
    });
  }

  @override
  Future<double> getTotal() async {
    await _open();
    final rows = await _db.rawQuery(
      "SELECT COALESCE(SUM(amount), 0) AS total FROM savings WHERE user_id = 'local'",
    );
    // SUM of INTEGER over zero rows is NULL; COALESCE guards against that.
    final totalCents = (rows.first['total'] ?? 0) as int;
    return totalCents / 100.0;
  }

  @override
  Future<void> clear() async {
    await _open();
    await _db.delete('savings', where: "user_id = 'local'");
  }
}
