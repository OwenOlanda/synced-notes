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
}
