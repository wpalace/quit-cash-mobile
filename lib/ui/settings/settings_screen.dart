import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:quit_cash_mobile/ui/core/themes/denominations.dart';
import 'package:quit_cash_mobile/ui/core/themes/palette.dart';
import 'package:quit_cash_mobile/ui/core/view_models/savings_view_model.dart';
import 'package:quit_cash_mobile/ui/core/widgets/backdrop.dart';
import 'package:quit_cash_mobile/ui/core/widgets/reminder_picker.dart';
import 'package:quit_cash_mobile/ui/core/widgets/spinning_coin.dart';

/// Settings: denominations, reminders, reset. Opened from the HUD gear.
class SettingsScreen extends StatelessWidget {
  const SettingsScreen({super.key});

  static const _heading = TextStyle(
    color: Palette.gold,
    fontSize: 18,
    fontWeight: FontWeight.w900,
  );

  @override
  Widget build(BuildContext context) {
    final model = context.watch<SavingsViewModel>();
    return Scaffold(
      extendBodyBehindAppBar: true,
      appBar: AppBar(
        title: const Text(
          'Settings',
          style: TextStyle(fontWeight: FontWeight.w900),
        ),
        backgroundColor: Colors.transparent,
        foregroundColor: Colors.white,
      ),
      body: Backdrop(
        child: SafeArea(
          child: ListView(
            padding: const EdgeInsets.all(16),
            children: [
              const Text('🪙 Coins', style: _heading),
              const SizedBox(height: 4),
              const Text(
                'Unlock bigger coins for big wins. Your history stays the same.',
                style: TextStyle(color: Colors.white60),
              ),
              const SizedBox(height: 8),
              _CoinToggles(model: model),
              const SizedBox(height: 24),
              const Text('⏰ Reminders (7 pm)', style: _heading),
              const SizedBox(height: 8),
              ReminderPicker(
                value: model.reminder,
                onChanged: (f) => applyReminder(context, f),
              ),
              const SizedBox(height: 32),
              const Text('⚠️ Danger zone', style: _heading),
              const SizedBox(height: 8),
              _ResetButton(
                goal: model.activeGoal?.title ?? '',
                onPressed: () => _confirmReset(context, model),
              ),
              const SizedBox(height: 6),
              const Text(
                'Resets only the current goal. Delete goals on the Goals tab.',
                style: TextStyle(color: Colors.white54),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _confirmReset(
    BuildContext context,
    SavingsViewModel model,
  ) async {
    final goal = model.activeGoal?.title ?? '';
    final ok = await showDialog<bool>(
      context: context,
      builder: (c) => AlertDialog(
        title: Text('Reset "$goal"?'),
        content: Text(
          'This deletes the savings history and badges of "$goal" only. '
          'Your other goals and your settings stay as they are.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(c, false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(c, true),
            child: const Text('Reset goal'),
          ),
        ],
      ),
    );
    if (ok == true) await model.reset();
  }
}

class _CoinToggles extends StatelessWidget {
  const _CoinToggles({required this.model});
  final SavingsViewModel model;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        _DenomSwitch(
          key: const Key('toggle-50'),
          denomination: denominationFor(50),
          title: 'Show \$50',
          subtitle: 'Sapphire coin',
          value: model.showFifty,
          onChanged: model.setShowFifty,
        ),
        _DenomSwitch(
          key: const Key('toggle-100'),
          denomination: denominationFor(100),
          title: 'Show \$100',
          subtitle: 'Ruby gem',
          value: model.showHundred,
          onChanged: model.setShowHundred,
        ),
        _DenomSwitch(
          key: const Key('toggle-500'),
          denomination: denominationFor(500),
          title: 'Show \$500',
          subtitle: 'Diamond gem',
          value: model.showFiveHundred,
          onChanged: model.setShowFiveHundred,
        ),
      ],
    );
  }
}

class _ResetButton extends StatelessWidget {
  const _ResetButton({required this.goal, required this.onPressed});
  final String goal;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    return OutlinedButton.icon(
      key: const Key('reset'),
      style: OutlinedButton.styleFrom(
        foregroundColor: Colors.redAccent,
        side: const BorderSide(color: Colors.redAccent),
      ),
      icon: const Icon(Icons.restart_alt),
      label: Text('Reset "$goal" progress'),
      onPressed: onPressed,
    );
  }
}

class _DenomSwitch extends StatelessWidget {
  const _DenomSwitch({
    super.key,
    required this.denomination,
    required this.title,
    required this.subtitle,
    required this.value,
    required this.onChanged,
  });

  final Denomination denomination;
  final String title;
  final String subtitle;
  final bool value;
  final ValueChanged<bool> onChanged;

  @override
  Widget build(BuildContext context) {
    return Card(
      color: Palette.card,
      elevation: 0,
      child: SwitchListTile(
        value: value,
        onChanged: onChanged,
        activeThumbColor: Palette.gold,
        secondary: SpinningCoin(size: 40, denomination: denomination),
        title: Text(
          title,
          style: const TextStyle(
            color: Colors.white,
            fontWeight: FontWeight.bold,
          ),
        ),
        subtitle: Text(subtitle, style: const TextStyle(color: Colors.white60)),
      ),
    );
  }
}
