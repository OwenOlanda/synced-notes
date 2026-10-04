import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:synced_notes/models/note.dart';
import 'package:synced_notes/services/note_storage.dart';

void main() {
  late Directory tempDir;
  late NoteStorage storage;

  // Antes de cada prueba: una carpeta temporal vacía.
  setUp(() async {
    tempDir = await Directory.systemTemp.createTemp('synced_notes_test_');
    storage = NoteStorage(tempDir);
  });

  // Después de cada prueba: se borra.
  tearDown(() async {
    await tempDir.delete(recursive: true);
  });

  test('crear una nota genera un .txt vacío con ese nombre', () async {
    final note = await storage.createNote('Lista del súper');

    expect(note.title, 'Lista del súper');
    expect(note.content, '');
    expect(File('${tempDir.path}/Lista del súper.txt').existsSync(), isTrue);
  });

  test('guardar y volver a leer conserva el texto (acentos incluidos)', () async {
    await storage.createNote('Ideas');
    await storage.saveNote(Note(
      title: 'Ideas',
      content: 'Año nuevo, ¡más café! ☕\nSegunda línea',
      modifiedAt: DateTime.now(),
    ));

    final read = await storage.readNote('Ideas');
    expect(read.content, 'Año nuevo, ¡más café! ☕\nSegunda línea');
  });

  test('guardar no deja archivos temporales', () async {
    await storage.saveNote(
      Note(title: 'A', content: 'hola', modifiedAt: DateTime.now()),
    );
    final names = tempDir.listSync().map((e) => e.uri.pathSegments.last);
    expect(names, ['A.txt']);
  });

  test('título repetido recibe un número', () async {
    final a = await storage.createNote('Nota');
    final b = await storage.createNote('Nota');
    final c = await storage.createNote('nota'); // mayúsculas distintas

    expect(a.title, 'Nota');
    expect(b.title, 'Nota (2)');
    expect(c.title, 'nota (3)');
  });

  test('listar devuelve todas las notas y omite otros archivos', () async {
    await storage.createNote('Uno');
    await storage.createNote('Dos');
    File('${tempDir.path}/foto.png').writeAsStringSync('x');

    final notes = await storage.listNotes();
    expect(notes.map((n) => n.title), containsAll(['Uno', 'Dos']));
    expect(notes.length, 2);
  });

  test('renombrar cambia el nombre del archivo y conserva el texto', () async {
    await storage.saveNote(
      Note(title: 'Viejo', content: 'texto', modifiedAt: DateTime.now()),
    );

    final renamed = await storage.renameNote('Viejo', 'Nuevo');

    expect(renamed.title, 'Nuevo');
    expect(renamed.content, 'texto');
    expect(File('${tempDir.path}/Viejo.txt').existsSync(), isFalse);
    expect(File('${tempDir.path}/Nuevo.txt').existsSync(), isTrue);
  });

  test('no se puede renombrar a un título que ya existe', () async {
    await storage.createNote('A');
    await storage.createNote('B');

    await expectLater(
      () => storage.renameNote('A', 'B'),
      throwsA(isA<NoteStorageException>()),
    );
  });

  test('borrar elimina el archivo', () async {
    await storage.createNote('Temporal');
    await storage.deleteNote('Temporal');

    expect(await storage.listNotes(), isEmpty);
  });

  test('títulos inválidos se rechazan con un mensaje claro', () async {
    expect(NoteStorage.validateTitle('Hola'), isNull);
    expect(NoteStorage.validateTitle('   '), isNotNull);
    expect(NoteStorage.validateTitle('a/b'), isNotNull);
    expect(NoteStorage.validateTitle('¿Qué?'), isNotNull); // el ? está prohibido
    expect(NoteStorage.validateTitle('con'), isNotNull); // reservado en Windows
    expect(NoteStorage.validateTitle('termina.'), isNotNull);

    await expectLater(
      () => storage.createNote('a:b'),
      throwsA(isA<NoteStorageException>()),
    );
  });
}
