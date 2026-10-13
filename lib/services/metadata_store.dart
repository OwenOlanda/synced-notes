import 'dart:convert';
import 'dart:io';

import '../models/collection.dart';

/// Datos extra de la app que no caben en las notas (.txt): por ahora, el
/// color de cada colección. Más adelante: pins, orden, etc.
///
/// Viven dentro de la propia carpeta de notas, en una carpeta oculta:
///   `Synced Notes/.synced-notes/collections.json`
/// Así viajan con la sincronización: el color que se elige en la PC también
/// aparece en el celular. La carpeta empieza con punto, y NoteStorage ignora
/// esas carpetas al buscar colecciones.
///
/// Formato (pensado para crecer sin romper versiones anteriores):
///   {
///     "version": 1,
///     "collections": {
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
  static const String _collectionsFile = 'collections.json';
  static const int _version = 1;

  /// Carpeta oculta donde se guardan los datos.
  final Directory folder;

  File get _file =>
      File('${folder.path}${Platform.pathSeparator}$_collectionsFile');

  /// Color de cada colección, por nombre. Solo incluye las que tienen color.
  Future<Map<String, CollectionColor>> collectionColors() async {
    final data = await _read();
    final result = <String, CollectionColor>{};
    final collections = data['collections'];
    if (collections is Map) {
      collections.forEach((name, value) {
        if (value is Map) {
          final color = CollectionColor.fromName(value['color'] as String?);
          if (color != null) result['$name'] = color;
        }
      });
    }
    return result;
  }

  /// Cambia el color de una colección (`null` = quitarle el color).
  Future<void> setCollectionColor(String name, CollectionColor? color) {
    return _update((collections) {
      final entry = _entry(collections, name);
      if (color == null) {
        entry.remove('color');
      } else {
        entry['color'] = color.name;
      }
      if (entry.isEmpty) collections.remove(name);
    });
  }

  /// La colección cambió de nombre: sus datos la siguen.
  Future<void> renameCollection(String oldName, String newName) {
    return _update((collections) {
      final entry = collections.remove(oldName);
      if (entry != null) collections[newName] = entry;
    });
  }

  /// La colección se borró: se olvidan sus datos.
  Future<void> removeCollection(String name) {
    return _update((collections) => collections.remove(name));
  }

  // ---------------------------------------------------------------------------
  // Ayudantes internos
  // ---------------------------------------------------------------------------

  Map<String, dynamic> _entry(Map<String, dynamic> collections, String name) {
    final existing = collections[name];
    if (existing is Map<String, dynamic>) return existing;
    final created = <String, dynamic>{};
    collections[name] = created;
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
      void Function(Map<String, dynamic> collections) change) async {
    final data = await _read();
    final collections = data['collections'] is Map<String, dynamic>
        ? data['collections'] as Map<String, dynamic>
        : <String, dynamic>{};
    change(collections);
    data['version'] = _version;
    data['collections'] = collections;

    // Guardado seguro, igual que las notas: temporal y luego reemplazar.
    await folder.create(recursive: true);
    final temp = File('${_file.path}.tmp');
    await temp.writeAsString(
        const JsonEncoder.withIndent('  ').convert(data),
        flush: true);
    await temp.rename(_file.path);
  }
}
