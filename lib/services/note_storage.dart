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
/// Nombres de archivo:
///   `AAAA-MM-DD_HH-MM-SS Título.txt`  (con título)
///   `AAAA-MM-DD_HH-MM-SS.txt`         (sin título)
/// La fecha es la de creación y no cambia nunca. Dos notas no pueden
/// compartir la misma fecha: si chocan, la nueva se recorre un segundo.
///
/// Archivos .txt que no siguen ese formato (por ejemplo `Compras.txt`, copiado
/// desde otro lado) también se muestran: todo el nombre es el título.
///
/// Guardado seguro: el texto se escribe primero en un archivo temporal que
/// luego reemplaza al original. Si la app se cierra a la mitad, la versión
/// anterior de la nota sigue intacta.
class NoteStorage {
  NoteStorage(this.folder);

  /// Carpeta donde viven las notas.
  final Directory folder;

  static const String extension = '.txt';
  static const String _tempSuffix = '.tmp';

  /// Límite de caracteres del título, para no chocar con el límite
  /// de longitud de rutas de Windows.
  static const int maxTitleLength = 120;

  /// Caracteres que Windows no permite en nombres de archivo.
  /// La pantalla del editor los usa para no dejar escribirlos en el título.
  static final RegExp forbiddenTitleChars = RegExp(r'[\\/:*?"<>|]');

  static final RegExp _stampedName = RegExp(
      r'^(\d{4})-(\d{2})-(\d{2})_(\d{2})-(\d{2})-(\d{2})(?: (.*))?$');

  // ---------------------------------------------------------------------------
  // Títulos y nombres de archivo
  // ---------------------------------------------------------------------------

  /// Devuelve `null` si el título es válido, o un mensaje explicando por qué no.
  /// Un título vacío es válido (la nota queda "Sin título").
  static String? validateTitle(String title) {
    final trimmed = title.trim();
    if (trimmed.length > maxTitleLength) {
      return 'El título no puede tener más de $maxTitleLength caracteres.';
    }
    if (forbiddenTitleChars.hasMatch(trimmed)) {
      return r'El título no puede contener: / \ : * ? " < > |';
    }
    if (trimmed.codeUnits.any((c) => c < 32)) {
      return 'El título contiene caracteres no permitidos.';
    }
    return null;
  }

  /// `2026-10-03_20-59-12`
  static String _stamp(DateTime c) {
    String two(int n) => n.toString().padLeft(2, '0');
    return '${c.year.toString().padLeft(4, '0')}-${two(c.month)}-${two(c.day)}'
        '_${two(c.hour)}-${two(c.minute)}-${two(c.second)}';
  }

  /// Nombre de archivo para un título y una fecha de creación.
  static String fileNameFor(String title, DateTime createdAt) {
    final stamp = _stamp(createdAt);
    final trimmed = title.trim();
    return trimmed.isEmpty ? '$stamp$extension' : '$stamp $trimmed$extension';
  }

  /// Saca el título y la fecha de creación de un nombre de archivo.
  /// `createdAt` es `null` si el nombre no empieza con fecha.
  static ({String title, DateTime? createdAt}) parseFileName(String fileName) {
    final stem = fileName.substring(0, fileName.length - extension.length);
    final match = _stampedName.firstMatch(stem);
    if (match == null) {
      return (title: stem, createdAt: null);
    }
    final n = [for (var i = 1; i <= 6; i++) int.parse(match.group(i)!)];
    return (
      title: (match.group(7) ?? '').trim(),
      createdAt: DateTime(n[0], n[1], n[2], n[3], n[4], n[5]),
    );
  }

  // ---------------------------------------------------------------------------
  // Operaciones
  // ---------------------------------------------------------------------------

  /// Todas las notas de la carpeta, la modificada más recientemente primero.
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

  /// Lee una nota por su nombre de archivo. Falla si no existe.
  Future<Note> readNote(String fileName) async {
    final file = _file(fileName);
    if (!await file.exists()) {
      throw NoteStorageException('La nota ya no existe en la carpeta.');
    }
    return _readFile(file);
  }

  /// Guarda una nota.
  /// - Si es nueva, crea su archivo.
  /// - Si cambió el título, renombra el archivo (la fecha se conserva).
  /// - Devuelve la nota actualizada: nombre de archivo y fecha de modificación.
  Future<Note> saveNote(Note note) async {
    final error = validateTitle(note.title);
    if (error != null) throw NoteStorageException(error);
    await _ensureFolder();

    final title = note.title.trim();
    final File target;

    if (note.fileName == null) {
      // Nota nueva: buscar una fecha que ninguna otra nota esté usando.
      var created = note.createdAt;
      final usedStamps = await _usedStamps();
      while (usedStamps.contains(_stamp(created))) {
        created = created.add(const Duration(seconds: 1));
      }
      target = _file(fileNameFor(title, created));
    } else {
      final oldFile = _file(note.fileName!);
      final current = parseFileName(note.fileName!);

      if (current.title == title) {
        // Mismo título: se escribe sobre el mismo archivo.
        target = oldFile;
      } else {
        // Cambió el título: primero se renombra, después se escribe el texto.
        // Así, si algo falla a la mitad, no se pierde nada.
        // Los archivos sin fecha (ej. "Compras.txt") la reciben al renombrarse.
        target = _file(fileNameFor(title, current.createdAt ?? note.createdAt));
        if (await target.exists() &&
            !await FileSystemEntity.identical(oldFile.path, target.path)) {
          throw NoteStorageException('Ya existe otra nota con ese nombre.');
        }
        if (await oldFile.exists()) {
          await oldFile.rename(target.path);
        }
      }
    }

    final temp = File('${target.path}$_tempSuffix');
    await temp.writeAsString(note.content, flush: true);
    await temp.rename(target.path);

    return _readFile(target);
  }

  /// Borra una nota por su nombre de archivo. Si ya no existe, no hace nada.
  Future<void> deleteNote(String fileName) async {
    final file = _file(fileName);
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

  File _file(String fileName) =>
      File('${folder.path}${Platform.pathSeparator}$fileName');

  String _nameOf(File file) => file.path.split(Platform.pathSeparator).last;

  bool _isNoteFile(File file) =>
      _nameOf(file).toLowerCase().endsWith(extension);

  /// Fechas de creación que ya usan las notas de la carpeta.
  Future<Set<String>> _usedStamps() async {
    final stamps = <String>{};
    await for (final entity in folder.list()) {
      if (entity is File && _isNoteFile(entity)) {
        final created = parseFileName(_nameOf(entity)).createdAt;
        if (created != null) stamps.add(_stamp(created));
      }
    }
    return stamps;
  }

  Future<Note> _readFile(File file) async {
    final name = _nameOf(file);
    final parsed = parseFileName(name);
    final modified = await file.lastModified();
    return Note(
      fileName: name,
      title: parsed.title,
      content: await file.readAsString(),
      // Archivos sin fecha en el nombre: se usa su fecha de modificación.
      createdAt: parsed.createdAt ?? modified,
      modifiedAt: modified,
    );
  }
}
