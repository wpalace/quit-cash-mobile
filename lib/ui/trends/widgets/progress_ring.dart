import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:quit_cash_mobile/ui/core/themes/palette.dart';

/// Calm score-style ring: a dark track and a gold arc that sweeps from
/// 12 o'clock to [fraction] (0..1) on first show and on change.
class ProgressRing extends StatelessWidget {
  const ProgressRing({
    super.key,
    required this.fraction,
    required this.center,
    this.size = 220,
  });

  final double fraction;
  final Widget center;
  final double size;

  @override
  Widget build(BuildContext context) {
    return SizedBox.square(
      dimension: size,
      child: TweenAnimationBuilder<double>(
        tween: Tween(end: fraction.clamp(0.0, 1.0)),
        duration: const Duration(milliseconds: 900),
        curve: Curves.easeOutCubic,
        builder: (context, v, child) =>
            CustomPaint(painter: _RingPainter(v), child: child),
        child: Center(child: center),
      ),
    );
  }
}

class _RingPainter extends CustomPainter {
  _RingPainter(this.value);
  final double value;

  @override
  void paint(Canvas canvas, Size size) {
    final stroke = size.width * 0.07;
    final rect = Rect.fromCircle(
      center: size.center(Offset.zero),
      radius: (size.shortestSide - stroke) / 2,
    );
    canvas.drawArc(
      rect,
      0,
      2 * math.pi,
      false,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = stroke
        ..color = const Color(0xFF2A2550),
    );
    if (value <= 0) return;
    canvas.drawArc(
      rect,
      -math.pi / 2,
      2 * math.pi * value,
      false,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = stroke
        ..strokeCap = StrokeCap.round
        ..shader = const SweepGradient(
          colors: [Palette.goldDeep, Palette.gold, Palette.goldLight],
          transform: GradientRotation(-math.pi / 2),
        ).createShader(rect),
    );
  }

  @override
  bool shouldRepaint(_RingPainter old) => old.value != value;
}
