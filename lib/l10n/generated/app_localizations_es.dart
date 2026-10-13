// ignore: unused_import
import 'package:intl/intl.dart' as intl;

import 'app_localizations.dart';

// ignore_for_file: type=lint

/// The translations for Spanish Castilian (`es`).
class AppLocalizationsEs extends AppLocalizations {
  AppLocalizationsEs([String locale = 'es']) : super(locale);

  @override
  String get languageName => 'Español';

  @override
  String get settingsTitle => 'Ajustes';

  @override
  String get settingsSectionGeneral => 'General';

  @override
  String get settingsSectionSaving => 'Guardado';

  @override
  String get settingsSectionNotesLocation => 'Ubicación de las notas';

  @override
  String get settingsSectionAbout => 'Acerca de';

  @override
  String get languageTitle => 'Idioma';

  @override
  String get languageSystem => 'Idioma del sistema';

  @override
  String languageSystemWithCurrent(String language) {
    return 'Idioma del sistema ($language)';
  }

  @override
  String get autosaveTitle => 'Autoguardado';

  @override
  String get autosaveDescription =>
      'Guarda la nota automáticamente después de dejar de escribir, al salir y al cerrar la app. El botón de guardar siempre está disponible.';

  @override
  String get notesLocationWindows =>
      'Cada nota es un archivo .txt dentro de esta carpeta.';

  @override
  String get notesLocationAndroid =>
      'Las notas se guardan dentro de la app. Por ahora no se ven desde el administrador de archivos del teléfono.';

  @override
  String get openInExplorer => 'Abrir en el explorador';

  @override
  String openFolderError(String error) {
    return 'No se pudo abrir la carpeta: $error';
  }

  @override
  String version(String version) {
    return 'Versión $version';
  }

  @override
  String get versionLoading => 'Versión…';

  @override
  String get versionUnknown => 'Versión desconocida';

  @override
  String get license => 'Licencia';

  @override
  String get licenseDescription =>
      'GPL-3.0: software libre y de código abierto.';

  @override
  String get sourceCode => 'Código fuente';

  @override
  String browserOpenError(String url) {
    return 'No se pudo abrir el navegador. La dirección es $url';
  }

  @override
  String get thirdPartyLicenses => 'Licencias de terceros';

  @override
  String get thirdPartyLicensesDescription =>
      'Paquetes de código abierto que usa la app';

  @override
  String get untitled => 'Sin título';

  @override
  String get cancel => 'Cancelar';

  @override
  String get delete => 'Borrar';

  @override
  String get save => 'Guardar';

  @override
  String get discard => 'Descartar';

  @override
  String get refreshList => 'Actualizar lista';

  @override
  String get newNote => 'Nueva nota';

  @override
  String get noteDeleted => 'Nota borrada';

  @override
  String deleteError(String error) {
    return 'No se pudo borrar: $error';
  }

  @override
  String notesFolderError(String path, String error) {
    return 'No se pudo abrir la carpeta de notas:\n$path\n\n$error';
  }

  @override
  String get retry => 'Reintentar';

  @override
  String get emptyNotes => 'Aún no tienes notas.\nToca + para crear una.';

  @override
  String get noPreview => 'Sin texto';

  @override
  String get deleteNoteQuestion => '¿Borrar nota?';

  @override
  String deleteNoteWarning(String title) {
    return '\"$title\" se borrará de la carpeta de notas. Esto no se puede deshacer.';
  }

  @override
  String get statusSaving => 'Guardando…';

  @override
  String get statusSaveError => 'Error al guardar';

  @override
  String get statusNewNote => 'Nota nueva';

  @override
  String get statusUnsaved => 'Sin guardar';

  @override
  String get statusSaved => 'Guardado';

  @override
  String saveError(String error) {
    return 'No se pudo guardar: $error';
  }

  @override
  String get emptyNoteNotSaved =>
      'Escribe un título o un texto para guardar la nota.';

  @override
  String get noteSaved => 'Nota guardada';

  @override
  String get unsavedChangesQuestion => '¿Guardar los cambios?';

  @override
  String get unsavedChangesMessage => 'Esta nota tiene cambios sin guardar.';

