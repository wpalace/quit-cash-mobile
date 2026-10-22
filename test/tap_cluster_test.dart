import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:quit_cash_mobile/data/repositories/in_memory_savings_repository.dart';
import 'package:quit_cash_mobile/data/repositories/prefs_savings_repository.dart';
import 'package:quit_cash_mobile/data/repositories/savings_repository.dart';
import 'package:quit_cash_mobile/domain/models/goal.dart';
import 'package:quit_cash_mobile/domain/models/save_entry.dart';
import 'package:quit_cash_mobile/domain/models/tap_cluster.dart';
import 'package:quit_cash_mobile/ui/core/view_models/savings_view_model.dart';
import 'package:quit_cash_mobile/utils/money.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:shared_preferences_platform_interface/in_memory_shared_preferences_async.dart';
import 'package:shared_preferences_platform_interface/shared_preferences_async_platform_interface.dart';

final t0 = DateTime(2026, 10, 21, 19);
Duration ms(int v) => Duration(milliseconds: v);

/// View model over [repo] with a clock the test moves by hand.
class Rig {
  Rig(this.repo)
    : model = SavingsViewModel(repository: repo, clock: () => _now);
  static DateTime _now = t0;
  final SavingsRepository repo;
  final SavingsViewModel model;

  set now(DateTime t) => _now = t;
  Future<void> tapAt(Duration after, double dollars) async {
    _now = t0.add(after);
    await model.addSavings(dollars);
  }

  List<int> get cents => [for (final e in model.entries) e.cents];
}

Future<Rig> rig([InMemorySavingsRepository? repo]) async {
  final r = Rig(repo ?? InMemorySavingsRepository.withGoal('Smoking'));
  r.now = t0;
  await Future<void>.delayed(Duration.zero);
  return r;
}

