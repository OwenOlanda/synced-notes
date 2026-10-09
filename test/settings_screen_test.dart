import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:synced_notes/screens/settings_screen.dart';
import 'package:synced_notes/services/app_settings.dart';

void main() {
  late AppSettings settings;

  setUp(() async {
    // Preferencias vacías en memoria (no toca las reales de tu PC).
    SharedPreferences.setMockInitialValues({});
    settings = await AppSettings.load();
  });

  Future<void> showSettings(WidgetTester tester, {required bool isWindows}) {
    return tester.pumpWidget(MaterialApp(
      home: SettingsScreen(
        settings: settings,
        notesFolder: Directory('C:/Users/Prueba/Documents/Synced Notes'),
        isWindows: isWindows,
      ),
    ));
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
    await tester.pumpAndSettle();
    expect(find.text('Abrir en el explorador'), findsNothing);
    expect(find.textContaining('dentro de la app'), findsOneWidget);
  });
}
