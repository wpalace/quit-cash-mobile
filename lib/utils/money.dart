/// Formats dollars as \$1,234.56.
String money(double v) {
  final whole = v.floor();
  final s = whole.toString().replaceAllMapped(
    RegExp(r'(\d)(?=(\d{3})+$)'),
    (m) => '${m[1]},',
  );
  return '\$$s.${((v - whole) * 100).round().clamp(0, 99).toString().padLeft(2, '0')}';
}

/// Formats integer cents as \$1,234.56.
String moneyCents(int cents) => money(cents / 100);

/// Largest amount a single record may hold (\$9,999.99).
const maxRecordCents = 999999;

/// Parses user input such as `8`, `8.5`, `\$8.50` or `1,000` to cents.
/// Returns null unless it is a positive amount with at most two decimals
/// and at most [maxRecordCents].
int? parseCents(String input) {
  final s = input.trim().replaceAll(RegExp(r'[\$,\s]'), '');
  final m = RegExp(r'^(\d{1,7})(?:\.(\d{0,2}))?$|^\.(\d{1,2})$').firstMatch(s);
  if (m == null) return null;
  final whole = int.parse(m[1] ?? '0');
  final frac = (m[2] ?? m[3] ?? '').padRight(2, '0');
  final cents = whole * 100 + int.parse(frac.isEmpty ? '0' : frac);
  return cents <= 0 || cents > maxRecordCents ? null : cents;
}
