import 'dart:io';

import '../models/note_group.dart';
import '../models/note.dart';
import 'metadata_store.dart';

/// Qué salió mal al leer o guardar una nota o un grupo.
///
/// NoteStorage no escribe mensajes: solo dice qué pasó. La pantalla lo
/// traduce al idioma de la app (ver `AppLocalizations.noteError`). Así este
/// código no depende del idioma, y otras partes (ej. la sincronización)
/// pueden reaccionar a cada caso sin comparar textos.
enum NoteError {
  /// El título pasa de [NoteStorage.maxTitleLength] caracteres.
  titleTooLong,

  /// El título tiene alguno de / \ : * ? " < > |
  titleForbiddenChars,

  /// El título tiene caracteres de control (ej. un salto de línea).
  titleControlChars,

  /// El archivo de la nota ya no está en la carpeta.
  noteNotFound,

  /// Ya hay otra nota con el mismo nombre de archivo.
  duplicateName,

  /// El nombre del grupo está vacío.
  groupNameEmpty,

  /// El nombre del grupo pasa de [NoteStorage.maxTitleLength].
  groupNameTooLong,

  /// El nombre del grupo tiene / \ : * ? " < > | o caracteres de control.
  groupNameForbiddenChars,

  /// Nombre que Windows no permite para carpetas (CON, NUL, COM1…),
  /// o que empieza o termina con punto.
  groupNameReserved,

  /// Ya hay un grupo con ese nombre (sin importar mayúsculas).
  groupExists,

  /// La carpeta del grupo ya no existe.
  groupNotFound,

  /// El sistema no deja leer o escribir el archivo o la carpeta
  /// (ej. una carpeta de solo lectura, o creada por otro usuario).
  permissionDenied,
}

/// Error de NoteStorage. [error] dice qué pasó.
class NoteStorageException implements Exception {
  NoteStorageException(this.error);
  final NoteError error;

  @override
  String toString() => 'NoteStorageException(${error.name})';
}

/// Lee y escribe las notas como archivos .txt dentro de una carpeta.
///
/// Nombres de archivo:
///   `AAAA-MM-DD_HH-MM-SS Título.txt`  (con título)
///   `AAAA-MM-DD_HH-MM-SS.txt`         (sin título)
/// La fecha es la de creación y no cambia nunca. Dos notas no pueden
/// compartir la misma fecha, aunque estén en grupos distintos: si
/// chocan, la nueva se recorre un segundo. (La fecha servirá para reconocer
/// cada nota al sincronizar.)
///
/// Grupos: cada grupo es una subcarpeta de la carpeta de notas.
/// Las notas sin grupo quedan en la raíz. Un solo nivel: las carpetas
/// dentro de un grupo se ignoran, igual que las que empiezan con punto
/// (ej. `.synced-notes`, donde se guardan los colores).
///
/// Archivos .txt que no siguen el formato (por ejemplo `Compras.txt`, copiado
/// desde otro lado) también se muestran: todo el nombre es el título.
///
/// Guardado seguro: el texto se escribe primero en un archivo temporal que
/// luego reemplaza al original. Si la app se cierra a la mitad, la versión
/// anterior de la nota sigue intacta.
class NoteStorage {
  NoteStorage(this.folder) : metadata = MetadataStore(folder);

  /// Carpeta donde viven las notas.
  final Directory folder;

  /// Datos extra (color de cada grupo), en `.synced-notes`.
  final MetadataStore metadata;

  static const String extension = '.txt';
  static const String _tempSuffix = '.tmp';

  /// Límite de caracteres del título (y del nombre de un grupo), para
  /// no chocar con el límite de longitud de rutas de Windows.
  static const int maxTitleLength = 120;

  /// Caracteres que Windows no permite en nombres de archivo.
  /// La pantalla del editor los usa para no dejar escribirlos en el título.
  static final RegExp forbiddenTitleChars = RegExp(r'[\\/:*?"<>|]');

  /// Nombres que Windows reserva (no se pueden usar para carpetas, ni
  /// siquiera con algo después de un punto, ej. "CON.algo").
  static final RegExp _reservedWindowsName =
      RegExp(r'^(con|prn|aux|nul|com[0-9]|lpt[0-9])$', caseSensitive: false);

  static final RegExp _stampedName = RegExp(
      r'^(\d{4})-(\d{2})-(\d{2})_(\d{2})-(\d{2})-(\d{2})(?: (.*))?$');

