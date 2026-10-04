/// Una nota de Synced Notes.
///
/// Cada nota es un archivo .txt en disco:
/// - el título es el nombre del archivo, sin la extensión;
/// - el contenido es el texto del archivo.
///
/// Esta clase no sabe nada de archivos. Solo guarda los datos.
/// El que lee y escribe en disco es NoteStorage.
class Note {
  const Note({
    required this.title,
    required this.content,
    required this.modifiedAt,
  });

  /// Nombre del archivo sin ".txt". Ejemplo: "Lista del súper".
  final String title;

  /// Todo el texto de la nota.
  final String content;

  /// Última vez que se guardó el archivo.
  final DateTime modifiedAt;

  /// Devuelve una copia de la nota con los campos que cambies.
  /// Las notas son inmutables: en lugar de modificarlas, se crea una nueva.
  Note copyWith({String? title, String? content, DateTime? modifiedAt}) {
    return Note(
      title: title ?? this.title,
      content: content ?? this.content,
      modifiedAt: modifiedAt ?? this.modifiedAt,
    );
  }

  @override
  String toString() => 'Note("$title", ${content.length} caracteres)';
}
