/// Colores que puede tener un grupo.
///
/// Se guarda el nombre (ej. "orange"), no un código de color: así la pantalla
/// puede ajustar el tono para el tema claro y el oscuro, y cambiar la paleta
/// en el futuro sin tocar los datos guardados.
enum GroupColor {
  red,
  orange,
  amber,
  green,
  teal,
  blue,
  indigo,
  purple,
  pink,
  brown,
  grey;

  /// El color con ese nombre, o `null` si no existe (ej. datos de una
  /// versión futura con colores nuevos).
  static GroupColor? fromName(String? name) {
    for (final color in values) {
      if (color.name == name) return color;
    }
    return null;
  }
}

/// Un grupo: una subcarpeta dentro de la carpeta de notas.
class NoteGroup {
  const NoteGroup({required this.name, this.color});

  /// Nombre del grupo = nombre de su carpeta.
  final String name;

  /// Color elegido por el usuario. `null` = sin color.
  final GroupColor? color;

  @override
  bool operator ==(Object other) =>
      other is NoteGroup && other.name == name && other.color == color;

  @override
  int get hashCode => Object.hash(name, color);

  @override
  String toString() => 'NoteGroup($name, ${color?.name ?? "sin color"})';
}
