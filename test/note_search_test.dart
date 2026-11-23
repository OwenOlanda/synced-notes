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

  test('busca la frase tal cual, con sus espacios', () {
    final note = _note('Libro', 'Pasó ante sus ojos. Antes de nada.');
    expect(NoteSearch('ante s').rangesIn(note.content), [(5, 11)]);
    expect(NoteSearch('sus ojos').matches(note), isTrue);
    // Ya no son palabras sueltas en cualquier orden.
    expect(NoteSearch('ojos sus').matches(note), isFalse);
    // Los espacios al inicio y al final no cuentan (el teclado agrega uno).
    expect(NoteSearch(' ante sus ').rangesIn(note.content), [(5, 13)]);
    // Las comillas son texto normal.
    expect(NoteSearch('"hola"').matches(_note('X', 'dijo "hola" y se fue')),
        isTrue);
  });

  test('Aa: distinguir mayúsculas', () {
    const aa = SearchOptions(matchCase: true);
    final note = _note('X', 'Antes y ante');
    expect(NoteSearch('ante', options: aa).rangesIn(note.content),
        [(8, 12)]);
    expect(NoteSearch('Ante', options: aa).rangesIn(note.content), [(0, 4)]);
    // Sigue sin importar acentos: "Canción" con "Cancion".
    expect(NoteSearch('Cancion', options: aa).matches(_note('Canción', '')),
        isTrue);
    expect(NoteSearch('cancion', options: aa).matches(_note('Canción', '')),
        isFalse);
  });

  test('á: distinguir acentos', () {
    const accents = SearchOptions(matchAccents: true);
    final note = _note('X', 'limon y limón');
    expect(NoteSearch('limón', options: accents).rangesIn(note.content),
        [(8, 13)]);
    // Sigue sin importar mayúsculas.
    expect(NoteSearch('LIMÓN', options: accents).rangesIn(note.content),
        [(8, 13)]);
  });

  test('ab: solo palabras completas', () {
    const word = SearchOptions(wholeWord: true);
    final note = _note('X', 'salsa, sal y sal.');
    expect(NoteSearch('sal', options: word).rangesIn(note.content),
        [(7, 10), (13, 16)]);
    expect(NoteSearch('sal').rangesIn(note.content), hasLength(3));
    // Las letras con acento también cuentan como letras.
    expect(NoteSearch('cancio', options: word).matches(_note('X', 'canción')),
        isFalse);
  });

  test('sabe si la coincidencia está en el título', () {
    final search = NoteSearch('limon');
    expect(search.matchesTitle(_note('Limonada', '')), isTrue);
    expect(search.matchesTitle(_note('Receta', 'limón')), isFalse);
  });

  test('rangos para resaltar, en el texto original y sin encimarse', () {
    expect(NoteSearch('receta').rangesIn('Una Receta'), [(4, 10)]);
    expect(NoteSearch('aa').rangesIn('aaaa'), [(0, 2), (2, 4)]);
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
