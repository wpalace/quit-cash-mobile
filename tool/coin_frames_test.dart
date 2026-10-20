// Renders spinning-coin frames to PNG for a marketing GIF.
// Run: flutter test tool/coin_frames_test.dart --dart-define=OUT=/tmp/frames
import 'dart:io';
import 'dart:math' as math;
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:quit_cash_mobile/ui/palette.dart';
import 'package:quit_cash_mobile/ui/widgets/coin_painter.dart';

void main() {
  test('render coin frames', () async {
    const out = String.fromEnvironment('OUT', defaultValue: 'build/frames');
    Directory(out).createSync(recursive: true);
    const frames = 48, size = 320.0;
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
      CoinPainter(
        angle: t * 2 * math.pi,
        glint: (t * 1.5) % 1,
      ).paint(canvas, const Size.square(size - 80));
      canvas.restore();
      SparklePainter(
        t: t,
        points: sparkles,
      ).paint(canvas, const Size.square(size));
      final img = await rec.endRecording().toImage(size.toInt(), size.toInt());
      final png = await img.toByteData(format: ui.ImageByteFormat.png);
      File(
        '$out/f${i.toString().padLeft(3, '0')}.png',
      ).writeAsBytesSync(png!.buffer.asUint8List());
    }
  });
}
