import 'dart:async';

import 'dart:developer' as developer;

import 'package:flutter/foundation.dart';
import 'package:quit_cash_mobile/data/repositories/savings_repository.dart';
import 'package:quit_cash_mobile/data/services/reminder_service.dart';
import 'package:quit_cash_mobile/domain/models/goal.dart';
import 'package:quit_cash_mobile/domain/models/progress.dart';
import 'package:quit_cash_mobile/domain/models/reminder_plan.dart';
import 'package:quit_cash_mobile/domain/models/save_entry.dart';
import 'package:quit_cash_mobile/domain/models/tap_cluster.dart';
import 'package:quit_cash_mobile/ui/core/themes/denominations.dart';
import 'package:quit_cash_mobile/utils/money.dart';
import 'package:quit_cash_mobile/utils/result.dart';

/// Events the UI celebrates once (level up, new badge).
class Celebration {
  const Celebration({this.newLevel, this.badges = const []});
  final int? newLevel;
  final List<Achievement> badges;
  bool get isEmpty => newLevel == null && badges.isEmpty;
}

void _logFailure(String what, Object error) =>
    developer.log('$what failed', name: 'quitcash', error: error);

/// App-wide view model: goals, the active goal's savings and progress,
/// and the global settings and reminders.
class SavingsViewModel extends ChangeNotifier {
  SavingsViewModel({
    required SavingsRepository repository,
    DateTime Function()? clock,
    this._reminders = const NoopReminderService(),
  }) : _repo = repository,
       _clock = clock ?? DateTime.now {
    unawaited(_load());
  }

  final SavingsRepository _repo;
  final ReminderService _reminders;
  final DateTime Function() _clock;
  bool _loading = true;
  bool _loadError = false;

  List<Goal> _goals = const [];
  String? _activeId;
  final Map<String, List<SaveEntry>> _entriesByGoal = {};
  int _nextId = 0;

  /// All goals in creation order. Empty means first-install onboarding.
  List<Goal> get goals => _goals;

  /// The goal shown on Bank and Trophies (null only when there are none).
  Goal? get activeGoal {
    for (final g in _goals) {
      if (g.id == _activeId) return g;
    }
    return _goals.firstOrNull;
  }

  /// Habit of the active goal; null until the first goal exists.
  String? get habit => activeGoal?.habit;

  List<SaveEntry> entriesFor(String goalId) =>
      _entriesByGoal[goalId] ?? const [];

  Progress progressFor(String goalId) => Progress.from(entriesFor(goalId));

  /// Records of every goal together (Trends "All goals").
  List<SaveEntry> get allEntries => [
    for (final g in _goals) ...entriesFor(g.id),
  ];

  /// Clock used for "today" in reports (injectable for tests).
  DateTime now() => _clock();

  /// Dollars saved across every goal (used by reminder copy).
  int get totalCentsAllGoals =>
      _goals.fold(0, (sum, g) => sum + progressFor(g.id).totalCents);

  String _newId() {
    String id;
    do {
      id = 'g${_clock().microsecondsSinceEpoch}${_nextId++}';
    } while (_goals.any((g) => g.id == id));
    return id;
  }

  /// Creates a goal and makes it active.
  Future<Goal> addGoal(String habit, {String? label}) async {
    final trimmed = label?.trim();
    final goal = Goal(
      id: _newId(),
      habit: habit,
      label: trimmed == null || trimmed.isEmpty ? null : trimmed,
    );
    _goals = [..._goals, goal];
    _entriesByGoal[goal.id] = const [];
    closeCluster();
    _activeId = goal.id;
    notifyListeners();
    _report('save goals', await _repo.saveGoals(_goals));
    _report('save active goal', await _repo.saveActiveGoal(goal.id));
    return goal;
  }

  Future<void> switchGoal(String id) async {
    if (id == activeGoal?.id || !_goals.any((g) => g.id == id)) return;
    closeCluster(); // switching goals ends the tap cluster
    _activeId = id;
    notifyListeners();
    _report('save active goal', await _repo.saveActiveGoal(id));
  }

