import 'note.dart';

enum _FilterKind { all, none, collection }

/// Qué notas se están viendo en la lista:
/// - [all]: todas las notas.
/// - [none]: solo las notas sin colección.
/// - [CollectionFilter.collection]: solo las de una colección.
class CollectionFilter {
  const CollectionFilter._(this._kind, this.name);

  static const CollectionFilter all = CollectionFilter._(_FilterKind.all, null);
  static const CollectionFilter none =
      CollectionFilter._(_FilterKind.none, null);

  const CollectionFilter.collection(String name)
      : this._(_FilterKind.collection, name);

  final _FilterKind _kind;

  /// Nombre de la colección (solo si es una colección).
  final String? name;

  bool get isAll => _kind == _FilterKind.all;
  bool get isNone => _kind == _FilterKind.none;
  bool get isCollection => _kind == _FilterKind.collection;

  /// ¿Esta nota se ve con este filtro?
  bool matches(Note note) => switch (_kind) {
        _FilterKind.all => true,
        _FilterKind.none => note.collection == null,
        _FilterKind.collection => note.collection == name,
      };

  /// Colección donde nace una nota nueva creada desde aquí
  /// (desde "Todas" o "Sin colección": sin colección).
  String? get collectionForNewNote => isCollection ? name : null;

  /// Texto para guardarlo en los ajustes: "all", "none" o "c:Recetas".
  String encode() => switch (_kind) {
        _FilterKind.all => 'all',
        _FilterKind.none => 'none',
        _FilterKind.collection => 'c:$name',
      };

  /// Lo contrario de [encode]. Algo desconocido o vacío = [all].
  static CollectionFilter decode(String? value) {
    if (value == 'none') return none;
    if (value != null && value.startsWith('c:') && value.length > 2) {
      return CollectionFilter.collection(value.substring(2));
    }
    return all;
  }

  @override
  bool operator ==(Object other) =>
      other is CollectionFilter && other._kind == _kind && other.name == name;

  @override
  int get hashCode => Object.hash(_kind, name);

  @override
  String toString() => 'CollectionFilter(${encode()})';
}
