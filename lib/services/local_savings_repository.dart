// lib/services/local_savings_repository.dart
//
// Local-only persistence backed by SQLite (user_id = 'local', integer cents
// (D-04/D-05), epoch-ms timestamps (D-06)).
//
// Cross-platform storage layer (Phase 1, G-01-17): Android/iOS use the
// `sqflite` mobile plugin (its default factory), while desktop
// (Linux/Windows/macOS) uses `sqflite_common_ffi` (SQLite over FFI), since
// the sqflite plugin has no Linux target. The FFI factory is set only on
// desktop; the DB directory is the application-support dir on desktop
// (launch-cwd-independent, G-01-18) and the sqflite plugin's databases dir
// on mobile.
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
import 'dart:io' as io;

import 'package:path_provider/path_provider.dart';
import 'package:sqflite_common_ffi/sqflite_common_ffi.dart';

import 'savings_repository.dart';

/// Whether [os] (the value of [io.Platform.operatingSystem]) is a desktop OS
/// that should use the application-support database directory and the FFI
/// backend, as opposed to the mobile `sqflite` plugin factory.
///
/// Pure (no IO) so it can be unit-tested without a real [io.Platform]. The
/// comparison is case-insensitive because [io.Platform.operatingSystem] is
/// lower-cased (e.g. 'linux', 'windows', 'macos').
bool isDesktopDbPlatform(String os) {
  final normalized = os.toLowerCase();
  return normalized == 'linux' || normalized == 'windows' ||
      normalized == 'macos';
}

/// Database directory.
///
/// Desktop (Linux/Windows/macOS): the application-support directory —
/// stable and independent of the launch working directory (G-01-18). Mobile
/// (Android/iOS): the sqflite plugin's default databases directory.
Future<String> databaseDirectory() async {
  if (isDesktopDbPlatform(io.Platform.operatingSystem)) {
    final support = await getApplicationSupportDirectory();
    return support.path;
  }
  return await getDatabasesPath();
}

/// D-15: the local SQLite database could not be created or opened (disk
/// full, read-only filesystem, bad path, etc.). Distinct from a read
/// failure (D-14) or a write failure (D-13): the app enters a dedicated
/// "storage unavailable" state (total hidden, coin taps disabled) instead
/// of showing a failed read or a failed save.
class StorageUnavailableException implements Exception {
  StorageUnavailableException(this.detail);

  final String detail;

  @override
  String toString() => 'Storage unavailable: $detail';
}

class LocalSavingsRepository extends SavingsRepository {
  // The database is opened lazily, once, and kept for the lifetime of the app.
  // Null until [_open] succeeds — a failed open (D-15) leaves the repository
  // unopened so a later call can retry.
  Database? _db;
  bool _opened = false;

  LocalSavingsRepository();

  Future<void> _open() async {
    if (_opened) {
      return;
    }
    // Platform-select the persistence backend (G-01-17): desktop runs the FFI
    // backend (`sqflite_common_ffi`), which does not register the global factory
    // by itself; Android/iOS keep the default sqflite plugin factory.
    if (isDesktopDbPlatform(io.Platform.operatingSystem)) {
      sqfliteFfiInit();
      if (databaseFactoryOrNull == null) {
        databaseFactory = databaseFactoryFfi;
      }
    }
    // Stable DB directory (G-01-18): application-support dir on desktop
    // (launch-cwd-independent), sqflite plugin databases dir on mobile.
    final path = await databaseDirectory();
    final dbPath = '$path/quitcash_local.db';
    try {
      _db = await openDatabase(
        dbPath,
        version: 1,
        onUpgrade: _onUpgrade,
      );
      _opened = true;
    } catch (e) {
      // D-15: unopenable DB (storage full, read-only fs, ...) is a distinct
      // failure mode from a read failure (D-14) — the app enters a dedicated
      // "storage unavailable" state.
      _db = null;
      throw StorageUnavailableException(
          'Could not open local savings database at $dbPath: $e');
    }
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

  /// Schema version 1; [onUpgrade] re-runs the idempotent schema creation so
  /// future migrations can migrate in place (D-07, 01-03 Task 2).
  Future<void> _onUpgrade(Database db, int oldVersion, int newVersion) async {
    await db.execute(
      """
      CREATE TABLE IF NOT EXISTS savings (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        user_id TEXT NOT NULL,
        amount INTEGER NOT NULL,
        created_at INTEGER NOT NULL
      );
    """);
  }

  @override
  Future<void> add(double amount) async {
    _validateAmount(amount);
    await _open();
    final cents = _dollarsToCents(amount);
    final nowMs = DateTime.now().millisecondsSinceEpoch;
    await _db!.insert('savings', {
      'user_id': 'local',
      'amount': cents,
      'created_at': nowMs,
    });
  }

  @override
  Future<double> getTotal() async {
    await _open();
    final rows = await _db!.rawQuery(
      "SELECT COALESCE(SUM(amount), 0) AS total FROM savings WHERE user_id = 'local'",
    );
    // SUM of INTEGER over zero rows is NULL; COALESCE guards against that.
    final totalCents = (rows.first['total'] ?? 0) as int;
    return totalCents / 100.0;
  }

  @override
  Future<void> clear() async {
    await _open();
    await _db!.delete('savings', where: "user_id = 'local'");
  }
}