  @override
  String get saveFailedTitle => 'No se pudo guardar';

  @override
  String get leaveWithoutSaving => 'Salir sin guardar';

  @override
  String get stay => 'Quedarme';

  @override
  String get saveTooltip => 'Guardar (Ctrl+S)';

  @override
  String get moreOptions => 'Más opciones';

  @override
  String get deleteNote => 'Borrar nota';

  @override
  String get titleHint => 'Título';

  @override
  String get contentHint => 'Escribe aquí…';

  @override
  String errorTitleTooLong(int max) {
    return 'El título no puede tener más de $max caracteres.';
  }

  @override
  String get errorTitleForbiddenChars =>
      'El título no puede contener: / \\ : * ? \" < > |';

  @override
  String get errorTitleControlChars =>
      'El título contiene caracteres no permitidos.';

  @override
  String get errorNoteNotFound => 'La nota ya no existe en la carpeta.';

  @override
  String get errorDuplicateName => 'Ya existe otra nota con ese nombre.';

  @override
  String get dateYesterday => 'Ayer';

  @override
  String get dateMonthsShort =>
      'ene|feb|mar|abr|may|jun|jul|ago|sep|oct|nov|dic';

  @override
  String dateDayMonth(String day, String month) {
    return '$day $month';
  }

  @override
  String dateDayMonthYear(String day, String month, String year) {
    return '$day $month $year';
  }

  @override
  String timeOfDay(String hour12, String hour24, String minute, String period) {
    return '$hour24:$minute';
  }

  @override
  String get timeAm => 'a. m.';

  @override
  String get timePm => 'p. m.';

  @override
  String get errorCollectionNameEmpty => 'Escribe un nombre para la colección.';

  @override
  String errorCollectionNameTooLong(int max) {
    return 'El nombre de la colección no puede tener más de $max caracteres.';
  }

  @override
  String get errorCollectionNameForbiddenChars =>
      'El nombre de la colección no puede contener: / \\ : * ? \" < > |';

  @override
  String get errorCollectionNameReserved =>
      'Ese nombre no se puede usar para una colección: está reservado por el sistema, o empieza o termina con punto.';

  @override
  String get errorCollectionExists => 'Ya existe una colección con ese nombre.';

  @override
  String get errorCollectionNotFound => 'La colección ya no existe.';

  @override
  String get errorPermissionDenied =>
      'La app no tiene permiso para modificar este archivo o carpeta.';

  @override
  String get collectionsAll => 'Todas';

  @override
  String get collectionsNone => 'Sin colección';

  @override
  String get newCollection => 'Nueva colección';

  @override
  String get collectionNameHint => 'Nombre';

  @override
  String get create => 'Crear';

  @override
  String get rename => 'Renombrar';

  @override
  String get renameCollection => 'Renombrar colección';

  @override
  String get collectionColor => 'Color';

  @override
  String get colorNone => 'Sin color';

  @override
  String deleteCollectionQuestion(String name) {
    return '¿Borrar la colección \"$name\"?';
  }

  @override
  String get deleteEmptyCollectionMessage => 'La colección está vacía.';

  @override
  String deleteCollectionWithNotes(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'Tiene $count notas. ¿Qué quieres hacer con ellas?',
      one: 'Tiene 1 nota. ¿Qué quieres hacer con ella?',
    );
    return '$_temp0';
  }

  @override
  String get moveNotesToNone => 'Pasar a \"Sin colección\"';

  @override
  String get deleteNotesToo => 'Borrar también las notas';

  @override
  String get collectionDeleted => 'Colección borrada';

  @override
  String get emptyFilter =>
      'Aquí todavía no hay notas.\nToca + para crear una.';

  @override
  String get moveTo => 'Mover a…';

  @override
  String get moveNoteTitle => 'Mover nota a';

  @override
  String get newCollectionEllipsis => 'Nueva colección…';

  @override
  String noteMovedTo(String name) {
    return 'Nota movida a \"$name\"';
  }

  @override
  String get noteMovedToNone => 'Nota movida a \"Sin colección\"';

  @override
  String newNoteIn(String name) {
    return 'Nueva nota en \"$name\"';
  }
}
