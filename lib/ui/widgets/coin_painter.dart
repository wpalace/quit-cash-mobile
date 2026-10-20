import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../palette.dart';

/// Paints a chunky, cartoon-3D gold coin rotated [angle] radians around the
/// vertical (Y) axis. Original artwork in the spirit of classic 3D platformer
/// coins: bright face gradient, dark rim, visible edge thickness when turned,
/// embossed star, moving specular glint and a bold outline.
class CoinPainter extends CustomPainter {
  CoinPainter({
    required this.angle,
    this.glint = 0,
    this.thicknessRatio = 0.16,
  });

  final double angle;

  /// 0..1 phase of the sweeping highlight.
  final double glint;
  final double thicknessRatio;

  @override
  void paint(Canvas canvas, Size size) {
    final r = size.shortestSide / 2 * 0.92;
    final c = size.center(Offset.zero);
    final cosA = math.cos(angle);
    final sinA = math.sin(angle);
    final faceW = (r * cosA.abs()).clamp(r * 0.02, r);
    final thick = r * thicknessRatio;
    final edgeShift = thick * sinA; // edge peeks out on the turning side

    // Edge: a stack of ellipses from the back face to the front face.
    final back = c.translate(-edgeShift / 2, 0);
    final front = c.translate(edgeShift / 2, 0);
    final edgePaint = Paint()..style = PaintingStyle.fill;
    const steps = 14;
    for (var i = 0; i <= steps; i++) {
      final t = i / steps;
      final p = Offset.lerp(back, front, t)!;
      // Ridged edge: alternate shades like reeding.
      edgePaint.color = Color.lerp(
        Palette.goldEdge,
        Palette.goldDeep,
        (i.isEven ? 0.2 : 0.65),
      )!;
      canvas.drawOval(
        Rect.fromCenter(center: p, width: faceW * 2, height: r * 2),
        edgePaint,
      );
    }
    // Edge outline.
    final outline = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = r * 0.07
      ..color = Palette.outline;
    final edgePath = Path()
      ..addOval(Rect.fromCenter(center: back, width: faceW * 2, height: r * 2))
      ..addRect(
        Rect.fromLTRB(
          math.min(back.dx, front.dx),
          c.dy - r,
          math.max(back.dx, front.dx),
          c.dy + r,
        ),
      );
    canvas.drawPath(edgePath, outline);

    // Front face.
    final faceRect = Rect.fromCenter(
      center: front,
      width: faceW * 2,
      height: r * 2,
    );
    final light = 0.55 + 0.45 * cosA.abs(); // dimmer when edge-on
    canvas.drawOval(
      faceRect,
      Paint()
        ..shader = RadialGradient(
          center: const Alignment(-0.35, -0.45),
          radius: 1.05,
          colors: [
            Color.lerp(Palette.goldDeep, Palette.goldLight, light)!,
            Color.lerp(Palette.goldEdge, Palette.gold, light)!,
            Palette.goldDeep,
          ],
          stops: const [0.0, 0.55, 1.0],
        ).createShader(faceRect),
    );
    canvas.drawOval(faceRect, outline);

    canvas.save();
    canvas.translate(front.dx, front.dy);
    canvas.scale(faceW / r, 1);

    // Inner raised rim.
    canvas.drawCircle(
      Offset.zero,
      r * 0.76,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = r * 0.07
        ..color = Palette.goldEdge.withValues(alpha: 0.75),
    );
    canvas.drawCircle(
      Offset(-r * 0.02, -r * 0.03),
      r * 0.76,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = r * 0.025
        ..color = Palette.goldLight.withValues(alpha: 0.9),
    );

    // Embossed star: shadow, body, highlight.
    final star = _star(r * 0.46, r * 0.2);
    canvas.drawPath(
      star.shift(Offset(r * 0.04, r * 0.05)),
      Paint()..color = Palette.goldEdge.withValues(alpha: 0.8),
    );
    canvas.drawPath(
      star,
      Paint()
        ..shader = const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [Palette.goldLight, Palette.gold, Palette.goldDeep],
        ).createShader(Rect.fromCircle(center: Offset.zero, radius: r * 0.46)),
    );
    canvas.drawPath(
      star,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = r * 0.03
        ..strokeJoin = StrokeJoin.round
        ..color = Palette.outline.withValues(alpha: 0.6),
    );

    // Sweeping specular glint, clipped to the face.
    canvas.clipPath(
      Path()..addOval(Rect.fromCircle(center: Offset.zero, radius: r)),
    );
    final gx = (glint * 2 - 1) * r * 1.8 + sinA * r * 0.6;
    canvas.save();
    canvas.translate(gx, 0);
    canvas.rotate(-0.5);
    canvas.drawRect(
      Rect.fromCenter(center: Offset.zero, width: r * 0.28, height: r * 3),
      Paint()
        ..shader =
            LinearGradient(
              colors: [
                Colors.white.withValues(alpha: 0),
                Colors.white.withValues(alpha: 0.85),
                Colors.white.withValues(alpha: 0),
              ],
            ).createShader(
              Rect.fromCenter(
                center: Offset.zero,
                width: r * 0.28,
                height: r * 3,
              ),
            ),
    );
    canvas.restore();
    // Static top-left gloss.
    canvas.drawOval(
      Rect.fromCenter(
        center: Offset(-r * 0.38, -r * 0.48),
        width: r * 0.42,
        height: r * 0.22,
      ),
      Paint()..color = Colors.white.withValues(alpha: 0.55 * light),
    );
    canvas.restore();
  }

  Path _star(double outer, double inner) {
    final path = Path();
    for (var i = 0; i < 10; i++) {
      final rad = i.isEven ? outer : inner;
      final a = -math.pi / 2 + i * math.pi / 5;
      final p = Offset(math.cos(a) * rad, math.sin(a) * rad);
      i == 0 ? path.moveTo(p.dx, p.dy) : path.lineTo(p.dx, p.dy);
    }
    return path..close();
  }

  @override
  bool shouldRepaint(CoinPainter old) =>
      old.angle != angle || old.glint != glint;
}

/// Four-point twinkle star.
class SparklePainter extends CustomPainter {
  SparklePainter({required this.t, required this.points});

  /// Animation phase 0..1.
  final double t;

  /// Normalised positions (0..1) with a phase offset in z.
  final List<(double, double, double)> points;

  @override
  void paint(Canvas canvas, Size size) {
    for (final (x, y, phase) in points) {
      final s = math.max(0.0, math.sin((t + phase) * math.pi * 2));
      if (s <= 0.01) continue;
      final len = size.shortestSide * 0.07 * s;
      final p = Offset(x * size.width, y * size.height);
      final paint = Paint()..color = Colors.white.withValues(alpha: s);
      final path = Path()
        ..moveTo(p.dx, p.dy - len)
        ..quadraticBezierTo(p.dx, p.dy, p.dx + len, p.dy)
        ..quadraticBezierTo(p.dx, p.dy, p.dx, p.dy + len)
        ..quadraticBezierTo(p.dx, p.dy, p.dx - len, p.dy)
        ..quadraticBezierTo(p.dx, p.dy, p.dx, p.dy - len);
      canvas.drawPath(path, paint);
      canvas.drawCircle(
        p,
        len * 0.25,
        Paint()..color = Palette.goldLight.withValues(alpha: s),
      );
    }
  }

  @override
  bool shouldRepaint(SparklePainter old) => old.t != t;
}
