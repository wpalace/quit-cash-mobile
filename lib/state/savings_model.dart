import 'package:flutter/foundation.dart';

import '../data/save_entry.dart';
import '../data/savings_repository.dart';
import '../game/progress.dart';

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
  }) : _repo = repository,
       _clock = clock ?? DateTime.now {
    _load();
  }

  final SavingsRepository _repo;
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

  bool get isLoading => _loading;
  bool get loadError => _loadError;
  List<SaveEntry> get entries => _entries;
  Progress get progress => Progress.from(_entries, now: _clock());

  Future<void> _load() async {
    try {
      _entries = await _repo.loadAll();
      _habit = await _repo.loadHabit();
    } catch (e) {
      debugPrint('QuitCash: load failed: $e');
      _loadError = true;
    }
    _loading = false;
    notifyListeners();
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