  // ---------------------------------------------------------------------------
  // Títulos, nombres de grupo y nombres de archivo
  // ---------------------------------------------------------------------------

  /// Devuelve `null` si el título es válido, o qué tiene de malo.
  /// Un título vacío es válido (la nota queda "Sin título").
  static NoteError? validateTitle(String title) {
    final trimmed = title.trim();
    if (trimmed.length > maxTitleLength) return NoteError.titleTooLong;
    if (forbiddenTitleChars.hasMatch(trimmed)) {
      return NoteError.titleForbiddenChars;
    }
    if (_hasControlChars(trimmed)) return NoteError.titleControlChars;
    return null;
  }

  /// Devuelve `null` si el nombre sirve para un grupo, o qué tiene de
  /// malo. Mismas reglas que los títulos, más las de carpetas de Windows.
  /// (No revisa si ya existe otro grupo con ese nombre.)
  static NoteError? validateGroupName(String name) {
    final trimmed = name.trim();
    if (trimmed.isEmpty) return NoteError.groupNameEmpty;
    if (trimmed.length > maxTitleLength) {
      return NoteError.groupNameTooLong;
    }
    if (forbiddenTitleChars.hasMatch(trimmed) || _hasControlChars(trimmed)) {
      return NoteError.groupNameForbiddenChars;
    }
    if (trimmed.startsWith('.') ||
        trimmed.endsWith('.') ||
        _reservedWindowsName.hasMatch(trimmed.split('.').first.trim())) {
      return NoteError.groupNameReserved;
    }
    return null;
  }

  /// Qué tipo de error es [error], si es uno que la app reconoce:
  /// - los de NoteStorage ([NoteStorageException]);
  /// - "permiso denegado" del sistema (Android/Linux: 1 y 13; Windows: 5).
  /// Devuelve `null` para cualquier otro error (se muestra tal cual).
  static NoteError? errorFor(Object error) {
    if (error is NoteStorageException) return error.error;
    if (error is FileSystemException) {
      final code = error.osError?.errorCode;
      final denied = Platform.isWindows ? code == 5 : (code == 1 || code == 13);
      if (denied) return NoteError.permissionDenied;
    }
    return null;
  }

  static bool _hasControlChars(String text) =>
      text.codeUnits.any((c) => c < 32);

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
  // Notas
  // ---------------------------------------------------------------------------

  /// Todas las notas (sin grupo y de todos los grupos), la
  /// modificada más recientemente primero.
  Future<List<Note>> listNotes() async {
    await _ensureFolder();
    final notes = <Note>[];
    for (final group in [null, ...await _groupNames()]) {
      await for (final entity in _dirFor(group).list()) {
        if (entity is File && _isNoteFile(entity)) {
          notes.add(await _readFile(entity, group));
        }
      }
    }
    notes.sort((a, b) => b.modifiedAt.compareTo(a.modifiedAt));
    return notes;
  }

  /// Lee una nota por su nombre de archivo (y su grupo, si tiene).
  /// Falla si no existe.
  Future<Note> readNote(String fileName, {String? group}) async {
    final file = _file(fileName, group);
    if (!await file.exists()) {
      throw NoteStorageException(NoteError.noteNotFound);
    }
    return _readFile(file, group);
  }

  /// Guarda una nota en su grupo.
  /// - Si es nueva, crea su archivo.
  /// - Si cambió el título, renombra el archivo (la fecha se conserva).
  /// - Devuelve la nota actualizada: nombre de archivo y fecha de modificación.
  Future<Note> saveNote(Note note) async {
    final error = validateTitle(note.title);
    if (error != null) throw NoteStorageException(error);
    final dir = _dirFor(note.group);
    // Si la carpeta del grupo no existe (ej. alguien la borró desde el
    // explorador mientras se escribía), se vuelve a crear: no se pierde nada.
    await dir.create(recursive: true);

    final title = note.title.trim();
    final File target;

    if (note.fileName == null) {
      // Nota nueva: buscar una fecha que ninguna otra nota esté usando.
      var created = note.createdAt;
      final usedStamps = await _usedStamps();
      while (usedStamps.contains(_stamp(created))) {
        created = created.add(const Duration(seconds: 1));
      }
      target = _file(fileNameFor(title, created), note.group);
    } else {
      final oldFile = _file(note.fileName!, note.group);
      final current = parseFileName(note.fileName!);

      if (current.title == title) {
        // Mismo título: se escribe sobre el mismo archivo.
        target = oldFile;
      } else {
        // Cambió el título: primero se renombra, después se escribe el texto.
        // Así, si algo falla a la mitad, no se pierde nada.
        // Los archivos sin fecha (ej. "Compras.txt") la reciben al renombrarse.
        target = _file(fileNameFor(title, current.createdAt ?? note.createdAt),
            note.group);
        if (await target.exists() &&
            !await FileSystemEntity.identical(oldFile.path, target.path)) {
          throw NoteStorageException(NoteError.duplicateName);
        }
        if (await oldFile.exists()) {
          await oldFile.rename(target.path);
        }
      }
    }

    final temp = File('${target.path}$_tempSuffix');
    await temp.writeAsString(note.content, flush: true);
    await temp.rename(target.path);

    return _readFile(target, note.group);
  }

