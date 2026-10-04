/// Fechas cortas en español para la lista de notas:
///   hoy        → "20:59"
///   ayer       → "ayer"
///   este año   → "3 oct"
///   otro año   → "3 oct 2025"
const List<String> _months = [
  'ene', 'feb', 'mar', 'abr', 'may', 'jun',
  'jul', 'ago', 'sep', 'oct', 'nov', 'dic',
];

String shortDate(DateTime date, {DateTime? now}) {
  now ??= DateTime.now();
  String two(int n) => n.toString().padLeft(2, '0');

  final day = DateTime(date.year, date.month, date.day);
  final today = DateTime(now.year, now.month, now.day);
  final yesterday = DateTime(now.year, now.month, now.day - 1);

  if (day == today) return '${two(date.hour)}:${two(date.minute)}';
  if (day == yesterday) return 'ayer';
  final dayMonth = '${date.day} ${_months[date.month - 1]}';
  return date.year == now.year ? dayMonth : '$dayMonth ${date.year}';
}
