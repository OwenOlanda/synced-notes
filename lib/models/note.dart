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
/// - Si la nota está en un grupo, el archivo vive en la subcarpeta de
///   ese grupo (ej. `Synced Notes/Recetas/…`); si no, en la raíz.
///
/// Esta clase no sabe nada de archivos ni de idiomas. Solo guarda los datos.
/// El que lee y escribe en disco es NoteStorage. El título que se muestra
/// para una nota sin título ("Sin título"/"Untitled") lo da
/// `AppLocalizations.displayTitle` (lib/l10n/l10n.dart).
class Note {
  const Note({
    this.fileName,
    this.group,
    required this.title,
    required this.content,
    required this.createdAt,
    required this.modifiedAt,
  });

  /// Una nota nueva, vacía y todavía sin guardar.
  /// [group]: dónde se va a crear (`null` = sin grupo).
  factory Note.blank({String? group}) {
    final now = DateTime.now();
    // Sin milisegundos: el nombre del archivo solo guarda hasta los segundos.
    final created = DateTime(
        now.year, now.month, now.day, now.hour, now.minute, now.second);
    return Note(
      group: group,
      title: '',
      content: '',
      createdAt: created,
      modifiedAt: created,
    );
  }

  /// Nombre actual del archivo, por ejemplo `2026-10-03_20-59-12 Ideas.txt`.
  /// Es `null` si la nota todavía no se ha guardado nunca.
  final String? fileName;

  /// Nombre del grupo donde vive la nota. `null` = sin grupo
  /// (el archivo está en la raíz de la carpeta de notas).
  final String? group;

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

  /// ¿No tiene ni título ni texto? Las notas nuevas en blanco no se guardan.
  bool get isBlank => title.trim().isEmpty && content.trim().isEmpty;

  /// La misma nota, pero en otro grupo (`null` = sin grupo).
  /// (copyWith no sirve para esto: no puede distinguir "no cambiar" de "null").
  Note withGroup(String? group) => Note(
        fileName: fileName,
        group: group,
        title: title,
        content: content,
        createdAt: createdAt,
        modifiedAt: modifiedAt,
      );

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
      group: group,
      title: title ?? this.title,
      content: content ?? this.content,
      createdAt: createdAt ?? this.createdAt,
      modifiedAt: modifiedAt ?? this.modifiedAt,
    );
  }

  @override
  String toString() =>
      'Note(${group ?? "-"}/${fileName ?? "sin guardar"}, '
      '${content.length} caracteres)';
}