  /// Borra una nota por su nombre de archivo (y su grupo, si tiene).
  /// Si ya no existe, no hace nada.
  Future<void> deleteNote(String fileName, {String? group}) async {
    final file = _file(fileName, group);
    if (await file.exists()) {
      await file.delete();
    }
  }

  /// Mueve una nota a otro grupo (`null` = sin grupo).
  /// Mover = mover el archivo; el nombre (y su fecha) no cambian.
  /// Una nota que todavía no se ha guardado solo cambia de grupo en
  /// memoria: se creará en la nueva al guardarla.
  Future<Note> moveNote(Note note, String? toGroup) async {
    if (note.group == toGroup) return note;
    if (!note.isSaved) return note.withGroup(toGroup);

    if (toGroup != null && !await _dirFor(toGroup).exists()) {
      throw NoteStorageException(NoteError.groupNotFound);
    }
    final source = _file(note.fileName!, note.group);
    if (!await source.exists()) {
      throw NoteStorageException(NoteError.noteNotFound);
    }
    final target = _file(note.fileName!, toGroup);
    if (await target.exists()) {
      throw NoteStorageException(NoteError.duplicateName);
    }
    await source.rename(target.path);
    return _readFile(target, toGroup);
  }

  // ---------------------------------------------------------------------------
  // Grupos
  // ---------------------------------------------------------------------------

  /// Todos los grupos, en orden alfabético, con su color.
  Future<List<NoteGroup>> listGroups() async {
    await _ensureFolder();
    final colors = await metadata.groupColors();
    return [
      for (final name in await _groupNames())
        NoteGroup(name: name, color: colors[name]),
    ];
  }

  /// Crea un grupo vacío (una carpeta). Devuelve el grupo creado.
  Future<NoteGroup> createGroup(String name,
      {GroupColor? color}) async {
    final trimmed = await _checkNewGroupName(name);
    await _dirFor(trimmed).create(recursive: true);
    if (color != null) await metadata.setGroupColor(trimmed, color);
    return NoteGroup(name: trimmed, color: color);
  }

  /// Cambia el nombre de un grupo (renombra su carpeta; las notas se
  /// quedan como están). Se permite cambiar solo mayúsculas/minúsculas.
  Future<NoteGroup> renameGroup(String oldName, String newName) async {
    final oldDir = _dirFor(oldName);
    if (!await oldDir.exists()) {
      throw NoteStorageException(NoteError.groupNotFound);
    }
    final trimmed = await _checkNewGroupName(newName, renaming: oldName);
    if (trimmed != oldName) {
      if (trimmed.toLowerCase() == oldName.toLowerCase()) {
        // Solo cambian mayúsculas: Windows cree que el nombre nuevo "ya
        // existe" (es la misma carpeta), así que se pasa por un nombre
        // intermedio. Es visible a propósito: si la app se cerrara justo a
        // la mitad, las notas seguirían a la vista en ese grupo.
        final step = await oldDir.rename('${_dirFor(trimmed).path}~');
        await step.rename(_dirFor(trimmed).path);
      } else {
        await oldDir.rename(_dirFor(trimmed).path);
      }
      await metadata.renameGroup(oldName, trimmed);
    }
    final colors = await metadata.groupColors();
    return NoteGroup(name: trimmed, color: colors[trimmed]);
  }

  /// Cambia el color de un grupo (`null` = sin color).
  Future<void> setGroupColor(String name, GroupColor? color) async {
    if (!await _dirFor(name).exists()) {
      throw NoteStorageException(NoteError.groupNotFound);
    }
    await metadata.setGroupColor(name, color);
  }

