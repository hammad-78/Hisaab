/// Plain number, used in exports and inputs: 1250, 20.5
String formatPrice(num p) => p == p.roundToDouble() ? '${p.toInt()}' : '$p';

/// Money for display: Rs 1,250 / Rs 20.50
String formatMoney(num p) {
  final whole = p == p.roundToDouble();
  final fixed = whole ? p.abs().toInt().toString() : p.abs().toStringAsFixed(2);
  final parts = fixed.split('.');
  final digits = parts[0];
  final buf = StringBuffer();
  for (var i = 0; i < digits.length; i++) {
    if (i > 0 && (digits.length - i) % 3 == 0) buf.write(',');
    buf.write(digits[i]);
  }
  final frac = parts.length > 1 ? '.${parts[1]}' : '';
  return '${p < 0 ? '-' : ''}Rs $buf$frac';
}

/// Local calendar day key, e.g. 2026-11-13. Stored on every sale so reports
/// and "today" lists can query by simple equality.
String dayKey(DateTime d) =>
    '${d.year.toString().padLeft(4, '0')}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';

/// 2:05 PM
String formatTime(DateTime? t) {
  if (t == null) return 'Just now';
  final h = t.hour % 12 == 0 ? 12 : t.hour % 12;
  return '$h:${t.minute.toString().padLeft(2, '0')} ${t.hour < 12 ? 'AM' : 'PM'}';
}
