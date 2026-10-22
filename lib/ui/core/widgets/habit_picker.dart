import 'package:flutter/material.dart';
import 'package:quit_cash_mobile/domain/models/habits.dart';
import 'package:quit_cash_mobile/ui/core/themes/palette.dart';

/// Choice chips for the habit being kicked or curbed. Used by onboarding
/// and by Add goal.
class HabitPicker extends StatelessWidget {
  const HabitPicker({super.key, required this.value, required this.onChanged});
  final String? value;
  final ValueChanged<String> onChanged;

  @override
  Widget build(BuildContext context) {
    return Wrap(
      spacing: 10,
      runSpacing: 10,
      children: [
        for (final (emoji, name) in habits)
          ChoiceChip(
            key: Key('habit-$name'),
            label: Text('$emoji  $name'),
            selected: value == name,
            onSelected: (_) => onChanged(name),
            selectedColor: Palette.gold,
            backgroundColor: Palette.card,
            labelStyle: TextStyle(
              color: value == name ? Palette.outline : Colors.white,
              fontWeight: FontWeight.w600,
            ),
            side: BorderSide.none,
          ),
      ],
    );
  }
}
