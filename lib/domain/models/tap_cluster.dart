import 'package:quit_cash_mobile/domain/models/save_entry.dart';

/// Choices for Settings > "Group taps within", in seconds.
const tapWindowChoices = [10, 30, 60, 120, 300];

/// Default grouping window (also used to migrate old per-tap history).
const defaultTapWindow = Duration(seconds: 60);

/// Whether a tap at [tap] joins a cluster whose latest tap was at
/// [lastTap]: a sliding window, inclusive at exactly [window].
bool joinsCluster(DateTime lastTap, DateTime tap, Duration window) {
  final gap = tap.difference(lastTap);
  return !gap.isNegative && gap <= window;
}

/// Merges per-tap rows into clusters: each record keeps the first tap's
/// time and id and sums the cents. The total is unchanged.
List<SaveEntry> clusterTaps(
  List<SaveEntry> taps, {
  Duration window = defaultTapWindow,
}) {
  final sorted = [...taps]..sort((a, b) => a.at.compareTo(b.at));
  final out = <SaveEntry>[];
  DateTime? lastTap;
  for (final t in sorted) {
    final prev = lastTap;
    if (out.isNotEmpty && prev != null && joinsCluster(prev, t.at, window)) {
      out[out.length - 1] = out.last.copyWith(cents: out.last.cents + t.cents);
    } else {
      out.add(t);
    }
    lastTap = t.at;
  }
  return out;
}

/// Label for a window choice in seconds (for example '2 min').
String tapWindowLabel(int seconds) =>
    seconds <= 60 ? '${seconds}s' : '${seconds ~/ 60} min';
