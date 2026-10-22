import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'package:quit_cash_mobile/domain/models/progress.dart';
import 'package:quit_cash_mobile/ui/core/themes/denominations.dart';
import 'package:quit_cash_mobile/ui/core/themes/palette.dart';
import 'package:quit_cash_mobile/ui/core/view_models/savings_view_model.dart';
import 'package:quit_cash_mobile/ui/core/widgets/celebration_dialog.dart';
import 'package:quit_cash_mobile/ui/core/widgets/coin_burst.dart';
import 'package:quit_cash_mobile/ui/core/widgets/flying_coin.dart';
import 'package:quit_cash_mobile/ui/core/widgets/reminder_picker.dart';
import 'package:quit_cash_mobile/ui/core/widgets/spinning_coin.dart';
import 'package:quit_cash_mobile/ui/core/widgets/ticking_number.dart';
import 'package:quit_cash_mobile/ui/settings/settings_screen.dart';
import 'package:quit_cash_mobile/utils/money.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen>
    with SingleTickerProviderStateMixin {
  final _stackKey = GlobalKey();
  final _heroKey = GlobalKey();
  final _hudCoinKey = GlobalKey();
  final List<Widget> _fx = [];
  double _amount = 5;
  int _fxId = 0;

  /// Coins shown in the HUD lag the model until the flying coins land.
  int? _displayCoins;
  bool _hudBump = false;
  bool _reminderPrompted = false;

  late final AnimationController _squash = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 260),
  );

  @override
  void dispose() {
    _squash.dispose();
    super.dispose();
  }

  Offset _centerOf(GlobalKey k) {
    final stack = _stackKey.currentContext?.findRenderObject();
    final box = k.currentContext?.findRenderObject();
    if (stack is! RenderBox || box is! RenderBox) return Offset.zero;
    return stack.globalToLocal(box.localToGlobal(box.size.center(Offset.zero)));
  }

  void _removeFx(Key key) =>
      setState(() => _fx.removeWhere((w) => w.key == key));

  Future<void> _collect(SavingsViewModel model) async {
    final denom = model.denominationForPick(_amount.round());
    unawaited(HapticFeedback.mediumImpact());
    unawaited(SystemSound.play(SystemSoundType.click));
    _squash.forward(from: 0);
    final before = model.progress.coins;
    final from = _centerOf(_heroKey);
    final to = _centerOf(_hudCoinKey);
    final cel = await model.addSavings(denom.dollars.toDouble());
    if (!mounted) return;
    if (cel == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Couldn't save. Try again.")),
      );
      return;
    }
    final gained = model.progress.coins - before;
    final flights = math.min(gained, 8);
    setState(() {
      _displayCoins = before;
      final bk = ValueKey('b${_fxId++}');
      _fx.add(
        CoinBurst(
          key: bk,
          at: from,
          label: '+${denom.label}',
          metal: denom.metal,
          onDone: () => _removeFx(bk),
        ),
      );
      for (var i = 0; i < flights; i++) {
        final k = ValueKey('f${_fxId++}');
        final last = i == flights - 1;
        _fx.add(
          FlyingCoin(
            key: k,
            from: from + Offset((i - flights / 2) * 14.0, 0),
            to: to,
            delay: Duration(milliseconds: 70 * i),
            denomination: denom,
            onArrive: () {
              HapticFeedback.selectionClick();
              _removeFx(k);
              setState(() {
                _hudBump = true;
                _displayCoins = last
                    ? null
                    : before + ((i + 1) * gained ~/ flights);
              });
              Future.delayed(
                const Duration(milliseconds: 120),
                () => mounted ? setState(() => _hudBump = false) : null,
              );
            },
          ),
        );
      }
    });
    if (!cel.isEmpty) {
      Future.delayed(const Duration(milliseconds: 1100), () {
        if (mounted) unawaited(showCelebration(context, cel));
      });
    }
  }

  Future<void> _checkIn(SavingsViewModel model) async {
    unawaited(HapticFeedback.heavyImpact());
    final cel = await model.checkIn();
    if (!mounted || cel == null) return;
    unawaited(showCelebration(context, cel, checkIn: true));
  }

  @override
  Widget build(BuildContext context) {
    final model = context.watch<SavingsViewModel>();
    final p = model.progress;
    // Users who onboarded before reminders existed: ask once.
    if (model.reminder == null && !_reminderPrompted) {
      _reminderPrompted = true;
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) unawaited(showReminderPrompt(context));
      });
    }
    final denom = model.denominationForPick(_amount.round());
    return SafeArea(
      child: Stack(
        key: _stackKey,
        children: [
          Column(
            children: [
              _Hud(
                progress: p,
                coins: _displayCoins ?? p.coins,
                bump: _hudBump,
                coinKey: _hudCoinKey,
              ),
              const SizedBox(height: 8),
              _TotalHeader(total: p.total, habit: model.habit),
              Expanded(
                child: Center(
                  child: _HeroCoin(
                    denomination: denom,
                    squash: _squash,
                    coinKey: _heroKey,
                    onTap: () => _collect(model),
                  ),
                ),
              ),
              _AmountPicker(
                options: model.pickerDenominations,
                value: denom,
                onChanged: (d) {
                  unawaited(HapticFeedback.selectionClick());
                  setState(() => _amount = d.dollars.toDouble());
                },
              ),
              const SizedBox(height: 12),
              _DailyBonus(done: p.checkedInToday, onTap: () => _checkIn(model)),
              const SizedBox(height: 12),
            ],
          ),
          ..._fx,
        ],
      ),
    );
  }
}

