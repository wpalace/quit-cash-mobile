import 'dart:async';

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:quit_cash_mobile/domain/models/goal.dart';
import 'package:quit_cash_mobile/ui/core/themes/palette.dart';
import 'package:quit_cash_mobile/ui/core/view_models/savings_view_model.dart';
import 'package:quit_cash_mobile/ui/core/widgets/goal_tile.dart';
import 'package:quit_cash_mobile/ui/goals/add_goal_screen.dart';
import 'package:quit_cash_mobile/utils/money.dart';

/// Opens Add goal.
void openAddGoal(BuildContext context) => unawaited(
  Navigator.of(context)
      .push(MaterialPageRoute<void>(builder: (_) => const AddGoalScreen())),
);

/// Goals tab: every goal with the active one marked. Tap to switch, trash
/// to delete (with confirmation), button to add.
class GoalsScreen extends StatelessWidget {
  const GoalsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final model = context.watch<SavingsViewModel>();
    final active = model.activeGoal;
    return SafeArea(
      child: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Text(
            'Goals',
            style: Theme.of(context).textTheme.headlineMedium
                ?.copyWith(color: Palette.gold, fontWeight: FontWeight.w900),
          ),
          const SizedBox(height: 4),
          Text(
            'Tap a goal to make it active. '
            '${money(model.totalCentsAllGoals / 100)} saved across all goals.',
            style: const TextStyle(color: Colors.white70),
          ),
          const SizedBox(height: 16),
          for (final g in model.goals) ...[
            GoalTile(
              goal: g,
              progress: model.progressFor(g.id),
              active: g.id == active?.id,
              onTap: () => model.switchGoal(g.id),
              onDelete: () => confirmDeleteGoal(context, model, g),
            ),
            const SizedBox(height: 10),
          ],
          const SizedBox(height: 6),
          _AddButton(onPressed: () => openAddGoal(context)),
        ],
      ),
    );
  }
}

class _AddButton extends StatelessWidget {
  const _AddButton({required this.onPressed});
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    return OutlinedButton.icon(
      key: const Key('add-goal'),
      style: OutlinedButton.styleFrom(
        foregroundColor: Palette.gold,
        side: const BorderSide(color: Palette.gold, width: 2),
        minimumSize: const Size.fromHeight(54),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
      ),
      onPressed: onPressed,
      icon: const Icon(Icons.add),
      label: const Text(
        'Add a goal',
        style: TextStyle(fontWeight: FontWeight.w900, fontSize: 16),
      ),
    );
  }
}

/// Destructive confirm. Deleting the last goal returns to onboarding.
Future<void> confirmDeleteGoal(
  BuildContext context,
  SavingsViewModel model,
  Goal goal,
) async {
  final total = money(model.progressFor(goal.id).total);
  final last = model.goals.length == 1;
  final ok = await showDialog<bool>(
    context: context,
    builder: (c) => AlertDialog(
      title: Text('Delete "${goal.title}"?'),
      content: Text(
        'This permanently deletes this goal, its $total savings history '
        'and its badges. This cannot be undone.'
        '${last ? '\n\nIt is your only goal, so QuitCash will start over.' : ''}',
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(c, false),
          child: const Text('Cancel'),
        ),
        FilledButton(
          key: const Key('confirm-delete'),
          style: FilledButton.styleFrom(
            backgroundColor: Colors.redAccent,
            foregroundColor: Colors.white,
          ),
          onPressed: () => Navigator.pop(c, true),
          child: const Text('Delete'),
        ),
      ],
    ),
  );
  if (ok == true) await model.deleteGoal(goal.id);
}
