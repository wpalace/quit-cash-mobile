import 'dart:math' as math;

import 'package:flutter/material.dart';

import 'package:quit_cash_mobile/ui/core/themes/denominations.dart';
import 'package:quit_cash_mobile/ui/core/themes/palette.dart';

/// Radial burst of gold sparks + floating "+$5" label.
class CoinBurst extends StatefulWidget {
  const CoinBurst({
    super.key,
    required this.at,
    required this.label,
    required this.onDone,
    this.metal = Metals.gold,
  });

  final Metal metal;

  final Offset at;
  final String label;
  final VoidCallback onDone;

  @override
  State<CoinBurst> createState() => _CoinBurstState();
}

class _CoinBurstState extends State<CoinBurst>
    with SingleTickerProviderStateMixin {
  late final AnimationController _c = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 900),
  )..forward().whenComplete(widget.onDone);
  final _rnd = math.Random();
  late final _parts = List.generate(
    18,
    (i) => (
      i / 18 * 2 * math.pi + _rnd.nextDouble() * 0.3,
      80 + _rnd.nextDouble() * 70,
    ),
  );

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Positioned.fill(
      child: IgnorePointer(
        child: AnimatedBuilder(
          animation: _c,
          builder: (context, _) => CustomPaint(
            painter: _BurstPainter(_c.value, widget.at, _parts, widget.metal),
            child: Stack(
              children: [
                Positioned(
                  left: widget.at.dx - 60,
                  top:
                      widget.at.dy -
                      120 -
                      80 * Curves.easeOut.transform(_c.value),
                  width: 120,
                  child: Opacity(
                    opacity: (1 - _c.value).clamp(0, 1),
                    child: Text(
                      widget.label,
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        fontSize: 36,
                        fontWeight: FontWeight.w900,
                        color: widget.metal.light,
                        shadows: [
                          Shadow(
                            color: widget.metal.outline,
                            offset: const Offset(2, 3),
                          ),
                          Shadow(color: widget.metal.deep, blurRadius: 12),
                        ],
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _BurstPainter extends CustomPainter {
  _BurstPainter(this.t, this.at, this.parts, this.metal);
  final Metal metal;
  final double t;
  final Offset at;
  final List<(double, double)> parts;

  @override
  void paint(Canvas canvas, Size size) {
    final e = Curves.easeOutCubic.transform(t);
    canvas.drawCircle(
      at,
      40 + 120 * e,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 10 * (1 - t)
        ..color = metal.light.withValues(alpha: (1 - t) * 0.8),
    );
    for (final (a, d) in parts) {
      final p = at + Offset(math.cos(a), math.sin(a)) * (d * e + 30);
      canvas.drawCircle(
        p,
        6 * (1 - t) + 1,
        Paint()..color = mixColor(metal.light, metal.base, t),
      );
    }
  }

  @override
  bool shouldRepaint(_BurstPainter old) => old.t != t;
}
