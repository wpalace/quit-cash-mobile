import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../game/progress.dart';
import '../../state/savings_model.dart';
import '../palette.dart';
import 'home_screen.dart' show money;

class TrophiesScreen extends StatelessWidget {
  const TrophiesScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final model = context.watch<SavingsModel>();
    final p = model.progress;
    final unlocked = p.unlocked;
    final next = achievements
        .where((a) => !unlocked.contains(a.id))
        .firstOrNull;
    final text = Theme.of(context).textTheme;
    return SafeArea(
      child: CustomScrollView(
        slivers: [
          SliverPadding(
            padding: const EdgeInsets.all(16),
            sliver: SliverList.list(
              children: [
                Text(
                  'Trophy Room',
                  style: text.headlineMedium?.copyWith(
                    color: Palette.gold,
                    fontWeight: FontWeight.w900,
                  ),
                ),
                const SizedBox(height: 12),
                Row(
                  children: [
                    _Stat('Total', money(p.total)),
                    _Stat('Best streak', '${p.bestStreak} d'),
                    _Stat(
                      'Badges',
                      '${unlocked.length}/${achievements.length}',
                    ),
                  ],
                ),
                if (next != null) ...[
                  const SizedBox(height: 12),
                  Text(
                    'Next up: ${next.emoji} ${next.title} — ${next.description}',
                    style: const TextStyle(color: Colors.white70),
                  ),
                ],
                const SizedBox(height: 16),
              ],
            ),
          ),
          SliverPadding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            sliver: SliverGrid.count(
              crossAxisCount: 2,
              mainAxisSpacing: 12,
              crossAxisSpacing: 12,
              childAspectRatio: 1.1,
              children: [
                for (final a in achievements)
                  _Badge(a: a, unlocked: unlocked.contains(a.id)),
              ],
            ),
          ),
          const SliverToBoxAdapter(child: SizedBox(height: 24)),
        ],
      ),
    );
  }
}

class _Stat extends StatelessWidget {
  const _Stat(this.label, this.value);
  final String label;
  final String value;

  @override
  Widget build(BuildContext context) => Expanded(
    child: Container(
      margin: const EdgeInsets.only(right: 8),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Palette.card,
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        children: [
          Text(
            value,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 18,
              fontWeight: FontWeight.w900,
            ),
          ),
          Text(
            label,
            style: const TextStyle(color: Colors.white60, fontSize: 12),
          ),
        ],
      ),
    ),
  );
}

class _Badge extends StatelessWidget {
  const _Badge({required this.a, required this.unlocked});
  final Achievement a;
  final bool unlocked;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: unlocked ? Palette.gold.withValues(alpha: 0.18) : Palette.card,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: unlocked ? Palette.gold : Colors.white12,
          width: 2,
        ),
      ),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Opacity(
            opacity: unlocked ? 1 : 0.25,
            child: Text(
              unlocked ? a.emoji : '🔒',
              style: const TextStyle(fontSize: 40),
            ),
          ),
          const SizedBox(height: 6),
          Text(
            a.title,
            textAlign: TextAlign.center,
            style: TextStyle(
              color: unlocked ? Palette.goldLight : Colors.white54,
              fontWeight: FontWeight.w900,
            ),
          ),
          Text(
            a.description,
            textAlign: TextAlign.center,
            style: const TextStyle(color: Colors.white54, fontSize: 12),
          ),
        ],
      ),
    );
  }
}
