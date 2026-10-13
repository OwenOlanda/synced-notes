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
}
