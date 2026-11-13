String formatPrice(num p) => p == p.roundToDouble() ? '${p.toInt()}' : '$p';

/// Local calendar day key, e.g. 2026-11-13. Stored on every sale so reports
/// and "today" lists can query by simple equality.
String dayKey(DateTime d) =>
    '${d.year.toString().padLeft(4, '0')}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';
