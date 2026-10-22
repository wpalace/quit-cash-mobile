import 'package:flutter/material.dart';

/// Five-stop material ramp used by every coin/gem painter and effect so the
/// outline/highlight treatment is consistent across denominations.
@immutable
class Metal {
  const Metal({
    required this.light,
    required this.base,
    required this.deep,
    required this.edge,
    required this.outline,
  });

  /// Specular / sparkle tint.
  final Color light;

  /// Main face color.
  final Color base;

  /// Shadowed face and rim.
  final Color deep;

  /// Coin edge (reeding) color.
  final Color edge;

  /// Bold cartoon outline.
  final Color outline;
}

abstract final class Metals {
  static const copper = Metal(
    light: Color(0xFFFFD2B0),
    base: Color(0xFFE08A4F),
    deep: Color(0xFFB0582A),
    edge: Color(0xFF7E3A17),
    outline: Color(0xFF451C07),
  );
  static const silver = Metal(
    light: Color(0xFFFFFFFF),
    base: Color(0xFFD5DCE4),
    deep: Color(0xFF9AA6B4),
    edge: Color(0xFF6C7887),
    outline: Color(0xFF2E3742),
  );
  static const sapphire = Metal(
    light: Color(0xFFBFE3FF),
    base: Color(0xFF3D8BFF),
    deep: Color(0xFF1F55C9),
    edge: Color(0xFF173A8F),
    outline: Color(0xFF0A1C4D),
  );
  static const emerald = Metal(
    light: Color(0xFFC6FFD9),
    base: Color(0xFF2FCB6E),
    deep: Color(0xFF138A47),
    edge: Color(0xFF0C5F31),
    outline: Color(0xFF032A14),
  );
  static const gold = Metal(
    light: Color(0xFFFFF59A),
    base: Color(0xFFFFD21F),
    deep: Color(0xFFF29A00),
    edge: Color(0xFFB86A00),
    outline: Color(0xFF5A2E00),
  );
  static const ruby = Metal(
    light: Color(0xFFFFC2CF),
    base: Color(0xFFE0123F),
    deep: Color(0xFF9B0626),
    edge: Color(0xFF5E0016),
    outline: Color(0xFF33000B),
  );
}

@immutable
class Denomination {
  const Denomination(this.dollars, this.name, this.metal, {this.isGem = false});

  final int dollars;
  final String name;
  final Metal metal;

  /// Drawn as a faceted gem instead of a coin.
  final bool isGem;

  String get label => '\$$dollars';
}

const denominations = <Denomination>[
  Denomination(1, 'Copper', Metals.copper),
  Denomination(5, 'Silver', Metals.silver),
  defaultCoin,
  Denomination(20, 'Emerald', Metals.emerald),
  Denomination(50, 'Sapphire', Metals.sapphire),
  Denomination(100, 'Ruby', Metals.ruby, isGem: true),
];

/// Gold coin: the HUD counter icon and default coin artwork.
const defaultCoin = Denomination(10, 'Gold', Metals.gold);

/// Denominations that can be hidden in Settings.
const optionalDenominations = {50, 100};

Denomination denominationFor(num dollars) => denominations.firstWhere(
  (d) => d.dollars == dollars,
  orElse: () => defaultCoin,
);

/// The picker list after applying the Settings toggles.
List<Denomination> visibleDenominations({
  required bool showFifty,
  required bool showHundred,
}) => [
  for (final d in denominations)
    if ((d.dollars != 50 || showFifty) && (d.dollars != 100 || showHundred)) d,
];
