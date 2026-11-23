import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:synced_notes/models/note_group.dart';
import 'package:synced_notes/models/note.dart';
import 'package:synced_notes/screens/note_editor_screen.dart';
import 'package:synced_notes/services/app_settings.dart';
import 'package:synced_notes/widgets/find_highlight_controller.dart';

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
    await tester.pump(const Duration(seconds: 7));
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
    await tester.pump(const Duration(seconds: 7));
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

  group('buscar en esta nota', () {
    final date = DateTime(2026, 10, 3, 20, 59, 12);
    final note = Note(
      fileName: '2026-10-03_20-59-12 Sopa.txt',
      title: 'Sopa',
      content: 'Sal al gusto.\nAgua y sal.\nMás SAL si hace falta.',
      createdAt: date,
      modifiedAt: date,
    );
    final findField = find.byKey(const ValueKey('find-in-note-field'));
    final count = find.byKey(const ValueKey('find-in-note-count'));

    Future<void> showNote(WidgetTester tester) async {
      await tester.pumpWidget(localizedApp(
        NoteEditorScreen(
          note: note,
          storage: FakeStorage(),
          settings: settings,
        ),
        locale: const Locale('es'),
      ));
      await tester.pumpAndSettle();
    }

    // El texto es siempre el último campo (la barra de búsqueda va arriba).
    Finder contentField() => find.byType(TextField).last;
    FindHighlightController content(WidgetTester tester) => tester
        .widget<TextField>(find.byType(TextField).last)
        .controller! as FindHighlightController;
    String countText(WidgetTester tester) => tester.widget<Text>(count).data!;

    Future<void> ctrlF(WidgetTester tester) async {
      await tester.sendKeyDownEvent(LogicalKeyboardKey.controlLeft);
      await tester.sendKeyEvent(LogicalKeyboardKey.keyF);
      await tester.sendKeyUpEvent(LogicalKeyboardKey.controlLeft);
      await tester.pumpAndSettle();
    }

    testWidgets('la lupa abre la barra; cuenta y resalta lo encontrado',
        (tester) async {
      await showNote(tester);
      expect(findField, findsNothing);

      await tester.tap(find.byTooltip('Buscar en esta nota'));
      await tester.pumpAndSettle();
      expect(findField, findsOneWidget);
      expect(tester.widget<TextField>(findField).focusNode!.hasFocus, isTrue);

      // Sin importar mayúsculas ni acentos.
      await tester.enterText(findField, 'sal');
      await tester.pumpAndSettle();
      expect(countText(tester), '1 de 3');
      expect(content(tester).highlights, hasLength(3));
      expect(content(tester).current, 0);
    });

    testWidgets('Enter va al siguiente, Shift+Enter al anterior y da la vuelta',
        (tester) async {
      await showNote(tester);
      await tester.tap(find.byTooltip('Buscar en esta nota'));
      await tester.pumpAndSettle();
      await tester.enterText(findField, 'sal');
      await tester.pumpAndSettle();

      await tester.testTextInput.receiveAction(TextInputAction.search);
      await tester.pumpAndSettle();
      expect(countText(tester), '2 de 3');
      // El campo sigue listo para seguir con Enter.
      expect(tester.widget<TextField>(findField).focusNode!.hasFocus, isTrue);

      await tester.sendKeyDownEvent(LogicalKeyboardKey.shiftLeft);
      await tester.sendKeyEvent(LogicalKeyboardKey.enter);
      await tester.sendKeyUpEvent(LogicalKeyboardKey.shiftLeft);
      await tester.pumpAndSettle();
      expect(countText(tester), '1 de 3');

      await tester.tap(find.byTooltip('Anterior'));
      await tester.pumpAndSettle();
      expect(countText(tester), '3 de 3'); // dio la vuelta

      await tester.tap(find.byTooltip('Siguiente'));
      await tester.pumpAndSettle();
      expect(countText(tester), '1 de 3');
    });

    testWidgets('sin resultados lo dice y las flechas no hacen nada',
        (tester) async {
      await showNote(tester);
      await tester.tap(find.byTooltip('Buscar en esta nota'));
      await tester.pumpAndSettle();
      await tester.enterText(findField, 'pimienta');
      await tester.pumpAndSettle();
      expect(countText(tester), 'Sin resultados');
      expect(
          tester
              .widget<IconButton>(find.widgetWithIcon(
                  IconButton, Icons.keyboard_arrow_down))
              .onPressed,
          isNull);
    });

    testWidgets('Ctrl+F abre la barra; Esc la cierra sin cerrar la nota',
        (tester) async {
      await showNote(tester);
      await tester.tap(contentField());
      await tester.pump();

      await ctrlF(tester);
      expect(findField, findsOneWidget);
      await tester.enterText(findField, 'agua');
      await tester.pumpAndSettle();
      expect(countText(tester), '1 de 1');

      await tester.sendKeyEvent(LogicalKeyboardKey.escape);
      await tester.pumpAndSettle();
      expect(findField, findsNothing);
      expect(find.byType(NoteEditorScreen), findsOneWidget);
      expect(content(tester).highlights, isEmpty);
    });

    testWidgets('también busca en el título (va primero)', (tester) async {
      await showNote(tester);
      await tester.tap(find.byTooltip('Buscar en esta nota'));
      await tester.pumpAndSettle();
      await tester.enterText(findField, 'sopa');
      await tester.pumpAndSettle();
      expect(countText(tester), '1 de 1');
      // Con la barra abierta: barra, título y texto.
      final title = tester
          .widget<TextField>(find.byType(TextField).at(1))
          .controller! as FindHighlightController;
      expect(title.highlights, [(0, 4)]);
      expect(title.current, 0);
      expect(content(tester).highlights, isEmpty);

      // Lo que solo está en el texto ya no resalta el título.
      await tester.enterText(findField, 'agua');
      await tester.pumpAndSettle();
      expect(title.highlights, isEmpty);
      expect(content(tester).current, 0);
    });

    testWidgets('editar con la barra abierta actualiza los resultados',
        (tester) async {
      await showNote(tester);
      await tester.tap(find.byTooltip('Buscar en esta nota'));
      await tester.pumpAndSettle();
      await tester.enterText(findField, 'sal');
      await tester.pumpAndSettle();
      expect(countText(tester), '1 de 3');

      await tester.enterText(contentField(), 'Sin nada.');
      await tester.pumpAndSettle();
      expect(countText(tester), 'Sin resultados');
      expect(content(tester).highlights, isEmpty);
    });
  });
}
