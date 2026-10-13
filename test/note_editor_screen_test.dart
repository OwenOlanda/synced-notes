import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:synced_notes/models/note_group.dart';
import 'package:synced_notes/models/note.dart';
import 'package:synced_notes/screens/note_editor_screen.dart';
import 'package:synced_notes/services/app_settings.dart';

import 'helpers/fake_storage.dart';
import 'helpers/localized_app.dart';

void main() {
  late AppSettings settings;

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    settings = await AppSettings.load();
    // Sin autoguardado: esta prueba solo revisa lo que se ve al escribir.
    await settings.setAutosave(false);
  });

  Future<void> showEditor(WidgetTester tester,
      {Locale locale = const Locale('es')}) async {
    await tester.pumpWidget(localizedApp(
      NoteEditorScreen(
        note: Note.blank(),
        storage: FakeStorage(groups: const [
          NoteGroup(name: 'Recetas', color: GroupColor.orange),
        ]),
        settings: settings,
      ),
      locale: locale,
    ));
    await tester.pumpAndSettle();
  }

  TextEditingController titleField(WidgetTester tester) =>
      tester.widget<TextField>(find.byType(TextField).first).controller!;

  testWidgets('título: un carácter prohibido no se escribe y se avisa',
      (tester) async {
    await showEditor(tester);

    await tester.enterText(find.byType(TextField).first, 'Lista: súper');
    await tester.pump();
    expect(titleField(tester).text, 'Lista súper');
    expect(find.text(r'El título no puede contener: / \ : * ? " < > |'),
        findsOneWidget);

    // El aviso se quita solo.
    await tester.pump(const Duration(seconds: 4));
    expect(find.textContaining('no puede contener'), findsNothing);
  });

  testWidgets('título: sin caracteres prohibidos no hay aviso',
      (tester) async {
    await showEditor(tester);
    await tester.enterText(find.byType(TextField).first, 'Lista del súper');
    await tester.pump();
    expect(titleField(tester).text, 'Lista del súper');
    expect(find.textContaining('no puede contener'), findsNothing);
  });

  testWidgets('el aviso sale en el idioma de la app', (tester) async {
    await showEditor(tester, locale: const Locale('en'));
    await tester.enterText(find.byType(TextField).first, 'a?b');
    await tester.pump();
    expect(find.textContaining("can't contain"), findsOneWidget);
    await tester.pump(const Duration(seconds: 4));
  });

  testWidgets('mover la nota desde el menú ⋮', (tester) async {
    await showEditor(tester);

    await tester.tap(find.byTooltip('Más opciones'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Mover a…'));
    await tester.pumpAndSettle();
    await tester.tap(find.descendant(
        of: find.byType(SimpleDialog), matching: find.text('Recetas')));
    await tester.pumpAndSettle();

    expect(find.text('Nota movida a "Recetas"'), findsOneWidget);
  });
}
