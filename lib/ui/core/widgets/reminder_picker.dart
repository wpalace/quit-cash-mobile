import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:quit_cash_mobile/domain/models/reminder_plan.dart';
import 'package:quit_cash_mobile/ui/core/themes/palette.dart';
import 'package:quit_cash_mobile/ui/core/view_models/savings_view_model.dart';

/// Chip row for choosing reminder frequency.
class ReminderPicker extends StatelessWidget {
  const ReminderPicker({
    super.key,
    required this.value,
    required this.onChanged,
  });

  final ReminderFrequency? value;
  final ValueChanged<ReminderFrequency> onChanged;

  @override
  Widget build(BuildContext context) {
    return Wrap(
      spacing: 8,
      runSpacing: 8,
      children: [
        for (final f in ReminderFrequency.values)
          ChoiceChip(
            key: Key('reminder-${f.name}'),
            label: Text(
              f == ReminderFrequency.never ? '🔕  ${f.label}' : f.label,
            ),
            selected: value == f,
            onSelected: (_) => onChanged(f),
            selectedColor: Palette.gold,
            backgroundColor: Palette.card,
            labelStyle: TextStyle(
              color: value == f ? Palette.outline : Colors.white,
              fontWeight: FontWeight.w600,
            ),
            side: BorderSide.none,
          ),
      ],
    );
  }
}

/// Save [f] via the model and tell the user if the OS blocked notifications.
Future<void> applyReminder(BuildContext context, ReminderFrequency f) async {
  final messenger = ScaffoldMessenger.maybeOf(context);
  final granted = await context.read<SavingsViewModel>().setReminder(f);
  if (!granted && f.enabled) {
    messenger?.showSnackBar(
      const SnackBar(
        content: Text(
          'Notifications are off for QuitCash. Turn them on in system settings to get reminders.',
        ),
      ),
    );
  }
}

/// One-time sheet for users who finished onboarding before reminders existed.
Future<void> showReminderPrompt(BuildContext context) {
  return showModalBottomSheet<void>(
    context: context,
    isDismissible: false,
    enableDrag: false,
    backgroundColor: Palette.skyTop,
    builder: (sheet) => Padding(
      padding: const EdgeInsets.fromLTRB(24, 24, 24, 32),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            '⏰ Want a nudge?',
            style: TextStyle(
              color: Palette.gold,
              fontSize: 24,
              fontWeight: FontWeight.w900,
            ),
          ),
          const SizedBox(height: 6),
          const Text(
            'We can remind you at 7 pm to check in and keep your streak alive.',
            style: TextStyle(color: Colors.white70),
          ),
          const SizedBox(height: 16),
          ReminderPicker(
            value: null,
            onChanged: (f) {
              Navigator.of(sheet).pop();
              applyReminder(context, f);
            },
          ),
        ],
      ),
    ),
  );
}
