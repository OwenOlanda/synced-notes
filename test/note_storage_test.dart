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

  // 3 de octubre de 2026, 20:59 con los segundos que se indiquen.
  DateTime at(int second) => DateTime(2026, 10, 3, 20, 59, second);

  Note newNote({String title = '', String content = '', int second = 12}) =>
      Note(
        title: title,
        content: content,
        createdAt: at(second),
        modifiedAt: at(second),
      );

  /// Nombres de los archivos en la carpeta, en orden alfabético.
  List<String> files() => tempDir
      .listSync()
      .map((e) => e.path.split(Platform.pathSeparator).last)
      .toList()
    ..sort();

  group('nombres de archivo', () {
    test('con título y sin título', () {
      expect(NoteStorage.fileNameFor('Lista del súper', at(12)),
          '2026-10-03_20-59-12 Lista del súper.txt');
      expect(NoteStorage.fileNameFor('   ', at(12)), '2026-10-03_20-59-12.txt');
    });

    test('se leen de vuelta: título y fecha', () {
      final withTitle =
          NoteStorage.parseFileName('2026-10-03_20-59-12 Ideas.txt');
      expect(withTitle.title, 'Ideas');
      expect(withTitle.createdAt, at(12));

      final noTitle = NoteStorage.parseFileName('2026-10-03_20-59-12.txt');
      expect(noTitle.title, '');
      expect(noTitle.createdAt, at(12));

      final foreign = NoteStorage.parseFileName('Compras.txt');
      expect(foreign.title, 'Compras');
      expect(foreign.createdAt, isNull);
    });
  });

  group('guardar', () {
    test('nota nueva con título: archivo con fecha + título', () async {
      final saved = await storage.saveNote(
          newNote(title: 'Ideas', content: 'Año nuevo, ¡más café! ☕\nOtra línea'));

      expect(saved.fileName, '2026-10-03_20-59-12 Ideas.txt');
      expect(saved.title, 'Ideas');
      expect(saved.createdAt, at(12));
      expect(files(), ['2026-10-03_20-59-12 Ideas.txt']);

      final read = await storage.readNote(saved.fileName!);
      expect(read.content, 'Año nuevo, ¡más café! ☕\nOtra línea');
    });

    test('nota nueva sin título: archivo solo con la fecha', () async {
      final saved = await storage.saveNote(newNote(content: 'hola'));

      expect(files(), ['2026-10-03_20-59-12.txt']);
      expect(saved.hasTitle, isFalse);
    });

    test('dos notas creadas en el mismo segundo no comparten fecha', () async {
      await storage.saveNote(newNote(title: 'Ideas'));
      await storage.saveNote(newNote(title: 'Otra cosa'));

      expect(files(), [
        '2026-10-03_20-59-12 Ideas.txt',
        '2026-10-03_20-59-13 Otra cosa.txt',
      ]);
    });

    test('volver a guardar con el mismo título reemplaza el texto', () async {
      final first = await storage.saveNote(newNote(title: 'A', content: 'uno'));
      await storage.saveNote(first.copyWith(content: 'dos'));

      expect(files(), ['2026-10-03_20-59-12 A.txt']); // sin temporales
      expect((await storage.readNote(first.fileName!)).content, 'dos');
    });

    test('cambiar el título renombra el archivo y conserva la fecha', () async {
      final first =
          await storage.saveNote(newNote(title: 'Viejo', content: 'texto'));
      final renamed = await storage.saveNote(first.copyWith(title: 'Nuevo'));

      expect(files(), ['2026-10-03_20-59-12 Nuevo.txt']);
      expect(renamed.title, 'Nuevo');
      expect(renamed.content, 'texto');
      expect(renamed.createdAt, at(12));
    });

    test('quitar el título deja solo la fecha', () async {
      final first = await storage.saveNote(newNote(title: 'Algo', content: 'x'));
      await storage.saveNote(first.copyWith(title: ''));

      expect(files(), ['2026-10-03_20-59-12.txt']);
    });

    test('cambiar solo mayúsculas del título funciona (importante en Windows)',
        () async {
      final first = await storage.saveNote(newNote(title: 'ideas', content: 'x'));
      final renamed = await storage.saveNote(first.copyWith(title: 'Ideas'));

      expect(files(), ['2026-10-03_20-59-12 Ideas.txt']);
      expect(renamed.content, 'x');
    });

    test('títulos inválidos se rechazan con un mensaje claro', () async {
      expect(NoteStorage.validateTitle(''), isNull); // vacío está permitido
      expect(NoteStorage.validateTitle('Hola'), isNull);
      expect(NoteStorage.validateTitle('a/b'), isNotNull);
      expect(NoteStorage.validateTitle('¿Qué?'), isNotNull); // el ? está prohibido
      expect(NoteStorage.validateTitle('x' * 121), isNotNull);

      await expectLater(
        () => storage.saveNote(newNote(title: 'a:b')),
        throwsA(isA<NoteStorageException>()),
      );
      expect(files(), isEmpty);
    });
  });

  group('listar y borrar', () {
    test('lista notas propias y .txt de afuera; ignora otros archivos; '
        'la más reciente primero', () async {
      final older = await storage.saveNote(newNote(title: 'Vieja', second: 1));
      final newer = await storage.saveNote(newNote(second: 2)); // sin título
      final foreign = File('${tempDir.path}/Compras.txt')
        ..writeAsStringSync('leche');
      File('${tempDir.path}/foto.png').writeAsStringSync('x');

      await File('${tempDir.path}/${older.fileName}')
          .setLastModified(DateTime(2026, 1, 1));
      await File('${tempDir.path}/${newer.fileName}')
          .setLastModified(DateTime(2026, 3, 1));
      await foreign.setLastModified(DateTime(2026, 2, 1));

      final notes = await storage.listNotes();
      expect(notes.map((n) => n.title), ['', 'Compras', 'Vieja']);
      expect(notes[1].content, 'leche');
      expect(notes[1].createdAt, DateTime(2026, 2, 1)); // sin fecha en el nombre
    });

    test('editar un .txt de afuera sin cambiar el título conserva su nombre',
        () async {
      File('${tempDir.path}/Compras.txt').writeAsStringSync('leche');

      final note = await storage.readNote('Compras.txt');
      await storage.saveNote(note.copyWith(content: 'leche y pan'));

      expect(files(), ['Compras.txt']);
      expect((await storage.readNote('Compras.txt')).content, 'leche y pan');
    });

    test('borrar elimina el archivo', () async {
      final saved = await storage.saveNote(newNote(title: 'Temporal'));
      await storage.deleteNote(saved.fileName!);

      expect(await storage.listNotes(), isEmpty);
    });
  });
}
