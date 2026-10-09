import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:synced_notes/models/note.dart';
import 'package:synced_notes/screens/notes_list_screen.dart';
import 'package:synced_notes/services/app_settings.dart';
import 'package:synced_notes/services/note_storage.dart';

import 'helpers/localized_app.dart';

/// Almacenamiento de mentira: devuelve las notas que se le den, sin tocar
/// el disco. Así la prueba solo revisa lo que se ve en pantalla.
class _FakeStorage extends NoteStorage {
  _FakeStorage(this.notes) : super(Directory('notas-de-prueba'));
  final List<Note> notes;

  @override
  Future<List<Note>> listNotes() async => notes;
}

Note _note({String title = '', String content = ''}) {
  final date = DateTime(2026, 10, 3, 20, 59, 12);
  return Note(
    fileName: '2026-10-03_20-59-12 $title.txt',
    title: title,
    content: content,
    createdAt: date,
    modifiedAt: date,
  );
}

void main() {
  late AppSettings settings;

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    settings = await AppSettings.load();
  });

  Future<void> showList(WidgetTester tester, List<Note> notes,
      {Locale locale = const Locale('es')}) async {
    await tester.pumpWidget(localizedApp(
      NotesListScreen(storage: _FakeStorage(notes), settings: settings),
      locale: locale,
    ));
    await tester.pumpAndSettle();
  }

  testWidgets('sin notas: mensaje en el idioma de la app', (tester) async {
    await showList(tester, []);
    expect(find.text('Aún no tienes notas.\nToca + para crear una.'),
        findsOneWidget);

    await showList(tester, [], locale: const Locale('en'));
    expect(find.text("You don't have any notes yet.\nTap + to create one."),
        findsOneWidget);
  });

  testWidgets('nota sin título y nota sin texto', (tester) async {
    final notes = [
      _note(content: 'Leche y pan'),
      _note(title: 'Ideas'),
    ];

    await showList(tester, notes);
    expect(find.text('Sin título'), findsOneWidget);
    expect(find.text('Sin texto'), findsOneWidget);

    await showList(tester, notes, locale: const Locale('en'));
    expect(find.text('Untitled'), findsOneWidget);
    expect(find.text('No text'), findsOneWidget);
  });

  testWidgets('el diálogo de borrar sale en el idioma de la app',
      (tester) async {
    await showList(tester, [_note(content: 'Leche y pan')],
        locale: const Locale('en'));

    await tester.longPress(find.text('Untitled'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Delete'));
    await tester.pumpAndSettle();

    expect(find.text('Delete note?'), findsOneWidget);
    expect(
        find.text('"Untitled" will be deleted from the notes folder. '
            "This can't be undone."),
        findsOneWidget);

    await tester.tap(find.text('Cancel'));
    await tester.pumpAndSettle();
    expect(find.text('Delete note?'), findsNothing);
  });
}