  /// Deletes a goal and its history. If it was active, the first remaining
  /// goal becomes active; deleting the last goal returns to onboarding.
  /// Global settings (coins, reminder choice) are kept.
  Future<void> deleteGoal(String id) async {
    if (await _repo.clear(id) case Error(:final error)) {
      _logFailure('delete goal history', error);
      return;
    }
    final wasActive = activeGoal?.id == id;
    if (_cluster?.goalId == id) closeCluster();
    _goals = [
      for (final g in _goals)
        if (g.id != id) g,
    ];
    _entriesByGoal.remove(id);
    if (wasActive) _activeId = _goals.firstOrNull?.id;
    notifyListeners();
    _report('save goals', await _repo.saveGoals(_goals));
    if (wasActive) {
      _report('save active goal', await _repo.saveActiveGoal(_activeId));
    }
    unawaited(_reschedule());
  }

  ReminderFrequency? _reminder;

  /// Null until the user has chosen (existing users get a one-time prompt).
  ReminderFrequency? get reminder => _reminder;

  /// Store [f] and (re)schedule. Permission is requested only for a
  /// non-Never choice on a supported platform. Returns false only if the
  /// OS denied notifications.
  Future<bool> setReminder(ReminderFrequency f) async {
    _reminder = f;
    notifyListeners();
    _report('save reminder', await _repo.saveReminder(f.name));
    var granted = true;
    if (f.enabled && _reminders.supported) {
      granted = await _reminders.requestPermission();
    }
    await _reschedule();
    return granted;
  }

  Future<void> _reschedule() async {
    final f = _reminder;
    if (f == null) return;
    await _reminders.schedule(f, dollars: totalCentsAllGoals ~/ 100);
  }

  bool _showFifty = false;
  bool _showHundred = false;
  bool _showFiveHundred = false;

  /// Settings: show the \$50 sapphire coin / \$100 ruby / \$500 diamond in the picker.
  /// All three default to off (opt-in). Hiding never touches saved history.
  bool get showFifty => _showFifty;
  bool get showHundred => _showHundred;
  bool get showFiveHundred => _showFiveHundred;

  static const showFiftyKey = 'show50';
  static const showHundredKey = 'show100';
  static const showFiveHundredKey = 'show500';

  Future<void> setShowFifty(bool value) async {
    _showFifty = value;
    notifyListeners();
    _report('save setting', await _repo.saveFlag(showFiftyKey, value));
  }

  Future<void> setShowHundred(bool value) async {
    _showHundred = value;
    notifyListeners();
    _report('save setting', await _repo.saveFlag(showHundredKey, value));
  }

  /// Picker denominations after the Settings toggles.
  List<Denomination> get pickerDenominations => inChangeMode
      ? changeDenominations
      : visibleDenominations(
          showFifty: _showFifty,
          showHundred: _showHundred,
          showFiveHundred: _showFiveHundred,
        );

  static const showLevelsKey = 'showLevels';
  bool _showLevels = true;

  /// Settings: show levels (rank, progress bar, level-ups) for all goals.
  /// On by default. Levels derive from totals, so nothing is lost when off.
  bool get showLevels => _showLevels;

  Future<void> setShowLevels(bool value) async {
    _showLevels = value;
    notifyListeners();
    _report('save setting', await _repo.saveFlag(showLevelsKey, value));
  }

  static const changeKey = 'change';
  static const changeModeKey = 'changeMode';
  bool _changeEnabled = false;
  bool _changeMode = false;

  /// Settings: allow change coins (1¢–25¢). Off by default.
  bool get changeEnabled => _changeEnabled;

  /// The picker shows change coins. Always false while change is disabled;
  /// the last chosen mode is remembered for when it is enabled again.
  bool get inChangeMode => _changeEnabled && _changeMode;

  Future<void> setChangeEnabled(bool value) async {
    _changeEnabled = value;
    notifyListeners();
    _report('save setting', await _repo.saveFlag(changeKey, value));
  }

  Future<void> setChangeMode(bool value) async {
    _changeMode = value;
    notifyListeners();
    _report('save setting', await _repo.saveFlag(changeModeKey, value));
  }

  /// The denomination to show for a requested amount in cents: the largest
  /// visible one at or below it (Settings may have hidden the requested
  /// one, or the picker mode may have changed).
  Denomination denominationForPick(int cents) {
    final visible = pickerDenominations;
    return visible.lastWhere(
      (d) => d.cents <= cents,
      orElse: () => visible.first,
    );
  }

  /// Logs a failed write; the in-memory state stays as the user set it.
  void _report(String what, Result<void> r) {
    if (r case Error(:final error)) _logFailure(what, error);
  }

