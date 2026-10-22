// Screenshot-only entry point with a seeded, in-memory DEMO dataset.
// Not shipped: the app's real entry point is lib/main.dart, which starts
// empty. Build: flutter build web --release -t tool/demo_main.dart -o build/web-demo
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:quit_cash_mobile/data/repositories/in_memory_savings_repository.dart';
import 'package:quit_cash_mobile/domain/models/goal.dart';
import 'package:quit_cash_mobile/domain/models/save_entry.dart';
import 'package:quit_cash_mobile/ui/app/quit_cash_app.dart';
import 'package:quit_cash_mobile/ui/core/view_models/savings_view_model.dart';

/// About 14 months of believable history for two goals: evening cigarette
/// cravings (more on Fri/Sat) and weekday morning coffees. Seeded, so every
/// run looks the same relative to today.
InMemorySavingsRepository demoRepository(DateTime now) {
  final rnd = math.Random(7);
  final repo = InMemorySavingsRepository()
    ..reminder = 'daily'
    ..active = 'smoking';
  repo.goals.addAll(const [
    Goal(id: 'smoking', habit: 'Smoking'),
    Goal(id: 'coffee', habit: 'Fancy coffee', label: 'Lattes'),
  ]);
  final smoking = <SaveEntry>[], coffee = <SaveEntry>[];
  var n = 0;
  SaveEntry rec(DateTime at, int cents) =>
      SaveEntry(id: 'demo${n++}', kind: EntryKind.save, cents: cents, at: at);
  for (var d = 430; d >= 0; d--) {
    final day = DateTime(now.year, now.month, now.day - d);
    final weekend = day.weekday >= DateTime.friday;
    // Saving grows as the habit takes hold.
    final ramp = 0.45 + 0.4 * (430 - d) / 430;
    if (rnd.nextDouble() < ramp + (weekend ? 0.1 : 0)) {
      final hour = rnd.nextDouble() < 0.7
          ? 17 + rnd.nextInt(5)
          : 12 + rnd.nextInt(5);
      final at = day.add(Duration(hours: hour, minutes: rnd.nextInt(60)));
      if (!at.isAfter(now)) {
        smoking.add(rec(at, [500, 600, 700, 1000, 1200][rnd.nextInt(5)]));
      }
    }
    if (day.weekday <= DateTime.friday && rnd.nextDouble() < 0.5) {
      final at = day.add(Duration(hours: 8, minutes: rnd.nextInt(80)));
      if (!at.isAfter(now)) {
        coffee.add(rec(at, [450, 525, 575, 650][rnd.nextInt(4)]));
      }
    }
  }
  repo.entries['smoking'] = smoking;
  repo.entries['coffee'] = coffee;
  return repo;
}

void main() {
  final repo = demoRepository(DateTime.now());
  runApp(
    ChangeNotifierProvider(
      create: (_) => SavingsViewModel(repository: repo),
      child: const QuitCashApp(initialTab: 2),
    ),
  );
}
