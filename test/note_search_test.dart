import 'package:flutter_test/flutter_test.dart';
import 'package:synced_notes/models/note.dart';
import 'package:synced_notes/utils/note_search.dart';

Note _note(String title, String content) {
  final date = DateTime(2026, 10, 13, 14, 30);
  return Note(
    fileName: '2026-10-13_14-30-00 $title.txt',
    title: title,
    content: content,
    createdAt: date,
    modifiedAt: date,
  );
}

void main() {
  test('normaliza sin cambiar la longitud (minúsculas y sin acentos)', () {
    expect(NoteSearch.normalize('Canción ÑANDÚ'), 'cancion nandu');
    const text = 'Él comió pingüino';
    expect(NoteSearch.normalize(text).length, text.length);
  });

  test('una búsqueda vacía no filtra', () {
    final search = NoteSearch('   ');
    expect(search.isEmpty, isTrue);
    expect(search.matches(_note('Lo que sea', '')), isTrue);
  });

  test('sin importar mayúsculas ni acentos', () {
    final note = _note('Canción', 'Letra de la canción');
    expect(NoteSearch('cancion').matches(note), isTrue);
    expect(NoteSearch('CANCIÓN').matches(note), isTrue);
    expect(NoteSearch('poema').matches(note), isFalse);
  });

  test('varias palabras: todas, en cualquier orden, título o texto', () {
    final note = _note('Receta', 'Agua con limón y miel');
    expect(NoteSearch('receta limon').matches(note), isTrue);
    expect(NoteSearch('miel receta').matches(note), isTrue);
    expect(NoteSearch('receta naranja').matches(note), isFalse);
  });

  test('sabe si la coincidencia está en el título', () {
    final search = NoteSearch('limon');
    expect(search.matchesTitle(_note('Limonada', '')), isTrue);
    expect(search.matchesTitle(_note('Receta', 'limón')), isFalse);
  });

  test('rangos para resaltar, en el texto original y sin encimarse', () {
    final search = NoteSearch('re receta');
    expect(search.rangesIn('Una Receta'), [(4, 10)]);
    expect(NoteSearch('limon').rangesIn('Limón y limón'), [(0, 5), (8, 13)]);
  });

  test('fragmento: empieza cerca de la palabra si está lejos', () {
    final long = '${'palabra ' * 10}aquí está el limón';
    final snippet = NoteSearch('limon').snippetOf(_note('X', long))!;
    expect(snippet.startsWith('…'), isTrue);
    expect(snippet, contains('limón'));
    expect(snippet.length, lessThan(long.length));
    // Si ya se ve al principio, no hace falta fragmento.
    expect(NoteSearch('palabra').snippetOf(_note('X', long)), isNull);
  });

  test('coincidencias de una nota: primero el título, luego el texto', () {
    final search = NoteSearch('sal');
    expect(search.matchesIn(_note('Sal y pimienta', 'Agua y sal. Más sal.')), [
      (true, 0, 3),
      (false, 7, 10),
      (false, 16, 19),
    ]);
    expect(NoteSearch('').matchesIn(_note('Sal', 'sal')), isEmpty);
  });

  test('pedazo alrededor de una coincidencia, en una línea', () {
    expect(NoteSearch.excerptAround('Agua\ny sal', 7), 'Agua · y sal');
    final long = '${'palabra ' * 10}aquí está el limón';
    final piece = NoteSearch.excerptAround(long, long.indexOf('limón'));
    expect(piece.startsWith('…'), isTrue);
    expect(piece, endsWith('el limón'));
    // Empieza al inicio de una palabra.
    expect(piece.substring(1).startsWith(RegExp(r'palabra|aquí')), isTrue);
  });

  test('los cortes nunca parten un emoji a la mitad', () {
    const text = 'ab😀cd'; // el emoji ocupa las posiciones 2 y 3
    expect(NoteSearch.safeCut(text, 3), 2);
    expect(NoteSearch.safeCut(text, 2), 2);
    expect(NoteSearch.safeCut(text, 4), 4);
    // Un pedazo cuyo final caería a la mitad del emoji.
    final long = '${'a' * 159}😀 sal';
    final piece = NoteSearch.excerptAround(long, 0);
    expect(piece.endsWith('\uD83D'), isFalse);
    expect(() => piece.runes.toList(), returnsNormally);
    expect(piece.codeUnits.last == 0xD83D, isFalse);
  });
}
