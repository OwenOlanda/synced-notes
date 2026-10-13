import 'package:flutter/widgets.dart';

import '../models/note.dart';
import '../services/note_storage.dart';
import 'generated/app_localizations.dart';

export 'generated/app_localizations.dart';

/// Reglas de idioma de la app, en un solo lugar.
///
/// Los idiomas disponibles salen de los archivos lib/l10n/app_<código>.arb
/// (Flutter los junta en `AppLocalizations.supportedLocales`). Agregar un
/// idioma no requiere tocar este archivo ni el selector de Ajustes.

/// Idioma que se usa cuando el del sistema no está disponible en la app.
const Locale fallbackLocale = Locale('en');

/// Atajo para las pantallas: `context.l10n.settingsTitle`.
extension L10nContext on BuildContext {
  AppLocalizations get l10n => AppLocalizations.of(this);
}

/// Convierte el idioma guardado en Ajustes en un `Locale` para la app.
/// `null` significa "idioma del sistema". Un código que ya no existe
/// (por ejemplo, de una versión futura) también se trata como "del sistema".
Locale? localeForLanguageCode(String? code) {
  if (code == null) return null;
  for (final locale in AppLocalizations.supportedLocales) {
    if (locale.languageCode == code) return locale;
  }
  return null;
}

/// Elige el idioma de la app a partir de los idiomas preferidos del sistema
/// (en orden). Si ninguno está disponible, usa [fallbackLocale].
/// Ejemplos: [es-MX] → es; [fr, es] → es; [fr] → en.
Locale resolveAppLocale(
    List<Locale>? preferred, Iterable<Locale> supported) {
  // basicLocaleListResolution usa el primero de la lista como respaldo,
  // así que se pone el inglés al frente.
  return basicLocaleListResolution(preferred, [
    fallbackLocale,
    ...supported.where((locale) => locale != fallbackLocale),
  ]);
}

/// Textos que dependen de una nota o de sus errores.
extension NoteTexts on AppLocalizations {
  /// Título para mostrar: el de la nota, o "Sin título"/"Untitled".
  String displayTitle(Note note) => note.hasTitle ? note.title : untitled;

  /// Mensaje para un error de NoteStorage.
  String noteError(NoteError error) => switch (error) {
        NoteError.titleTooLong =>
          errorTitleTooLong(NoteStorage.maxTitleLength),
        NoteError.titleForbiddenChars => errorTitleForbiddenChars,
        NoteError.titleControlChars => errorTitleControlChars,
        NoteError.noteNotFound => errorNoteNotFound,
        NoteError.duplicateName => errorDuplicateName,
        NoteError.collectionNameEmpty => errorCollectionNameEmpty,
        NoteError.collectionNameTooLong =>
          errorCollectionNameTooLong(NoteStorage.maxTitleLength),
        NoteError.collectionNameForbiddenChars =>
          errorCollectionNameForbiddenChars,
        NoteError.collectionNameReserved => errorCollectionNameReserved,
        NoteError.collectionExists => errorCollectionExists,
        NoteError.collectionNotFound => errorCollectionNotFound,
        NoteError.permissionDenied => errorPermissionDenied,
      };

  /// Texto para cualquier error: los que reconoce NoteStorage (incluido
  /// "permiso denegado") se traducen; los demás (raros) se muestran tal cual.
  String errorText(Object error) {
    final known = NoteStorage.errorFor(error);
    return known != null ? noteError(known) : '$error';
  }
}

/// Nombre de un idioma escrito en ese mismo idioma ("English", "Español"),
/// sin importar en qué idioma esté la app en ese momento.
String languageNameOf(Locale locale) =>
    lookupAppLocalizations(locale).languageName;
