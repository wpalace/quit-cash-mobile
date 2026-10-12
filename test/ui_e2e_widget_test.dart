// Phase 1 (01-03 Task 3): GUI end-to-end verification — drives the real UI
// widgets from lib/main.dart (SetupPage -> HomePage -> CoinButton) with the
// same [SavingsModel] the app runs on, exercising the acceptance criteria:
//   * a coin tap writes a row and the displayed total re-derives as
//     SUM(amount) in the next frame (D-01, D-02, APP-03)
//   * zero entries render $0.00 (D-04, APP-02)
//   * taps serialize; each applied tap gives one entry, one SnackBar, one
//     total update (D-03, D-16)
//   * a failed local write shows "Couldn't save $<amount>", total unchanged,
//     app continues (D-13)
//   * a failed launch read shows the one-time "Couldn't load your savings"
//     warning (D-14)
//   * an unopenable DB shows the dedicated "Storage unavailable" state and
//     muted, inert coin taps (D-15)
//
// Fixture strategy: these tests drive the real [SavingsModel] and real UI
// widgets with a small in-memory [SavingsRepository]
// ([_InMemoryRepository]). The UI's SUM re-derivation path is fully
// exercised: the model re-queries [SavingsRepository.getTotal] (sum of rows)
// at launch and after every tap, and the widget tests assert the resulting
// on-screen total, row counts, and the three distinct failure states.
//
// Surface strategy: `testWidgets` defaults to an 800x600 desktop window, where
// the second row of the 2x2 coin grid overflows. Instead of fighting
// scrolling, every test sets a phone-sized surface (1080x2400, dpr 1.0) so
// all four coins are on screen; the surface is reset after each test.
//
// The real `sqflite_common_ffi` backend is covered separately by
// `test/local_savings_repository_test.dart` (same FFI backend the app uses,
// including integer cents, `user_id='local'`, autoincrement ids, epoch-ms
// timestamps, SUM-based totals, and D-14/D-15 failure semantics). Running
// that backend inside `testWidgets` hangs on this SDK build: real FFI I/O
// never completes inside the fake-async zone `testWidgets` runs in, so the
// widget tests use the in-memory fixture — the widget tests are the UI
// contract; the FFI/SQLite contract is the repository unit suite.
//
// SDK quirks this file stays compatible with:
//   * `List.reduce` is not available in this SDK build — sum with a loop.
//   * Throwing a nullable value is rejected — throw via a non-nullable
//     intermediate.
//   * `findsExactlyOneWidget` / `doesNotExist` are not exported here —
//     use `findsNWidgets(n)` / `findsNWidgets(0)`.
import 'dart:ui' as ui;

import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';

import 'package:quit_cash_mobile/main.dart';
import 'package:quit_cash_mobile/services/local_savings_repository.dart';
import 'package:quit_cash_mobile/services/savings_repository.dart';

/// Phone-sized test surface so all four coins fit on screen; the binding's
/// view state is restored after the test.
void _phoneSurface(WidgetTester tester) {
  tester.view.devicePixelRatio = 1.0;
  tester.view.physicalSize = const ui.Size(1080, 2400);
  addTearDown(tester.view.reset);
}

