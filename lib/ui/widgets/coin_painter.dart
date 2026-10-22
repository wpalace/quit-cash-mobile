import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../denominations.dart';

/// Paints a chunky, cartoon-3D gold coin rotated [angle] radians around the
/// vertical (Y) axis. Original artwork in the spirit of classic 3D platformer
/// coins: bright face gradient, dark rim, visible edge thickness when turned,
/// embossed star, moving specular glint and a bold outline.
class CoinPainter extends CustomPainter {
  CoinPainter({
    required this.angle,
    this.glint = 0,
    this.thicknessRatio = 0.16,
    this.metal = Metals.gold,
  });

  /// Color ramp (copper, silver, sapphire, emerald, gold, ...).
  final Metal metal;

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
        metal.edge,
        metal.deep,
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
      ..color = metal.outline;
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
            Color.lerp(metal.deep, metal.light, light)!,
            Color.lerp(metal.edge, metal.base, light)!,
            metal.deep,
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
        ..color = metal.edge.withValues(alpha: 0.75),
    );
    canvas.drawCircle(
      Offset(-r * 0.02, -r * 0.03),
      r * 0.76,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = r * 0.025
        ..color = metal.light.withValues(alpha: 0.9),
    );

    // Embossed star: shadow, body, highlight.
    final star = _star(r * 0.46, r * 0.2);
    canvas.drawPath(
      star.shift(Offset(r * 0.04, r * 0.05)),
      Paint()..color = metal.edge.withValues(alpha: 0.8),
    );
    canvas.drawPath(
      star,
      Paint()
        ..shader = LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [metal.light, metal.base, metal.deep],
        ).createShader(Rect.fromCircle(center: Offset.zero, radius: r * 0.46)),
    );
    canvas.drawPath(
      star,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = r * 0.03
        ..strokeJoin = StrokeJoin.round
        ..color = metal.outline.withValues(alpha: 0.6),
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
      old.angle != angle || old.glint != glint || old.metal != metal;
}

/// Four-point twinkle star.
class SparklePainter extends CustomPainter {
  SparklePainter({
    required this.t,
    required this.points,
    this.tint = Metals.gold,
  });

  final Metal tint;

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
        Paint()..color = tint.light.withValues(alpha: s),
      );
    }
  }

  @override
  bool shouldRepaint(SparklePainter old) => old.t != t;
}

/// Faceted, cushion-cut ruby seen from the front. The "spin" is a turntable
/// shimmer: the gem narrows slightly with |cos| and every facet's shading
/// follows the rotation, so light rolls across the cut. Glint and outline
/// match the coin treatment.
class GemPainter extends CustomPainter {
  GemPainter({required this.angle, this.glint = 0, this.metal = Metals.ruby});

  final double angle;
  final double glint;
  final Metal metal;

  static const _sides = 8;

  @override
  void paint(Canvas canvas, Size size) {
    final r = size.shortestSide / 2 * 0.9;
    final c = size.center(Offset.zero);
    final squeeze = 0.78 + 0.22 * math.cos(angle).abs();
    canvas.save();
    canvas.translate(c.dx, c.dy);
    canvas.scale(squeeze, 1);

    Offset vert(double rad, int i, double rot) {
      final a = -math.pi / 2 + (i + 0.5) * 2 * math.pi / _sides + rot;
      return Offset(math.cos(a) * rad * 0.92, math.sin(a) * rad);
    }

    // Outer girdle and inner table (table rotates a touch for parallax).
    final outer = [for (var i = 0; i < _sides; i++) vert(r, i, 0)];
    final mid = [
      for (var i = 0; i < _sides; i++) vert(r * 0.78, i, math.pi / _sides),
    ];
    final table = [
      for (var i = 0; i < _sides; i++)
        vert(r * 0.46, i, math.sin(angle) * 0.12),
    ];
    final girdle = Path()..addPolygon(outer, true);

    // Glow behind the gem.
    canvas.drawCircle(
      Offset.zero,
      r * 1.05,
      Paint()
        ..color = metal.base.withValues(alpha: 0.35)
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 18),
    );
    canvas.drawPath(girdle, Paint()..color = metal.deep);

