import 'dart:convert';
import 'dart:io';

import '../models/note_group.dart';

/// Datos extra de la app que no caben en las notas (.txt): por ahora, el
/// color de cada grupo. Más adelante: pins, orden, etc.
///
/// Viven dentro de la propia carpeta de notas, en una carpeta oculta:
///   `Synced Notes/.synced-notes/groups.json`
/// Así viajan con la sincronización: el color que se elige en la PC también
/// aparece en el celular. La carpeta empieza con punto, y NoteStorage ignora
/// esas carpetas al buscar grupos.
///
/// Formato (pensado para crecer sin romper versiones anteriores):
///   {
///     "version": 1,
///     "groups": {
///       "Recetas": { "color": "orange" }
///     }
///   }
/// Las claves que esta versión no conoce se conservan al volver a guardar.
class MetadataStore {
  MetadataStore(Directory notesFolder)
      : folder = Directory(
            '${notesFolder.path}${Platform.pathSeparator}$folderName');

  /// Nombre de la carpeta oculta.
  static const String folderName = '.synced-notes';
  static const String _groupsFile = 'groups.json';
  static const int _version = 1;

  /// Carpeta oculta donde se guardan los datos.
  final Directory folder;

  File get _file =>
      File('${folder.path}${Platform.pathSeparator}$_groupsFile');

  /// Color de cada grupo, por nombre. Solo incluye los que tienen color.
  Future<Map<String, GroupColor>> groupColors() async {
    final data = await _read();
    final result = <String, GroupColor>{};
    final groups = data['groups'];
    if (groups is Map) {
      groups.forEach((name, value) {
        if (value is Map) {
          final color = GroupColor.fromName(value['color'] as String?);
          if (color != null) result['$name'] = color;
        }
      });
    }
    return result;
  }

  /// Cambia el color de un grupo (`null` = quitarle el color).
  Future<void> setGroupColor(String name, GroupColor? color) {
    return _update((groups) {
      final entry = _entry(groups, name);
      if (color == null) {
        entry.remove('color');
      } else {
        entry['color'] = color.name;
      }
      if (entry.isEmpty) groups.remove(name);
    });
  }

  /// El grupo cambió de nombre: sus datos lo siguen.
  Future<void> renameGroup(String oldName, String newName) {
    return _update((groups) {
      final entry = groups.remove(oldName);
      if (entry != null) groups[newName] = entry;
    });
  }

  /// El grupo se borró: se olvidan sus datos.
  Future<void> removeGroup(String name) {
    return _update((groups) => groups.remove(name));
  }

  // ---------------------------------------------------------------------------
  // Ayudantes internos
  // ---------------------------------------------------------------------------

  Map<String, dynamic> _entry(Map<String, dynamic> groups, String name) {
    final existing = groups[name];
    if (existing is Map<String, dynamic>) return existing;
    final created = <String, dynamic>{};
    groups[name] = created;
    return created;
  }

  /// Lee el archivo. Si no existe o está dañado, empieza vacío: perder un
  /// color es molesto, pero nunca debe impedir que la app abra las notas.
  Future<Map<String, dynamic>> _read() async {
    try {
      if (!await _file.exists()) return {};
      final decoded = jsonDecode(await _file.readAsString());
      return decoded is Map<String, dynamic> ? decoded : {};
    } on FormatException {
      return {};
    }
  }

  Future<void> _update(
      void Function(Map<String, dynamic> groups) change) async {
    final data = await _read();
    final groups = data['groups'] is Map<String, dynamic>
        ? data['groups'] as Map<String, dynamic>
        : <String, dynamic>{};
    change(groups);
    data['version'] = _version;
    data['groups'] = groups;

    // Guardado seguro, igual que las notas: temporal y luego reemplazar.
    await folder.create(recursive: true);
    final temp = File('${_file.path}.tmp');
    await temp.writeAsString(
        const JsonEncoder.withIndent('  ').convert(data),
        flush: true);
    await temp.rename(_file.path);
  }
}
