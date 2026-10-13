import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:synced_notes/models/collection.dart';
import 'package:synced_notes/models/note.dart';
import 'package:synced_notes/services/note_storage.dart';

void main() {
  late Directory tempDir;
  late NoteStorage storage;

  setUp(() async {
    tempDir = await Directory.systemTemp.createTemp('synced_notes_col_');
    storage = NoteStorage(tempDir);
  });

  tearDown(() async {
    await tempDir.delete(recursive: true);
  });

  final sep = Platform.pathSeparator;
  DateTime at(int second) => DateTime(2026, 10, 3, 20, 59, second);

  Note newNote({String title = '', String? collection, int second = 12}) =>
      Note(
        title: title,
        content: 'texto',
        collection: collection,
        createdAt: at(second),
        modifiedAt: at(second),
      );

  /// Archivos y carpetas dentro de [path] (relativo a la carpeta de notas),
  /// en orden alfabético.
  List<String> entries([String path = '']) =>
      Directory(path.isEmpty ? tempDir.path : '${tempDir.path}$sep$path')
          .listSync()
          .map((e) => e.path.split(sep).last)
          .toList()
        ..sort();

  Matcher throwsNoteError(NoteError error) => throwsA(
      isA<NoteStorageException>().having((e) => e.error, 'error', error));

  group('nombres de colección', () {
    test('válidos', () {
      expect(NoteStorage.validateCollectionName('Recetas'), isNull);
      expect(NoteStorage.validateCollectionName('Ideas 2026'), isNull);
      expect(NoteStorage.validateCollectionName('Console'), isNull);
    });

    test('inválidos, cada uno con su motivo', () {
      expect(NoteStorage.validateCollectionName('   '),
          NoteError.collectionNameEmpty);
      expect(NoteStorage.validateCollectionName('x' * 121),
          NoteError.collectionNameTooLong);
      expect(NoteStorage.validateCollectionName('a/b'),
          NoteError.collectionNameForbiddenChars);
      for (final reserved in ['CON', 'nul', 'Com1', 'LPT9', 'con.txt']) {
        expect(NoteStorage.validateCollectionName(reserved),
            NoteError.collectionNameReserved,
            reason: reserved);
      }
      expect(NoteStorage.validateCollectionName('.oculta'),
          NoteError.collectionNameReserved);
      expect(NoteStorage.validateCollectionName('Notas.'),
          NoteError.collectionNameReserved);
    });
  });

  group('crear y listar colecciones', () {
    test('en orden alfabético sin importar mayúsculas, incluidas las vacías',
        () async {
      await storage.createCollection('Recetas');
      await storage.createCollection('cartas');
      await storage.createCollection('Frases');

      final names = (await storage.listCollections()).map((c) => c.name);
      expect(names, ['cartas', 'Frases', 'Recetas']);
      expect(entries(), ['Frases', 'Recetas', 'cartas']);
    });

    test('se quitan los espacios sobrantes del nombre', () async {
      final created = await storage.createCollection('  Recetas  ');
      expect(created.name, 'Recetas');
      expect(entries(), ['Recetas']);
    });

    test('no puede haber dos con el mismo nombre (sin importar mayúsculas)',
        () async {
      await storage.createCollection('Recetas');
      await expectLater(() => storage.createCollection('recetas'),
          throwsNoteError(NoteError.collectionExists));
    });

    test('un nombre inválido no crea nada', () async {
      await expectLater(() => storage.createCollection('CON'),
          throwsNoteError(NoteError.collectionNameReserved));
      expect(await storage.listCollections(), isEmpty);
    });

    test('ignora carpetas con punto y no busca notas más adentro', () async {
      await storage.createCollection('Recetas');
      Directory('${tempDir.path}$sep.oculta').createSync();
      Directory('${tempDir.path}${sep}Recetas${sep}Postres').createSync();
      File('${tempDir.path}${sep}Recetas${sep}Postres${sep}Flan.txt')
          .writeAsStringSync('x');

      final names = (await storage.listCollections()).map((c) => c.name);
      expect(names, ['Recetas']);
      expect(await storage.listNotes(), isEmpty);
    });
  });

  group('notas dentro de colecciones', () {
    test('se guardan en la subcarpeta y se listan con su colección', () async {
      await storage.createCollection('Recetas');
      final saved = await storage
          .saveNote(newNote(title: 'Tacos', collection: 'Recetas'));

      expect(entries('Recetas'), ['2026-10-03_20-59-12 Tacos.txt']);
      final notes = await storage.listNotes();
      expect(notes.single.collection, 'Recetas');
      expect(notes.single.title, 'Tacos');

      final read =
          await storage.readNote(saved.fileName!, collection: 'Recetas');
      expect(read.content, 'texto');
    });

    test('lista juntas las notas sueltas y las de colecciones', () async {
      await storage.createCollection('Recetas');
      await storage.saveNote(newNote(title: 'Suelta', second: 1));
      await storage
          .saveNote(newNote(title: 'Tacos', collection: 'Recetas', second: 2));

      final notes = await storage.listNotes();
      expect(notes.map((n) => n.collection).toSet(), {null, 'Recetas'});
    });

    test('dos notas no comparten fecha aunque estén en colecciones distintas',
        () async {
      await storage.createCollection('Recetas');
      await storage.saveNote(newNote(title: 'A', collection: 'Recetas'));
      final second = await storage.saveNote(newNote(title: 'B'));

      expect(second.fileName, '2026-10-03_20-59-13 B.txt');
    });

    test('si la carpeta de la colección desapareció, guardar la vuelve a crear',
        () async {
      final saved = await storage
          .saveNote(newNote(title: 'Tacos', collection: 'Recetas'));
      expect(saved.collection, 'Recetas');
      expect(entries(), ['Recetas']);
    });

    test('borrar una nota de una colección', () async {
      await storage.createCollection('Recetas');
      final saved = await storage
          .saveNote(newNote(title: 'Tacos', collection: 'Recetas'));
      await storage.deleteNote(saved.fileName!, collection: 'Recetas');
      expect(entries('Recetas'), isEmpty);
    });
  });

  group('mover notas', () {
    test('de sin colección a una colección y de regreso; el nombre no cambia',
        () async {
      await storage.createCollection('Recetas');
      final saved = await storage.saveNote(newNote(title: 'Tacos'));

      final moved = await storage.moveNote(saved, 'Recetas');
      expect(moved.collection, 'Recetas');
      expect(moved.fileName, saved.fileName);
      expect(entries('Recetas'), [saved.fileName]);
      expect(entries(), ['Recetas']);

      final back = await storage.moveNote(moved, null);
      expect(back.collection, isNull);
      expect(entries(), [saved.fileName, 'Recetas']);
      expect(entries('Recetas'), isEmpty);
    });

    test('una nota sin guardar solo cambia de colección en memoria', () async {
      final note = Note.blank();
      final moved = await storage.moveNote(note, 'Recetas');
      expect(moved.collection, 'Recetas');
      expect(entries(), isEmpty);
    });

    test('a una colección que no existe: collectionNotFound', () async {
      final saved = await storage.saveNote(newNote(title: 'Tacos'));
      await expectLater(() => storage.moveNote(saved, 'No existe'),
          throwsNoteError(NoteError.collectionNotFound));
    });

    test('si ya hay una nota con el mismo nombre: duplicateName', () async {
      await storage.createCollection('Recetas');
      File('${tempDir.path}${sep}Compras.txt').writeAsStringSync('a');
      File('${tempDir.path}${sep}Recetas${sep}Compras.txt')
          .writeAsStringSync('b');
      final note = await storage.readNote('Compras.txt');

      await expectLater(() => storage.moveNote(note, 'Recetas'),
          throwsNoteError(NoteError.duplicateName));
      expect(entries(), ['Compras.txt', 'Recetas']); // no se movió nada
    });
  });

  group('renombrar colecciones', () {
    test('renombra la carpeta; las notas y el color la siguen', () async {
      await storage.createCollection('Recetas',
          color: CollectionColor.orange);
      await storage.saveNote(newNote(title: 'Tacos', collection: 'Recetas'));

      final renamed = await storage.renameCollection('Recetas', 'Cocina');
      expect(renamed, const Collection(
          name: 'Cocina', color: CollectionColor.orange));
      expect(entries(), ['.synced-notes', 'Cocina']);
      expect((await storage.listNotes()).single.collection, 'Cocina');
      expect(await storage.listCollections(), [renamed]);
    });

    test('cambiar solo mayúsculas funciona (importante en Windows)', () async {
      await storage.createCollection('recetas', color: CollectionColor.green);
      await storage.saveNote(newNote(title: 'Tacos', collection: 'recetas'));

      await storage.renameCollection('recetas', 'Recetas');
      expect(await storage.listCollections(), const [
        Collection(name: 'Recetas', color: CollectionColor.green),
      ]);
      expect((await storage.listNotes()).single.collection, 'Recetas');
    });

    test('no se puede usar el nombre de otra colección', () async {
      await storage.createCollection('Recetas');
      await storage.createCollection('Cartas');
      await expectLater(() => storage.renameCollection('Cartas', 'RECETAS'),
          throwsNoteError(NoteError.collectionExists));
    });

    test('una colección que no existe: collectionNotFound', () async {
      await expectLater(() => storage.renameCollection('No existe', 'Otra'),
          throwsNoteError(NoteError.collectionNotFound));
    });
  });

  group('borrar colecciones', () {
    test('moviendo sus notas a "sin colección"', () async {
      await storage.createCollection('Recetas', color: CollectionColor.red);
      final note = await storage
          .saveNote(newNote(title: 'Tacos', collection: 'Recetas'));

      await storage.deleteCollection('Recetas', deleteNotes: false);
      expect(entries(), ['.synced-notes', note.fileName]);
      expect((await storage.listNotes()).single.collection, isNull);
      expect(await storage.metadata.collectionColors(), isEmpty);
    });

    test('borrando también sus notas', () async {
      await storage.createCollection('Recetas');
      await storage.saveNote(newNote(title: 'Tacos', collection: 'Recetas'));

      await storage.deleteCollection('Recetas', deleteNotes: true);
      expect(await storage.listNotes(), isEmpty);
      expect(await storage.listCollections(), isEmpty);
    });

    test('si una nota chocaría con otra de la raíz, no se toca nada', () async {
      await storage.createCollection('Recetas');
      File('${tempDir.path}${sep}Compras.txt').writeAsStringSync('raíz');
      File('${tempDir.path}${sep}Recetas${sep}Compras.txt')
          .writeAsStringSync('colección');
      File('${tempDir.path}${sep}Recetas${sep}Otra.txt').writeAsStringSync('x');

      await expectLater(
          () => storage.deleteCollection('Recetas', deleteNotes: false),
          throwsNoteError(NoteError.duplicateName));
      expect(entries('Recetas'), ['Compras.txt', 'Otra.txt']);
      expect(entries(), ['Compras.txt', 'Recetas']);
    });
  });

  group('colores (archivo de datos en .synced-notes)', () {
    test('se guardan, se cambian y se quitan', () async {
      await storage.createCollection('Recetas');
      expect((await storage.listCollections()).single.color, isNull);

      await storage.setCollectionColor('Recetas', CollectionColor.blue);
      expect((await storage.listCollections()).single.color,
          CollectionColor.blue);

      await storage.setCollectionColor('Recetas', null);
      expect((await storage.listCollections()).single.color, isNull);
    });

    test('viven en .synced-notes/collections.json', () async {
      await storage.createCollection('Recetas',
          color: CollectionColor.orange);
      final file = File(
          '${tempDir.path}$sep.synced-notes${sep}collections.json');
      final data = jsonDecode(file.readAsStringSync());
      expect(data['version'], 1);
      expect(data['collections'], {
        'Recetas': {'color': 'orange'},
      });
    });

    test('un archivo dañado no impide abrir las notas', () async {
      await storage.createCollection('Recetas');
      Directory('${tempDir.path}$sep.synced-notes').createSync();
      File('${tempDir.path}$sep.synced-notes${sep}collections.json')
          .writeAsStringSync('{esto no es json');

      expect((await storage.listCollections()).single.color, isNull);
      // Y se puede volver a guardar encima.
      await storage.setCollectionColor('Recetas', CollectionColor.pink);
      expect((await storage.listCollections()).single.color,
          CollectionColor.pink);
    });

    test('conserva datos que esta versión no conoce', () async {
      Directory('${tempDir.path}$sep.synced-notes').createSync();
      final file = File(
          '${tempDir.path}$sep.synced-notes${sep}collections.json')
        ..writeAsStringSync(jsonEncode({
          'version': 1,
          'futuro': 'algo',
          'collections': {
            'Recetas': {'color': 'red', 'pinned': true},
          },
        }));
      await storage.createCollection('Recetas');

      await storage.setCollectionColor('Recetas', CollectionColor.teal);
      final data = jsonDecode(file.readAsStringSync());
      expect(data['futuro'], 'algo');
      expect(data['collections']['Recetas'],
          {'color': 'teal', 'pinned': true});
    });

    test('un color desconocido (de una versión futura) se ignora', () async {
      Directory('${tempDir.path}$sep.synced-notes').createSync();
      File('${tempDir.path}$sep.synced-notes${sep}collections.json')
          .writeAsStringSync(jsonEncode({
        'collections': {
          'Recetas': {'color': 'ultravioleta'},
        },
      }));
      await storage.createCollection('Recetas');
      expect((await storage.listCollections()).single.color, isNull);
    });
  });

  group('permiso denegado', () {
    test('un error de permisos del sistema se reconoce', () {
      final code = Platform.isWindows ? 5 : 13;
      final error = FileSystemException('Cannot rename file', 'x.txt',
          OSError('Permission denied', code));
      expect(NoteStorage.errorFor(error), NoteError.permissionDenied);
    });

    test('otros errores del sistema no se confunden con permisos', () {
      final error = FileSystemException(
          'Cannot open', 'x.txt', const OSError('Disk full', 28));
      expect(NoteStorage.errorFor(error), isNull);
      expect(NoteStorage.errorFor(Exception('x')), isNull);
      expect(
          NoteStorage.errorFor(NoteStorageException(NoteError.duplicateName)),
          NoteError.duplicateName);
    });
  });
}
