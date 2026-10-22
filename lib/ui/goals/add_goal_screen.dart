import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:quit_cash_mobile/ui/core/themes/palette.dart';
import 'package:quit_cash_mobile/ui/core/view_models/savings_view_model.dart';
import 'package:quit_cash_mobile/ui/core/widgets/backdrop.dart';
import 'package:quit_cash_mobile/ui/core/widgets/habit_picker.dart';

/// Add a goal: the onboarding habit picker plus an optional label. The new
/// goal becomes active.
class AddGoalScreen extends StatefulWidget {
  const AddGoalScreen({super.key});

  @override
  State<AddGoalScreen> createState() => _AddGoalScreenState();
}

class _AddGoalScreenState extends State<AddGoalScreen> {
  String? _pick;
  final _label = TextEditingController();

  @override
  void dispose() {
    _label.dispose();
    super.dispose();
  }

  Future<void> _add(String habit) async {
    final model = context.read<SavingsViewModel>();
    final navigator = Navigator.of(context);
    await model.addGoal(habit, label: _label.text);
    navigator.pop();
  }

  @override
  Widget build(BuildContext context) {
    final pick = _pick;
    return Scaffold(
      appBar: AppBar(
        title: const Text('New goal'),
        backgroundColor: Colors.transparent,
        foregroundColor: Colors.white,
      ),
      body: Backdrop(
        child: SafeArea(
          child: ListView(
            padding: const EdgeInsets.all(20),
            children: [
              const Text('What are you kicking or curbing?', style: _heading),
              const SizedBox(height: 12),
              HabitPicker(
                value: pick,
                onChanged: (h) => setState(() => _pick = h),
              ),
              const SizedBox(height: 24),
              const Text('Label (optional)', style: _heading),
              const SizedBox(height: 8),
              _LabelField(controller: _label),
              const SizedBox(height: 28),
              FilledButton(
                key: const Key('add-goal-confirm'),
                style: FilledButton.styleFrom(
                  backgroundColor: Palette.gold,
                  foregroundColor: Palette.outline,
                  disabledBackgroundColor: Colors.white24,
                  minimumSize: const Size.fromHeight(56),
                  textStyle: const TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.w900,
                  ),
                ),
                onPressed: pick == null ? null : () => _add(pick),
                child: const Text('ADD GOAL'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

const _heading = TextStyle(
  color: Colors.white,
  fontSize: 18,
  fontWeight: FontWeight.bold,
);

class _LabelField extends StatelessWidget {
  const _LabelField({required this.controller});
  final TextEditingController controller;

  @override
  Widget build(BuildContext context) {
    return TextField(
      key: const Key('goal-label'),
      controller: controller,
      maxLength: 30,
      textCapitalization: TextCapitalization.sentences,
      style: const TextStyle(color: Colors.white),
      decoration: InputDecoration(
        hintText: 'e.g. Weekend beers',
        hintStyle: const TextStyle(color: Colors.white38),
        filled: true,
        fillColor: Palette.card,
        counterStyle: const TextStyle(color: Colors.white38),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: BorderSide.none,
        ),
      ),
    );
  }
}
