import 'dart:async';

import 'dart:developer' as developer;

import 'package:flutter/foundation.dart';
import 'package:quit_cash_mobile/data/repositories/savings_repository.dart';
import 'package:quit_cash_mobile/data/services/reminder_service.dart';
import 'package:quit_cash_mobile/domain/models/progress.dart';
import 'package:quit_cash_mobile/domain/models/reminder_plan.dart';
import 'package:quit_cash_mobile/domain/models/save_entry.dart';
import 'package:quit_cash_mobile/ui/core/themes/denominations.dart';
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

/// App-wide view model: savings, progress, settings and reminders.
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
  List<SaveEntry> _entries = const [];
  bool _loading = true;
  bool _loadError = false;

  String? _habit;
  String? get habit => _habit;

  Future<void> setHabit(String value) async {
    _habit = value;
    notifyListeners();
    _report('save habit', await _repo.saveHabit(value));
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
    final p = progress;
    await _reminders.schedule(f, streak: p.currentStreak, coins: p.coins);
  }

  bool _showFifty = false;
  bool _showHundred = false;

  /// Settings: show the \$50 sapphire coin / \$100 ruby in the picker.
  /// Both default to off (opt-in). Hiding never touches saved history.
  bool get showFifty => _showFifty;
  bool get showHundred => _showHundred;

  static const showFiftyKey = 'show50';
  static const showHundredKey = 'show100';

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
  List<Denomination> get pickerDenominations =>
      visibleDenominations(showFifty: _showFifty, showHundred: _showHundred);

  /// The denomination to show for a requested amount: the largest visible
  /// one at or below it (Settings may have hidden the requested one).
  Denomination denominationForPick(int dollars) {
    final visible = pickerDenominations;
    return visible.lastWhere(
      (d) => d.dollars <= dollars,
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

  bool get isLoading => _loading;
  bool get loadError => _loadError;
  List<SaveEntry> get entries => _entries;
  Progress get progress => Progress.from(_entries, now: _clock());

  Future<void> _load() async {
    _entries = _orElse('load history', await _repo.loadAll(), const []);
    _habit = _orElse('load habit', await _repo.loadHabit(), null);
    _reminder = ReminderFrequency.tryParse(
      _orElse('load reminder', await _repo.loadReminder(), null),
    );
    _showFifty =
        _orElse('load setting', await _repo.loadFlag(showFiftyKey), null) ??
        false;
    _showHundred =
        _orElse('load setting', await _repo.loadFlag(showHundredKey), null) ??
        false;
    _loading = false;
    notifyListeners();
    // Refresh the queued batch (and its streak/coin copy) on every launch.
    await _reschedule();
  }

  Future<Celebration?> addSavings(double dollars) async {
    if (!dollars.isFinite || dollars <= 0 || dollars > 9999) {
      throw ArgumentError.value(dollars, 'dollars', 'must be in (0, 9999]');
    }
    return _record(
      SaveEntry(
        kind: EntryKind.save,
        cents: (dollars * 100).round(),
        at: _clock(),
      ),
    );
  }

  /// Daily check-in. Returns null if already done today.
  Future<Celebration?> checkIn() async {
    if (progress.checkedInToday) return null;
    return _record(SaveEntry(kind: EntryKind.checkIn, cents: 0, at: _clock()));
  }

  Future<Celebration?> _record(SaveEntry e) async {
    final before = progress;
    if (await _repo.append(e) case Error(:final error)) {
      _logFailure('save entry', error);
      return null;
    }
    _entries = [..._entries, e];
    notifyListeners();
    if (e.kind == EntryKind.checkIn) unawaited(_reschedule());
    final after = progress;
    final newIds = after.unlocked.difference(before.unlocked);
    return Celebration(
      newLevel: after.level > before.level ? after.level : null,
      badges: [
        for (final a in achievements)
          if (newIds.contains(a.id)) a,
      ],
    );
  }

  Future<void> reset() async {
    if (await _repo.clear() case Error(:final error)) {
      _logFailure('reset', error);
      return;
    }
    _entries = const [];
    notifyListeners();
  }
}
