import 'package:intl/intl.dart';

final NumberFormat _inr =
    NumberFormat.currency(locale: 'en_IN', symbol: '₹', decimalDigits: 0);

/// Amount as Indian Rupees with lakh/crore grouping and no decimals, e.g.
/// rupees(125000) -> "₹1,25,000". Guards NaN/Infinity (NumberFormat throws on them).
String rupees(num v) {
  if (v is double && (v.isNaN || v.isInfinite)) v = 0;
  return _inr.format(v);
}

final DateFormat _dateTime = DateFormat('d MMM, h:mm a');
final DateFormat _dateOnly = DateFormat('d MMM yyyy');

/// Friendly relative time for anything recent ("2h ago", "just now"), falling
/// back to an absolute date once it's more than a week old — mirrors how most
/// social/commerce apps show "created" timestamps.
String timeAgo(DateTime? dt, {required bool hi}) {
  if (dt == null) return '—';
  final d = DateTime.now().difference(dt);
  if (d.inSeconds < 45) return hi ? 'अभी' : 'just now';
  if (d.inMinutes < 60) return hi ? '${d.inMinutes} मिनट पहले' : '${d.inMinutes}m ago';
  if (d.inHours < 24) return hi ? '${d.inHours} घंटे पहले' : '${d.inHours}h ago';
  if (d.inDays < 7) return hi ? '${d.inDays} दिन पहले' : '${d.inDays}d ago';
  return _dateOnly.format(dt);
}

/// Absolute "created on" timestamp for detail views, e.g. "24 Aug, 3:46 PM".
String createdOn(DateTime? dt) => dt == null ? '—' : _dateTime.format(dt.toLocal());
