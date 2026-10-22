import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:quit_cash_mobile/ui/core/themes/denominations.dart';
import 'package:quit_cash_mobile/ui/core/themes/palette.dart';

/// Round brilliant-cut diamond seen from the top: octagonal table, eight
/// star facets, sixteen upper-girdle facets, icy facet shading that rolls
/// with [angle], a sweeping glint and rainbow "fire" flashes. Outline and
/// glint match the coin and ruby treatment.
class DiamondPainter extends CustomPainter {
  DiamondPainter({
    required this.angle,
    this.glint = 0,
    this.metal = Metals.diamond,
  });

  final double angle;
  final double glint;
  final Metal metal;

  static const _n = 8;

  @override
  void paint(Canvas canvas, Size size) {
    final r = size.shortestSide / 2 * 0.9;
    final c = size.center(Offset.zero);
    canvas.save();
    canvas.translate(c.dx, c.dy);
    canvas.scale(0.84 + 0.16 * math.cos(angle).abs(), 1);

    Offset at(double rad, double a) => Offset(math.cos(a), math.sin(a)) * rad;
    final step = 2 * math.pi / _n;
    final twist = math.sin(angle) * 0.1;
    final table = [for (var i = 0; i < _n; i++) at(r * 0.5, i * step + twist)];
    final star = [
      for (var i = 0; i < _n; i++) at(r * 0.74, (i + 0.5) * step + twist / 2),
    ];
    final girdle = [for (var i = 0; i < _n * 2; i++) at(r, i * step / 2)];
    final outline = Path()
      ..addOval(Rect.fromCircle(center: Offset.zero, radius: r));

    _glow(canvas, r);
    canvas.drawPath(outline, Paint()..color = metal.deep);
    _facets(canvas, table, star, girdle, step);
    _table(canvas, table, r);
    _edges(canvas, table, star, girdle, r);
    canvas.drawPath(
      outline,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = r * 0.07
        ..color = metal.outline,
    );
    canvas.clipPath(outline);
    _sweep(canvas, r);
    _fire(canvas, star, r);
    canvas.restore();
  }

  Color _shade(double facetAngle, double bias) {
    final k = 0.5 + 0.5 * math.cos(facetAngle * 2 - angle * 3);
    final t = (k * 0.9 + bias).clamp(0.0, 1.0);
    return t < 0.5
        ? mixColor(metal.edge, metal.base, t * 2)
        : mixColor(metal.base, metal.light, (t - 0.5) * 2);
  }

  void _glow(Canvas canvas, double r) => canvas.drawCircle(
    Offset.zero,
    r * 1.05,
    Paint()
      ..color = metal.base.withValues(alpha: 0.45)
      ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 18),
  );

  void _facets(
    Canvas canvas,
    List<Offset> table,
    List<Offset> star,
    List<Offset> girdle,
    double step,
  ) {
    final p = Paint();
    for (var i = 0; i < _n; i++) {
      final j = (i + 1) % _n;
      final a = (i + 0.5) * step;
      // Star facet: two table corners and a star point.
      p.color = _shade(a, 0.1);
      canvas.drawPath(
        Path()..addPolygon([table[i], table[j], star[i]], true),
        p,
      );
      // Upper-girdle facets: star point to two girdle points each side.
      final g0 = girdle[2 * i],
          g1 = girdle[2 * i + 1],
          g2 = girdle[(2 * i + 2) % (_n * 2)];
      p.color = _shade(a - step / 4, -0.15);
      canvas.drawPath(Path()..addPolygon([star[i], g0, g1], true), p);
      p.color = _shade(a + step / 4, -0.05);
      canvas.drawPath(Path()..addPolygon([star[i], g1, g2], true), p);
      // Kite (bezel) facet: table corner, star points, girdle point.
      final prev = star[(i + _n - 1) % _n];
      p.color = _shade(i * step, 0.0);
      canvas.drawPath(
        Path()..addPolygon([table[i], prev, g0, star[i]], true),
        p,
      );
    }
  }

  void _table(Canvas canvas, List<Offset> table, double r) {
    canvas.drawPath(
      Path()..addPolygon(table, true),
      Paint()
        ..shader = LinearGradient(
          begin: Alignment(-1 + math.sin(angle) * 0.7, -1),
          end: const Alignment(1, 1),
          colors: [
            metal.light,
            metal.base,
            mixColor(metal.base, metal.deep, 0.5),
          ],
          stops: const [0.0, 0.6, 1.0],
        ).createShader(Rect.fromCircle(center: Offset.zero, radius: r * 0.5)),
    );
  }

  void _edges(
    Canvas canvas,
    List<Offset> table,
    List<Offset> star,
    List<Offset> girdle,
    double r,
  ) {
    final e = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = r * 0.012
      ..color = Colors.white.withValues(alpha: 0.7);
    canvas.drawPath(Path()..addPolygon(table, true), e);
    for (var i = 0; i < _n; i++) {
      canvas.drawLine(table[i], star[i], e);
      canvas.drawLine(table[(i + 1) % _n], star[i], e);
      canvas.drawLine(star[i], girdle[2 * i], e);
      canvas.drawLine(star[i], girdle[2 * i + 1], e);
      canvas.drawLine(star[i], girdle[(2 * i + 2) % (_n * 2)], e);
    }
  }

  void _sweep(Canvas canvas, double r) {
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
            Colors.white.withValues(alpha: 0.85),
            Colors.white.withValues(alpha: 0),
          ],
        ).createShader(band),
    );
    canvas.restore();
  }

  /// Rainbow fire: small four-point flashes on star facets whose hue and
  /// brightness change as the stone turns.
  void _fire(Canvas canvas, List<Offset> star, double r) {
    for (var i = 0; i < _n; i += 2) {
      final s = math.max(0.0, math.sin(angle * 2 + i * 0.9));
      if (s < 0.15) continue;
      final hue = (angle * 120 + i * 50) % 360;
      final color = HSVColor.fromAHSV(s, hue, 0.75, 1).toColor();
      final p = star[i] * 0.85;
      final len = r * 0.14 * s;
      final flash = Path()
        ..moveTo(p.dx, p.dy - len)
        ..quadraticBezierTo(p.dx, p.dy, p.dx + len, p.dy)
        ..quadraticBezierTo(p.dx, p.dy, p.dx, p.dy + len)
        ..quadraticBezierTo(p.dx, p.dy, p.dx - len, p.dy)
        ..quadraticBezierTo(p.dx, p.dy, p.dx, p.dy - len);
      canvas.drawPath(flash, Paint()..color = color);
      canvas.drawCircle(
        p,
        len * 0.22,
        Paint()..color = Colors.white.withValues(alpha: s),
      );
    }
  }

  @override
  bool shouldRepaint(DiamondPainter old) =>
      old.angle != angle || old.glint != glint || old.metal != metal;
}
