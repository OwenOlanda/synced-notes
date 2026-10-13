import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:synced_notes/models/note_group.dart';
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

  Note newNote({String title = '', String? group, int second = 12}) =>
      Note(
        title: title,
        content: 'texto',
        group: group,
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

  group('nombres de grupo', () {
    test('válidos', () {
      expect(NoteStorage.validateGroupName('Recetas'), isNull);
      expect(NoteStorage.validateGroupName('Ideas 2026'), isNull);
      expect(NoteStorage.validateGroupName('Console'), isNull);
    });

    test('inválidos, cada uno con su motivo', () {
      expect(NoteStorage.validateGroupName('   '),
          NoteError.groupNameEmpty);
      expect(NoteStorage.validateGroupName('x' * 121),
          NoteError.groupNameTooLong);
      expect(NoteStorage.validateGroupName('a/b'),
          NoteError.groupNameForbiddenChars);
      for (final reserved in ['CON', 'nul', 'Com1', 'LPT9', 'con.txt']) {
        expect(NoteStorage.validateGroupName(reserved),
            NoteError.groupNameReserved,
            reason: reserved);
      }
      expect(NoteStorage.validateGroupName('.oculta'),
          NoteError.groupNameReserved);
      expect(NoteStorage.validateGroupName('Notas.'),
          NoteError.groupNameReserved);
    });
  });

  group('crear y listar grupos', () {
    test('en orden alfabético sin importar mayúsculas, incluidas las vacíos',
        () async {
      await storage.createGroup('Recetas');
      await storage.createGroup('cartas');
      await storage.createGroup('Frases');

      final names = (await storage.listGroups()).map((c) => c.name);
      expect(names, ['cartas', 'Frases', 'Recetas']);
      expect(entries(), ['Frases', 'Recetas', 'cartas']);
    });

    test('se quitan los espacios sobrantes del nombre', () async {
      final created = await storage.createGroup('  Recetas  ');
      expect(created.name, 'Recetas');
      expect(entries(), ['Recetas']);
    });

    test('no puede haber dos con el mismo nombre (sin importar mayúsculas)',
        () async {
      await storage.createGroup('Recetas');
      await expectLater(() => storage.createGroup('recetas'),
          throwsNoteError(NoteError.groupExists));
    });

    test('un nombre inválido no crea nada', () async {
      await expectLater(() => storage.createGroup('CON'),
          throwsNoteError(NoteError.groupNameReserved));
      expect(await storage.listGroups(), isEmpty);
    });

    test('ignora carpetas con punto y no busca notas más adentro', () async {
      await storage.createGroup('Recetas');
      Directory('${tempDir.path}$sep.oculta').createSync();
      Directory('${tempDir.path}${sep}Recetas${sep}Postres').createSync();
      File('${tempDir.path}${sep}Recetas${sep}Postres${sep}Flan.txt')
          .writeAsStringSync('x');

      final names = (await storage.listGroups()).map((c) => c.name);
      expect(names, ['Recetas']);
      expect(await storage.listNotes(), isEmpty);
    });
  });

  group('notas dentro de grupos', () {
    test('se guardan en la subcarpeta y se listan con su grupo', () async {
      await storage.createGroup('Recetas');
      final saved = await storage
          .saveNote(newNote(title: 'Tacos', group: 'Recetas'));

      expect(entries('Recetas'), ['2026-10-03_20-59-12 Tacos.txt']);
      final notes = await storage.listNotes();
      expect(notes.single.group, 'Recetas');
      expect(notes.single.title, 'Tacos');

      final read =
          await storage.readNote(saved.fileName!, group: 'Recetas');
      expect(read.content, 'texto');
    });

    test('lista juntas las notas sueltas y las de grupos', () async {
      await storage.createGroup('Recetas');
      await storage.saveNote(newNote(title: 'Suelta', second: 1));
      await storage
          .saveNote(newNote(title: 'Tacos', group: 'Recetas', second: 2));

      final notes = await storage.listNotes();
      expect(notes.map((n) => n.group).toSet(), {null, 'Recetas'});
    });

    test('dos notas no comparten fecha aunque estén en grupos distintos',
        () async {
      await storage.createGroup('Recetas');
      await storage.saveNote(newNote(title: 'A', group: 'Recetas'));
      final second = await storage.saveNote(newNote(title: 'B'));

      expect(second.fileName, '2026-10-03_20-59-13 B.txt');
    });

    test('si la carpeta del grupo desapareció, guardar la vuelve a crear',
        () async {
      final saved = await storage
          .saveNote(newNote(title: 'Tacos', group: 'Recetas'));
      expect(saved.group, 'Recetas');
      expect(entries(), ['Recetas']);
    });

    test('borrar una nota de un grupo', () async {
      await storage.createGroup('Recetas');
      final saved = await storage
          .saveNote(newNote(title: 'Tacos', group: 'Recetas'));
      await storage.deleteNote(saved.fileName!, group: 'Recetas');
      expect(entries('Recetas'), isEmpty);
    });
  });

  group('mover notas', () {
    test('de sin grupo a un grupo y de regreso; el nombre no cambia',
        () async {
      await storage.createGroup('Recetas');
      final saved = await storage.saveNote(newNote(title: 'Tacos'));

      final moved = await storage.moveNote(saved, 'Recetas');
      expect(moved.group, 'Recetas');
      expect(moved.fileName, saved.fileName);
      expect(entries('Recetas'), [saved.fileName]);
      expect(entries(), ['Recetas']);

      final back = await storage.moveNote(moved, null);
      expect(back.group, isNull);
      expect(entries(), [saved.fileName, 'Recetas']);
      expect(entries('Recetas'), isEmpty);
    });

    test('una nota sin guardar solo cambia de grupo en memoria', () async {
      final note = Note.blank();
      final moved = await storage.moveNote(note, 'Recetas');
      expect(moved.group, 'Recetas');
      expect(entries(), isEmpty);
    });

    test('a un grupo que no existe: groupNotFound', () async {
      final saved = await storage.saveNote(newNote(title: 'Tacos'));
      await expectLater(() => storage.moveNote(saved, 'No existe'),
          throwsNoteError(NoteError.groupNotFound));
    });

    test('si ya hay una nota con el mismo nombre: duplicateName', () async {
      await storage.createGroup('Recetas');
      File('${tempDir.path}${sep}Compras.txt').writeAsStringSync('a');
      File('${tempDir.path}${sep}Recetas${sep}Compras.txt')
          .writeAsStringSync('b');
      final note = await storage.readNote('Compras.txt');

      await expectLater(() => storage.moveNote(note, 'Recetas'),
          throwsNoteError(NoteError.duplicateName));
      expect(entries(), ['Compras.txt', 'Recetas']); // no se movió nada
    });
  });

  group('renombrar grupos', () {
    test('renombra la carpeta; las notas y el color la siguen', () async {
      await storage.createGroup('Recetas',
          color: GroupColor.orange);
      await storage.saveNote(newNote(title: 'Tacos', group: 'Recetas'));

      final renamed = await storage.renameGroup('Recetas', 'Cocina');
      expect(renamed, const NoteGroup(
          name: 'Cocina', color: GroupColor.orange));
      expect(entries(), ['.synced-notes', 'Cocina']);
      expect((await storage.listNotes()).single.group, 'Cocina');
      expect(await storage.listGroups(), [renamed]);
    });

    test('cambiar solo mayúsculas funciona (importante en Windows)', () async {
      await storage.createGroup('recetas', color: GroupColor.green);
      await storage.saveNote(newNote(title: 'Tacos', group: 'recetas'));

      await storage.renameGroup('recetas', 'Recetas');
      expect(await storage.listGroups(), const [
        NoteGroup(name: 'Recetas', color: GroupColor.green),
      ]);
      expect((await storage.listNotes()).single.group, 'Recetas');
    });

    test('no se puede usar el nombre de otro grupo', () async {
      await storage.createGroup('Recetas');
      await storage.createGroup('Cartas');
      await expectLater(() => storage.renameGroup('Cartas', 'RECETAS'),
          throwsNoteError(NoteError.groupExists));
    });

    test('un grupo que no existe: groupNotFound', () async {
      await expectLater(() => storage.renameGroup('No existe', 'Otra'),
          throwsNoteError(NoteError.groupNotFound));
    });
  });

  group('borrar grupos', () {
    test('moviendo sus notas a "sin grupo"', () async {
      await storage.createGroup('Recetas', color: GroupColor.red);
      final note = await storage
          .saveNote(newNote(title: 'Tacos', group: 'Recetas'));

      await storage.deleteGroup('Recetas', deleteNotes: false);
      expect(entries(), ['.synced-notes', note.fileName]);
      expect((await storage.listNotes()).single.group, isNull);
      expect(await storage.metadata.groupColors(), isEmpty);
    });

    test('borrando también sus notas', () async {
      await storage.createGroup('Recetas');
      await storage.saveNote(newNote(title: 'Tacos', group: 'Recetas'));

      await storage.deleteGroup('Recetas', deleteNotes: true);
      expect(await storage.listNotes(), isEmpty);
      expect(await storage.listGroups(), isEmpty);
    });

    test('si una nota chocaría con otra de la raíz, no se toca nada', () async {
      await storage.createGroup('Recetas');
      File('${tempDir.path}${sep}Compras.txt').writeAsStringSync('raíz');
      File('${tempDir.path}${sep}Recetas${sep}Compras.txt')
          .writeAsStringSync('grupo');
      File('${tempDir.path}${sep}Recetas${sep}Otra.txt').writeAsStringSync('x');

      await expectLater(
          () => storage.deleteGroup('Recetas', deleteNotes: false),
          throwsNoteError(NoteError.duplicateName));
      expect(entries('Recetas'), ['Compras.txt', 'Otra.txt']);
      expect(entries(), ['Compras.txt', 'Recetas']);
    });
  });

  group('colores (archivo de datos en .synced-notes)', () {
    test('se guardan, se cambian y se quitan', () async {
      await storage.createGroup('Recetas');
      expect((await storage.listGroups()).single.color, isNull);

      await storage.setGroupColor('Recetas', GroupColor.blue);
      expect((await storage.listGroups()).single.color,
          GroupColor.blue);

      await storage.setGroupColor('Recetas', null);
      expect((await storage.listGroups()).single.color, isNull);
    });

    test('viven en .synced-notes/groups.json', () async {
      await storage.createGroup('Recetas',
          color: GroupColor.orange);
      final file = File(
          '${tempDir.path}$sep.synced-notes${sep}groups.json');
      final data = jsonDecode(file.readAsStringSync());
      expect(data['version'], 1);
      expect(data['groups'], {
        'Recetas': {'color': 'orange'},
      });
    });

    test('un archivo dañado no impide abrir las notas', () async {
      await storage.createGroup('Recetas');
      Directory('${tempDir.path}$sep.synced-notes').createSync();
      File('${tempDir.path}$sep.synced-notes${sep}groups.json')
          .writeAsStringSync('{esto no es json');

      expect((await storage.listGroups()).single.color, isNull);
      // Y se puede volver a guardar encima.
      await storage.setGroupColor('Recetas', GroupColor.pink);
      expect((await storage.listGroups()).single.color,
          GroupColor.pink);
    });

    test('conserva datos que esta versión no conoce', () async {
      Directory('${tempDir.path}$sep.synced-notes').createSync();
      final file = File(
          '${tempDir.path}$sep.synced-notes${sep}groups.json')
        ..writeAsStringSync(jsonEncode({
          'version': 1,
          'futuro': 'algo',
          'groups': {
            'Recetas': {'color': 'red', 'pinned': true},
          },
        }));
      await storage.createGroup('Recetas');

      await storage.setGroupColor('Recetas', GroupColor.teal);
      final data = jsonDecode(file.readAsStringSync());
      expect(data['futuro'], 'algo');
      expect(data['groups']['Recetas'],
          {'color': 'teal', 'pinned': true});
    });

    test('un color desconocido (de una versión futura) se ignora', () async {
      Directory('${tempDir.path}$sep.synced-notes').createSync();
      File('${tempDir.path}$sep.synced-notes${sep}groups.json')
          .writeAsStringSync(jsonEncode({
        'groups': {
          'Recetas': {'color': 'ultravioleta'},
        },
      }));
      await storage.createGroup('Recetas');
      expect((await storage.listGroups()).single.color, isNull);
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
