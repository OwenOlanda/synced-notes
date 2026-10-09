import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:synced_notes/screens/settings_screen.dart';
import 'package:synced_notes/services/app_settings.dart';

import 'helpers/localized_app.dart';

void main() {
  late AppSettings settings;

  setUp(() async {
    // Preferencias vacías en memoria (no toca las reales de tu PC).
    SharedPreferences.setMockInitialValues({});
    settings = await AppSettings.load();
  });

  Future<void> showSettings(
    WidgetTester tester, {
    required bool isWindows,
    Locale locale = const Locale('es'),
  }) async {
    await tester.pumpWidget(localizedApp(
      SettingsScreen(
        settings: settings,
        notesFolder: Directory('C:/Users/Prueba/Documents/Synced Notes'),
        isWindows: isWindows,
      ),
      locale: locale,
    ));
    await tester.pumpAndSettle();
  }

  testWidgets('el interruptor activa y desactiva el autoguardado',
      (tester) async {
    await showSettings(tester, isWindows: true);
    expect(settings.autosave, isTrue);

    await tester.tap(find.byType(Switch));
    await tester.pumpAndSettle();
    expect(settings.autosave, isFalse);

    await tester.tap(find.byType(Switch));
    await tester.pumpAndSettle();
    expect(settings.autosave, isTrue);
  });

  testWidgets('el botón "Abrir en el explorador" solo aparece en Windows',
      (tester) async {
    await showSettings(tester, isWindows: true);
    expect(find.text('Abrir en el explorador'), findsOneWidget);

    await showSettings(tester, isWindows: false);
    expect(find.text('Abrir en el explorador'), findsNothing);
    expect(find.textContaining('dentro de la app'), findsOneWidget);
  });

  testWidgets('en inglés, los textos salen en inglés', (tester) async {
    await showSettings(tester, isWindows: true, locale: const Locale('en'));
    expect(find.text('Settings'), findsOneWidget);
    expect(find.text('Open in File Explorer'), findsOneWidget);
    expect(find.text('System language (English)'), findsOneWidget);
  });

  testWidgets('el selector de idioma guarda la elección', (tester) async {
    await showSettings(tester, isWindows: true, locale: const Locale('en'));

    // Elegir "Español".
    await tester.tap(find.text('Language'));
    await tester.pumpAndSettle();
    expect(find.text('System language'), findsOneWidget);
    expect(find.text('English'), findsOneWidget);
    await tester.tap(find.text('Español'));
    await tester.pumpAndSettle();
    expect(settings.languageCode, 'es');
    expect(find.text('Español'), findsOneWidget); // ahora es el actual

    // Volver a "Idioma del sistema".
    await tester.tap(find.text('Language'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('System language'));
    await tester.pumpAndSettle();
    expect(settings.languageCode, isNull);
  });
}
