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
    // Ventana alta: así se construyen todas las secciones sin desplazar.
    tester.view.physicalSize = const Size(800, 2000);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
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

    await tester.tap(find.byType(Switch).first);
    await tester.pumpAndSettle();
    expect(settings.autosave, isFalse);

    await tester.tap(find.byType(Switch).first);
    await tester.pumpAndSettle();
    expect(settings.autosave, isTrue);
  });

  testWidgets('mayúscula automática: prendida por defecto y se puede apagar',
      (tester) async {
    await showSettings(tester, isWindows: true);
    expect(settings.autoCapitalize, isTrue);
    final tile = find.byKey(const ValueKey('auto-capitalize-switch'));
    await tester.scrollUntilVisible(tile, 100,
        scrollable: find.byType(Scrollable).first);
    expect(find.text('Mayúscula automática'), findsOneWidget);

    await tester.tap(tile);
    await tester.pumpAndSettle();
    expect(settings.autoCapitalize, isFalse);
  });

  testWidgets('tamaño del texto: − y + de 10 % en 10 % y volver a 100 %',
      (tester) async {
    await showSettings(tester, isWindows: false);
    final value = find.byKey(const ValueKey('text-zoom-value'));
    await tester.scrollUntilVisible(value, 100,
        scrollable: find.byType(Scrollable).first);
    expect(find.text('Tamaño del texto'), findsOneWidget);
    expect(tester.widget<Text>(value).data, '100%');

    await tester.tap(find.byKey(const ValueKey('text-zoom-in')));
    await tester.tap(find.byKey(const ValueKey('text-zoom-in')));
    await tester.pumpAndSettle();
    expect(settings.textZoom, 1.2);
    expect(tester.widget<Text>(value).data, '120%');

    await tester.tap(find.byKey(const ValueKey('text-zoom-out')));
    await tester.pumpAndSettle();
    expect(settings.textZoom, 1.1);

    await tester.tap(find.byKey(const ValueKey('text-zoom-reset')));
    await tester.pumpAndSettle();
    expect(settings.textZoom, 1.0);
    expect(tester.widget<Text>(value).data, '100%');
  });

  testWidgets('números de línea: el interruptor los prende y apaga',
      (tester) async {
    await showSettings(tester, isWindows: false);
    final tile = find.byKey(const ValueKey('line-numbers-switch'));
    await tester.scrollUntilVisible(tile, 100,
        scrollable: find.byType(Scrollable).first);
    expect(find.text('Números de línea'), findsOneWidget);
    await tester.tap(tile);
    await tester.pumpAndSettle();
    expect(settings.lineNumbers, isTrue);
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

  testWidgets('el selector de tema guarda la elección', (tester) async {
    await showSettings(tester, isWindows: true);
    expect(find.textContaining('Del sistema'), findsOneWidget);

    await tester.tap(find.text('Tema'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Oscuro'));
    await tester.pumpAndSettle();
    expect(settings.themeMode, ThemeMode.dark);
    expect(find.text('Oscuro'), findsOneWidget); // ahora es el actual
  });

  testWidgets('vista previa en la lista: por defecto igual que al abrir',
      (tester) async {
    await showSettings(tester, isWindows: false);
    final tile = find.byKey(const ValueKey('list-preview-tile'));
    await tester.scrollUntilVisible(tile, 100,
        scrollable: find.byType(Scrollable).first);
    expect(
        find.descendant(
            of: tile,
            matching:
                find.text('Igual que al abrir una nota (Donde estaba leyendo)')),
        findsOneWidget);

    await tester.tap(tile);
    await tester.pumpAndSettle();
    // Cada opción explica qué muestra.
    expect(find.text('Las últimas líneas de la nota.'), findsOneWidget);
    expect(find.text('Ahora: Donde estaba leyendo.'), findsOneWidget);
    await tester.tap(find.text('El final'));
    await tester.pumpAndSettle();
    expect(settings.listPreview, ListPreview.end);
    expect(find.descendant(of: tile, matching: find.text('El final')),
        findsOneWidget);
  });

  testWidgets('al abrir una nota: cada opción con su explicación',
      (tester) async {
    await showSettings(tester, isWindows: false);
    final tile = find.byKey(const ValueKey('open-position-tile'));
    await tester.scrollUntilVisible(tile, 100,
        scrollable: find.byType(Scrollable).first);
    expect(find.descendant(of: tile, matching: find.text('Donde estaba leyendo')),
        findsOneWidget);
    await tester.tap(tile);
    await tester.pumpAndSettle();
    expect(find.text('La nota se ve igual que cuando la cerraste.'),
        findsOneWidget);
    expect(find.text('Cada dispositivo recuerda su propio lugar en cada nota.'),
        findsOneWidget);
    await tester.tap(find.text('Donde estaba escribiendo'));
    await tester.pumpAndSettle();
    expect(settings.noteOpenPosition, NoteOpenPosition.cursor);
  });
}
