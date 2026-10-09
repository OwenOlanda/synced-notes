import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:synced_notes/l10n/l10n.dart';
import 'package:synced_notes/models/note.dart';
import 'package:synced_notes/services/note_storage.dart';

void main() {
  const supported = AppLocalizations.supportedLocales;

  group('resolveAppLocale (idioma del sistema)', () {
    test('español de cualquier país → español', () {
      expect(resolveAppLocale([const Locale('es', 'MX')], supported),
          const Locale('es'));
    });

    test('inglés → inglés', () {
      expect(resolveAppLocale([const Locale('en', 'US')], supported),
          const Locale('en'));
    });

    test('idioma que la app no tiene → inglés', () {
      expect(resolveAppLocale([const Locale('fr')], supported),
          const Locale('en'));
    });

    test('usa el primer idioma preferido que la app sí tenga', () {
      expect(
          resolveAppLocale(
              [const Locale('fr'), const Locale('es', 'ES')], supported),
          const Locale('es'));
    });

    test('sin información del sistema → inglés', () {
      expect(resolveAppLocale(null, supported), const Locale('en'));
    });
  });

  test('localeForLanguageCode: null o desconocido = idioma del sistema', () {
    expect(localeForLanguageCode(null), isNull);
    expect(localeForLanguageCode('xx'), isNull);
    expect(localeForLanguageCode('es'), const Locale('es'));
  });

  test('cada idioma tiene su nombre escrito en su propio idioma', () {
    expect(languageNameOf(const Locale('en')), 'English');
    expect(languageNameOf(const Locale('es')), 'Español');
  });

  test('una nota sin título se muestra como "Sin título" / "Untitled"', () {
    final date = DateTime(2026, 10, 3);
    final untitled =
        Note(title: '  ', content: 'x', createdAt: date, modifiedAt: date);
    final titled = untitled.copyWith(title: 'Ideas');

    final es = lookupAppLocalizations(const Locale('es'));
    final en = lookupAppLocalizations(const Locale('en'));
    expect(es.displayTitle(untitled), 'Sin título');
    expect(en.displayTitle(untitled), 'Untitled');
    expect(en.displayTitle(titled), 'Ideas');
  });

  test('los errores de NoteStorage se traducen', () {
    final es = lookupAppLocalizations(const Locale('es'));
    final en = lookupAppLocalizations(const Locale('en'));

    expect(es.noteError(NoteError.duplicateName),
        'Ya existe otra nota con ese nombre.');
    expect(en.noteError(NoteError.duplicateName),
        'Another note already has that name.');
    expect(en.noteError(NoteError.titleTooLong), contains('120'));

    // errorText traduce los de NoteStorage y deja los demás como vienen.
    expect(en.errorText(NoteStorageException(NoteError.noteNotFound)),
        'The note is no longer in the folder.');
    expect(en.errorText(Exception('disco lleno')), 'Exception: disco lleno');
  });

  test('cada error de NoteStorage tiene mensaje en cada idioma', () {
    for (final locale in AppLocalizations.supportedLocales) {
      final l10n = lookupAppLocalizations(locale);
      for (final error in NoteError.values) {
        expect(l10n.noteError(error), isNotEmpty);
      }
    }
  });
}
