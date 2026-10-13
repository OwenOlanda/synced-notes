import 'note.dart';

enum _FilterKind { all, none, group }

/// Qué notas se están viendo en la lista:
/// - [all]: todas las notas.
/// - [none]: solo las notas sin grupo.
/// - [GroupFilter.group]: solo las de un grupo.
class GroupFilter {
  const GroupFilter._(this._kind, this.name);

  static const GroupFilter all = GroupFilter._(_FilterKind.all, null);
  static const GroupFilter none =
      GroupFilter._(_FilterKind.none, null);

  const GroupFilter.group(String name)
      : this._(_FilterKind.group, name);

  final _FilterKind _kind;

  /// Nombre del grupo (solo si es un grupo).
  final String? name;

  bool get isAll => _kind == _FilterKind.all;
  bool get isNone => _kind == _FilterKind.none;
  bool get isGroup => _kind == _FilterKind.group;

  /// ¿Esta nota se ve con este filtro?
  bool matches(Note note) => switch (_kind) {
        _FilterKind.all => true,
        _FilterKind.none => note.group == null,
        _FilterKind.group => note.group == name,
      };

  /// Grupo donde nace una nota nueva creada desde aquí
  /// (desde "Todas" o "Sin grupo": sin grupo).
  String? get groupForNewNote => isGroup ? name : null;

  /// Texto para guardarlo en los ajustes: "all", "none" o "g:Recetas".
  String encode() => switch (_kind) {
        _FilterKind.all => 'all',
        _FilterKind.none => 'none',
        _FilterKind.group => 'g:$name',
      };

  /// Lo contrario de [encode]. Algo desconocido o vacío = [all].
  static GroupFilter decode(String? value) {
    if (value == 'none') return none;
    if (value != null && value.startsWith('g:') && value.length > 2) {
      return GroupFilter.group(value.substring(2));
    }
    return all;
  }

  @override
  bool operator ==(Object other) =>
      other is GroupFilter && other._kind == _kind && other.name == name;

  @override
  int get hashCode => Object.hash(_kind, name);

  @override
  String toString() => 'GroupFilter(${encode()})';
}
