import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../denominations.dart';
import 'coin_painter.dart';

/// Number that rolls smoothly to its new value (slot-machine feel).
class TickingNumber extends StatelessWidget {
  const TickingNumber({
    super.key,
    required this.value,
    required this.format,
    required this.style,
    this.duration = const Duration(milliseconds: 700),
  });

  final double value;
  final String Function(double) format;
  final TextStyle style;
  final Duration duration;

  @override
  Widget build(BuildContext context) {
    return TweenAnimationBuilder<double>(
      tween: Tween(end: value),
      duration: duration,
      curve: Curves.easeOutCubic,
      builder: (context, v, _) => Text(format(v), style: style),
    );
  }
}

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
        Paint()..color = Color.lerp(metal.light, metal.base, t)!,
      );
    }
  }

  @override
  bool shouldRepaint(_BurstPainter old) => old.t != t;
}

/// Coins raining down for big moments (level up, badges).
class CoinRain extends StatefulWidget {
  const CoinRain({super.key, this.count = 24});
  final int count;

  @override
  State<CoinRain> createState() => _CoinRainState();
}

class _CoinRainState extends State<CoinRain>
    with SingleTickerProviderStateMixin {
  late final AnimationController _c = AnimationController(
    vsync: this,
    duration: const Duration(seconds: 3),
  )..repeat();
  final _rnd = math.Random(7);
  late final _coins = List.generate(
    widget.count,
    (i) => (
      _rnd.nextDouble(),
      _rnd.nextDouble(),
      18 + _rnd.nextDouble() * 22,
      denominations[i % denominations.length],
    ),
  );

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return IgnorePointer(
      child: LayoutBuilder(
        builder: (context, box) {
          return AnimatedBuilder(
            animation: _c,
            builder: (context, _) => Stack(
              children: [
                for (final (x, phase, s, d) in _coins)
                  Positioned(
                    left: x * box.maxWidth,
                    top: ((_c.value + phase) % 1.0) * (box.maxHeight + 60) - 60,
                    child: CustomPaint(
                      size: Size.square(s),
                      painter: painterFor(
                        d,
                        angle: (_c.value * 4 + phase * 6) * math.pi,
                        glint: phase,
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
