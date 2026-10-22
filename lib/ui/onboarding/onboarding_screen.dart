import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:quit_cash_mobile/domain/models/reminder_plan.dart';
import 'package:quit_cash_mobile/ui/core/themes/palette.dart';
import 'package:quit_cash_mobile/ui/core/view_models/savings_view_model.dart';
import 'package:quit_cash_mobile/ui/core/widgets/backdrop.dart';
import 'package:quit_cash_mobile/ui/core/widgets/reminder_picker.dart';
import 'package:quit_cash_mobile/ui/core/widgets/spinning_coin.dart';

const habits = [
  ('🚬', 'Smoking'),
  ('💨', 'Vaping'),
  ('☕', 'Fancy coffee'),
  ('🍔', 'Takeout'),
  ('🍺', 'Drinking'),
  ('🛍️', 'Impulse buys'),
  ('🎰', 'Gambling'),
  ('✨', 'Something else'),
];

class OnboardingScreen extends StatefulWidget {
  const OnboardingScreen({super.key});

  @override
  State<OnboardingScreen> createState() => _OnboardingScreenState();
}

class _OnboardingScreenState extends State<OnboardingScreen> {
  String? _pick;
  ReminderFrequency _reminder = ReminderFrequency.daily;

  Future<void> _start() async {
    final model = context.read<SavingsViewModel>();
    await applyReminder(context, _reminder);
    final pick = _pick;
    if (pick == null) return; // The start button is disabled until a pick.
    await model.setHabit(pick);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Backdrop(
        child: SafeArea(
          child: SingleChildScrollView(
            padding: const EdgeInsets.symmetric(horizontal: 24),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const SizedBox(height: 24),
                const _Brand(),
                const SizedBox(height: 28),
                const _SectionTitle('What are you quitting?'),
                const SizedBox(height: 12),
                _HabitChips(
                  value: _pick,
                  onChanged: (name) => setState(() => _pick = name),
                ),
                const SizedBox(height: 24),
                const _SectionTitle('How often should we nudge you?'),
                const SizedBox(height: 4),
                const Text(
                  'Reminders arrive at 7 pm. Change any time in Settings.',
                  style: TextStyle(color: Colors.white60),
                ),
                const SizedBox(height: 12),
                ReminderPicker(
                  value: _reminder,
                  onChanged: (f) => setState(() => _reminder = f),
                ),
                const SizedBox(height: 24),
                _StartButton(onPressed: _pick == null ? null : _start),
                const SizedBox(height: 24),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _Brand extends StatelessWidget {
  const _Brand();

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    return Center(
      child: Column(
        children: [
          const SpinningCoin(size: 140, sparkles: true),
          Text(
            'QuitCash',
            style: text.displayMedium?.copyWith(
              color: Palette.gold,
              fontWeight: FontWeight.w900,
              shadows: const [
                Shadow(color: Palette.outline, offset: Offset(3, 4)),
              ],
            ),
          ),
          const SizedBox(height: 6),
          Text(
            'Every craving you skip turns into gold.',
            textAlign: TextAlign.center,
            style: text.titleMedium?.copyWith(color: Colors.white70),
          ),
        ],
      ),
    );
  }
}

class _SectionTitle extends StatelessWidget {
  const _SectionTitle(this.text);
  final String text;

  @override
  Widget build(BuildContext context) => Text(
    text,
    style: Theme.of(context).textTheme.titleLarge
        ?.copyWith(color: Colors.white, fontWeight: FontWeight.bold),
  );
}

class _HabitChips extends StatelessWidget {
  const _HabitChips({required this.value, required this.onChanged});
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

class _StartButton extends StatelessWidget {
  const _StartButton({required this.onPressed});
  final VoidCallback? onPressed;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: double.infinity,
      height: 60,
      child: FilledButton(
        key: const Key('start'),
        style: FilledButton.styleFrom(
          backgroundColor: Palette.gold,
          foregroundColor: Palette.outline,
          disabledBackgroundColor: Colors.white24,
          textStyle: const TextStyle(fontSize: 20, fontWeight: FontWeight.w900),
        ),
        onPressed: onPressed,
        child: const Text("LET'S GO!"),
      ),
    );
  }
}
