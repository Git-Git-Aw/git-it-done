const List<String> _shortMonths = [
  'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun',
  'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec',
];

const List<String> _longMonths = [
  'January', 'February', 'March', 'April', 'May', 'June',
  'July', 'August', 'September', 'October', 'November', 'December',
];

/// 3500 -> "₱3,500.00"
String peso(num value) {
  final negative = value < 0;
  final fixed = value.abs().toStringAsFixed(2);
  final parts = fixed.split('.');
  final whole = parts[0];
  final buffer = StringBuffer();
  for (var i = 0; i < whole.length; i++) {
    if (i > 0 && (whole.length - i) % 3 == 0) buffer.write(',');
    buffer.write(whole[i]);
  }
  return '${negative ? '-' : ''}₱${buffer.toString()}.${parts[1]}';
}

/// "2026-10-05" or an ISO date-time -> "Oct 5, 2026"
String formatDate(String? value) {
  if (value == null || value.isEmpty) return '-';
  final parsed = DateTime.tryParse(value);
  if (parsed == null) return value;
  final date = value.length > 10 ? parsed.toLocal() : parsed;
  return '${_shortMonths[date.month - 1]} ${date.day}, ${date.year}';
}

/// ISO date-time -> "Oct 5, 2026 3:07 PM" (in the device's time zone)
String formatDateTime(String? value) {
  if (value == null || value.isEmpty) return '-';
  final parsed = DateTime.tryParse(value);
  if (parsed == null) return value;
  final d = parsed.toLocal();
  final hour12 = d.hour % 12 == 0 ? 12 : d.hour % 12;
  final minute = d.minute.toString().padLeft(2, '0');
  final suffix = d.hour >= 12 ? 'PM' : 'AM';
  return '${_shortMonths[d.month - 1]} ${d.day}, ${d.year} $hour12:$minute $suffix';
}

/// "Ana Reyes" -> "Ana"
String firstName(String fullName) {
  final parts = fullName.trim().split(RegExp(r'\s+'));
  return parts.isEmpty || parts.first.isEmpty ? fullName : parts.first;
}

/// "2026-11" -> "November 2026"
String monthLabel(String period) {
  final match = RegExp(r'^(\d{4})-(0[1-9]|1[0-2])$').firstMatch(period);
  if (match == null) return period;
  final month = int.parse(match.group(2)!);
  return '${_longMonths[month - 1]} ${match.group(1)}';
}

/// DateTime -> "2026-11"
String periodOf(DateTime date) {
  final month = date.month.toString().padLeft(2, '0');
  return '${date.year}-$month';
}

/// "in_progress" -> "In Progress"
String titleCase(String? value) {
  if (value == null || value.isEmpty) return '-';
  final words = value.replaceAll('_', ' ').split(' ');
  return words
      .map((w) => w.isEmpty ? w : '${w[0].toUpperCase()}${w.substring(1)}')
      .join(' ');
}

/// Readable label for payment, maintenance, and other statuses.
String statusLabel(String? status) {
  if (status == 'pending_confirmation') return 'Awaiting confirmation';
  return titleCase(status);
}

bool isValidEmail(String value) {
  return RegExp(r'^[^\s@]+@[^\s@]+\.[^\s@]+$').hasMatch(value.trim());
}

/// Removes simple Markdown marks (**bold**, # headings, - bullets) from the
/// AI's replies, because the chat shows plain text.
String plainText(String text) {
  final cleaned = text.replaceAll('**', '').replaceAll('__', '').replaceAll('`', '');
  return cleaned.split('\n').map((line) {
    var result = line;
    final heading = RegExp(r'^\s*#{1,6}\s+').firstMatch(result);
    if (heading != null) result = result.substring(heading.end);
    final bullet = RegExp(r'^(\s*)[-*]\s+').firstMatch(result);
    if (bullet != null) {
      result = '${bullet.group(1)}\u2022 ${result.substring(bullet.end)}';
    }
    return result;
  }).join('\n');
}

/// 3500.0 -> "3500", 3500.5 -> "3500.5" (for pre-filling number fields)
String plainNumber(double value) {
  return value == value.roundToDouble() ? value.toStringAsFixed(0) : value.toString();
}

/// True for "2026-11".
bool isPeriodText(String value) {
  return RegExp(r'^\d{4}-(0[1-9]|1[0-2])$').hasMatch(value);
}