class _TotalHeader extends StatelessWidget {
  const _TotalHeader({required this.total, required this.habit});
  final double total;
  final String? habit;

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    final habit = this.habit;
    return Column(
      children: [
        Text(
          'TOTAL SAVED',
          style: text.labelLarge?.copyWith(
            color: Colors.white60,
            letterSpacing: 3,
          ),
        ),
        TickingNumber(
          value: total,
          format: money,
          style: (text.displayMedium ?? const TextStyle(fontSize: 45)).copyWith(
            color: Colors.white,
            fontWeight: FontWeight.w900,
            shadows: const [Shadow(color: Palette.goldDeep, blurRadius: 18)],
          ),
        ),
        if (habit != null)
          Text(
            'by skipping ${habit.toLowerCase()}',
            style: text.bodyMedium?.copyWith(color: Colors.white54),
          ),
      ],
    );
  }
}

/// The big tappable coin (or gem) with a squash-and-stretch on tap.
class _HeroCoin extends StatelessWidget {
  const _HeroCoin({
    required this.denomination,
    required this.squash,
    required this.coinKey,
    required this.onTap,
  });
  final Denomination denomination;
  final Animation<double> squash;
  final GlobalKey coinKey;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      key: const Key('hero-coin'),
      onTap: onTap,
      child: AnimatedBuilder(
        animation: squash,
        builder: (context, child) {
          final k = math.sin(squash.value * math.pi);
          return Transform.scale(
            scaleX: 1 + 0.12 * k,
            scaleY: 1 - 0.12 * k,
            child: child,
          );
        },
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            SpinningCoin(
              key: coinKey,
              size: 190,
              sparkles: true,
              denomination: denomination,
            ),
            const SizedBox(height: 4),
            Text(
              'TAP TO BANK ${denomination.label}',
              style: Theme.of(context).textTheme.titleMedium?.copyWith(
                color: denomination.metal.light,
                fontWeight: FontWeight.w900,
                letterSpacing: 1.5,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

const _hudLabel = TextStyle(
  color: Colors.white,
  fontWeight: FontWeight.w900,
  fontSize: 20,
);

class _Hud extends StatelessWidget {
  const _Hud({
    required this.progress,
    required this.coins,
    required this.bump,
    required this.coinKey,
  });
  final Progress progress;
  final int coins;
  final bool bump;
  final GlobalKey coinKey;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
      child: Column(
        children: [
          Row(
            children: [
              _CoinCounter(coins: coins, bump: bump, coinKey: coinKey),
              const Spacer(),
              _StreakPill(streak: progress.currentStreak),
              const SizedBox(width: 8),
              _Pill(
                color: Palette.gold,
                child: Text(
                  'LV ${progress.level}',
                  style: _hudLabel.copyWith(color: Palette.outline),
                ),
              ),
              const _SettingsButton(),
            ],
          ),
          const SizedBox(height: 10),
          _LevelProgress(progress: progress),
        ],
      ),
    );
  }
}

class _CoinCounter extends StatelessWidget {
  const _CoinCounter({
    required this.coins,
    required this.bump,
    required this.coinKey,
  });
  final int coins;
  final bool bump;
  final GlobalKey coinKey;

  @override
  Widget build(BuildContext context) {
    return _Pill(
      child: Row(
        children: [
          AnimatedScale(
            scale: bump ? 1.35 : 1,
            duration: const Duration(milliseconds: 100),
            child: SpinningCoin(
              key: coinKey,
              size: 30,
              period: const Duration(milliseconds: 900),
            ),
          ),
          const SizedBox(width: 6),
          Text('× ', style: _hudLabel.copyWith(color: Colors.white70)),
          TickingNumber(
            key: const Key('coin-count'),
            value: coins.toDouble(),
            format: (v) => v.round().toString(),
            duration: const Duration(milliseconds: 250),
            style: _hudLabel,
          ),
        ],
      ),
    );
  }
}

class _StreakPill extends StatelessWidget {
  const _StreakPill({required this.streak});
  final int streak;

  @override
  Widget build(BuildContext context) {
    return _Pill(
      key: const Key('streak'),
      child: Row(
        children: [
          Text(streak > 0 ? '🔥' : '🩶', style: const TextStyle(fontSize: 20)),
          const SizedBox(width: 4),
          Text('$streak', style: _hudLabel),
        ],
      ),
    );
  }
}

class _SettingsButton extends StatelessWidget {
  const _SettingsButton();

  @override
  Widget build(BuildContext context) {
    return IconButton(
      key: const Key('settings'),
      tooltip: 'Settings',
      icon: const Icon(Icons.settings, color: Colors.white),
      onPressed: () => Navigator.of(
        context,
      ).push(MaterialPageRoute<void>(builder: (_) => const SettingsScreen())),
    );
  }
}

class _LevelProgress extends StatelessWidget {
  const _LevelProgress({required this.progress});
  final Progress progress;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Row(
          children: [
            Text(
              progress.rankTitle,
              style: const TextStyle(
                color: Palette.goldLight,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                '\$${progress.total.floor()} / \$${progress.nextThreshold}'
                ' to LV ${progress.level + 1}',
                key: const Key('next-level'),
                textAlign: TextAlign.end,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(color: Colors.white60, fontSize: 12),
              ),
            ),
          ],
        ),
        const SizedBox(height: 4),
        ClipRRect(
          borderRadius: BorderRadius.circular(8),
          child: TweenAnimationBuilder<double>(
            tween: Tween(end: progress.levelFraction),
            duration: const Duration(milliseconds: 600),
            curve: Curves.easeOutBack,
            builder: (context, v, _) => LinearProgressIndicator(
              value: v.clamp(0, 1),
              minHeight: 12,
              backgroundColor: Colors.white12,
              color: Palette.mint,
            ),
          ),
        ),
      ],
    );
  }
}

