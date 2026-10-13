/// Colores que puede tener una colección.
///
/// Se guarda el nombre (ej. "orange"), no un código de color: así la pantalla
/// puede ajustar el tono para el tema claro y el oscuro, y cambiar la paleta
/// en el futuro sin tocar los datos guardados.
enum CollectionColor {
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
  static CollectionColor? fromName(String? name) {
    for (final color in values) {
      if (color.name == name) return color;
    }
    return null;
  }
}

/// Una colección: una subcarpeta dentro de la carpeta de notas.
class Collection {
  const Collection({required this.name, this.color});

  /// Nombre de la colección = nombre de su carpeta.
  final String name;

  /// Color elegido por el usuario. `null` = sin color.
  final CollectionColor? color;

  @override
  bool operator ==(Object other) =>
      other is Collection && other.name == name && other.color == color;

  @override
  int get hashCode => Object.hash(name, color);

  @override
  String toString() => 'Collection($name, ${color?.name ?? "sin color"})';
}