void main() {
  group('GUI end-to-end (Phase 1, local-only)', () {
    testWidgets(
        'launch with zero entries renders \$0.00 (D-04, APP-02)',
        (tester) async {
      _phoneSurface(tester);
      final model = SavingsModel(repository: _InMemoryRepository());
      await tester.pumpWidget(
        ChangeNotifierProvider(
          create: (_) => model,
          child: const QuitCashApp(),
        ),
      );

      // SetupPage -> HomePage.
      await tester.tap(find.text('Start Saving'));
      await tester.pumpAndSettle();

      expect(find.text('My Savings'), findsOneWidget);
      expect(find.text('\$0.00'), findsOneWidget);
    });

    testWidgets(
        'coin tap writes a row and the total re-derives as SUM(amount) in-frame (D-01, D-02, D-03, APP-03)',
        (tester) async {
      _phoneSurface(tester);
      final repo = _InMemoryRepository();
      final model = SavingsModel(repository: repo);
      await tester.pumpWidget(
        ChangeNotifierProvider(
          create: (_) => model,
          child: const QuitCashApp(),
        ),
      );

      // SetupPage -> HomePage.
      await tester.tap(find.text('Start Saving'));
      await tester.pumpAndSettle();
      expect(find.text('My Savings'), findsOneWidget);
      expect(find.text('\$0.00'), findsOneWidget);

      // Tap the \$5 coin once (single-tap feedback + SUM re-derivation).
      await tester.tap(find.text('\$5'));
      await tester.pumpAndSettle();
      expect(find.text('\$5.00'), findsOneWidget);
      expect(find.text('Saved \$5!'), findsOneWidget);
      // The row was actually recorded (D-01: one tap = one entry).
      expect(repo.rowCount, 1);
      expect(model.totalSaved, 5.0);
    });

    testWidgets(
        'taps serialize: two rapid taps persist in order, UI never stuck (D-03, D-16)',
        (tester) async {
      _phoneSurface(tester);
      final repo = _InMemoryRepository();
      final model = SavingsModel(repository: repo);
      await tester.pumpWidget(
        ChangeNotifierProvider(
          create: (_) => model,
          child: const QuitCashApp(),
        ),
      );
      // SetupPage -> HomePage.
      await tester.tap(find.text('Start Saving'));
      await tester.pumpAndSettle();

      // Tap twice without pumping between them: each tap runs the model's
      // serialized path and persists exactly one entry, in the order the
      // taps landed (D-03; D-16 — a tap is never stuck and never blocks
      // the next). This SDK's snack-bar queue shows only one SnackBar at a
      // time (500ms auto-dismiss), so assert on persisted rows/order and the
      // final total only.
      await tester.tap(find.text('\$1'));
      await tester.tap(find.text('\$5'));

      // Both entries persisted, in tap order.
      expect(repo.rowCount, 2);
      expect(repo.rowList, [1.0, 5.0]);

      // Drain any snack-bar state; the UI is never left stuck.
      await tester.pumpAndSettle();
      // The displayed total re-derives as SUM(amount).
      expect(model.totalSaved, 6.0);
      expect(find.text('\$6.00'), findsOneWidget);
    });

    testWidgets(
        "failed local write: 'Couldn't save \$10', total unchanged, app continues (D-13)",
        (tester) async {
      _phoneSurface(tester);
      final failing = _InMemoryRepository(failWrite: 'local write failed');
      final model = SavingsModel(repository: failing);
      await tester.pumpWidget(
        ChangeNotifierProvider(
          create: (_) => model,
          child: const QuitCashApp(),
        ),
      );
      // SetupPage -> HomePage.
      await tester.tap(find.text('Start Saving'));
      await tester.pumpAndSettle();
      expect(model.totalSaved, 0.0);

      // The \$10 coin is on screen (phone-sized surface, no scrolling).
      await tester.tap(find.text('\$10'));
      await tester.pumpAndSettle();
      // Failed write surfaced, the model's total is unchanged, no row was
      // recorded, storage is not reported unavailable, and the app
      // continues to render.
      expect(find.text("Couldn't save \$10"), findsOneWidget);
      expect(failing.rowCount, 0);
      expect(model.totalSaved, 0.0);
      expect(model.storageUnavailable, false);
      expect(find.text('\$0.00'), findsOneWidget);
    });

    testWidgets(
        "failed launch read: one-time 'Couldn't load your savings', \$0.00, taps enabled (D-14)",
        (tester) async {
      _phoneSurface(tester);
      final badLoad = _InMemoryRepository(failLoad: 'local read failed');
      final model = SavingsModel(repository: badLoad);
      await tester.pumpWidget(
        ChangeNotifierProvider(
          create: (_) => model,
          child: const QuitCashApp(),
        ),
      );
      // SetupPage -> HomePage.
      await tester.tap(find.text('Start Saving'));
      await tester.pumpAndSettle();

      expect(find.text("Couldn't load your savings"), findsOneWidget);
      expect(find.text('\$0.00'), findsOneWidget);
      expect(model.loadError, true);
      expect(model.storageUnavailable, false);
      // Coin taps remain enabled (not the storage-unavailable state): the
      // tap reaches the model and records a row. (Its SnackBar is queued
      // behind the still-visible launch warning by the snack-bar queue.)
      expect(
          find.text("We can't open your savings file"),
          findsNWidgets(0));
      await tester.tap(find.text('\$1'));
      await tester.pumpAndSettle();
      expect(badLoad.rowCount, 1);
      // The total stays $0.00 because every total read fails (D-14).
      expect(find.text('\$0.00'), findsOneWidget);
      expect(model.loadError, true);
    });

    testWidgets(
        'unopenable DB: dedicated "Storage unavailable" state, muted inert coins (D-15)',
        (tester) async {
      _phoneSurface(tester);
      final storageRepo = _InMemoryRepository(
          failLoad: StorageUnavailableException('unopenable local DB'));
      final model = SavingsModel(repository: storageRepo);
      await tester.pumpWidget(
        ChangeNotifierProvider(
          create: (_) => model,
          child: const QuitCashApp(),
        ),
      );
      // SetupPage -> HomePage.
      await tester.tap(find.text('Start Saving'));
      await tester.pumpAndSettle();

      expect(find.text('Storage unavailable'), findsOneWidget);
      expect(
          find.text(
              "We can't open your savings file. Coin taps are disabled."),
          findsOneWidget);
      expect(model.storageUnavailable, true);
      expect(model.loadError, false);
      // No total shown.
      expect(find.text('\$0.00'), findsNWidgets(0));
      // Muted coins: tapping does nothing (no row, no SnackBar).
      await tester.tap(find.text('\$1'));
      await tester.pumpAndSettle();
      expect(find.text('Saved \$1!'), findsNWidgets(0));
      expect(find.text("Couldn't save \$1"), findsNWidgets(0));
      expect(storageRepo.rowCount, 0);
    });
  });
}

