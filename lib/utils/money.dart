/// Formats dollars as \$1,234.56.
String money(double v) {
  final whole = v.floor();
  final s = whole.toString().replaceAllMapped(
    RegExp(r'(\d)(?=(\d{3})+$)'),
    (m) => '${m[1]},',
  );
  return '\$$s.${((v - whole) * 100).round().clamp(0, 99).toString().padLeft(2, '0')}';
}
