import 'package:intl/intl.dart';

final NumberFormat _inr =
    NumberFormat.currency(locale: 'en_IN', symbol: '₹', decimalDigits: 0);

/// Amount as Indian Rupees with lakh/crore grouping and no decimals, e.g.
/// rupees(125000) -> "₹1,25,000". Guards NaN/Infinity (NumberFormat throws on them).
String rupees(num v) {
  if (v is double && (v.isNaN || v.isInfinite)) v = 0;
  return _inr.format(v);
}
