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
  static const diamond = Metal(
    light: Color(0xFFFFFFFF),
    base: Color(0xFFD6F1FF),
    deep: Color(0xFF8CC4EA),
    edge: Color(0xFF4E86B5),
    outline: Color(0xFF173352),
  );

  /// Penny: redder and darker than the \$1 copper.
  static const penny = Metal(
    light: Color(0xFFF2A07A),
    base: Color(0xFFB4502C),
    deep: Color(0xFF7C2C12),
    edge: Color(0xFF581C08),
    outline: Color(0xFF2B0C02),
  );

  /// Nickel: matte grey pewter, low contrast.
  static const nickel = Metal(
    light: Color(0xFFC9CDD0),
    base: Color(0xFF9DA3A7),
    deep: Color(0xFF71787D),
    edge: Color(0xFF52595E),
    outline: Color(0xFF22272A),
  );

  /// Dime: bright polished silver, cooler and lighter than the \$5.
  static const dime = Metal(
    light: Color(0xFFFFFFFF),
    base: Color(0xFFEFF5FB),
    deep: Color(0xFFAFC0D2),
    edge: Color(0xFF7D90A6),
    outline: Color(0xFF263443),
  );

  /// Quarter center: warm brass.
  static const brass = Metal(
    light: Color(0xFFFFF1AE),
    base: Color(0xFFD8B347),
    deep: Color(0xFFA38026),
    edge: Color(0xFF755A14),
    outline: Color(0xFF3B2B06),
  );
}

/// How a denomination is drawn.
enum Cut {
  /// Spinning coin.
  coin,

  /// Cushion-cut colored gem (ruby).
  cushion,

  /// Round brilliant (diamond) with rainbow fire.
  brilliant,
}

/// Outline of a change coin.
enum CoinShape {
  /// Plain disc (penny).
  round,

  /// Wavy flower edge (nickel).
  scalloped,

  /// Disc with a center hole, washer style (dime).
  holed,

  /// Eight-sided (quarter).
  octagonal,
}

@immutable
class Denomination {
  /// A dollar coin or gem worth [dollars].
  const Denomination(int dollars, this.name, this.metal, {this.cut = Cut.coin})
    : cents = dollars * 100,
      shape = CoinShape.round,
      inner = null,
      scale = 1;

  /// A change coin worth [cents] (under \$1), drawn smaller and thinner.
  const Denomination.change(
    this.cents,
    this.name,
    this.metal, {
    required this.shape,
    required this.scale,
    this.inner,
  }) : cut = Cut.coin;

  /// Value in integer cents.
  final int cents;
  final String name;
  final Metal metal;
  final Cut cut;
  final CoinShape shape;

  /// Second metal for the center of a two-tone coin.
  final Metal? inner;

  /// Drawn size relative to a dollar coin.
  final double scale;

  /// Whole dollars (0 for change coins).
  int get dollars => cents ~/ 100;

  bool get isChange => cents < 100;

  /// Drawn as a faceted gem instead of a coin.
  bool get isGem => cut != Cut.coin;

  /// '\$5' or '25¢'.
  String get label => isChange ? '$cents¢' : '\$$dollars';

  /// Stable id for keys: '5' for \$5, 'c25' for 25¢.
  String get id => isChange ? 'c$cents' : '$dollars';
}

const denominations = <Denomination>[
  Denomination(1, 'Copper', Metals.copper),
  Denomination(5, 'Silver', Metals.silver),
  defaultCoin,
  Denomination(20, 'Emerald', Metals.emerald),
  Denomination(50, 'Sapphire', Metals.sapphire),
  Denomination(100, 'Ruby', Metals.ruby, cut: Cut.cushion),
  Denomination(500, 'Diamond', Metals.diamond, cut: Cut.brilliant),
];

/// Change mode coins (Settings > Change), smallest first.
const changeDenominations = <Denomination>[
  Denomination.change(
    1,
    'Penny',
    Metals.penny,
    shape: CoinShape.round,
    scale: 0.62,
  ),
  Denomination.change(
    5,
    'Nickel',
    Metals.nickel,
    shape: CoinShape.scalloped,
    scale: 0.74,
  ),
  Denomination.change(
    10,
    'Dime',
    Metals.dime,
    shape: CoinShape.holed,
    scale: 0.68,
  ),
  Denomination.change(
    25,
    'Quarter',
    Metals.dime,
    shape: CoinShape.octagonal,
    scale: 0.82,
    inner: Metals.brass,
  ),
];

/// Every coin, change first, by value.
const allDenominations = [...changeDenominations, ...denominations];

/// Gold coin: the HUD counter icon and default coin artwork.
const defaultCoin = Denomination(10, 'Gold', Metals.gold);

/// Denominations that can be hidden in Settings.
const optionalDenominations = {50, 100, 500};

Denomination denominationFor(num dollars) => denominations.firstWhere(
  (d) => d.dollars == dollars,
  orElse: () => defaultCoin,
);

/// The picker list after applying the Settings toggles.
List<Denomination> visibleDenominations({
  required bool showFifty,
  required bool showHundred,
  required bool showFiveHundred,
}) => [
  for (final d in denominations)
    if (switch (d.dollars) {
      50 => showFifty,
      100 => showHundred,
      500 => showFiveHundred,
      _ => true,
    })
      d,
];
