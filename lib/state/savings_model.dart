import 'dart:async';

import 'package:flutter/foundation.dart';

import '../data/save_entry.dart';
import '../data/savings_repository.dart';
import '../game/progress.dart';
import '../reminders/reminder_plan.dart';
import '../reminders/reminder_service.dart';

/// Events the UI celebrates once (level up, new badge).
class Celebration {
  const Celebration({this.newLevel, this.badges = const []});
  final int? newLevel;
  final List<Achievement> badges;
  bool get isEmpty => newLevel == null && badges.isEmpty;
}

class SavingsModel extends ChangeNotifier {
  SavingsModel({
    required SavingsRepository repository,
    DateTime Function()? clock,
    ReminderService reminders = const NoopReminderService(),
  }) : _repo = repository,
       _reminders = reminders,
       _clock = clock ?? DateTime.now {
    _load();
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
    await _repo.saveHabit(value);
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
    await _repo.saveReminder(f.name);
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
    try {
      await _reminders.schedule(f, streak: p.currentStreak, coins: p.coins);
    } catch (e) {
      debugPrint('QuitCash: reminder scheduling failed: $e');
    }
  }

  bool _showFifty = true;
  bool _showHundred = true;

  /// Settings: show the \$50 gold coin / \$100 ruby in the picker.
  /// Both default to on. Hiding never touches saved history.
  bool get showFifty => _showFifty;
  bool get showHundred => _showHundred;

  static const showFiftyKey = 'show50';
  static const showHundredKey = 'show100';

  Future<void> setShowFifty(bool value) async {
    _showFifty = value;
    notifyListeners();
    await _repo.saveFlag(showFiftyKey, value);
  }

  Future<void> setShowHundred(bool value) async {
    _showHundred = value;
    notifyListeners();
    await _repo.saveFlag(showHundredKey, value);
  }

  bool get isLoading => _loading;
  bool get loadError => _loadError;
  List<SaveEntry> get entries => _entries;
  Progress get progress => Progress.from(_entries, now: _clock());

  Future<void> _load() async {
    try {
      _entries = await _repo.loadAll();
      _habit = await _repo.loadHabit();
      _reminder = ReminderFrequency.tryParse(await _repo.loadReminder());
      _showFifty = await _repo.loadFlag(showFiftyKey) ?? true;
      _showHundred = await _repo.loadFlag(showHundredKey) ?? true;
    } catch (e) {
      debugPrint('QuitCash: load failed: $e');
      _loadError = true;
    }
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
    try {
      await _repo.append(e);
    } catch (err) {
      debugPrint('QuitCash: save failed: $err');
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
    await _repo.clear();
    _entries = const [];
    notifyListeners();
  }
}
