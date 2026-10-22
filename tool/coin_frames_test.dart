// Renders spinning-coin frames to PNG for a marketing GIF.
// Run: flutter test tool/coin_frames_test.dart --dart-define=OUT=/tmp/frames
// Optional: --dart-define=DENOM=100 (ruby), 1, 5, 10, 20, 50, 500 (default 50)
// or --dart-define=CENTS=25 for a change coin (1, 5, 10, 25).
// Also writes OUT/sheet.png with every denomination side by side.
import 'dart:io';
import 'dart:math' as math;
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:quit_cash_mobile/ui/core/themes/denominations.dart';
import 'package:quit_cash_mobile/ui/core/themes/palette.dart';
import 'package:quit_cash_mobile/ui/core/widgets/coin_painter.dart';

void main() {
  test('render coin frames', () async {
    const out = String.fromEnvironment('OUT', defaultValue: 'build/frames');
    Directory(out).createSync(recursive: true);
    const frames = 48, size = 320.0;
    const denom = int.fromEnvironment('DENOM', defaultValue: 50);
    const cents = int.fromEnvironment('CENTS');
    final d = cents > 0
        ? changeDenominations.firstWhere((c) => c.cents == cents)
        : denominationFor(denom);
    const sparkles = [(0.15, 0.2, 0.0), (0.85, 0.3, 0.4), (0.78, 0.85, 0.7)];
    for (var i = 0; i < frames; i++) {
      final t = i / frames;
      final rec = ui.PictureRecorder();
      final canvas = Canvas(rec);
      canvas.drawRect(
        const Rect.fromLTWH(0, 0, size, size),
        Paint()
          ..shader = const LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [Palette.skyTop, Palette.skyBottom],
          ).createShader(const Rect.fromLTWH(0, 0, size, size)),
      );
      canvas.save();
      canvas.translate(40, 40 + math.sin(t * 2 * math.pi) * 6);
      painterFor(
        d,
        angle: t * 2 * math.pi,
        glint: (t * 1.5) % 1,
      ).paint(canvas, const Size.square(size - 80));
      canvas.restore();
      SparklePainter(
        t: t,
        points: sparkles,
        tint: d.metal,
      ).paint(canvas, const Size.square(size));
      final img = await rec.endRecording().toImage(size.toInt(), size.toInt());
      final png = await img.toByteData(format: ui.ImageByteFormat.png);
      File(
        '$out/f${i.toString().padLeft(3, '0')}.png',
        // `!` is safe: PNG encoding of an in-memory image always yields bytes.
      ).writeAsBytesSync(png!.buffer.asUint8List());
    }
    await _sheet('$out/sheet.png', denominations);
    await _sheet('$out/change-sheet.png', changeDenominations);
  });
}

/// All [coins] side by side, slightly turned so the edge shows.
Future<void> _sheet(String path, List<Denomination> denominations) async {
  const cell = 220.0;
  final rec = ui.PictureRecorder();
  final canvas = Canvas(rec);
  final w = cell * denominations.length;
  canvas.drawRect(
    Rect.fromLTWH(0, 0, w, cell),
    Paint()..color = Palette.skyTop,
  );
  for (var i = 0; i < denominations.length; i++) {
    canvas.save();
    canvas.translate(i * cell + 20, 20);
    painterFor(
      denominations[i],
      angle: 0.5,
      glint: 0.35,
    ).paint(canvas, const Size.square(cell - 40));
    canvas.restore();
  }
  final img = await rec.endRecording().toImage(w.toInt(), cell.toInt());
  final png = await img.toByteData(format: ui.ImageByteFormat.png);
  // `!` is safe: PNG encoding of an in-memory image always yields bytes.
  File(path).writeAsBytesSync(png!.buffer.asUint8List());
}
