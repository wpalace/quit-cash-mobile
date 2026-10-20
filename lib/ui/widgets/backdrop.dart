import 'package:flutter/material.dart';

import '../palette.dart';

/// Night-sky gradient with soft static stars; gold pops against it.
class Backdrop extends StatelessWidget {
  const Backdrop({super.key, required this.child});
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [Palette.skyTop, Palette.skyBottom, Color(0xFF6A3FB5)],
        ),
      ),
      child: CustomPaint(painter: _Stars(), child: child),
    );
  }
}

class _Stars extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final p = Paint()..color = Colors.white.withValues(alpha: 0.35);
    for (var i = 0; i < 60; i++) {
      final x = (i * 97 % 101) / 101 * size.width;
      final y = (i * 53 % 89) / 89 * size.height;
      canvas.drawCircle(Offset(x, y), (i % 3 + 1) * 0.7, p);
    }
  }

  @override
  bool shouldRepaint(_Stars oldDelegate) => false;
}
