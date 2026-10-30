/// "1234" -> "1.2K", "1500000" -> "1.5M" like the counts under a post.
String compactCount(int n) {
  String trim(double v) {
    final s = v.toStringAsFixed(v < 10 ? 1 : 0);
    return s.endsWith('.0') ? s.substring(0, s.length - 2) : s;
  }

  if (n < 1000) return '$n';
  if (n < 1000000) return '${trim(n / 1000)}K';
  return '${trim(n / 1000000)}M';
}

const List<String> monthNames = [
  'January', 'February', 'March', 'April', 'May', 'June', 'July',
  'August', 'September', 'October', 'November', 'December',
];