  /// Borra un grupo.
  /// - [deleteNotes] `false`: sus notas pasan a "sin grupo" (la raíz).
  ///   Si alguna chocara con una nota de la raíz con el mismo nombre, no se
  ///   mueve ni se borra nada y falla con [NoteError.duplicateName].
  /// - [deleteNotes] `true`: sus notas se borran también.
  /// En ambos casos la carpeta se borra con todo lo que tenga.
  Future<void> deleteGroup(String name,
      {required bool deleteNotes}) async {
    final dir = _dirFor(name);
    if (!await dir.exists()) {
      throw NoteStorageException(NoteError.groupNotFound);
    }

    if (!deleteNotes) {
      final notes = [
        await for (final entity in dir.list())
          if (entity is File && _isNoteFile(entity)) entity,
      ];
      // Primero revisar todo; mover solo si ninguna choca.
      for (final file in notes) {
        if (await _file(_nameOf(file), null).exists()) {
          throw NoteStorageException(NoteError.duplicateName);
        }
      }
      for (final file in notes) {
        await file.rename(_file(_nameOf(file), null).path);
      }
    }

    await dir.delete(recursive: true);
    await metadata.removeGroup(name);
  }

  // ---------------------------------------------------------------------------
  // Ayudantes internos
  // ---------------------------------------------------------------------------

  Future<void> _ensureFolder() async {
    if (!await folder.exists()) {
      await folder.create(recursive: true);
    }
  }

  String get _sep => Platform.pathSeparator;

  /// Carpeta de un grupo (`null` = la raíz).
  Directory _dirFor(String? group) => group == null
      ? folder
      : Directory('${folder.path}$_sep$group');

  File _file(String fileName, String? group) =>
      File('${_dirFor(group).path}$_sep$fileName');

  String _nameOf(FileSystemEntity entity) {
    final parts = entity.path.split(_sep);
    // Las carpetas pueden terminar con separador.
    return parts.last.isEmpty ? parts[parts.length - 2] : parts.last;
  }

  bool _isNoteFile(File file) =>
      _nameOf(file).toLowerCase().endsWith(extension);

  /// Nombres de los grupos (subcarpetas que no empiezan con punto),
  /// en orden alfabético sin importar mayúsculas.
  Future<List<String>> _groupNames() async {
    final names = [
      await for (final entity in folder.list())
        if (entity is Directory && !_nameOf(entity).startsWith('.'))
          _nameOf(entity),
    ];
    names.sort((a, b) {
      final byLower = a.toLowerCase().compareTo(b.toLowerCase());
      return byLower != 0 ? byLower : a.compareTo(b);
    });
    return names;
  }

  /// Valida un nombre nuevo de grupo y que no exista otro igual (sin
  /// importar mayúsculas). [renaming]: el grupo que se está renombrando,
  /// que no cuenta como "otra". Devuelve el nombre sin espacios sobrantes.
  Future<String> _checkNewGroupName(String name,
      {String? renaming}) async {
    final error = validateGroupName(name);
    if (error != null) throw NoteStorageException(error);
    final trimmed = name.trim();
    await _ensureFolder();
    for (final existing in await _groupNames()) {
      if (existing == renaming) continue;
      if (existing.toLowerCase() == trimmed.toLowerCase()) {
        throw NoteStorageException(NoteError.groupExists);
      }
    }
    return trimmed;
  }

  /// Fechas de creación que ya usan las notas (de todos los grupos).
  Future<Set<String>> _usedStamps() async {
    final stamps = <String>{};
    for (final group in [null, ...await _groupNames()]) {
      await for (final entity in _dirFor(group).list()) {
        if (entity is File && _isNoteFile(entity)) {
          final created = parseFileName(_nameOf(entity)).createdAt;
          if (created != null) stamps.add(_stamp(created));
        }
      }
    }
    return stamps;
  }

  Future<Note> _readFile(File file, String? group) async {
    final name = _nameOf(file);
    final parsed = parseFileName(name);
    final modified = await file.lastModified();
    return Note(
      fileName: name,
      group: group,
      title: parsed.title,
      content: await file.readAsString(),
      // Archivos sin fecha en el nombre: se usa su fecha de modificación.
      createdAt: parsed.createdAt ?? modified,
      modifiedAt: modified,
    );
  }
}
