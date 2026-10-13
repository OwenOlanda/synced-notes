import 'dart:io';

import 'package:path_provider/path_provider.dart';

/// Decide en qué carpeta viven las notas. La ruta es fija: la define la app.
///
/// - Windows: `Documentos\Synced Notes` (visible desde el explorador).
/// - Android: la carpeta interna de la app (`.../app_flutter/notes`).
///
/// Los grupos serán subcarpetas dentro de esta carpeta; las notas sin
/// grupo quedan sueltas en ella.
class NotesFolder {
  NotesFolder({
    Future<Directory> Function()? documentsDir,
    bool? isWindows,
  })  : _documentsDir = documentsDir ?? getApplicationDocumentsDirectory,
        _isWindows = isWindows ?? Platform.isWindows;

  /// De dónde sacar la carpeta "Documentos" (en Android: la carpeta
  /// interna de la app). Se puede reemplazar en las pruebas.
  final Future<Directory> Function() _documentsDir;
  final bool _isWindows;

  static const String windowsFolderName = 'Synced Notes';
  static const String androidFolderName = 'notes';

  /// La carpeta de notas.
  Future<Directory> resolve() async {
    final docs = await _documentsDir();
    final name = _isWindows ? windowsFolderName : androidFolderName;
    return Directory('${docs.path}${Platform.pathSeparator}$name');
  }
}
