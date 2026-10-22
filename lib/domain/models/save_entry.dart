/// One recorded event. Amounts are integer cents to avoid float drift.
enum EntryKind { save, checkIn }

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

  factory SaveEntry.fromJson(Map<String, dynamic> json) => SaveEntry(
    kind: EntryKind.values.byName(json['k'] as String),
    cents: json['c'] as int,
    at: DateTime.fromMillisecondsSinceEpoch(json['t'] as int),
  );
}