    // Facet shading driven by facet direction vs. rotating light.
    Color shade(double facetAngle, double bias) {
      final k = 0.5 + 0.5 * math.cos(facetAngle - angle * 2 + 0.8);
      final t = (k * 0.85 + bias).clamp(0.0, 1.0);
      return t < 0.5
          ? Color.lerp(metal.edge, metal.base, t * 2)!
          : Color.lerp(metal.base, metal.light, (t - 0.5) * 1.4)!;
    }

    final facet = Paint()..style = PaintingStyle.fill;
    for (var i = 0; i < _sides; i++) {
      final j = (i + 1) % _sides;
      final a = i * 2 * math.pi / _sides;
      // Crown facets: girdle -> mid ring (kite) and mid -> table (trapezoid).
      facet.color = shade(a, -0.1);
      canvas.drawPath(
        Path()..addPolygon([outer[i], outer[j], mid[i]], true),
        facet,
      );
      facet.color = shade(a + math.pi / _sides, 0.0);
      canvas.drawPath(
        Path()..addPolygon([
          outer[i],
          mid[i],
          mid[(i + _sides - 1) % _sides],
        ], true),
        facet,
      );
      facet.color = shade(a + 0.4, 0.12);
      canvas.drawPath(
        Path()..addPolygon([mid[i], table[i], table[j], mid[j]], true),
        facet,
      );
    }
    // Table: flat polished face with a diagonal sheen that follows the spin.
    final tablePath = Path()..addPolygon(table, true);
    canvas.drawPath(
      tablePath,
      Paint()
        ..shader = LinearGradient(
          begin: Alignment(-1 + math.sin(angle) * 0.6, -1),
          end: const Alignment(1, 1),
          colors: [
            Color.lerp(metal.base, metal.light, 0.55)!,
            metal.base,
            metal.deep,
          ],
          stops: const [0.0, 0.55, 1.0],
        ).createShader(Rect.fromCircle(center: Offset.zero, radius: r * 0.5)),
    );

    // Facet edges (thin light lines) and bold outline.
    final edges = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = r * 0.012
      ..color = metal.light.withValues(alpha: 0.45);
    for (var i = 0; i < _sides; i++) {
      canvas.drawLine(outer[i], mid[i], edges);
      canvas.drawLine(mid[i], table[i], edges);
      canvas.drawLine(outer[i], mid[(i + _sides - 1) % _sides], edges);
    }
    canvas.drawPath(Path()..addPolygon(mid, true), edges);
    canvas.drawPath(tablePath, edges);
    canvas.drawPath(
      girdle,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = r * 0.07
        ..strokeJoin = StrokeJoin.round
        ..color = metal.outline,
    );

    // Sweeping glint, clipped to the gem.
    canvas.clipPath(girdle);
    canvas.save();
    canvas.translate((glint * 2 - 1) * r * 1.8, 0);
    canvas.rotate(-0.6);
    final band = Rect.fromCenter(
      center: Offset.zero,
      width: r * 0.22,
      height: r * 3,
    );
    canvas.drawRect(
      band,
      Paint()
        ..shader = LinearGradient(
          colors: [
            Colors.white.withValues(alpha: 0),
            Colors.white.withValues(alpha: 0.75),
            Colors.white.withValues(alpha: 0),
          ],
        ).createShader(band),
    );
    canvas.restore();
    // Fixed star-glint on the table corner.
    final g = table[6] + Offset(r * 0.06, r * 0.04);
    final gl = r * 0.16 * (0.6 + 0.4 * math.sin(angle * 3).abs());
    final star = Path()
      ..moveTo(g.dx, g.dy - gl)
      ..quadraticBezierTo(g.dx, g.dy, g.dx + gl, g.dy)
      ..quadraticBezierTo(g.dx, g.dy, g.dx, g.dy + gl)
      ..quadraticBezierTo(g.dx, g.dy, g.dx - gl, g.dy)
      ..quadraticBezierTo(g.dx, g.dy, g.dx, g.dy - gl);
    canvas.drawPath(
      star,
      Paint()..color = Colors.white.withValues(alpha: 0.95),
    );
    canvas.restore();
  }

  @override
  bool shouldRepaint(GemPainter old) =>
      old.angle != angle || old.glint != glint || old.metal != metal;
}

/// Coin or gem painter for [d] at a spin [angle].
CustomPainter painterFor(
  Denomination d, {
  required double angle,
  double glint = 0,
}) => d.isGem
    ? GemPainter(angle: angle, glint: glint, metal: d.metal)
    : CoinPainter(angle: angle, glint: glint, metal: d.metal);