  /// Value of [r], or [fallback] (and a load error) on failure.
  T _orElse<T>(String what, Result<T> r, T fallback) {
    switch (r) {
      case Ok(:final value):
        return value;
      case Error(:final error):
        _logFailure(what, error);
        _loadError = true;
        return fallback;
    }
  }

  Future<void> setShowFiveHundred(bool value) async {
    _showFiveHundred = value;
    notifyListeners();
    _report('save setting', await _repo.saveFlag(showFiveHundredKey, value));
  }

  bool get isLoading => _loading;
  bool get loadError => _loadError;

  /// The active goal's history and progress.
  List<SaveEntry> get entries => switch (activeGoal) {
    final g? => entriesFor(g.id),
    null => const [],
  };
  Progress get progress => Progress.from(entries);

  Future<void> _load() async {
    _goals = _orElse('load goals', await _repo.loadGoals(), const []);
    _activeId = _orElse('load active goal', await _repo.loadActiveGoal(), null);
    for (final g in _goals) {
      _entriesByGoal[g.id] = _orElse(
        'load history',
        await _repo.loadAll(g.id),
        const [],
      );
    }
    _reminder = ReminderFrequency.tryParse(
      _orElse('load reminder', await _repo.loadReminder(), null),
    );
    _showFifty =
        _orElse('load setting', await _repo.loadFlag(showFiftyKey), null) ??
        false;
    _showHundred =
        _orElse('load setting', await _repo.loadFlag(showHundredKey), null) ??
        false;
    _showFiveHundred =
        _orElse(
          'load setting',
          await _repo.loadFlag(showFiveHundredKey),
          null,
        ) ??
        false;
    _changeEnabled =
        _orElse('load setting', await _repo.loadFlag(changeKey), null) ?? false;
    _changeMode =
        _orElse('load setting', await _repo.loadFlag(changeModeKey), null) ??
        false;
    _showLevels =
        _orElse('load setting', await _repo.loadFlag(showLevelsKey), null) ??
        true;
    _tapWindowSeconds = _validWindow(
      _orElse('load setting', await _repo.loadNumber(tapWindowKey), null),
    );
    _loading = false;
    notifyListeners();
    // Refresh the queued batch (and its dollar copy) on every launch.
    await _reschedule();
  }

  static const tapWindowKey = 'tapWindowSeconds';
  int _tapWindowSeconds = defaultTapWindow.inSeconds;

  /// Settings: taps closer together than this join one history record.
  int get tapWindowSeconds => _tapWindowSeconds;

  static int _validWindow(int? s) =>
      tapWindowChoices.contains(s) ? s ?? 0 : defaultTapWindow.inSeconds;

  Future<void> setTapWindowSeconds(int seconds) async {
    _changeEnabled =
        _orElse('load setting', await _repo.loadFlag(changeKey), null) ?? false;
    _changeMode =
        _orElse('load setting', await _repo.loadFlag(changeModeKey), null) ??
        false;
    _tapWindowSeconds = _validWindow(seconds);
    notifyListeners();
    _report(
      'save setting',
      await _repo.saveNumber(tapWindowKey, _tapWindowSeconds),
    );
  }

  /// The open tap cluster: goal, record id and time of its latest tap.
  ({String goalId, String entryId, DateTime lastTap})? _cluster;
  int _nextEntry = 0;

  /// Ends the open cluster; the next tap starts a new record.
  void closeCluster() => _cluster = null;

  /// One tap. Joins the open cluster if it is for the active goal and the
  /// previous tap was within the window (the record keeps the first tap's
  /// time and is updated in place); otherwise writes a new record at once.
  /// Either way the record is persisted before this returns, so killing
  /// the app mid-cluster loses nothing. Celebrations are per tap.
  Future<Celebration?> addSavings(double dollars) async {
    if (!dollars.isFinite || dollars <= 0 || dollars > 9999) {
      throw ArgumentError.value(dollars, 'dollars', 'must be in (0, 9999]');
    }
    return addCents((dollars * 100).round());
  }

