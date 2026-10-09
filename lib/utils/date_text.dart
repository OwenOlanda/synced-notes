import '../l10n/l10n.dart';

/// Fechas cortas para la lista de notas, en el idioma de la app:
///
///   cuándo       español        inglés
///   hoy          20:59          8:59 PM
///   ayer         Ayer           Yesterday
///   este año     3 oct          Oct 3
///   otro año     3 oct 2025     Oct 3, 2025
///
/// Los nombres de los meses y el orden de día/mes/año salen de los archivos
/// de traducción (claves dateMonthsShort, dateDayMonth, dateDayMonthYear,
/// timeOfDay…), así que un idioma nuevo solo necesita su archivo .arb.
String shortDate(DateTime date, AppLocalizations l10n, {DateTime? now}) {
  now ??= DateTime.now();
  String two(int n) => n.toString().padLeft(2, '0');

  final day = DateTime(date.year, date.month, date.day);
  final today = DateTime(now.year, now.month, now.day);
  final yesterday = DateTime(now.year, now.month, now.day - 1);

  if (day == today) {
    final hour12 = date.hour % 12 == 0 ? 12 : date.hour % 12;
    return l10n.timeOfDay(
      '$hour12',
      two(date.hour),
      two(date.minute),
      date.hour < 12 ? l10n.timeAm : l10n.timePm,
    );
  }
  if (day == yesterday) return l10n.dateYesterday;

  final month = l10n.dateMonthsShort.split('|')[date.month - 1].trim();
  return date.year == now.year
      ? l10n.dateDayMonth('${date.day}', month)
      : l10n.dateDayMonthYear('${date.day}', month, '${date.year}');
}
