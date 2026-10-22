import 'dart:math' as math;

import 'package:flutter/material.dart';

import 'package:quit_cash_mobile/ui/core/themes/denominations.dart';
import 'package:quit_cash_mobile/ui/core/widgets/coin_painter.dart';

/// A continuously spinning coin. [period] is one full Y-axis turn.
/// Pass [spin] = false for a static coin (used in golden/test contexts).
class SpinningCoin extends StatefulWidget {
  const SpinningCoin({
    super.key,
    required this.size,
    this.period = const Duration(milliseconds: 1400),
    this.spin = true,
    this.sparkles = false,
    this.denomination = defaultCoin,
  });

  /// Which coin (or gem) to draw. Defaults to the gold coin.
  final Denomination denomination;

  final double size;
  final Duration period;
  final bool spin;
  final bool sparkles;

  @override
  State<SpinningCoin> createState() => _SpinningCoinState();
}

class _SpinningCoinState extends State<SpinningCoin>
    with SingleTickerProviderStateMixin {
  late final AnimationController _c = AnimationController(
    vsync: this,
    duration: widget.period,
  );

  static const _sparkles = [
    (0.12, 0.2, 0.0),
    (0.88, 0.28, 0.35),
    (0.8, 0.86, 0.6),
    (0.2, 0.8, 0.8),
    (0.5, 0.02, 0.5),
  ];

  @override
  void initState() {
    super.initState();
    if (widget.spin && !_reducedMotion) _c.repeat();
  }

  bool get _reducedMotion => WidgetsBinding
      .instance
      .platformDispatcher
      .accessibilityFeatures
      .disableAnimations;

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return RepaintBoundary(
      child: AnimatedBuilder(
        animation: _c,
        builder: (context, _) {
          final v = _c.value;
          final coin = CustomPaint(
            size: Size.square(widget.size),
            painter: painterFor(
              widget.denomination,
              angle: widget.spin ? v * 2 * math.pi : 0.35,
              glint: (v * 1.5) % 1.0,
            ),
          );
          if (!widget.sparkles) return coin;
          return SizedBox.square(
            dimension: widget.size * 1.35,
            child: Stack(
              alignment: Alignment.center,
              children: [
                coin,
                Positioned.fill(
                  child: CustomPaint(
                    painter: SparklePainter(
                      t: v,
                      points: _sparkles,
                      tint: widget.denomination.metal,
                    ),
                  ),
                ),
              ],
            ),
          );
        },
      ),
    );
  }
}
