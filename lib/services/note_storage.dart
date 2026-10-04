import 'dart:io';

import '../models/note.dart';

/// Error con un mensaje que se le puede mostrar al usuario tal cual.
class NoteStorageException implements Exception {
  NoteStorageException(this.message);
  final String message;

  @override
  String toString() => message;
}

/// Lee y escribe las notas como archivos .txt dentro de una carpeta.
///
/// Reglas:
/// - Cada nota es `<título>.txt`.
/// - Los archivos se guardan en UTF-8 (acentos y ñ funcionan en todos lados).
/// - Al guardar se escribe primero un archivo temporal y luego se reemplaza
///   el original. Así, si la app se cierra a la mitad, la nota vieja
///   sigue intacta en lugar de quedar a medio escribir.
///
/// Esta clase no sabe si está en Windows o Android: solo recibe una carpeta.
/// Decidir qué carpeta usar le toca a otra parte de la app.
class NoteStorage {
  NoteStorage(this.folder);

  /// Carpeta donde viven las notas.
  final Directory folder;

  static const String _extension = '.txt';
  static const String _tempExtension = '.tmp';

  /// Caracteres que Windows no permite en nombres de archivo.
  static final RegExp _forbiddenChars = RegExp(r'[\\/:*?"<>|]');

  /// Nombres que Windows reserva (no se pueden usar aunque tengan extensión).
  static const Set<String> _reservedNames = {
    'CON', 'PRN', 'AUX', 'NUL',
    'COM1', 'COM2', 'COM3', 'COM4', 'COM5', 'COM6', 'COM7', 'COM8', 'COM9',
    'LPT1', 'LPT2', 'LPT3', 'LPT4', 'LPT5', 'LPT6', 'LPT7', 'LPT8', 'LPT9',
  };

  /// Límite de caracteres del título, para no chocar con el límite
  /// de longitud de rutas de Windows.
  static const int maxTitleLength = 120;

  // ---------------------------------------------------------------------------
  // Validación de títulos
  // ---------------------------------------------------------------------------

  /// Devuelve `null` si el título es válido, o un mensaje explicando por qué no.
  /// La interfaz puede usarla para avisar mientras el usuario escribe.
  static String? validateTitle(String title) {
    final trimmed = title.trim();
    if (trimmed.isEmpty) {
      return 'El título no puede estar vacío.';
    }
    if (trimmed.length > maxTitleLength) {
      return 'El título no puede tener más de $maxTitleLength caracteres.';
    }
    if (_forbiddenChars.hasMatch(trimmed)) {
      return r'El título no puede contener: / \ : * ? " < > |';
    }
    if (trimmed.codeUnits.any((c) => c < 32)) {
      return 'El título contiene caracteres no permitidos.';
    }
    if (trimmed.endsWith('.')) {
      return 'El título no puede terminar en punto.';
    }
    if (_reservedNames.contains(trimmed.toUpperCase())) {
      return '"$trimmed" es un nombre reservado por Windows.';
    }
    return null;
  }

  // ---------------------------------------------------------------------------
  // Operaciones
  // ---------------------------------------------------------------------------

  /// Todas las notas de la carpeta, la más reciente primero.
  Future<List<Note>> listNotes() async {
    await _ensureFolder();
    final notes = <Note>[];
    await for (final entity in folder.list()) {
      if (entity is File && _isNoteFile(entity)) {
        notes.add(await _readFile(entity));
      }
    }
    notes.sort((a, b) => b.modifiedAt.compareTo(a.modifiedAt));
    return notes;
  }

  /// Lee una nota por su título. Falla si no existe.
  Future<Note> readNote(String title) async {
    final file = _fileFor(title);
    if (!await file.exists()) {
      throw NoteStorageException('No existe la nota "$title".');
    }
    return _readFile(file);
  }

  /// Crea una nota vacía. Si el título ya existe, agrega un número:
  /// "Nota", "Nota (2)", "Nota (3)"...
  Future<Note> createNote(String title) async {
    _checkTitle(title);
    await _ensureFolder();
    final uniqueTitle = await _uniqueTitle(title.trim());
    return saveNote(Note(
      title: uniqueTitle,
      content: '',
      modifiedAt: DateTime.now(),
    ));
  }

  /// Guarda el contenido de una nota (la crea si no existe).
  /// Devuelve la nota con la fecha de modificación real del archivo.
  Future<Note> saveNote(Note note) async {
    _checkTitle(note.title);
    await _ensureFolder();
    final file = _fileFor(note.title);
    final temp = File('${file.path}$_tempExtension');

    // 1) Escribir todo en el temporal.  2) Reemplazar el original.
    await temp.writeAsString(note.content, flush: true);
    await temp.rename(file.path);

    return _readFile(file);
  }

  /// Cambia el título de una nota, es decir, renombra su archivo.
  Future<Note> renameNote(String oldTitle, String newTitle) async {
    _checkTitle(newTitle);
    final trimmedNew = newTitle.trim();
    final oldFile = _fileFor(oldTitle);
    if (!await oldFile.exists()) {
      throw NoteStorageException('No existe la nota "$oldTitle".');
    }
    if (trimmedNew == oldTitle) {
      return _readFile(oldFile);
    }

    // En Windows "nota" y "Nota" son el mismo archivo, así que se revisa
    // sin distinguir mayúsculas, excepto si solo cambian las mayúsculas
    // de la misma nota.
    final sameNoteDifferentCase =
        trimmedNew.toLowerCase() == oldTitle.toLowerCase();
    if (!sameNoteDifferentCase && await _titleExists(trimmedNew)) {
      throw NoteStorageException('Ya existe una nota llamada "$trimmedNew".');
    }

    final newFile = await oldFile.rename(_fileFor(trimmedNew).path);
    return _readFile(newFile);
  }

  /// Borra una nota. Si ya no existe, no hace nada.
  Future<void> deleteNote(String title) async {
    final file = _fileFor(title);
    if (await file.exists()) {
      await file.delete();
    }
  }

  // ---------------------------------------------------------------------------
  // Ayudantes internos
  // ---------------------------------------------------------------------------

  Future<void> _ensureFolder() async {
    if (!await folder.exists()) {
      await folder.create(recursive: true);
    }
  }

  void _checkTitle(String title) {
    final error = validateTitle(title);
    if (error != null) throw NoteStorageException(error);
  }

  File _fileFor(String title) =>
      File('${folder.path}${Platform.pathSeparator}${title.trim()}$_extension');

  bool _isNoteFile(File file) =>
      file.path.toLowerCase().endsWith(_extension);

  String _titleOf(File file) {
    final name = file.path.split(Platform.pathSeparator).last;
    return name.substring(0, name.length - _extension.length);
  }

  Future<Note> _readFile(File file) async {
    return Note(
      title: _titleOf(file),
      content: await file.readAsString(),
      modifiedAt: await file.lastModified(),
    );
  }

  /// ¿Ya hay una nota con ese título? (sin distinguir mayúsculas, como Windows)
  Future<bool> _titleExists(String title) async {
    final wanted = title.toLowerCase();
    await for (final entity in folder.list()) {
      if (entity is File &&
          _isNoteFile(entity) &&
          _titleOf(entity).toLowerCase() == wanted) {
        return true;
      }
    }
    return false;
  }

  Future<String> _uniqueTitle(String base) async {
    if (!await _titleExists(base)) return base;
    var n = 2;
    while (await _titleExists('$base ($n)')) {
      n++;
    }
    return '$base ($n)';
  }
}
