const _months = [
  'January', 'February', 'March', 'April', 'May', 'June', //
  'July', 'August', 'September', 'October', 'November', 'December',
];

String monthName(int month) => _months[month - 1];
String monthShort(int month) => _months[month - 1].substring(0, 3);

String formatDayMonth(DateTime d) => '${d.day} ${monthName(d.month)}';

String formatDate(DateTime d) {
  final now = DateTime.now();
  final today = DateTime(now.year, now.month, now.day);
  final day = DateTime(d.year, d.month, d.day);
  final diff = today.difference(day).inDays;
  if (diff == 0) return 'Today';
  if (diff == 1) return 'Yesterday';
  if (d.year == now.year) return '${d.day} ${monthShort(d.month)}';
  return '${d.day} ${monthShort(d.month)} ${d.year}';
}

String formatBytes(int bytes) {
  if (bytes <= 0) return '0 MB';
  const kb = 1024, mb = kb * 1024, gb = mb * 1024;
  if (bytes >= gb) {
    return '${(bytes / gb).toStringAsFixed(bytes >= 10 * gb ? 0 : 1)} GB';
  }
  if (bytes >= mb) {
    return '${(bytes / mb).toStringAsFixed(bytes >= 100 * mb ? 0 : 1)} MB';
  }
  return '${(bytes / kb).ceil()} KB';
}

String formatCount(int n) {
  final s = n.toString();
  final b = StringBuffer();
  for (var i = 0; i < s.length; i++) {
    if (i > 0 && (s.length - i) % 3 == 0) b.write(',');
    b.write(s[i]);
  }
  return b.toString();
}

String formatDuration(Duration d) {
  final m = d.inMinutes;
  final s = (d.inSeconds % 60).toString().padLeft(2, '0');
  if (d.inHours > 0) {
    return '${d.inHours}:${(m % 60).toString().padLeft(2, '0')}:$s';
  }
  return '$m:$s';
}

String plural(int n, String one, [String? many]) =>
    '${formatCount(n)} ${n == 1 ? one : (many ?? '${one}s')}';
