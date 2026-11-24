import 'dart:convert';
import 'dart:io';

import '../models/note_group.dart';

/// Datos extra de la app que no caben en las notas (.txt): el color de cada
/// grupo y las notas fijadas de cada vista. Más adelante: orden, etc.
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
///     },
///     "order": ["Rutinas", "Recetas"]
///   }
/// "order" es el orden de los grupos que el usuario acomodó arrastrándolos
/// (no existe mientras no acomode nada: entonces van en orden alfabético).
/// Las notas fijadas van en otro archivo, `pins.json`, por vista ("all" =
/// Todas, "none" = Sin grupo, "g:Recetas" = un grupo), con el id de cada
/// nota (su fecha de creación, ver `NoteStorage.noteId`), en el orden en
/// que se fijaron:
///   {
///     "version": 1,
///     "views": { "all": ["2026-10-03_20-59-12"], "g:Recetas": [...] }
///   }
/// Las claves que esta versión no conoce se conservan al volver a guardar.
class MetadataStore {
  MetadataStore(Directory notesFolder)
      : folder = Directory(
            '${notesFolder.path}${Platform.pathSeparator}$folderName');

  /// Nombre de la carpeta oculta.
  static const String folderName = '.synced-notes';
  static const String _groupsFile = 'groups.json';
  static const String _pinsFile = 'pins.json';
  static const int _version = 1;

  /// Carpeta oculta donde se guardan los datos.
  final Directory folder;

  File get _file =>
      File('${folder.path}${Platform.pathSeparator}$_groupsFile');
  File get _pins => File('${folder.path}${Platform.pathSeparator}$_pinsFile');

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

  /// El grupo cambió de nombre: sus datos lo siguen (y conserva su lugar
  /// en el orden).
  Future<void> renameGroup(String oldName, String newName) {
    return _update((groups) {
      final entry = groups.remove(oldName);
      if (entry != null) groups[newName] = entry;
    }, order: (order) {
      final i = order.indexOf(oldName);
      if (i >= 0) order[i] = newName;
    });
  }

  /// El grupo se borró: se olvidan sus datos.
  Future<void> removeGroup(String name) {
    return _update((groups) => groups.remove(name),
        order: (order) => order.remove(name));
  }

  /// El orden de los grupos que acomodó el usuario. `null` = nunca lo
  /// acomodó (van en orden alfabético).
  Future<List<String>?> groupOrder() async {
    final order = (await _read())['order'];
    if (order is! List) return null;
    return [for (final name in order) if (name is String) name];
  }

  /// Guarda el orden de los grupos.
  Future<void> setGroupOrder(List<String> names) {
    return _update((_) {}, order: (order) {
      order
        ..clear()
        ..addAll(names);
    }, createOrder: true);
  }

  /// Se creó un grupo: si ya hay un orden, va al final.
  Future<void> addToGroupOrder(String name) async {
    if (await groupOrder() == null) return;
    await _update((_) {}, order: (order) {
      if (!order.contains(name)) order.add(name);
    });
  }

  // ---------------------------------------------------------------------------
  // Notas fijadas
  // ---------------------------------------------------------------------------

  /// Las notas fijadas de cada vista (ids, en el orden en que se fijaron).
  Future<Map<String, List<String>>> pins() async {
    final views = (await _readFile(_pins))['views'];
    final result = <String, List<String>>{};
    if (views is Map) {
      views.forEach((view, ids) {
        if (ids is List) {
          final list = [for (final id in ids) if (id is String) id];
          if (list.isNotEmpty) result['$view'] = list;
        }
      });
    }
    return result;
  }

  /// Fija (o desfija) una nota en una vista.
  Future<void> setPinned(String view, String noteId, bool pinned) {
    return _updatePins((views) {
      final ids = _ids(views, view)..remove(noteId);
      if (pinned) ids.add(noteId);
      if (ids.isEmpty) views.remove(view);
    });
  }

  /// Desfija una nota: de [view], o de todas las vistas (`null`).
  Future<void> unpin(String noteId, {String? view}) {
    return _updatePins((views) {
      for (final key in [...views.keys]) {
        if (view != null && key != view) continue;
        final ids = _ids(views, key)..remove(noteId);
        if (ids.isEmpty) views.remove(key);
      }
    });
  }

  /// Una vista cambió de nombre (se renombró su grupo): sus pins la siguen.
  Future<void> renamePinView(String oldView, String newView) {
    return _updatePins((views) {
      final ids = views.remove(oldView);
      if (ids != null) views[newView] = ids;
    });
  }

  /// La vista ya no existe (se borró su grupo): se olvidan sus pins.
  Future<void> removePinView(String view) {
    return _updatePins((views) => views.remove(view));
  }

  List<dynamic> _ids(Map<String, dynamic> views, String view) {
    final existing = views[view];
    if (existing is List) return existing;
    final created = <dynamic>[];
    views[view] = created;
    return created;
  }

  Future<void> _updatePins(
      void Function(Map<String, dynamic> views) change) async {
    final data = await _readFile(_pins);
    final views = data['views'] is Map<String, dynamic>
        ? data['views'] as Map<String, dynamic>
        : <String, dynamic>{};
    final before = jsonEncode(views);
    change(views);
    // Sin cambios (ej. borrar una nota que no estaba fijada): no se escribe
    // nada, ni se crea la carpeta oculta.
    if (jsonEncode(views) == before) return;
    data['version'] = _version;
    data['views'] = views;
    await _writeFile(_pins, data);
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
  Future<Map<String, dynamic>> _read() => _readFile(_file);

  Future<Map<String, dynamic>> _readFile(File file) async {
    try {
      if (!await file.exists()) return {};
      final decoded = jsonDecode(await file.readAsString());
      return decoded is Map<String, dynamic> ? decoded : {};
    } on FormatException {
      return {};
    }
  }

  /// [order]: cambia también el orden de los grupos, si ya existe (o si
  /// [createOrder]).
  Future<void> _update(
    void Function(Map<String, dynamic> groups) change, {
    void Function(List<dynamic> order)? order,
    bool createOrder = false,
  }) async {
    final data = await _read();
    final groups = data['groups'] is Map<String, dynamic>
        ? data['groups'] as Map<String, dynamic>
        : <String, dynamic>{};
    change(groups);
    if (order != null) {
      final current = data['order'];
      if (current is List) {
        order(current);
      } else if (createOrder) {
        final created = <dynamic>[];
        order(created);
        data['order'] = created;
      }
    }
    data['version'] = _version;
    data['groups'] = groups;
    await _writeFile(_file, data);
  }

  /// Guardado seguro, igual que las notas: temporal y luego reemplazar.
  Future<void> _writeFile(File file, Map<String, dynamic> data) async {
    await folder.create(recursive: true);
    final temp = File('${file.path}.tmp');
    await temp.writeAsString(
        const JsonEncoder.withIndent('  ').convert(data),
        flush: true);
    await temp.rename(file.path);
  }
}
