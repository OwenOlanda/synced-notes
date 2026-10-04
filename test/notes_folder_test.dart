import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:synced_notes/services/notes_folder.dart';

void main() {
  late Directory fakeDocuments;
  final sep = Platform.pathSeparator;

  setUp(() async {
    // Preferencias vacías en memoria (no toca las reales de tu PC).
    SharedPreferences.setMockInitialValues({});
    fakeDocuments = await Directory.systemTemp.createTemp('synced_notes_docs_');
  });

  tearDown(() async {
    await fakeDocuments.delete(recursive: true);
  });

  NotesFolder make({required bool isWindows}) => NotesFolder(
        documentsDir: () async => fakeDocuments,
        isWindows: isWindows,
      );

  test('Windows: por defecto usa Documentos\\Synced Notes', () async {
    final folder = await make(isWindows: true).resolve();
    expect(folder.path, '${fakeDocuments.path}${sep}Synced Notes');
  });

  test('Android: usa la carpeta interna de la app', () async {
    final folder = await make(isWindows: false).resolve();
    expect(folder.path, '${fakeDocuments.path}${sep}notes');
  });

  test('Windows: recuerda la carpeta elegida y puede volver a la de por defecto',
      () async {
    final notesFolder = make(isWindows: true);
    final custom = Directory('${fakeDocuments.path}${sep}Mis notas');

    await notesFolder.setCustomFolder(custom);
    expect((await notesFolder.resolve()).path, custom.path);

    // Una instancia nueva (como al reabrir la app) también la recuerda.
    expect((await make(isWindows: true).resolve()).path, custom.path);

    await notesFolder.resetToDefault();
    expect((await notesFolder.resolve()).path,
        '${fakeDocuments.path}${sep}Synced Notes');
  });

  test('Android: no permite elegir carpeta', () async {
    final notesFolder = make(isWindows: false);
    expect(notesFolder.canChooseFolder, isFalse);
    await expectLater(
      () => notesFolder.setCustomFolder(Directory('x')),
      throwsA(isA<UnsupportedError>()),
    );
  });
}
