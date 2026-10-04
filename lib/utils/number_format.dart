/// Display helpers so amounts read "100" not "100.0", and "1½" not "1.5".

/// Up to [maxDecimals] decimals, without trailing zeros: 100.0 → "100",
/// 12.50 → "12.5".
String formatNumber(double value, {int maxDecimals = 1}) {
  final fixed = value.toStringAsFixed(maxDecimals);
  if (!fixed.contains('.')) return fixed;
  final trimmed = fixed.replaceAll(RegExp(r'0+$'), '');
  return trimmed.endsWith('.') ? trimmed.substring(0, trimmed.length - 1) : trimmed;
}

/// Serving counts: whole numbers plain, common fractions as glyphs
/// (0.5 → "½", 1.25 → "1¼"), anything else as a short decimal.
String formatServings(double value) {
  final whole = value.floor();
  final fraction = value - whole;
  const glyphs = [(0.25, '¼'), (0.5, '½'), (0.75, '¾')];
  for (final (value, glyph) in glyphs) {
    if ((fraction - value).abs() < 0.001) {
      return whole == 0 ? glyph : '$whole$glyph';
    }
  }
  return formatNumber(value, maxDecimals: 2);
}

/// Parses user input that may use a comma as the decimal separator.
double? parseAmount(String text) =>
    double.tryParse(text.trim().replaceAll(',', '.'));
