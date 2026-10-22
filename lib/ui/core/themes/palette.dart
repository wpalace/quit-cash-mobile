import 'package:flutter/material.dart';

abstract final class Palette {
  static const skyTop = Color(0xFF1B1446);
  static const skyBottom = Color(0xFF3B2A8C);
  static const gold = Color(0xFFFFD21F);
  static const goldLight = Color(0xFFFFF59A);
  static const goldDeep = Color(0xFFF29A00);
  static const goldEdge = Color(0xFFB86A00);
  static const outline = Color(0xFF5A2E00);
  static const mint = Color(0xFF3DDC97);
  static const card = Color(0x22FFFFFF);
}

/// [Color.lerp] for two non-null colors.
Color mixColor(Color a, Color b, double t) =>
    // `!` is safe: Color.lerp returns null only when both inputs are null.
    Color.lerp(a, b, t)!;

/// [Offset.lerp] for two non-null offsets.
Offset mixOffset(Offset a, Offset b, double t) =>
    // `!` is safe: Offset.lerp returns null only when both inputs are null.
    Offset.lerp(a, b, t)!;
