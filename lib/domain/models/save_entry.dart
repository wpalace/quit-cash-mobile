/// One recorded event. Amounts are integer cents to avoid float drift.
///
/// Only savings are recorded. Older builds also stored daily check-ins
/// (`'k': 'checkIn'`, zero cents); [SaveEntry.tryFromJson] skips them.
enum EntryKind { save }

class SaveEntry {
  const SaveEntry({required this.kind, required this.cents, required this.at});

  final EntryKind kind;
  final int cents;
  final DateTime at;

  double get dollars => cents / 100.0;

  Map<String, Object> toJson() => {
    'k': kind.name,
    'c': cents,
    't': at.millisecondsSinceEpoch,
  };

  /// Parses one stored row, or returns null for a legacy non-save row
  /// (such as an old daily check-in) that never counted as dollars.
  static SaveEntry? tryFromJson(Map<String, Object?> json) =>
      json['k'] == EntryKind.save.name ? SaveEntry.fromJson(json) : null;

  factory SaveEntry.fromJson(Map<String, Object?> json) => SaveEntry(
    kind: EntryKind.values.byName(json['k'] as String),
    cents: json['c'] as int,
    at: DateTime.fromMillisecondsSinceEpoch(json['t'] as int),
  );
}
