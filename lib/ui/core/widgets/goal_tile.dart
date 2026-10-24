import 'package:flutter/material.dart';
import 'package:quit_cash_mobile/domain/models/goal.dart';
import 'package:quit_cash_mobile/domain/models/progress.dart';
import 'package:quit_cash_mobile/ui/core/themes/palette.dart';
import 'package:quit_cash_mobile/utils/money.dart';

/// One goal row: emoji, title, level and total. The active goal gets a gold
/// border and an ACTIVE tag. Used by the Goals tab and the quick switcher.
class GoalTile extends StatelessWidget {
  const GoalTile({
    super.key,
    required this.goal,
    required this.progress,
    required this.active,
    required this.onTap,
    this.onDelete,
    this.showLevels = true,
  });

  final Goal goal;
  final Progress progress;
  final bool active;
  final VoidCallback onTap;
  final VoidCallback? onDelete;
  final bool showLevels;

  @override
  Widget build(BuildContext context) {
    final onDelete = this.onDelete;
    return Material(
      color: active ? Palette.gold.withValues(alpha: 0.16) : Palette.card,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(18),
        side: BorderSide(
          color: active ? Palette.gold : Colors.transparent,
          width: 2,
        ),
      ),
      child: ListTile(
        key: Key('goal-${goal.id}'),
        onTap: onTap,
        contentPadding: const EdgeInsets.fromLTRB(16, 6, 4, 6),
        leading: Text(goal.emoji, style: const TextStyle(fontSize: 30)),
        title: _Title(goal: goal, active: active),
        subtitle: Text(
          showLevels
              ? 'LV ${progress.level} · ${money(progress.total)} saved'
              : '${money(progress.total)} saved',
          style: const TextStyle(color: Colors.white70),
        ),
        trailing: onDelete == null
            ? (active
                  ? const Icon(Icons.check_circle, color: Palette.gold)
                  : null)
            : IconButton(
                key: Key('delete-${goal.id}'),
                tooltip: 'Delete goal',
                icon: const Icon(Icons.delete_outline, color: Colors.white70),
                onPressed: onDelete,
              ),
      ),
    );
  }
}

class _Title extends StatelessWidget {
  const _Title({required this.goal, required this.active});
  final Goal goal;
  final bool active;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Flexible(
          child: Text(
            goal.title,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(
              color: Colors.white,
              fontWeight: FontWeight.w900,
              fontSize: 17,
            ),
          ),
        ),
        if (active) ...[
          const SizedBox(width: 8),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
            decoration: BoxDecoration(
              color: Palette.gold,
              borderRadius: BorderRadius.circular(8),
            ),
            child: const Text(
              'ACTIVE',
              style: TextStyle(
                color: Palette.outline,
                fontSize: 11,
                fontWeight: FontWeight.w900,
              ),
            ),
          ),
        ],
      ],
    );
  }
}
