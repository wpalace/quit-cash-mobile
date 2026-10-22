import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:quit_cash_mobile/ui/core/themes/palette.dart';

/// Rounded bars of dollars per bucket that grow in smoothly. The tallest
/// bar is highlighted gold; [labels] (may contain '') sit under the bars.
class SavingsBarChart extends StatelessWidget {
  const SavingsBarChart({
    super.key,
    required this.values,
    required this.labels,
    this.height = 150,
  });

  final List<int> values;
  final List<String> labels;
  final double height;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: height,
      child: TweenAnimationBuilder<double>(
        key: ValueKey(values.length),
        tween: Tween(begin: 0, end: 1),
        duration: const Duration(milliseconds: 700),
        curve: Curves.easeOutCubic,
        builder: (context, t, _) => CustomPaint(
          size: Size.infinite,
          painter: _BarsPainter(values, labels, t),
        ),
      ),
    );
  }
}

class _BarsPainter extends CustomPainter {
  _BarsPainter(this.values, this.labels, this.t);
  final List<int> values;
  final List<String> labels;
  final double t;

  @override
  void paint(Canvas canvas, Size size) {
    if (values.isEmpty) return;
    const labelH = 18.0;
    final chartH = size.height - labelH;
    final maxV = values.reduce(math.max);
    final slot = size.width / values.length;
    final w = math.max(2.0, slot * 0.62);
    final peak = values.indexOf(maxV);
    for (var i = 0; i < values.length; i++) {
      final x = slot * i + (slot - w) / 2;
      final frac = maxV == 0 ? 0.0 : values[i] / maxV;
      final h = math.max(3.0, chartH * frac * t);
      final r = RRect.fromRectAndRadius(
        Rect.fromLTWH(x, chartH - h, w, h),
        Radius.circular(w / 2),
      );
      canvas.drawRRect(
        r,
        Paint()
          ..color = values[i] == 0
              ? const Color(0xFF2A2550)
              : i == peak
              ? Palette.gold
              : Palette.gold.withValues(alpha: 0.45),
      );
      if (i < labels.length && labels[i].isNotEmpty) {
        final tp = TextPainter(
          text: TextSpan(
            text: labels[i],
            style: const TextStyle(color: Colors.white54, fontSize: 11),
          ),
          textDirection: TextDirection.ltr,
        )..layout();
        tp.paint(canvas, Offset(x + w / 2 - tp.width / 2, chartH + 4));
      }
    }
  }

  @override
  bool shouldRepaint(_BarsPainter old) =>
      old.t != t || old.values != values || old.labels != labels;
}
