import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
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
}