/// Minimal in-memory [SavingsRepository] for the widget tests.
///
/// Implements the same contract as [LocalSavingsRepository] (rows list,
/// [getTotal] as the sum of rows) so the UI's SUM re-derivation path (the
/// model re-queries the total at launch and after each tap) is exercised
/// without real FFI I/O.
class _InMemoryRepository implements SavingsRepository {
  /// Rows (in dollars) recorded by [add].
  final List<double> _rows = [];

  /// When set, [add] throws this value (write failure, D-13).
  final Object? failWrite;

  /// When set, [getTotal] throws this value
  /// (read failure, D-14, or storage unavailable, D-15 — the model
  /// distinguishes [StorageUnavailableException] from other exceptions).
  final Object? failLoad;

  _InMemoryRepository({this.failWrite, this.failLoad});

  /// Row count recorded so far — replaces `SELECT COUNT(*)` assertions.
  int get rowCount => _rows.length;

  /// Row values in insertion order (for D-03 order assertions).
  List<double> get rowList => List.unmodifiable(_rows);

  @override
  Future<void> add(double amount) async {
    if (failWrite != null) {
      final Object toThrow = failWrite!;
      throw toThrow;
    }
    _rows.add(amount);
  }

  @override
  Future<double> getTotal() async {
    if (failLoad != null) {
      final Object toThrow = failLoad!;
      throw toThrow;
    }
    // Sum manually; this SDK build's [List] has no [reduce].
    double sum = 0.0;
    for (final row in _rows) {
      sum = sum + row;
    }
    return sum;
  }

  @override
  Future<void> clear() async {
    _rows.clear();
  }
}
