import 'dart:math' as math;

import 'package:flutter/material.dart';

import 'package:quit_cash_mobile/ui/core/themes/denominations.dart';
import 'package:quit_cash_mobile/ui/core/widgets/coin_painter.dart';

/// A coin that pops up, arcs and shrinks from [from] to [to], then calls
/// [onArrive]. Lives inside a [Stack] that both offsets are relative to.
class FlyingCoin extends StatefulWidget {
  const FlyingCoin({
    super.key,
    required this.from,
    required this.to,
    required this.onArrive,
    this.delay = Duration.zero,
    this.size = 64,
    this.denomination = defaultCoin,
  });

  final Denomination denomination;

  final Offset from;
  final Offset to;
  final VoidCallback onArrive;
  final Duration delay;
  final double size;

  @override
  State<FlyingCoin> createState() => _FlyingCoinState();
}

class _FlyingCoinState extends State<FlyingCoin>
    with SingleTickerProviderStateMixin {
  late final AnimationController _c = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 750),
  );

  @override
  void initState() {
    super.initState();
    Future.delayed(widget.delay, () {
      if (mounted) _c.forward().whenComplete(widget.onArrive);
    });
  }

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _c,
      builder: (context, _) {
        final t = Curves.easeInOutCubic.transform(_c.value);
        // Pop: rise first, then quadratic bezier toward the HUD.
        final ctrl = Offset(
          (widget.from.dx + widget.to.dx) / 2 + 60,
          widget.from.dy - 220,
        );
        final p = Offset(
          _bez(widget.from.dx, ctrl.dx, widget.to.dx, t),
          _bez(widget.from.dy, ctrl.dy, widget.to.dy, t),
        );
        final pop = _c.value < 0.2 ? 1 + _c.value * 2.5 : 1.5 - t * 1.1;
        final s = widget.size * pop.clamp(0.3, 1.5);
        return Positioned(
          left: p.dx - s / 2,
          top: p.dy - s / 2,
          child: IgnorePointer(
            child: Opacity(
              opacity: _c.value == 0 ? 0 : 1,
              child: CustomPaint(
                size: Size.square(s),
                painter: painterFor(
                  widget.denomination,
                  angle: _c.value * 6 * math.pi,
                  glint: t,
                ),
              ),
            ),
          ),
        );
      },
    );
  }

  static double _bez(double a, double b, double c, double t) =>
      (1 - t) * (1 - t) * a + 2 * (1 - t) * t * b + t * t * c;
}
