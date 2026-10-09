import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:synced_notes/l10n/l10n.dart';
import 'package:synced_notes/utils/date_text.dart';

void main() {
  final now = DateTime(2026, 10, 3, 21, 0);
  final es = lookupAppLocalizations(const Locale('es'));
  final en = lookupAppLocalizations(const Locale('en'));

  group('español', () {
    test('hoy muestra la hora (reloj de 24 horas)', () {
      expect(shortDate(DateTime(2026, 10, 3, 8, 5), es, now: now), '08:05');
      expect(shortDate(DateTime(2026, 10, 3, 20, 59), es, now: now), '20:59');
    });

    test('ayer muestra "Ayer", también al cambiar de año', () {
      expect(shortDate(DateTime(2026, 10, 2, 23, 0), es, now: now), 'Ayer');
      expect(
        shortDate(DateTime(2026, 12, 31, 22, 0), es,
            now: DateTime(2027, 1, 1, 9)),
        'Ayer',
      );
    });

    test('este año muestra día y mes', () {
      expect(shortDate(DateTime(2026, 1, 15), es, now: now), '15 ene');
    });

    test('otro año agrega el año', () {
      expect(shortDate(DateTime(2025, 12, 31), es, now: now), '31 dic 2025');
    });
  });

  group('inglés', () {
    test('hoy muestra la hora (reloj de 12 horas)', () {
      expect(shortDate(DateTime(2026, 10, 3, 8, 5), en, now: now), '8:05 AM');
      expect(
          shortDate(DateTime(2026, 10, 3, 20, 59), en, now: now), '8:59 PM');
    });

    test('medianoche y mediodía son las 12', () {
      expect(shortDate(DateTime(2026, 10, 3, 0, 30), en, now: now), '12:30 AM');
      expect(
          shortDate(DateTime(2026, 10, 3, 12, 15), en, now: now), '12:15 PM');
    });

    test('ayer muestra "Yesterday"', () {
      expect(
          shortDate(DateTime(2026, 10, 2, 23, 0), en, now: now), 'Yesterday');
    });

    test('este año: mes y día', () {
      expect(shortDate(DateTime(2026, 1, 15), en, now: now), 'Jan 15');
    });

    test('otro año: mes, día y año', () {
      expect(
          shortDate(DateTime(2025, 12, 31), en, now: now), 'Dec 31, 2025');
    });
  });
}
