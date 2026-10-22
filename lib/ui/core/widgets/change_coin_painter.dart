import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:quit_cash_mobile/ui/core/themes/denominations.dart';

/// Spinning change coin (1¢, 5¢, 10¢, 25¢): same cartoon outline, edge
/// stack and sweeping glint as the dollar coins, but smaller and thinner,
/// with its own outline: round penny, scalloped nickel, holed dime and a
/// two-tone octagonal quarter.
class ChangeCoinPainter extends CustomPainter {
  ChangeCoinPainter({
    required this.denomination,
    required this.angle,
    this.glint = 0,
  });

  final Denomination denomination;
  final double angle;
  final double glint;

  Metal get _metal => denomination.metal;

  /// Unit outline (radius 1, centered on the origin). Holes use even-odd.
  static Path unitPath(CoinShape shape, [double scale = 1]) {
    final p = Path();
    switch (shape) {
      case CoinShape.round:
        p.addOval(Rect.fromCircle(center: Offset.zero, radius: scale));
      case CoinShape.holed:
        p
          ..fillType = PathFillType.evenOdd
          ..addOval(Rect.fromCircle(center: Offset.zero, radius: scale))
          ..addOval(Rect.fromCircle(center: Offset.zero, radius: scale * 0.27));
      case CoinShape.scalloped:
        const n = 120;
        for (var i = 0; i <= n; i++) {
          final t = i / n * 2 * math.pi;
          final r = scale * (0.93 + 0.07 * math.cos(12 * t));
          final o = Offset(math.cos(t) * r, math.sin(t) * r);
          i == 0 ? p.moveTo(o.dx, o.dy) : p.lineTo(o.dx, o.dy);
        }
        p.close();
      case CoinShape.octagonal:
        p.addPolygon([
          for (var k = 0; k < 8; k++)
            Offset(
              math.cos(math.pi / 8 + k * math.pi / 4) * scale,
              math.sin(math.pi / 8 + k * math.pi / 4) * scale,
            ),
        ], true);
    }
    return p;
  }

  Path _placed(Path unit, Offset c, double sx, double sy) {
    final m = Matrix4.identity()
      ..translateByDouble(c.dx, c.dy, 0, 1)
      ..scaleByDouble(sx, sy, 1, 1);
    return unit.transform(m.storage);
  }

  @override
  void paint(Canvas canvas, Size size) {
    final r = size.shortestSide / 2 * 0.92 * denomination.scale;
    final c = size.center(Offset.zero);
    final cosA = math.cos(angle);
    final faceW = (r * cosA.abs()).clamp(r * 0.03, r);
    final shift = r * 0.1 * math.sin(angle); // thin edge
    final unit = unitPath(denomination.shape);
    final light = 0.55 + 0.45 * cosA.abs();

    // Edge stack, back to front.
    final back = c.translate(-shift / 2, 0), front = c.translate(shift / 2, 0);
    const steps = 8;
    for (var i = 0; i <= steps; i++) {
      final p = Offset.lerp(back, front, i / steps) ?? front;
      canvas.drawPath(
        _placed(unit, p, faceW, r),
        Paint()
          ..color =
              Color.lerp(_metal.edge, _metal.deep, i.isEven ? 0.2 : 0.6) ??
              _metal.edge,
      );
    }
    final outline = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = r * 0.08
      ..strokeJoin = StrokeJoin.round
      ..color = _metal.outline;
    canvas.drawPath(_placed(unit, back, faceW, r), outline);

    // Face.
    final face = _placed(unit, front, faceW, r);
    final faceRect = Rect.fromCenter(
      center: front,
      width: faceW * 2,
      height: r * 2,
    );
    canvas.drawPath(face, _facePaint(_metal, faceRect, light));
    final inner = denomination.inner;
    if (inner != null) {
      final core = _placed(unitPath(denomination.shape, 0.6), front, faceW, r);
      canvas.drawPath(core, _facePaint(inner, faceRect, light));
      canvas.drawPath(
        core,
        Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = r * 0.04
          ..color = inner.edge,
      );
    }
    // Raised rim.
    canvas.drawPath(
      _placed(unitPath(denomination.shape, 0.82), front, faceW, r),
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = r * 0.05
        ..color =
            Color.lerp(_metal.deep, _metal.light, 0.25 * light) ?? _metal.deep,
    );
    _glint(canvas, face, faceRect);
    canvas.drawPath(face, outline);
  }

  Paint _facePaint(Metal m, Rect rect, double light) =>
      Paint()
        ..shader = RadialGradient(
          center: const Alignment(-0.35, -0.45),
          radius: 1.05,
          colors: [
            Color.lerp(m.deep, m.light, light) ?? m.light,
            Color.lerp(m.edge, m.base, light) ?? m.base,
            m.deep,
          ],
          stops: const [0.0, 0.55, 1.0],
        ).createShader(rect);

  void _glint(Canvas canvas, Path face, Rect rect) {
    // The nickel is matte: a softer highlight.
    final strength = denomination.shape == CoinShape.scalloped ? 0.35 : 0.85;
    canvas.save();
    canvas.clipPath(face);
    final x = rect.left + rect.width * (glint * 1.6 - 0.3);
    final band = Path()
      ..moveTo(x, rect.top)
      ..lineTo(x + rect.width * 0.22, rect.top)
      ..lineTo(x - rect.width * 0.1, rect.bottom)
      ..lineTo(x - rect.width * 0.32, rect.bottom)
      ..close();
    canvas.drawPath(
      band,
      Paint()..color = Colors.white.withValues(alpha: strength * 0.7),
    );
    canvas.restore();
  }

  @override
  bool shouldRepaint(ChangeCoinPainter old) =>
      old.angle != angle ||
      old.glint != glint ||
      old.denomination != denomination;
}
