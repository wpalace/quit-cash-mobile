import 'dart:async';

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:quit_cash_mobile/ui/core/themes/palette.dart';
import 'package:quit_cash_mobile/ui/core/view_models/savings_view_model.dart';
import 'package:quit_cash_mobile/ui/core/widgets/goal_tile.dart';

/// Quick switcher from the Bank screen: tap a goal to switch and close.
/// [onAdd] opens Add goal.
Future<void> showGoalSwitcher(
  BuildContext context, {
  required VoidCallback onAdd,
}) => showModalBottomSheet<void>(
  context: context,
  backgroundColor: Palette.skyTop,
  isScrollControlled: true,
  showDragHandle: true,
  shape: const RoundedRectangleBorder(
    borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
  ),
  builder: (_) => _Switcher(onAdd: onAdd),
);

class _Switcher extends StatelessWidget {
  const _Switcher({required this.onAdd});
  final VoidCallback onAdd;

  @override
  Widget build(BuildContext context) {
    final model = context.watch<SavingsViewModel>();
    final active = model.activeGoal;
    return SafeArea(
      child: ConstrainedBox(
        constraints: BoxConstraints(
          maxHeight: MediaQuery.sizeOf(context).height * 0.7,
        ),
        child: ListView(
          key: const Key('goal-switcher-sheet'),
          shrinkWrap: true,
          padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
          children: [
            const Text(
              'Switch goal',
              style: TextStyle(
                color: Palette.gold,
                fontSize: 22,
                fontWeight: FontWeight.w900,
              ),
            ),
            const SizedBox(height: 12),
            for (final g in model.goals) ...[
              GoalTile(
                goal: g,
                progress: model.progressFor(g.id),
                active: g.id == active?.id,
                onTap: () {
                  unawaited(model.switchGoal(g.id));
                  Navigator.of(context).pop();
                },
              ),
              const SizedBox(height: 10),
            ],
            TextButton.icon(
              key: const Key('switcher-add-goal'),
              style: TextButton.styleFrom(foregroundColor: Palette.gold),
              onPressed: () {
                Navigator.of(context).pop();
                onAdd();
              },
              icon: const Icon(Icons.add),
              label: const Text(
                'Add a goal',
                style: TextStyle(fontWeight: FontWeight.w900),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
