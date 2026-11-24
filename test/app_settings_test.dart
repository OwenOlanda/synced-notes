import 'package:flutter/material.dart' show ThemeMode;
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:synced_notes/models/group_filter.dart';
import 'package:synced_notes/services/app_settings.dart';

void main() {
  setUp(() {
    // Preferencias vacíos en memoria (no toca las reales de tu PC).
    SharedPreferences.setMockInitialValues({});
  });

  test('el autoguardado viene activado por defecto', () async {
    final settings = await AppSettings.load();
    expect(settings.autosave, isTrue);
  });

  test('desactivar el autoguardado se recuerda', () async {
    final settings = await AppSettings.load();
    await settings.setAutosave(false);

    final reopened = await AppSettings.load(); // como al reabrir la app
    expect(reopened.autosave, isFalse);
  });

  test('por defecto se usa el idioma del sistema', () async {
    final settings = await AppSettings.load();
    expect(settings.languageCode, isNull);
  });

  test('el idioma elegido se recuerda, y se puede volver al del sistema',
      () async {
    final settings = await AppSettings.load();
    await settings.setLanguageCode('es');
    expect((await AppSettings.load()).languageCode, 'es');

    await settings.setLanguageCode(null);
    expect((await AppSettings.load()).languageCode, isNull);
  });

  test('por defecto se ven todas las notas', () async {
    final settings = await AppSettings.load();
    expect(settings.selectedGroup, GroupFilter.all);
  });

  test('el grupo que se estaba viendo se recuerda', () async {
    final settings = await AppSettings.load();
    await settings
        .setSelectedGroup(const GroupFilter.group('Recetas'));
    expect((await AppSettings.load()).selectedGroup,
        const GroupFilter.group('Recetas'));

    await settings.setSelectedGroup(GroupFilter.none);
    expect((await AppSettings.load()).selectedGroup,
        GroupFilter.none);
  });

  test('GroupFilter se guarda y se lee igual (incluso con ":" o "g:")',
      () {
    for (final filter in [
      GroupFilter.all,
      GroupFilter.none,
      const GroupFilter.group('Recetas'),
      const GroupFilter.group('g:rara'),
      const GroupFilter.group('none'),
    ]) {
      expect(GroupFilter.decode(filter.encode()), filter);
    }
    expect(GroupFilter.decode(null), GroupFilter.all);
    expect(GroupFilter.decode('basura'), GroupFilter.all);
  });

  test('el tema: del sistema por defecto, y se recuerda el elegido', () async {
    final settings = await AppSettings.load();
    expect(settings.themeMode, ThemeMode.system);

    await settings.setThemeMode(ThemeMode.dark);
    expect((await AppSettings.load()).themeMode, ThemeMode.dark);

    await settings.setThemeMode(ThemeMode.light);
    expect((await AppSettings.load()).themeMode, ThemeMode.light);

    await settings.setThemeMode(ThemeMode.system);
    expect((await AppSettings.load()).themeMode, ThemeMode.system);
  });

  test('las notas abren "donde me quedé" por defecto y se puede cambiar',
      () async {
    final settings = await AppSettings.load();
    expect(settings.noteOpenPosition, NoteOpenPosition.last);
    await settings.setNoteOpenPosition(NoteOpenPosition.end);
    expect((await AppSettings.load()).noteOpenPosition, NoteOpenPosition.end);
  });

  test('recuerda dónde se quedó cada nota', () async {
    final settings = await AppSettings.load();
    expect(settings.notePositionOf('a'), isNull);
    await settings.setNotePosition(
        'a', const NotePosition(cursor: 12, topChar: 5));
    final reopened = await AppSettings.load();
    expect(reopened.notePositionOf('a')!.cursor, 12);
    expect(reopened.notePositionOf('a')!.topChar, 5);
  });

  test('solo recuerda las posiciones de las notas más recientes', () async {
    final settings = await AppSettings.load();
    const max = AppSettings.maxRememberedPositions;
    for (var i = 0; i <= max; i++) {
      await settings.setNotePosition(
          'n$i', NotePosition(cursor: i, topChar: 0));
    }
    expect(settings.notePositionOf('n0'), isNull); // la más vieja se fue
    expect(settings.notePositionOf('n$max')!.cursor, max);
  });

  test('zoom del texto: 100 % por defecto, en pasos de 10 % y con límites',
      () async {
    final settings = await AppSettings.load();
    expect(settings.textZoom, 1.0);
    await settings.setTextZoom(1.234); // se acomoda en el paso más cercano
    expect(settings.textZoom, 1.2);
    expect((await AppSettings.load()).textZoom, 1.2);
    await settings.setTextZoom(5);
    expect(settings.textZoom, AppSettings.maxTextZoom);
    await settings.setTextZoom(0.1);
    expect(settings.textZoom, AppSettings.minTextZoom);
  });

  test('orden de la lista: editadas por defecto y se recuerda', () async {
    final settings = await AppSettings.load();
    expect(settings.noteOrder, NoteOrder.edited);
    await settings.setNoteOrder(NoteOrder.titleAz);
    expect((await AppSettings.load()).noteOrder, NoteOrder.titleAz);
  });

  test('anota cuándo se abrió cada nota (las más recientes)', () async {
    final settings = await AppSettings.load();
    await settings.markNoteOpened('a', DateTime(2026, 11, 23, 10));
    await settings.markNoteOpened('b', DateTime(2026, 11, 23, 11));
    expect(settings.noteOpenedTimes(), {
      'a': DateTime(2026, 11, 23, 10).millisecondsSinceEpoch,
      'b': DateTime(2026, 11, 23, 11).millisecondsSinceEpoch,
    });
  });

  test('números de línea: apagados por defecto y se recuerdan', () async {
    final settings = await AppSettings.load();
    expect(settings.lineNumbers, isFalse);
    await settings.setLineNumbers(true);
    expect((await AppSettings.load()).lineNumbers, isTrue);
  });
}
