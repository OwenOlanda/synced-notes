import 'dart:io';

import 'package:path_provider/path_provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Decide en qué carpeta viven las notas.
///
/// - Windows: por defecto `Documentos\Synced Notes`. El usuario puede elegir
///   otra carpeta; la elección se recuerda entre sesiones.
/// - Android: siempre la carpeta interna de la app (`.../notes`).
///   No pide permisos. Una carpeta visible se podrá agregar más adelante.
///
/// NoteStorage recibe la carpeta que devuelve esta clase; no sabe de dónde salió.
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

  static const String _prefsKey = 'notes_folder_path';
  static const String windowsFolderName = 'Synced Notes';
  static const String androidFolderName = 'notes';

  /// ¿Este sistema permite que el usuario elija la carpeta?
  bool get canChooseFolder => _isWindows;

  /// La carpeta de notas que debe usar la app ahora mismo.
  Future<Directory> resolve() async {
    if (_isWindows) {
      final prefs = await SharedPreferences.getInstance();
      final saved = prefs.getString(_prefsKey);
      if (saved != null && saved.isNotEmpty) {
        // Si la carpeta guardada ya no está (por ejemplo, una USB
        // desconectada), NO se cambia en silencio a otra. Así las notas no
        // quedan repartidas en dos lugares; la app mostrará el error.
        return Directory(saved);
      }
    }
    return defaultFolder();
  }

  /// La carpeta que se usa si el usuario no ha elegido otra.
  Future<Directory> defaultFolder() async {
    final docs = await _documentsDir();
    final name = _isWindows ? windowsFolderName : androidFolderName;
    return Directory('${docs.path}${Platform.pathSeparator}$name');
  }

  /// Guarda la carpeta que eligió el usuario (solo Windows).
  Future<void> setCustomFolder(Directory folder) async {
    if (!_isWindows) {
      throw UnsupportedError('En Android la carpeta de notas no se puede cambiar todavía.');
    }
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_prefsKey, folder.path);
  }

  /// Olvida la carpeta elegida y vuelve a la de por defecto.
  Future<void> resetToDefault() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_prefsKey);
  }
}
