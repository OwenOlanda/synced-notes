import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:synced_notes/models/collection_filter.dart';
import 'package:synced_notes/services/app_settings.dart';

void main() {
  setUp(() {
    // Preferencias vacías en memoria (no toca las reales de tu PC).
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
    expect(settings.selectedCollection, CollectionFilter.all);
  });

  test('la colección que se estaba viendo se recuerda', () async {
    final settings = await AppSettings.load();
    await settings
        .setSelectedCollection(const CollectionFilter.collection('Recetas'));
    expect((await AppSettings.load()).selectedCollection,
        const CollectionFilter.collection('Recetas'));

    await settings.setSelectedCollection(CollectionFilter.none);
    expect((await AppSettings.load()).selectedCollection,
        CollectionFilter.none);
  });

  test('CollectionFilter se guarda y se lee igual (incluso con ":" o "c:")',
      () {
    for (final filter in [
      CollectionFilter.all,
      CollectionFilter.none,
      const CollectionFilter.collection('Recetas'),
      const CollectionFilter.collection('c:rara'),
      const CollectionFilter.collection('none'),
    ]) {
      expect(CollectionFilter.decode(filter.encode()), filter);
    }
    expect(CollectionFilter.decode(null), CollectionFilter.all);
    expect(CollectionFilter.decode('basura'), CollectionFilter.all);
  });
}
