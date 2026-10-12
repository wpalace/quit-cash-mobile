// Phase 1 (01-03 Task 2): unit tests for the local SQLite repository —
// D-01/D-02 (single source of truth, SUM), D-04 (total), D-05 (integer
// cents), D-07 (schema version 1 + onUpgrade path), D-09 (validation),
// D-14 (read failure) and D-15 (storage unavailable).
//
// The FFI factory keeps a single [Database] per path (single-instance open
// is on by default) and top-level `deleteDatabase` closes the cached helper
// and removes the file, so a fresh `LocalSavingsRepository` after `_reset()`
// starts from a clean slate. All tests run against the real FFI backend
// (same isolate + native library the app uses), with the database at
// `<cwd>/.dart_tool/sqflite_common_ffi/databases/`.
//
// Tests are written to be order-independent: each one that touches the app
// database deletes it at the top and at the end.
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

import 'package:sqflite_common_ffi/sqflite_common_ffi.dart';
import '../lib/services/local_savings_repository.dart';

/// The FFI factory is not registered by itself; make sure it is before any
/// top-level sqflite API use (fresh process / isolated test run).
void _ensureFactory() {
  if (databaseFactoryOrNull == null) {
    databaseFactory = databaseFactoryFfi;
  }
}

Future<String> _dbPath() async =>
    '${await getDatabasesPath()}/quitcash_local.db';

/// Close the cached single-instance helper and delete the file (plus
/// auxiliary journal files).
Future<void> _reset() async {
  try {
    await deleteDatabase(await _dbPath());
  } catch (_) {
    // No database yet, or already deleted — harmless.
  }
}

/// Same single-instance handle as a [LocalSavingsRepository] at the same
/// path, so raw SQL here sees the repository's rows.
Future<Database> _sharedDb() async => openDatabase(await _dbPath());

/// Runs [op] and returns whatever it throws (or a [StateError] if none).
Future<dynamic> _captureError(Future<void> Function() op) async {
  try {
    await op();
    throw StateError('expected an error, none thrown');
  } catch (e) {
    return e;
  }
}

void main() {
  _ensureFactory();
  group('LocalSavingsRepository (Phase 1, local-only)', () {
    test(
        'add persists integer cents, user_id local, autoincrement ids, epoch-ms created_at (D-01/D-02/D-05)',
        () async {
      await _reset();
      final repo = LocalSavingsRepository();
      final before = DateTime.now().millisecondsSinceEpoch;
      await repo.add(1.10);
      await repo.add(2.25);

      final db = await _sharedDb();
      final rows = await db.rawQuery(
          'SELECT id, user_id, amount, created_at FROM savings ORDER BY id');
      expect(rows.length, 2);
      expect(rows.first['user_id'], 'local');
      expect(rows.first['amount'], 110);
      expect(rows[1]['amount'], 225);
      final firstId = rows.first['id'] as int;
      final secondId = rows[1]['id'] as int;
      expect(secondId, firstId + 1);
      final ts = rows.first['created_at'] as int;
      expect(ts, greaterThan(before - 60_000));
      expect(ts, lessThan(before + 60_000));
    });

    test('getTotal is SUM(amount) over local rows, 0.0 when empty (D-04)',
        () async {
      await _reset();
      final repo = LocalSavingsRepository();
      expect(await repo.getTotal(), 0.0);
      await repo.add(1.0);
      await repo.add(2.5);
      expect(await repo.getTotal(), 3.5);
    });

    test(
        'opens with version 1; onUpgrade path fires with the old version (D-07)',
        () async {
      // Temp dir under the cwd (avoids `createTempDir` from `package:test`,
      // which is not resolvable without adding `test` to pubspec.yaml).
      final tempDir = Directory(
          '.tmp_migration_test_${DateTime.now().millisecondsSinceEpoch}');
      await tempDir.create(recursive: true);
      addTearDown(() async => await tempDir.delete(recursive: true));
      final path = '$tempDir.path/migration.db';

      // Fresh valid DB at version 1 (no callbacks -> user_version 1, no
      // savings table).
      final dbV1 = await openDatabase(path, version: 1);
      expect((await dbV1.rawQuery('PRAGMA user_version')).first['user_version'],
          1);
      await dbV1.close();

      // Reopen at version 2: onUpgrade must fire with oldVersion == 1.
      final calledWith = <List<int>>[];
      final dbV2 = await openDatabase(
        path,
        version: 2,
        onUpgrade: (db, old, v) async {
          calledWith.add([old, v]);
          return db.execute(
              'CREATE TABLE IF NOT EXISTS history (id INTEGER PRIMARY KEY)');
        },
      );
      expect(calledWith, [[1, 2]]);
      expect((await dbV2.rawQuery('PRAGMA user_version')).first['user_version'],
          2);
      final tables = await dbV2.rawQuery(
          "SELECT name FROM sqlite_master WHERE type='table'");
      expect(tables.map((t) => t['name']), contains('history'));
      await dbV2.close();
    });

    test('add rejects non-finite, negative, and out-of-range amounts (D-09)',
        () async {
      await _reset();
      final repo = LocalSavingsRepository();
      await expectLater(repo.add(double.infinity),
          throwsA(isA<ArgumentError>()));
      await expectLater(repo.add(double.nan),
          throwsA(isA<ArgumentError>()));
      await expectLater(repo.add(-0.01), throwsA(isA<ArgumentError>()));
      await expectLater(repo.add(10000.0), throwsA(isA<ArgumentError>()));
      // Rejections never write anything, so the total is still 0.0.
      expect(await repo.getTotal(), 0.0);
    });

    test(
        'valid DB without savings table fails the read with a non-storage error (D-14)',
        () async {
      // Start from a clean slate, then hand-craft a "valid empty" DB:
      // version 1 (matches the repo), but no savings table. The open
      // succeeds (file is fine), but the SUM read must fail with a SQL
      // error — a non-storage failure (D-14), not a StorageUnavailable
      // exception (D-15).
      await _reset();
      final path = await _dbPath();
      final seed = await openDatabase(path, version: 1);
      await seed.close();

      final repo = LocalSavingsRepository();
      final error = await _captureError(() => repo.getTotal());
      expect(error, isNot(isA<StorageUnavailableException>()));
      expect(error.toString(), contains('no such table'));
      await _reset();
    });

    test('unopenable database throws StorageUnavailableException (D-15)',
        () async {
      // Make the FFI data dir non-writable so the file cannot be created.
      // (Directory.chmod was removed in this Dart version; use shell chmod.)
      await _reset();
      final dataDir = Directory(await getDatabasesPath());
      await dataDir.create(recursive: true);
      final path = '$dataDir.path/quitcash_local.db';
      if (File(path).existsSync()) {
        await File(path).delete();
      }
      Process.runSync('chmod', ['0555', dataDir.path]);
      try {
        final repo = LocalSavingsRepository();
        final error = await _captureError(() => repo.add(1.0));
        expect(error, isA<StorageUnavailableException>());
        expect(error.toString(), contains('quitcash_local.db'));
      } finally {
        Process.runSync('chmod', ['0755', dataDir.path]);
        await _reset();
      }
    });
  });
}
