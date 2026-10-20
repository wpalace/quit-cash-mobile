import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../state/savings_model.dart';
import '../palette.dart';
import '../widgets/backdrop.dart';
import '../widgets/spinning_coin.dart';

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

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    return Scaffold(
      body: Backdrop(
        child: SafeArea(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 24),
            child: Column(
              children: [
                const SizedBox(height: 24),
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
                const SizedBox(height: 28),
                Align(
                  alignment: Alignment.centerLeft,
                  child: Text(
                    'What are you quitting?',
                    style: text.titleLarge?.copyWith(
                      color: Colors.white,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
                const SizedBox(height: 12),
                Wrap(
                  spacing: 10,
                  runSpacing: 10,
                  children: [
                    for (final (emoji, name) in habits)
                      ChoiceChip(
                        label: Text('$emoji  $name'),
                        selected: _pick == name,
                        onSelected: (_) => setState(() => _pick = name),
                        selectedColor: Palette.gold,
                        backgroundColor: Palette.card,
                        labelStyle: TextStyle(
                          color: _pick == name ? Palette.outline : Colors.white,
                          fontWeight: FontWeight.w600,
                        ),
                        side: BorderSide.none,
                      ),
                  ],
                ),
                const Spacer(),
                SizedBox(
                  width: double.infinity,
                  height: 60,
                  child: FilledButton(
                    key: const Key('start'),
                    style: FilledButton.styleFrom(
                      backgroundColor: Palette.gold,
                      foregroundColor: Palette.outline,
                      disabledBackgroundColor: Colors.white24,
                      textStyle: const TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                    onPressed: _pick == null
                        ? null
                        : () => context.read<SavingsModel>().setHabit(_pick!),
                    child: const Text("LET'S GO!"),
                  ),
                ),
                const SizedBox(height: 24),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
