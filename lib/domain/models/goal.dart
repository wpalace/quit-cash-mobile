import 'package:flutter/foundation.dart';
import 'package:quit_cash_mobile/domain/models/habits.dart';

/// One habit being kicked or curbed. Each goal has its own savings history,
/// so its own total, level and badges.
@immutable
class Goal {
  const Goal({required this.id, required this.habit, this.label, this._emoji});

  final String id;

  /// Habit name from the habit picker (for example 'Smoking').
  final String habit;

  /// Optional user label (for example 'Weekend beers').
  final String? label;

  final String? _emoji;

  String get emoji => _emoji ?? emojiForHabit(habit);

  /// What the UI shows: the label if set, otherwise the habit.
  String get title {
    final l = label?.trim();
    return l == null || l.isEmpty ? habit : l;
  }

  Map<String, Object> toJson() => {
    'id': id,
    'habit': habit,
    if (label case final l?) 'label': l,
    if (_emoji case final e?) 'emoji': e,
  };

  factory Goal.fromJson(Map<String, Object?> json) => Goal(
    id: json['id'] as String,
    habit: json['habit'] as String,
    label: json['label'] as String?,
    emoji: json['emoji'] as String?,
  );

  @override
  bool operator ==(Object other) =>
      other is Goal &&
      other.id == id &&
      other.habit == habit &&
      other.label == label &&
      other._emoji == _emoji;

  @override
  int get hashCode => Object.hash(id, habit, label, _emoji);
}
