import 'package:flutter_test/flutter_test.dart';
import 'package:synced_notes/utils/date_text.dart';

void main() {
  final now = DateTime(2026, 10, 3, 21, 0);

  test('hoy muestra la hora', () {
    expect(shortDate(DateTime(2026, 10, 3, 8, 5), now: now), '08:05');
  });

  test('ayer muestra "ayer", también al cambiar de año', () {
    expect(shortDate(DateTime(2026, 10, 2, 23, 0), now: now), 'ayer');
    expect(
      shortDate(DateTime(2026, 12, 31, 22, 0), now: DateTime(2027, 1, 1, 9)),
      'ayer',
    );
  });

  test('este año muestra día y mes', () {
    expect(shortDate(DateTime(2026, 1, 15), now: now), '15 ene');
  });

  test('otro año agrega el año', () {
    expect(shortDate(DateTime(2025, 12, 31), now: now), '31 dic 2025');
  });
}
