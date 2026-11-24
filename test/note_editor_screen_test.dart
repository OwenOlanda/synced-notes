import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:synced_notes/models/note_group.dart';
import 'package:synced_notes/models/note.dart';
import 'package:synced_notes/screens/note_editor_screen.dart';
import 'package:synced_notes/services/app_settings.dart';
import 'package:synced_notes/widgets/find_highlight_controller.dart';
import 'package:synced_notes/widgets/line_numbers_painter.dart';

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

  testWidgets('título: el aviso se quita al seguir escribiendo',
      (tester) async {
    await showEditor(tester);
    await tester.enterText(find.byType(TextField).first, 'Lista: súper');
    await tester.pump();
    expect(find.textContaining('no puede contener'), findsOneWidget);

    // Se escribe algo permitido: el aviso se va de inmediato.
    await tester.enterText(find.byType(TextField).first, 'Lista súper!');
    await tester.pump();
    expect(find.textContaining('no puede contener'), findsNothing);
    await tester.pump(const Duration(seconds: 5));
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

  group('escritura', () {
    final date = DateTime(2026, 11, 23, 16, 40);
    final note = Note(
      fileName: '2026-11-23_16-40-00 Frase.txt',
      title: 'Frase',
      content: 'Hola mundo grande',
      createdAt: date,
      modifiedAt: date,
    );

    Future<void> showNote(WidgetTester tester, {bool embedded = false}) async {
      final editor = NoteEditorScreen(
        note: note,
        storage: FakeStorage(),
        settings: settings,
        embedded: embedded,
        onClose: embedded ? () {} : null,
      );
      await tester.pumpWidget(localizedApp(
        // En PC va dentro de otra pantalla; en el celular es la pantalla.
        embedded ? Scaffold(body: editor) : editor,
        locale: const Locale('es'),
      ));
      await tester.pumpAndSettle();
    }

    Finder contentField() => find.byType(TextField).last;
    TextEditingController content(WidgetTester tester) =>
        tester.widget<TextField>(contentField()).controller!;

    testWidgets('mayúscula automática según el ajuste', (tester) async {
      await showNote(tester);
      expect(tester.widget<TextField>(contentField()).textCapitalization,
          TextCapitalization.sentences);
      expect(tester.widget<TextField>(find.byType(TextField).first)
          .textCapitalization, TextCapitalization.sentences);

      await settings.setAutoCapitalize(false);
      await showNote(tester);
      expect(tester.widget<TextField>(contentField()).textCapitalization,
          TextCapitalization.none);
    });

    testWidgets('celular: la barrita ↶ ↷ sale sobre el teclado y deshace',
        (tester) async {
      await showNote(tester);
      // Flutter guarda el texto original en el historial medio segundo
      // después de abrir la nota.
      await tester.pump(const Duration(milliseconds: 600));
      final bar = find.byKey(const ValueKey('keyboard-bar'));
      expect(bar, findsNothing);

      await tester.tap(contentField());
      tester.view.viewInsets =
          FakeViewPadding(bottom: 300 * tester.view.devicePixelRatio);
      addTearDown(tester.view.resetViewInsets);
      await tester.pumpAndSettle();
      expect(bar, findsOneWidget);

      await tester.enterText(contentField(), 'Hola mundo grande!');
      await tester.pump(const Duration(milliseconds: 600));
      await tester.tap(find.byTooltip('Deshacer'));
      await tester.pumpAndSettle();
      expect(content(tester).text, 'Hola mundo grande');

      await tester.tap(find.byTooltip('Rehacer'));
      await tester.pumpAndSettle();
      expect(content(tester).text, 'Hola mundo grande!');

      // Sin teclado, la barrita no está.
      tester.view.resetViewInsets();
      await tester.pumpAndSettle();
      expect(bar, findsNothing);
    });

    testWidgets('PC: ↶ ↷ en la barra de la nota', (tester) async {
      await showNote(tester, embedded: true);
      expect(find.byTooltip('Deshacer (Ctrl+Z)'), findsOneWidget);
      expect(find.byTooltip('Rehacer (Ctrl+Y)'), findsOneWidget);
      expect(find.byKey(const ValueKey('keyboard-bar')), findsNothing);
    });

    testWidgets('números de línea: en el margen, sin estorbar los toques',
        (tester) async {
      await showNote(tester);
      expect(
          find.byWidgetPredicate(
              (w) => w is CustomPaint && w.painter is LineNumbersPainter),
          findsNothing);

      await settings.setLineNumbers(true);
      await showNote(tester);
      final painter = find.byWidgetPredicate(
          (w) => w is CustomPaint && w.painter is LineNumbersPainter);
      expect(painter, findsOneWidget);
      // No recibe toques: va dentro de un IgnorePointer.
      expect(
          find.ancestor(of: painter, matching: find.byType(IgnorePointer)),
          findsWidgets);

      // Tocar el margen (donde van los números) sigue poniendo el cursor
      // al principio del renglón, y el texto no perdió ancho.
      final editable =
          tester.state<EditableTextState>(find.byType(EditableText).last)
              .renderEditable;
      final field = tester.getRect(contentField());
      final start = editable.localToGlobal(
          editable.getLocalRectForCaret(const TextPosition(offset: 0))
              .centerLeft);
      expect(start.dx - field.left, greaterThanOrEqualTo(16));
      await tester.tap(contentField());
      await tester.pump(const Duration(milliseconds: 500));
      await tester.tapAt(Offset(field.left + 4, start.dy));
      await tester.pump(const Duration(milliseconds: 500));
      expect(content(tester).selection.baseOffset, 0);
    });

    testWidgets('tocar el margen a un lado del renglón pone el cursor en su orilla',
        (tester) async {
      await showNote(tester);
      final editable =
          tester.state<EditableTextState>(find.byType(EditableText).last)
              .renderEditable;
      final field = tester.getRect(contentField());
      final lineY = editable
          .localToGlobal(editable
              .getLocalRectForCaret(const TextPosition(offset: 0))
              .center)
          .dy;
      final textStart = editable
          .localToGlobal(editable
              .getLocalRectForCaret(const TextPosition(offset: 0))
              .centerLeft)
          .dx;
      // El margen va dentro del campo: hay espacio en blanco a la izquierda.
      expect(textStart - field.left, greaterThanOrEqualTo(16));

      // En el espacio en blanco a la izquierda de "Hola": antes de la "H".
      await tester.tap(contentField());
      await tester.pump(const Duration(milliseconds: 500));
      await tester.tapAt(Offset(field.left + 4, lineY));
      await tester.pump(const Duration(milliseconds: 500));
      expect(content(tester).selection.baseOffset, 0);

      // A la derecha de "grande": después de la última letra.
      await tester.tapAt(Offset(field.right - 4, lineY));
      await tester.pump(const Duration(milliseconds: 500));
      expect(content(tester).selection.baseOffset, 17);

      // Tocar la segunda letra deja el cursor ahí (nada de "imán").
      final second = editable.localToGlobal(editable
          .getLocalRectForCaret(const TextPosition(offset: 2))
          .centerLeft);
      await tester.tapAt(Offset(second.dx, lineY));
      await tester.pump(const Duration(milliseconds: 500));
      expect(content(tester).selection.baseOffset, 2);
    });
  });

  group('posición en la nota', () {
    final date = DateTime(2026, 11, 23, 18, 0);
    final long = Note(
      fileName: '2026-11-23_18-00-00 Larga.txt',
      title: 'Larga',
      content: List.generate(120, (i) => 'Renglón número $i').join('\n'),
      createdAt: date,
      modifiedAt: date,
    );
    final jump = find.byKey(const ValueKey('scroll-jump-button'));

    Future<void> showLong(WidgetTester tester) async {
      await tester.pumpWidget(localizedApp(
        NoteEditorScreen(note: long, storage: FakeStorage(), settings: settings),
        locale: const Locale('es'),
      ));
      await tester.pumpAndSettle();
    }

    ScrollController scrollOf(WidgetTester tester) => tester
        .widget<TextField>(find.byType(TextField).last)
        .scrollController!;
    TextEditingController contentOf(WidgetTester tester) =>
        tester.widget<TextField>(find.byType(TextField).last).controller!;

    double opacityOf(WidgetTester tester) => tester
        .widget<AnimatedOpacity>(
            find.ancestor(of: jump, matching: find.byType(AnimatedOpacity)))
        .opacity;

    testWidgets('el botón ↑/↓ sale al desplazar, lleva a la orilla y se esconde',
        (tester) async {
      await showLong(tester);
      expect(opacityOf(tester), 0);
      // La barra de la derecha (como VS Code) está siempre en la nota.
      expect(find.byKey(const ValueKey('content-scrollbar')), findsOneWidget);

      await tester.drag(find.byType(TextField).last, const Offset(0, -300));
      await tester.pumpAndSettle();
      expect(opacityOf(tester), 1);
      // Arriba de la mitad: lleva al final.
      expect(find.byTooltip('Ir al final'), findsOneWidget);

      await tester.tap(find.byTooltip('Ir al final'));
      await tester.pumpAndSettle();
      final scroll = scrollOf(tester);
      expect(scroll.offset, scroll.position.maxScrollExtent);
      // Ahora está abajo: lleva al inicio.
      expect(find.byTooltip('Ir al inicio'), findsOneWidget);

      await tester.pump(const Duration(seconds: 3));
      await tester.pumpAndSettle();
      expect(opacityOf(tester), 0);
    });

    testWidgets('arrastrar la barra de la derecha recorre la nota',
        (tester) async {
      await showLong(tester);
      final field = tester.getRect(find.byType(TextField).last);
      // La barra está en la orilla derecha, arriba (la nota empieza arriba).
      final grab = Offset(field.right - 6, field.top + 20);
      await tester.dragFrom(grab, Offset(0, field.height / 2));
      await tester.pumpAndSettle();
      expect(scrollOf(tester).offset, greaterThan(300));
    });

    testWidgets('"Al final" abre la nota hasta abajo', (tester) async {
      await settings.setNoteOpenPosition(NoteOpenPosition.end);
      await showLong(tester);
      final scroll = scrollOf(tester);
      expect(scroll.offset, scroll.position.maxScrollExtent);
      expect(contentOf(tester).selection.baseOffset, long.content.length);
    });

    testWidgets('"Donde me quedé" regresa al mismo lugar', (tester) async {
      await showLong(tester);
      expect(scrollOf(tester).offset, 0);
      await tester.drag(find.byType(TextField).last, const Offset(0, -500));
      await tester.pumpAndSettle();
      contentOf(tester).selection =
          const TextSelection.collapsed(offset: 700);
      await tester.pump();
      final before = scrollOf(tester).offset;
      expect(before, greaterThan(0));

      // Salir de la nota (como al tocar regresar) y volver a abrirla.
      await tester
          .state<NoteEditorScreenState>(find.byType(NoteEditorScreen))
          .prepareToLeave();
      await tester.pumpWidget(const SizedBox());
      await showLong(tester);
      expect(contentOf(tester).selection.baseOffset, 700);
      // Arriba se ve el mismo renglón (puede variar unos píxeles).
      expect(scrollOf(tester).offset, closeTo(before, 30));
    });
  });

  group('zoom del texto', () {
    final date = DateTime(2026, 11, 23, 18, 0);
    final long = Note(
      fileName: '2026-11-23_18-00-00 Larga.txt',
      title: 'Larga',
      content: List.generate(120, (i) => 'Renglón número $i').join('\n'),
      createdAt: date,
      modifiedAt: date,
    );

    Future<void> showLong(WidgetTester tester) async {
      await tester.pumpWidget(localizedApp(
        NoteEditorScreen(note: long, storage: FakeStorage(), settings: settings),
        locale: const Locale('es'),
      ));
      await tester.pumpAndSettle();
    }

    final contentField = find.byType(TextField).last;
    double sizeOf(WidgetTester tester) =>
        tester.widget<TextField>(contentField).style!.fontSize!;
    double titleSizeOf(WidgetTester tester) =>
        tester.widget<TextField>(find.byType(TextField).first).style!.fontSize!;
    ScrollController scrollOf(WidgetTester tester) =>
        tester.widget<TextField>(contentField).scrollController!;
    double pillOpacity(WidgetTester tester) => tester
        .widget<AnimatedOpacity>(find.ancestor(
            of: find.byKey(const ValueKey('zoom-indicator')),
            matching: find.byType(AnimatedOpacity)))
        .opacity;

    Future<void> ctrl(WidgetTester tester, LogicalKeyboardKey key) async {
      await tester.sendKeyDownEvent(LogicalKeyboardKey.controlLeft);
      await tester.sendKeyEvent(key);
      await tester.sendKeyUpEvent(LogicalKeyboardKey.controlLeft);
      await tester.pump();
    }

    testWidgets('Ctrl + / Ctrl − / Ctrl + 0 cambian el tamaño y se recuerda',
        (tester) async {
      await showLong(tester);
      final normal = sizeOf(tester);
      final normalTitle = titleSizeOf(tester);
      await tester.tap(contentField);
      await tester.pump();

      await ctrl(tester, LogicalKeyboardKey.equal);
      await ctrl(tester, LogicalKeyboardKey.numpadAdd);
      expect(settings.textZoom, 1.2);
      expect(sizeOf(tester), closeTo(normal * 1.2, 0.01));
      // El título también crece.
      expect(titleSizeOf(tester), closeTo(normalTitle * 1.2, 0.01));
      // La píldora dice el tamaño y se va sola.
      expect(find.text('120%'), findsOneWidget);
      expect(pillOpacity(tester), 1);
      await tester.pump(const Duration(seconds: 2));
      await tester.pumpAndSettle();
      expect(pillOpacity(tester), 0);

      await ctrl(tester, LogicalKeyboardKey.minus);
      expect(settings.textZoom, 1.1);

      await ctrl(tester, LogicalKeyboardKey.digit0);
      expect(settings.textZoom, 1.0);
      expect(sizeOf(tester), closeTo(normal, 0.01));
      await tester.pump(const Duration(seconds: 2));
    });

    testWidgets('no pasa de los límites (70 % y 200 %)', (tester) async {
      await settings.setTextZoom(1.95);
      await showLong(tester);
      await tester.tap(contentField);
      await tester.pump();
      await ctrl(tester, LogicalKeyboardKey.equal);
      await ctrl(tester, LogicalKeyboardKey.equal);
      expect(settings.textZoom, AppSettings.maxTextZoom);
      await ctrl(tester, LogicalKeyboardKey.digit0);
      for (var i = 0; i < 6; i++) {
        await ctrl(tester, LogicalKeyboardKey.minus);
      }
      expect(settings.textZoom, AppSettings.minTextZoom);
      await tester.pump(const Duration(seconds: 2));
    });

    testWidgets('Ctrl + rueda hace zoom; la rueda sola desplaza',
        (tester) async {
      await showLong(tester);
      final center = tester.getCenter(contentField);
      final mouse = TestPointer(1, PointerDeviceKind.mouse)..hover(center);

      await tester.sendKeyDownEvent(LogicalKeyboardKey.controlLeft);
      await tester.sendEventToBinding(mouse.scroll(const Offset(0, -100)));
      await tester.sendKeyUpEvent(LogicalKeyboardKey.controlLeft);
      await tester.pumpAndSettle();
      expect(settings.textZoom, 1.1);
      expect(scrollOf(tester).offset, 0); // no se desplazó

      await tester.sendEventToBinding(mouse.scroll(const Offset(0, 200)));
      await tester.pumpAndSettle();
      expect(settings.textZoom, 1.1);
      expect(scrollOf(tester).offset, greaterThan(0));
    });

    testWidgets('pellizcar agranda el texto sin perder el renglón de arriba',
        (tester) async {
      await showLong(tester);
      await tester.drag(contentField, const Offset(0, -600));
      await tester.pumpAndSettle();
      final before = scrollOf(tester).offset;
      expect(before, greaterThan(300));

      final center = tester.getCenter(contentField);
      final a = await tester.startGesture(center - const Offset(0, 50),
          pointer: 11, kind: PointerDeviceKind.touch);
      final b = await tester.startGesture(center + const Offset(0, 50),
          pointer: 12, kind: PointerDeviceKind.touch);
      await tester.pump();
      for (var i = 0; i < 4; i++) {
        await a.moveBy(const Offset(0, -10));
        await b.moveBy(const Offset(0, 10));
        await tester.pump();
      }
      // De 100 a 180 px entre los dedos: 180 %.
      expect(find.text('180%'), findsOneWidget);
      expect(settings.textZoom, 1.0); // aún no se guarda
      await a.up();
      await b.up();
      await tester.pumpAndSettle();

      expect(settings.textZoom, 1.8);
      // El mismo renglón sigue arriba: todo creció 1.8 veces (el renglón
      // de arriba empieza un poco antes de donde estaba la orilla).
      expect(scrollOf(tester).offset,
          inInclusiveRange((before - 30) * 1.8, before * 1.8 + 15));
      await tester.pump(const Duration(seconds: 2));
    });
  });

  group('seleccionar más allá de lo que se ve', () {
    final date = DateTime(2026, 11, 23, 18, 0);
    final long = Note(
      fileName: '2026-11-23_18-00-00 Larga.txt',
      title: 'Larga',
      content: List.generate(120, (i) => 'Renglón número $i').join('\n'),
      createdAt: date,
      modifiedAt: date,
    );
    final contentField = find.byType(TextField).last;

    Future<void> showLong(WidgetTester tester) async {
      await tester.pumpWidget(localizedApp(
        NoteEditorScreen(note: long, storage: FakeStorage(), settings: settings),
        locale: const Locale('es'),
      ));
      await tester.pumpAndSettle();
    }

    ScrollController scrollOf(WidgetTester tester) =>
        tester.widget<TextField>(contentField).scrollController!;
    TextEditingController contentOf(WidgetTester tester) =>
        tester.widget<TextField>(contentField).controller!;

    test('la velocidad depende de qué tan cerca está el dedo de la orilla', () {
      const box = Rect.fromLTWH(0, 100, 400, 600); // de y=100 a y=700
      double speed(double y) =>
          NoteEditorScreenState.edgeScrollSpeed(y, box, 24);
      expect(speed(400), 0); // en medio: nada
      expect(speed(690), allOf(greaterThan(0), lessThan(700))); // abajo
      expect(speed(110), allOf(lessThan(0), greaterThan(-700))); // arriba
      expect(speed(695), greaterThan(speed(670))); // más cerca, más rápido
      expect(speed(760), greaterThan(700)); // pasándose de la orilla
      expect(speed(5000), 2400); // con tope
      expect(speed(0), lessThan(-700)); // arriba, pasándose
    });

    testWidgets('con el dedo quieto en la orilla, la nota baja sola y la '
        'selección lo sigue', (tester) async {
      await showLong(tester);
      final field = tester.getRect(contentField);
      final finger = await tester.startGesture(
          Offset(field.left + 40, field.top + 30));
      await tester.pump(const Duration(milliseconds: 700)); // mantener
      final start = contentOf(tester).selection;
      expect(start.isCollapsed, isFalse);

      // Hasta abajo, pasando un poco la orilla del texto, y quieto.
      await finger.moveTo(Offset(field.left + 60, field.bottom - 4));
      await tester.pump();
      for (var i = 0; i < 10; i++) {
        await tester.pump(const Duration(milliseconds: 50));
      }
      final scrolled = scrollOf(tester).offset;
      expect(scrolled, greaterThan(100));
      expect(contentOf(tester).selection.end, greaterThan(start.end + 100));

      // Al soltar, se detiene.
      await finger.up();
      await tester.pump();
      final stopped = scrollOf(tester).offset;
      await tester.pump(const Duration(milliseconds: 300));
      expect(scrollOf(tester).offset, stopped);
      await tester.pumpAndSettle();
    });

    testWidgets('desplazar la nota con el dedo no activa nada en la orilla',
        (tester) async {
      await showLong(tester);
      final field = tester.getRect(contentField);
      final before = contentOf(tester).selection;
      final finger = await tester.startGesture(field.center);
      await finger.moveTo(Offset(field.center.dx, field.bottom - 4));
      for (var i = 0; i < 10; i++) {
        await tester.pump(const Duration(milliseconds: 50));
      }
      // Ya estaba hasta arriba: arrastrar hacia abajo no la mueve, y la
      // orilla no la hace bajar sola.
      expect(scrollOf(tester).offset, 0);
      expect(contentOf(tester).selection, before);
      await finger.up();
      await tester.pumpAndSettle();
    });
  });

  group('enlaces', () {
    final date = DateTime(2026, 11, 23, 21, 0);
    final note = Note(
      fileName: '2026-11-23_21-00-00 Enlaces.txt',
      title: 'Enlaces',
      content: 'Visita https://example.com hoy\nCorreo: a@b.mx',
      createdAt: date,
      modifiedAt: date,
    );
    final contentField = find.byType(TextField).last;
    final chip = find.byKey(const ValueKey('link-chip'));
    late List<Uri> opened;

    setUp(() {
      opened = [];
      NoteEditorScreen.openUri = (uri) async {
        opened.add(uri);
        return true;
      };
    });

    Future<FindHighlightController> showLinks(WidgetTester tester) async {
      await tester.pumpWidget(localizedApp(
        NoteEditorScreen(note: note, storage: FakeStorage(), settings: settings),
        locale: const Locale('es'),
      ));
      await tester.pumpAndSettle();
      return tester.widget<TextField>(contentField).controller!
          as FindHighlightController;
    }

    testWidgets('los enlaces se ven subrayados', (tester) async {
      final controller = await showLinks(tester);
      final span = controller.buildTextSpan(
          context: tester.element(contentField), withComposing: false);
      final underlined = <String>[];
      span.visitChildren((child) {
        final s = child as TextSpan;
        if (s.style?.decoration == TextDecoration.underline) {
          underlined.add(s.text!);
        }
        return true;
      });
      expect(underlined, ['https://example.com', 'a@b.mx']);
    });

    testWidgets('el cursor sobre un enlace muestra "Abrir …"; tocarla lo abre',
        (tester) async {
      final controller = await showLinks(tester);
      await tester.tap(contentField);
      await tester.pump();
      controller.selection = const TextSelection.collapsed(offset: 12);
      await tester.pump();
      expect(chip, findsOneWidget);
      expect(find.text('Abrir example.com'), findsOneWidget);

      await tester.tap(chip);
      await tester.pumpAndSettle();
      expect(opened, [Uri.parse('https://example.com')]);
      expect(chip, findsNothing);
    });

    testWidgets('al escribir, la pastillita desaparece', (tester) async {
      final controller = await showLinks(tester);
      await tester.tap(contentField);
      await tester.pump();
      controller.selection = TextSelection.collapsed(
          offset: controller.text.length - 2); // en el correo
      await tester.pump();
      expect(find.text('Abrir a@b.mx'), findsOneWidget);
      await tester.enterText(contentField, '${controller.text} más');
      await tester.pump();
      expect(chip, findsNothing);
      // Fuera de un enlace no hay pastillita.
      controller.selection = const TextSelection.collapsed(offset: 2);
      await tester.pump();
      expect(chip, findsNothing);
    });

    testWidgets('PC: Ctrl + clic sobre el enlace lo abre', (tester) async {
      await showLinks(tester);
      final editable = tester
          .state<EditableTextState>(find.descendant(
              of: contentField, matching: find.byType(EditableText)))
          .renderEditable;
      final box = editable
          .getBoxesForSelection(
              const TextSelection(baseOffset: 9, extentOffset: 18))
          .first
          .toRect();
      final point = editable.localToGlobal(box.center);

      // Sin Ctrl, el clic solo pone el cursor.
      final mouse = await tester.createGesture(kind: PointerDeviceKind.mouse);
      await mouse.addPointer(location: point);
      addTearDown(mouse.removePointer);
      await mouse.down(point);
      await mouse.up();
      await tester.pumpAndSettle();
      expect(opened, isEmpty);

      await tester.sendKeyDownEvent(LogicalKeyboardKey.controlLeft);
      await mouse.down(point);
      await mouse.up();
      await tester.sendKeyUpEvent(LogicalKeyboardKey.controlLeft);
      await tester.pumpAndSettle();
      expect(opened, [Uri.parse('https://example.com')]);
    });
  });
}
