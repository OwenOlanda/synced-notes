import 'package:flutter_test/flutter_test.dart';
import 'package:synced_notes/models/note.dart';
import 'package:synced_notes/services/app_settings.dart';
import 'package:synced_notes/services/note_storage.dart';
import 'package:synced_notes/utils/note_order.dart';

void main() {
  // Día 1..n de noviembre de 2026.
  DateTime day(int d) => DateTime(2026, 11, d, 12);

  Note note(String title, {required int created, required int edited,
          String? group}) =>
      Note(
        title: title,
        content: '',
        group: group,
        createdAt: day(created),
        modifiedAt: day(edited),
      );

  final viejaEditada = note('Zanahoria', created: 1, edited: 20);
  final nueva = note('árbol', created: 15, edited: 15);
  final sinTitulo = note('', created: 10, edited: 18, group: 'Recetas');
  final media = note('Banana', created: 5, edited: 6, group: 'Cartas');
  final all = [media, sinTitulo, nueva, viejaEditada];

  List<String> titles(List<Note> notes) =>
      [for (final n in notes) n.title.isEmpty ? '(sin título)' : n.title];

  test('editadas recientemente', () {
    expect(titles(sortNotes(all, NoteOrder.edited)),
        ['Zanahoria', '(sin título)', 'árbol', 'Banana']);
  });

  test('creadas recientemente', () {
    expect(titles(sortNotes(all, NoteOrder.created)),
        ['árbol', '(sin título)', 'Banana', 'Zanahoria']);
  });

  test('A–Z y Z–A: sin acentos ni mayúsculas; sin título al final', () {
    expect(titles(sortNotes(all, NoteOrder.titleAz)),
        ['árbol', 'Banana', 'Zanahoria', '(sin título)']);
    expect(titles(sortNotes(all, NoteOrder.titleZa)),
        ['Zanahoria', 'Banana', 'árbol', '(sin título)']);
  });

  test('abiertas recientemente: lo abierto sube; si no, cuenta la edición',
      () {
    final opened = {
      NoteStorage.noteId(media): day(25).millisecondsSinceEpoch,
      // Abierta antes de su última edición: manda la edición.
      NoteStorage.noteId(viejaEditada): day(2).millisecondsSinceEpoch,
    };
    expect(titles(sortNotes(all, NoteOrder.opened, opened: opened)),
        ['Banana', 'Zanahoria', '(sin título)', 'árbol']);
  });

  test('por grupo: en el orden de los grupos, Sin grupo al final', () {
    expect(
        titles(sortNotes(all, NoteOrder.byGroup,
            groupOrder: ['Recetas', 'Cartas'])),
        ['(sin título)', 'Banana', 'Zanahoria', 'árbol']);
  });
}
