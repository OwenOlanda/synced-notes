import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:synced_notes/services/notes_folder.dart';

void main() {
  final fakeDocuments = Directory('${Directory.systemTemp.path}${Platform.pathSeparator}docs');
  final sep = Platform.pathSeparator;

  test('Windows: usa Documentos\\Synced Notes', () async {
    final folder = await NotesFolder(
      documentsDir: () async => fakeDocuments,
      isWindows: true,
    ).resolve();
    expect(folder.path, '${fakeDocuments.path}${sep}Synced Notes');
  });

  test('Android: usa la carpeta interna de la app', () async {
    final folder = await NotesFolder(
      documentsDir: () async => fakeDocuments,
      isWindows: false,
    ).resolve();
    expect(folder.path, '${fakeDocuments.path}${sep}notes');
  });
}
