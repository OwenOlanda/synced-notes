import 'package:flutter_test/flutter_test.dart';
import 'package:synced_notes/widgets/line_numbers_painter.dart';

void main() {
  test('dónde empieza cada renglón (los renglones vacíos cuentan)', () {
    expect(lineStartsOf(''), [0]);
    expect(lineStartsOf('uno\ndos\n\ncuatro'), [0, 4, 8, 9]);
    expect(lineStartsOf('fin\n'), [0, 4]);
  });

  test('en qué renglón está un punto del texto', () {
    final starts = lineStartsOf('uno\ndos\n\ncuatro');
    expect(lineIndexOf(starts, 0), 0);
    expect(lineIndexOf(starts, 3), 0); // al final de "uno"
    expect(lineIndexOf(starts, 4), 1);
    expect(lineIndexOf(starts, 8), 2); // el renglón vacío
    expect(lineIndexOf(starts, 12), 3);
  });

  test('tamaño de los números: crecen poco con el zoom y se encogen si no '
      'caben', () {
    // Caben de sobra: 11.5 a 100 %, y con tope a 200 %.
    expect(lineNumberFontSize(zoom: 1, digitsWidthAt10: 12, available: 30),
        11.5);
    expect(lineNumberFontSize(zoom: 2, digitsWidthAt10: 12, available: 60),
        14);
    // 4 dígitos que a 11.5 miden 34.5 px en 25 px: se encogen para caber.
    final size =
        lineNumberFontSize(zoom: 1, digitsWidthAt10: 30, available: 25);
    expect(size, lessThan(11.5));
    expect(30 * size / 10, closeTo(25, 0.01));
  });
}