class _Pill extends StatelessWidget {
  const _Pill({super.key, required this.child, this.color = Palette.card});
  final Widget child;
  final Color color;

  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
    decoration: BoxDecoration(
      color: color,
      borderRadius: BorderRadius.circular(30),
    ),
    child: child,
  );
}

class _AmountPicker extends StatelessWidget {
  const _AmountPicker({
    required this.options,
    required this.value,
    required this.onChanged,
  });
  final List<Denomination> options;
  final Denomination value;
  final ValueChanged<Denomination> onChanged;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 12),
      child: Row(
        children: [
          for (final d in options)
            Expanded(
              child: _DenomChip(
                key: Key('amount-${d.dollars}'),
                denomination: d,
                selected: d == value,
                onTap: () => onChanged(d),
              ),
            ),
        ],
      ),
    );
  }
}

class _DenomChip extends StatelessWidget {
  const _DenomChip({
    super.key,
    required this.denomination,
    required this.selected,
    required this.onTap,
  });
  final Denomination denomination;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final m = denomination.metal;
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 180),
        height: 76,
        margin: const EdgeInsets.symmetric(horizontal: 3),
        padding: const EdgeInsets.all(4),
        decoration: BoxDecoration(
          color: selected ? m.base.withValues(alpha: 0.35) : Palette.card,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: selected ? m.light : Colors.white24,
            width: 2,
          ),
          boxShadow: selected
              ? [BoxShadow(color: m.deep, offset: const Offset(0, 4))]
              : null,
        ),
        child: FittedBox(
          fit: BoxFit.scaleDown,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              SpinningCoin(size: 32, spin: false, denomination: denomination),
              const SizedBox(height: 4),
              Text(
                denomination.label,
                style: const TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w900,
                  color: Colors.white,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _DailyBonus extends StatelessWidget {
  const _DailyBonus({required this.done, required this.onTap});
  final bool done;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Material(
        color: done ? Palette.card : Palette.mint,
        borderRadius: BorderRadius.circular(18),
        child: InkWell(
          key: const Key('daily-bonus'),
          borderRadius: BorderRadius.circular(18),
          onTap: done ? null : onTap,
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
            child: Row(
              children: [
                Text(done ? '✅' : '🎁', style: const TextStyle(fontSize: 28)),
                const SizedBox(width: 12),
                Expanded(child: _BonusText(done: done)),
                if (!done)
                  const Icon(Icons.chevron_right, color: Palette.skyTop),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _BonusText extends StatelessWidget {
  const _BonusText({required this.done});
  final bool done;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          done ? 'Daily bonus claimed' : 'Stayed strong today?',
          style: TextStyle(
            fontWeight: FontWeight.w900,
            fontSize: 16,
            color: done ? Colors.white70 : Palette.skyTop,
          ),
        ),
        Text(
          done
              ? 'Come back tomorrow to keep the streak alive'
              : 'Check in for +$checkInCoins coins and keep your streak',
          style: TextStyle(color: done ? Colors.white54 : Palette.skyTop),
        ),
      ],
    );
  }
}
