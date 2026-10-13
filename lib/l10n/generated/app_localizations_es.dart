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
  String get emptyNotes =>
      'Aún no tienes notas.\nToca \"Nueva nota\" para crear una.';

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
  String get errorGroupNameEmpty => 'Escribe un nombre para el grupo.';

  @override
  String errorGroupNameTooLong(int max) {
    return 'El nombre del grupo no puede tener más de $max caracteres.';
  }

  @override
  String get errorGroupNameForbiddenChars =>
      'El nombre del grupo no puede contener: / \\ : * ? \" < > |';

  @override
  String get errorGroupNameReserved =>
      'Ese nombre no se puede usar para un grupo: está reservado por el sistema, o empieza o termina con punto.';

  @override
  String get errorGroupExists => 'Ya existe un grupo con ese nombre.';

  @override
  String get errorGroupNotFound => 'El grupo ya no existe.';

  @override
  String get errorPermissionDenied =>
      'La app no tiene permiso para modificar este archivo o carpeta.';

  @override
  String get groupsAll => 'Todas';

  @override
  String get groupsNone => 'Sin grupo';

  @override
  String get newGroup => 'Nuevo grupo';

  @override
  String get groupNameHint => 'Nombre';

  @override
  String get create => 'Crear';

  @override
  String get rename => 'Renombrar';

  @override
  String get renameGroup => 'Renombrar grupo';

  @override
  String get groupColor => 'Color';

  @override
  String get colorNone => 'Sin color';

  @override
  String deleteGroupQuestion(String name) {
    return '¿Borrar el grupo \"$name\"?';
  }

  @override
  String get deleteEmptyGroupMessage => 'El grupo está vacío.';

  @override
  String deleteGroupWithNotes(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'Tiene $count notas. ¿Qué quieres hacer con ellas?',
      one: 'Tiene 1 nota. ¿Qué quieres hacer con ella?',
    );
    return '$_temp0';
  }

  @override
  String get moveNotesToNone => 'Pasar a \"Sin grupo\"';

  @override
  String get deleteNotesToo => 'Borrar también las notas';

  @override
  String get groupDeleted => 'Grupo borrado';

  @override
  String get emptyFilter =>
      'Aquí todavía no hay notas.\nToca \"Nueva nota\" para crear una.';

  @override
  String get moveTo => 'Mover a…';

  @override
  String get moveNoteTitle => 'Mover nota a';

  @override
  String get newGroupEllipsis => 'Nuevo grupo…';

  @override
  String noteMovedTo(String name) {
    return 'Nota movida a \"$name\"';
  }

  @override
  String get noteMovedToNone => 'Nota movida a \"Sin grupo\"';

  @override
  String newNoteIn(String name) {
    return 'Nueva nota en \"$name\"';
  }

  @override
  String get themeTitle => 'Tema';

  @override
  String get themeSystem => 'Del sistema';

  @override
  String themeSystemWithCurrent(String theme) {
    return 'Del sistema ($theme)';
  }

  @override
  String get themeLight => 'Claro';

  @override
  String get themeDark => 'Oscuro';

  @override
  String notesCount(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count notas',
      one: '1 nota',
      zero: 'Sin notas',
    );
    return '$_temp0';
  }

  @override
  String get searchGroupsHint => 'Buscar grupo';

  @override
  String get noGroupsFound => 'Ningún grupo con ese nombre';

  @override
  String get groupOptions => 'Opciones del grupo';

  @override
  String get noteGroupsTitle => 'Grupos de notas';

  @override
  String get showAllGroups => 'Ver todos los grupos';

  @override
  String listSummary(String view, String notes) {
    return '$view · $notes';
  }

  @override
  String get closeNote => 'Cerrar nota';

  @override
  String get noNoteOpen => 'Elige una nota de la lista\no crea una nueva.';

  @override
  String get newNoteInPrefix => 'Nueva nota en';
}
