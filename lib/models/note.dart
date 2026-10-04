/// Una nota de Synced Notes.
///
/// Cada nota es un archivo .txt en disco con este nombre:
///   `2026-10-03_20-59-12 Lista del súper.txt`   (con título)
///   `2026-10-03_20-59-12.txt`                   (sin título)
///
/// - La fecha y hora del inicio es cuándo se creó la nota. Nunca cambia,
///   aunque cambie el título (servirá para reconocer la nota al sincronizar).
/// - Lo que sigue es el título que escribió el usuario (puede estar vacío).
/// - El contenido es el texto del archivo.
///
/// Esta clase no sabe nada de archivos. Solo guarda los datos.
/// El que lee y escribe en disco es NoteStorage.
class Note {
  const Note({
    this.fileName,
    required this.title,
    required this.content,
    required this.createdAt,
    required this.modifiedAt,
  });

  /// Una nota nueva, vacía y todavía sin guardar.
  factory Note.blank() {
    final now = DateTime.now();
    // Sin milisegundos: el nombre del archivo solo guarda hasta los segundos.
    final created = DateTime(
        now.year, now.month, now.day, now.hour, now.minute, now.second);
    return Note(title: '', content: '', createdAt: created, modifiedAt: created);
  }

  /// Nombre actual del archivo, por ejemplo `2026-10-03_20-59-12 Ideas.txt`.
  /// Es `null` si la nota todavía no se ha guardado nunca.
  final String? fileName;

  /// Título que escribió el usuario. Puede estar vacío.
  final String title;

  /// Todo el texto de la nota.
  final String content;

  /// Cuándo se creó la nota.
  final DateTime createdAt;

  /// Última vez que se guardó el archivo.
  final DateTime modifiedAt;

  /// ¿Ya existe en disco?
  bool get isSaved => fileName != null;

  /// ¿El usuario le puso título?
  bool get hasTitle => title.trim().isNotEmpty;

  /// Título para mostrar en pantalla.
  String get displayTitle => hasTitle ? title : 'Sin título';

  /// ¿No tiene ni título ni texto? Las notas nuevas en blanco no se guardan.
  bool get isBlank => title.trim().isEmpty && content.trim().isEmpty;

  /// Devuelve una copia de la nota con los campos que cambies.
  /// Las notas son inmutables: en lugar de modificarlas, se crea una nueva.
  Note copyWith({
    String? fileName,
    String? title,
    String? content,
    DateTime? createdAt,
    DateTime? modifiedAt,
  }) {
    return Note(
      fileName: fileName ?? this.fileName,
      title: title ?? this.title,
      content: content ?? this.content,
      createdAt: createdAt ?? this.createdAt,
      modifiedAt: modifiedAt ?? this.modifiedAt,
    );
  }

  @override
  String toString() =>
      'Note(${fileName ?? "sin guardar"}, ${content.length} caracteres)';
}
