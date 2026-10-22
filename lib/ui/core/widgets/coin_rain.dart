import 'dart:math' as math;

import 'package:flutter/material.dart';

import 'package:quit_cash_mobile/ui/core/themes/denominations.dart';
import 'package:quit_cash_mobile/ui/core/widgets/coin_painter.dart';

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