  /// One tap worth [cents] (1¢ to \$9,999). Dollar and change taps join
  /// the same cluster.
  Future<Celebration?> addCents(int cents) async {
    if (cents <= 0 || cents > 999900) {
      throw ArgumentError.value(cents, 'cents', 'must be in [1, 999900]');
    }
    final goal = activeGoal;
    if (goal == null) return null;
    final now = _clock();
    final before = progress;
    final rows = entriesFor(goal.id);
    final c = _cluster;
    final i = c == null || c.goalId != goal.id
        ? -1
        : rows.indexWhere((r) => r.id == c.entryId);
    final Result<void> written;
    final SaveEntry record;
    if (c != null &&
        i >= 0 &&
        rows[i].cents + cents <= maxRecordCents &&
        joinsCluster(c.lastTap, now, Duration(seconds: _tapWindowSeconds))) {
      record = rows[i].copyWith(cents: rows[i].cents + cents);
      written = await _repo.update(goal.id, record);
      if (written is Ok<void>) {
        _entriesByGoal[goal.id] = [...rows]..[i] = record;
      }
    } else {
      record = SaveEntry(
        id: 'e${now.microsecondsSinceEpoch}-${_nextEntry++}',
        kind: EntryKind.save,
        cents: cents,
        at: now,
      );
      written = await _repo.append(goal.id, record);
      if (written is Ok<void>) _entriesByGoal[goal.id] = [...rows, record];
    }
    if (written case Error(:final error)) {
      _logFailure('save entry', error);
      return null;
    }
    _cluster = (goalId: goal.id, entryId: record.id, lastTap: now);
    return _changed(before);
  }

  /// Notifies, refreshes reminder copy and reports what was newly earned.
  Celebration _changed(Progress before) {
    notifyListeners();
    // Reminder copy quotes the total, so refresh it.
    unawaited(_reschedule());
    // Levels off: badges are still earned (derived from dollars), but
    // nothing pops up, now or later.
    if (!_showLevels) return const Celebration();
    final after = progress;
    final newIds = after.unlocked.difference(before.unlocked);
    return Celebration(
      newLevel: _showLevels && after.level > before.level ? after.level : null,
      badges: [
        for (final a in achievements)
          if (newIds.contains(a.id)) a,
      ],
    );
  }

  /// Edits a record of the active goal. Total, level and badges are
  /// recomputed from history, so an edit down can drop them again.
  Future<bool> editEntry(String id, {required int cents, DateTime? at}) async {
    final goal = activeGoal;
    if (goal == null || cents <= 0 || cents > maxRecordCents) return false;
    final rows = entriesFor(goal.id);
    final i = rows.indexWhere((r) => r.id == id);
    if (i < 0) return false;
    final record = rows[i].copyWith(cents: cents, at: at);
    if (await _repo.update(goal.id, record) case Error(:final error)) {
      _logFailure('edit entry', error);
      return false;
    }
    closeCluster();
    _entriesByGoal[goal.id] = [...rows]..[i] = record;
    _changed(progress);
    return true;
  }

  /// Deletes a record of the active goal and returns it (for undo).
  Future<SaveEntry?> deleteEntry(String id) async {
    final goal = activeGoal;
    if (goal == null) return null;
    final rows = entriesFor(goal.id);
    final i = rows.indexWhere((r) => r.id == id);
    if (i < 0) return null;
    if (await _repo.remove(goal.id, id) case Error(:final error)) {
      _logFailure('delete entry', error);
      return null;
    }
    closeCluster();
    final removed = rows[i];
    _entriesByGoal[goal.id] = [...rows]..removeAt(i);
    _changed(progress);
    return removed;
  }

  /// Puts back a record removed by [deleteEntry] (undo).
  Future<void> restoreEntry(SaveEntry entry) async {
    final goal = activeGoal;
    if (goal == null) return;
    final rows = entriesFor(goal.id);
    if (rows.any((r) => r.id == entry.id)) return;
    if (await _repo.append(goal.id, entry) case Error(:final error)) {
      _logFailure('restore entry', error);
      return;
    }
    _entriesByGoal[goal.id] = [...rows, entry];
    _changed(progress);
  }

  /// Clears the active goal's history only. Other goals and settings stay.
  Future<void> reset() async {
    final goal = activeGoal;
    if (goal == null) return;
    if (await _repo.clear(goal.id) case Error(:final error)) {
      _logFailure('reset', error);
      return;
    }
    _entriesByGoal[goal.id] = const [];
    closeCluster();
    notifyListeners();
    unawaited(_reschedule());
  }
}
