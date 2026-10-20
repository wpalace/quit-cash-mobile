import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';

import '../../game/progress.dart';
import '../../state/savings_model.dart';
import '../palette.dart';
import '../widgets/celebration_dialog.dart';
import '../widgets/effects.dart';
import '../widgets/reminder_picker.dart';
import '../widgets/spinning_coin.dart';

const amounts = [1.0, 5.0, 10.0, 20.0];

String money(double v) {
  final whole = v.floor();
  final s = whole.toString().replaceAllMapped(
    RegExp(r'(\d)(?=(\d{3})+$)'),
    (m) => '${m[1]},',
  );
  return '\$$s.${((v - whole) * 100).round().clamp(0, 99).toString().padLeft(2, '0')}';
}

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
    final stack = _stackKey.currentContext!.findRenderObject()! as RenderBox;
    final box = k.currentContext!.findRenderObject()! as RenderBox;
    return stack.globalToLocal(box.localToGlobal(box.size.center(Offset.zero)));
  }

  void _removeFx(Key key) =>
      setState(() => _fx.removeWhere((w) => w.key == key));

  Future<void> _collect(SavingsModel model) async {
    unawaited(HapticFeedback.mediumImpact());
    unawaited(SystemSound.play(SystemSoundType.click));
    _squash.forward(from: 0);
    final before = model.progress.coins;
    final from = _centerOf(_heroKey);
    final to = _centerOf(_hudCoinKey);
    final cel = await model.addSavings(_amount);
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
          label: '+${money(_amount).replaceAll('.00', '')}',
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

  Future<void> _checkIn(SavingsModel model) async {
    unawaited(HapticFeedback.heavyImpact());
    final cel = await model.checkIn();
    if (!mounted || cel == null) return;
    unawaited(showCelebration(context, cel, checkIn: true));
  }

  @override
  Widget build(BuildContext context) {
    final model = context.watch<SavingsModel>();
    final p = model.progress;
    // Users who onboarded before reminders existed: ask once.
    if (model.reminder == null && !_reminderPrompted) {
      _reminderPrompted = true;
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) unawaited(showReminderPrompt(context));
      });
    }
    final text = Theme.of(context).textTheme;
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
              Text(
                'TOTAL SAVED',
                style: text.labelLarge?.copyWith(
                  color: Colors.white60,
                  letterSpacing: 3,
                ),
              ),
              TickingNumber(
                value: p.total,
                format: money,
                style: text.displayMedium!.copyWith(
                  color: Colors.white,
                  fontWeight: FontWeight.w900,
                  shadows: const [
                    Shadow(color: Palette.goldDeep, blurRadius: 18),
                  ],
                ),
              ),
              if (model.habit != null)
                Text(
                  'by skipping ${model.habit!.toLowerCase()}',
                  style: text.bodyMedium?.copyWith(color: Colors.white54),
                ),
              Expanded(
                child: Center(
                  child: GestureDetector(
                    key: const Key('hero-coin'),
                    onTap: () => _collect(model),
                    child: AnimatedBuilder(
                      animation: _squash,
                      builder: (context, child) {
                        final t = _squash.value;
                        final k = math.sin(t * math.pi);
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
                            key: _heroKey,
                            size: 190,
                            sparkles: true,
                          ),
                          const SizedBox(height: 4),
                          Text(
                            'TAP TO BANK ${money(_amount).replaceAll('.00', '')}',
                            style: text.titleMedium?.copyWith(
                              color: Palette.goldLight,
                              fontWeight: FontWeight.w900,
                              letterSpacing: 1.5,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
              _AmountPicker(
                value: _amount,
                onChanged: (v) {
                  HapticFeedback.selectionClick();
                  setState(() => _amount = v);
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
    const label = TextStyle(
      color: Colors.white,
      fontWeight: FontWeight.w900,
      fontSize: 20,
    );
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
      child: Column(
        children: [
          Row(
            children: [
              _Pill(
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
                    Text('× ', style: label.copyWith(color: Colors.white70)),
                    TickingNumber(
                      key: const Key('coin-count'),
                      value: coins.toDouble(),
                      format: (v) => v.round().toString(),
                      duration: const Duration(milliseconds: 250),
                      style: label,
                    ),
                  ],
                ),
              ),
              const Spacer(),
              _Pill(
                key: const Key('streak'),
                child: Row(
                  children: [
                    Text(
                      progress.currentStreak > 0 ? '🔥' : '🩶',
                      style: const TextStyle(fontSize: 20),
                    ),
                    const SizedBox(width: 4),
                    Text('${progress.currentStreak}', style: label),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              _Pill(
                color: Palette.gold,
                child: Text(
                  'LV ${progress.level}',
                  style: label.copyWith(color: Palette.outline),
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
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
      ),
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
  const _AmountPicker({required this.value, required this.onChanged});
  final double value;
  final ValueChanged<double> onChanged;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        for (final a in amounts)
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 6),
            child: GestureDetector(
              key: Key('amount-${a.toInt()}'),
              onTap: () => onChanged(a),
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 180),
                width: 70,
                height: 52,
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  color: a == value ? Palette.gold : Palette.card,
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(
                    color: a == value ? Palette.outline : Colors.white24,
                    width: 2,
                  ),
                  boxShadow: a == value
                      ? const [
                          BoxShadow(
                            color: Palette.goldDeep,
                            offset: Offset(0, 4),
                          ),
                        ]
                      : null,
                ),
                child: Text(
                  '\$${a.toInt()}',
                  style: TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.w900,
                    color: a == value ? Palette.outline : Colors.white,
                  ),
                ),
              ),
            ),
          ),
      ],
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
                Expanded(
                  child: Column(
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
                        style: TextStyle(
                          color: done ? Colors.white54 : Palette.skyTop,
                        ),
                      ),
                    ],
                  ),
                ),
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