void main() {
  setUp(() {
    SharedPreferencesAsyncPlatform.instance =
        InMemorySharedPreferencesAsync.empty();
  });

  group('window (default 60 s)', () {
    test('default is 60 s', () async {
      final r = await rig();
      expect(r.model.tapWindowSeconds, 60);
      expect(defaultTapWindow, const Duration(seconds: 60));
    });

    test('59.9 s joins, 60.1 s does not', () async {
      final r = await rig();
      await r.tapAt(Duration.zero, 5);
      await r.tapAt(ms(59900), 1);
      expect(r.cents, [600]);
      await r.tapAt(ms(59900 + 60100), 1);
      expect(r.cents, [600, 100]);
    });

    test('exactly 60 s joins (inclusive)', () async {
      final r = await rig();
      await r.tapAt(Duration.zero, 5);
      await r.tapAt(ms(60000), 1);
      expect(r.cents, [600]);
    });

    test('sliding: each tap extends the window', () async {
      final r = await rig();
      for (var i = 0; i < 4; i++) {
        await r.tapAt(ms(50000 * i), 1);
      }
      expect(r.cents, [400]);
    });

    test(r'$5 + $1 + $1 is one $7 record at the FIRST tap time', () async {
      final r = await rig();
      await r.tapAt(ms(1000), 5);
      await r.tapAt(ms(3000), 1);
      await r.tapAt(ms(4000), 1);
      expect(r.model.entries, hasLength(1));
      expect(r.model.entries.single.cents, 700);
      expect(r.model.entries.single.at, t0.add(ms(1000)));
      expect(r.model.progress.totalCents, 700);
    });

    test('levels and badges still react per tap', () async {
      final r = await rig();
      await r.tapAt(Duration.zero, 0.5);
      final c1 = await r.model.addSavings(0.5);
      expect(c1?.newLevel, 1);
      final c2 = await r.model.addSavings(9);
      expect(c2?.badges.map((b) => b.id), ['ten']);
      expect(r.cents, [1000]);
    });

    test('a cluster never exceeds the per-record max', () async {
      final r = await rig();
      await r.tapAt(Duration.zero, 9999);
      await r.tapAt(ms(1000), 1);
      expect(r.cents, [999900, 100]);
    });
  });

  group('configurable window', () {
    test('10 s: 9.9 s joins, 10.1 s does not', () async {
      final r = await rig();
      await r.model.setTapWindowSeconds(10);
      await r.tapAt(Duration.zero, 5);
      await r.tapAt(ms(9900), 1);
      await r.tapAt(ms(9900 + 10100), 1);
      expect(r.cents, [600, 100]);
    });

    test('5 min joins a tap 4 min later', () async {
      final r = await rig();
      await r.model.setTapWindowSeconds(300);
      await r.tapAt(Duration.zero, 5);
      await r.tapAt(const Duration(minutes: 4), 1);
      expect(r.cents, [600]);
    });

    test('choice is saved; unknown values fall back to 60 s', () async {
      final repo = InMemorySavingsRepository.withGoal('Smoking');
      final r = await rig(repo);
      await r.model.setTapWindowSeconds(120);
      expect(repo.numbers[SavingsViewModel.tapWindowKey], 120);
      final again = SavingsViewModel(repository: repo);
      await Future<void>.delayed(Duration.zero);
      expect(again.tapWindowSeconds, 120);
      repo.numbers[SavingsViewModel.tapWindowKey] = 7;
      final bad = SavingsViewModel(repository: repo);
      await Future<void>.delayed(Duration.zero);
      expect(bad.tapWindowSeconds, 60);
      expect(tapWindowChoices.map(tapWindowLabel), [
        '10s',
        '30s',
        '60s',
        '2 min',
        '5 min',
      ]);
    });
  });

  test('switching goals closes the cluster', () async {
    final r = await rig();
    await r.tapAt(Duration.zero, 5);
    final other = await r.model.addGoal('Vaping');
    await r.tapAt(ms(1000), 1);
    expect(r.cents, [100]);
    await r.model.switchGoal('g1');
    await r.tapAt(ms(2000), 1);
    expect(r.cents, [500, 100]);
    await r.model.switchGoal(other.id);
    await r.tapAt(ms(3000), 1);
    expect(r.cents, [100, 100]);
  });

  test('persistence mid-cluster: every tap is on disk at once', () async {
    // Use the real on-device repository.
    final prefsRepo = PrefsSavingsRepository();
    await prefsRepo.saveGoals([const Goal(id: 'g1', habit: 'Smoking')]);
    await prefsRepo.saveActiveGoal('g1');
    final live = Rig(prefsRepo);
    await Future<void>.delayed(const Duration(milliseconds: 10));
    await live.tapAt(Duration.zero, 5);
    await live.tapAt(ms(2000), 1);
    // "Kill" the app now: a fresh model reads what is on disk.
    final after = SavingsViewModel(
      repository: PrefsSavingsRepository(),
      clock: () => t0.add(ms(3000)), // within the window of the last tap
    );
    await Future<void>.delayed(const Duration(milliseconds: 10));
    expect(after.entries.map((e) => (e.cents, e.at)), [(600, t0)]);
    // The relaunched app has no open cluster: its next tap is a new record.
    await after.addSavings(1);
    expect(after.entries.map((e) => e.cents), [600, 100]);
  });

  group('edit and delete', () {
    test(
      'edit to a value with cents; total, level, badges recompute',
      () async {
        final r = await rig();
        await r.tapAt(Duration.zero, 5);
        await r.tapAt(ms(1000), 1);
        await r.tapAt(ms(2000), 1);
        final id = r.model.entries.single.id;
        expect(await r.model.editEntry(id, cents: 850), isTrue);
        expect(r.model.progress.totalCents, 850);
        expect(r.model.entries.single.at, t0); // time kept
        await r.tapAt(ms(3000), 20);
        expect(r.model.progress.level, 2);
        expect(r.model.progress.unlocked, contains('twentyfive'));
        // Editing down can lose a level and badges (derived from history).
        final big = r.model.entries.last.id;
        await r.model.editEntry(big, cents: 100);
        expect(r.model.progress.totalCents, 950);
        expect(r.model.progress.level, 1);
        expect(r.model.progress.unlocked, isNot(contains('twentyfive')));
      },
    );

    test('edit can move the time; rejects invalid amounts', () async {
      final r = await rig();
      await r.tapAt(Duration.zero, 5);
      final id = r.model.entries.single.id;
      final when = DateTime(2026, 10, 1, 8, 30);
      expect(await r.model.editEntry(id, cents: 500, at: when), isTrue);
      expect(r.model.entries.single.at, when);
      expect(await r.model.editEntry(id, cents: 0), isFalse);
      expect(await r.model.editEntry(id, cents: maxRecordCents + 1), isFalse);
      expect(await r.model.editEntry('nope', cents: 100), isFalse);
    });

    test('an edit closes the cluster', () async {
      final r = await rig();
      await r.tapAt(Duration.zero, 5);
      await r.model.editEntry(r.model.entries.single.id, cents: 700);
      await r.tapAt(ms(1000), 1);
      expect(r.cents, [700, 100]);
    });

    test('delete then undo restores the record and the total', () async {
      final repo = InMemorySavingsRepository.withGoal('Smoking');
      final r = await rig(repo);
      await r.tapAt(Duration.zero, 20);
      await r.tapAt(const Duration(hours: 1), 5);
      final first = r.model.entries.first;
      final removed = await r.model.deleteEntry(first.id);
      expect(removed?.cents, 2000);
      expect(r.model.progress.totalCents, 500);
      expect(r.model.progress.level, 1);
      expect(repo.entries['g1'], hasLength(1));
      await r.model.restoreEntry(first);
      expect(r.model.progress.totalCents, 2500);
      expect(r.model.progress.level, 2);
      expect(repo.entries['g1']?.map((e) => e.id), containsAll([first.id]));
      // Undo twice is harmless.
      await r.model.restoreEntry(first);
      expect(r.model.entries, hasLength(2));
    });

    test('edits and deletes persist in the on-device store', () async {
      final repo = PrefsSavingsRepository();
      final at = DateTime(2026, 1, 1);
      final a = SaveEntry(id: 'a', kind: EntryKind.save, cents: 500, at: at);
      final b = SaveEntry(id: 'b', kind: EntryKind.save, cents: 700, at: at);
      await repo.append('g', a);
      await repo.append('g', b);
      await repo.update('g', b.copyWith(cents: 850));
      await repo.remove('g', 'a');
      final rows = (await PrefsSavingsRepository().loadAll('g')).valueOrNull;
      expect(rows?.map((r) => (r.id, r.cents)), [('b', 850)]);
    });
  });

  group('parseCents', () {
    test('accepts dollars with up to two decimals', () {
      expect(parseCents('8'), 800);
      expect(parseCents('8.5'), 850);
      expect(parseCents(r'$8.50'), 850);
      expect(parseCents(' 1,000.05 '), 100005);
      expect(parseCents('.75'), 75);
      expect(parseCents('9999.99'), maxRecordCents);
    });

    test('rejects zero, negatives, too many decimals and too much', () {
      for (final s in [
        '',
        '0',
        '0.00',
        '-1',
        '8.505',
        'abc',
        '10000',
        '1.2.3',
      ]) {
        expect(parseCents(s), isNull, reason: s);
      }
    });
  });

  group('migration of per-tap history', () {
    SaveEntry tap(int seconds, int cents) => SaveEntry(
      kind: EntryKind.save,
      cents: cents,
      at: t0.add(Duration(seconds: seconds)),
    );

    test('clusterTaps uses 60 s by default and keeps the total', () {
      final taps = [
        tap(0, 500),
        tap(30, 100),
        tap(90, 100), // 60 s after the previous tap: joins
        tap(151, 2000), // 61 s: new record
        tap(10000, 1),
      ];
      final out = clusterTaps(taps.reversed.toList());
      expect(out.map((e) => (e.cents, e.at)), [
        (700, t0),
        (2000, t0.add(const Duration(seconds: 151))),
        (1, t0.add(const Duration(seconds: 10000))),
      ]);
      int sum(List<SaveEntry> l) => l.fold(0, (s, e) => s + e.cents);
      expect(sum(out), sum(taps));
    });

    test('stored v1 taps become v2 records on first load', () async {
      final rows = [
        for (final t in [
          tap(0, 500),
          tap(20, 100),
          tap(45, 100),
          tap(500, 300),
        ])
          t.toJson()..remove('id'),
        {'k': 'checkIn', 'c': 0, 't': t0.millisecondsSinceEpoch},
      ];
      SharedPreferencesAsyncPlatform.instance =
          InMemorySharedPreferencesAsync.withData({
            PrefsSavingsRepository.legacyGoalEntriesKey('g1'): jsonEncode(rows),
          });
      final prefs = SharedPreferencesAsync();
      final repo = PrefsSavingsRepository(prefs: prefs);
      final out = (await repo.loadAll('g1')).valueOrNull ?? const [];
      expect(out.map((e) => e.cents), [700, 300]);
      expect(out.first.at, t0);
      expect(
        await prefs.getString(
          PrefsSavingsRepository.legacyGoalEntriesKey('g1'),
        ),
        isNull,
      );
      final again = (await PrefsSavingsRepository().loadAll('g1')).valueOrNull;
      expect(again?.map((e) => (e.id, e.cents)), [
        for (final e in out) (e.id, e.cents),
      ]);
    });
  });
}
