import 'package:flutter/gestures.dart' show kSecondaryButton;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:synced_notes/models/group_filter.dart';
import 'package:synced_notes/models/note.dart';
import 'package:synced_notes/models/note_group.dart';
import 'package:synced_notes/screens/note_editor_screen.dart';
import 'package:synced_notes/screens/notes_list_screen.dart';
import 'package:synced_notes/services/app_settings.dart';
import 'package:synced_notes/widgets/group_panel.dart';
import 'package:synced_notes/widgets/group_sidebar.dart';
import 'package:synced_notes/widgets/note_row.dart';

import 'helpers/fake_storage.dart';
import 'helpers/localized_app.dart';

Note _note({String title = '', String content = '', String? group}) {
  final date = DateTime(2026, 10, 3, 20, 59, 12);
  return Note(
    fileName: '2026-10-03_20-59-12 $title.txt',
    group: group,
    title: title,
    content: content,
    createdAt: date,
    modifiedAt: date,
  );
}

/// Lo que esté dentro del panel de grupos de abajo.
Finder inPanel(Finder finder) =>
    find.descendant(of: find.byType(GroupPanel), matching: finder);

/// Un chip de la fila de grupos (panel cerrado).
Finder chipOf(String label) => find.widgetWithText(GroupChip, label);

/// Una fila de la lista completa de grupos (panel abierto).
Finder tileOf(String label) =>
    inPanel(find.widgetWithText(ListTile, label));

/// El fondo oscurecido: solo existe con el panel abierto.
final scrim = find.byKey(const ValueKey('group-panel-scrim'));

/// Etiquetas con el nombre del grupo en las filas de notas.
final groupLabels = find.byKey(const ValueKey('note-group-label'));

/// Barritas de color del grupo en las filas de notas.
final groupBars = find.byKey(const ValueKey('note-group-bar'));

void main() {
  late AppSettings settings;

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    settings = await AppSettings.load();
  });

  Future<FakeStorage> showList(
    WidgetTester tester, {
    List<Note> notes = const [],
    List<NoteGroup> groups = const [],
    Locale locale = const Locale('es'),
  }) async {
    final storage = FakeStorage(notes: notes, groups: groups);
    await tester.pumpWidget(localizedApp(
      NotesListScreen(storage: storage, settings: settings),
      locale: locale,
    ));
    await tester.pumpAndSettle();
    return storage;
  }

  /// Abre el panel con todos los grupos tocando "Grupos de notas".
  Future<void> openPanel(WidgetTester tester) async {
    await tester.tap(find.byTooltip('Ver todos los grupos'));
    await tester.pumpAndSettle();
  }

  /// Elige qué ver tocando un chip del panel de abajo.
  Future<void> choose(WidgetTester tester, String label) async {
    await tester.tap(chipOf(label));
    await tester.pumpAndSettle();
  }

  Finder dialogField() => find.descendant(
      of: find.byType(AlertDialog), matching: find.byType(TextField));

  testWidgets('sin notas: mensaje en el idioma de la app', (tester) async {
    await showList(tester);
    expect(find.text('Aún no tienes notas.\nToca "Nueva nota" para crear una.'),
        findsOneWidget);

    await showList(tester, locale: const Locale('en'));
    expect(
        find.text("You don't have any notes yet.\n"
            'Tap "New note" to create one.'),
        findsOneWidget);
  });

  testWidgets('nota sin título y nota sin texto', (tester) async {
    final notes = [
      _note(content: 'Leche y pan'),
      _note(title: 'Ideas'),
    ];

    await showList(tester, notes: notes);
    expect(find.text('Sin título'), findsOneWidget);
    expect(find.text('Sin texto'), findsOneWidget);

    await showList(tester, notes: notes, locale: const Locale('en'));
    expect(find.text('Untitled'), findsOneWidget);
    expect(find.text('No text'), findsOneWidget);
  });

  testWidgets('el diálogo de borrar sale en el idioma de la app',
      (tester) async {
    await showList(tester,
        notes: [_note(content: 'Leche y pan')], locale: const Locale('en'));

    await tester.longPress(find.text('Untitled'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Delete'));
    await tester.pumpAndSettle();

    expect(find.text('Delete note?'), findsOneWidget);
    expect(
        find.text('"Untitled" will be deleted from the notes folder. '
            "This can't be undone."),
        findsOneWidget);

    await tester.tap(find.text('Cancel'));
    await tester.pumpAndSettle();
    expect(find.text('Delete note?'), findsNothing);
  });

  group('grupos', () {
    final notes = [
      _note(title: 'Suelta'),
      _note(title: 'Tacos', group: 'Recetas'),
      _note(title: 'Querida tía', group: 'Cartas'),
    ];
    const groups = [
      NoteGroup(name: 'Recetas', color: GroupColor.orange),
      NoteGroup(name: 'Cartas'),
    ];

    testWidgets('arriba: nombre de la app, qué se ve y cuántas notas',
        (tester) async {
      await showList(tester, notes: notes, groups: groups);
      expect(find.text('Synced Notes'), findsOneWidget);
      expect(find.text('Todas · 3 notas'), findsOneWidget);

      await choose(tester, 'Recetas');
      expect(find.text('Recetas · 1 nota'), findsOneWidget);

      await showList(tester,
          notes: notes, groups: groups, locale: const Locale('en'));
      expect(find.text('Recetas · 1 note'), findsOneWidget);
    });

    testWidgets('el panel tiene un chip por grupo; "Sin grupo" solo si hay',
        (tester) async {
      await showList(tester, notes: notes, groups: groups);
      expect(find.text('Grupos de notas'), findsOneWidget);
      for (final label in ['Todas', 'Sin grupo', 'Recetas', 'Cartas']) {
        expect(chipOf(label), findsOneWidget, reason: label);
      }

      await showList(tester, notes: [_note(title: 'Suelta')]);
      expect(chipOf('Todas'), findsOneWidget);
      expect(chipOf('Sin grupo'), findsNothing);
    });

    testWidgets('tocar un chip filtra las notas y se recuerda',
        (tester) async {
      await showList(tester, notes: notes, groups: groups);

      await choose(tester, 'Recetas');
      expect(find.text('Tacos'), findsOneWidget);
      expect(find.text('Suelta'), findsNothing);
      expect(find.text('Querida tía'), findsNothing);
      expect(settings.selectedGroup, const GroupFilter.group('Recetas'));
      expect(
          tester
              .widget<GroupChip>(find.widgetWithText(GroupChip, 'Recetas'))
              .selected,
          isTrue);

      await choose(tester, 'Sin grupo');
      expect(find.text('Suelta'), findsOneWidget);
      expect(find.text('Tacos'), findsNothing);
      expect(settings.selectedGroup, GroupFilter.none);
    });

    testWidgets('elegir un chip no mueve el panel (el asa sigue a la vista)',
        (tester) async {
      await showList(tester, notes: notes, groups: groups);
      final before = tester.getTopLeft(find.text('Grupos de notas'));

      await choose(tester, 'Cartas');
      await choose(tester, 'Recetas');
      expect(tester.getTopLeft(find.text('Grupos de notas')), before);
    });

    testWidgets('deslizar el panel hacia arriba lo abre; elegir lo cierra',
        (tester) async {
      await showList(tester, notes: notes, groups: groups);
      expect(scrim, findsNothing);

      await tester.fling(
          find.text('Grupos de notas'), const Offset(0, -200), 1000);
      await tester.pumpAndSettle();
      expect(scrim, findsOneWidget);

      // Elegir desde la lista completa cierra el panel.
      await tester.tap(tileOf('Cartas'));
      await tester.pumpAndSettle();
      expect(scrim, findsNothing);
      expect(settings.selectedGroup, const GroupFilter.group('Cartas'));
    });

    testWidgets('el asa se puede tocar a todo lo ancho, no solo el texto',
        (tester) async {
      await showList(tester, notes: notes, groups: groups);
      final label = tester.getCenter(find.text('Grupos de notas'));

      await tester.tapAt(Offset(12, label.dy));
      await tester.pumpAndSettle();
      expect(scrim, findsOneWidget);
    });

    testWidgets('tocar fuera del panel abierto lo cierra', (tester) async {
      await showList(tester, notes: notes, groups: groups);
      await openPanel(tester);
      expect(scrim, findsOneWidget);

      await tester.tapAt(tester.getTopLeft(scrim) + const Offset(20, 20));
      await tester.pumpAndSettle();
      expect(scrim, findsNothing);
    });

    testWidgets('el chip elegido se sombrea con el color de su grupo y no cambia de ancho',
        (tester) async {
      await showList(tester, notes: notes, groups: groups);
      final width = tester.getSize(chipOf('Recetas')).width;
      await choose(tester, 'Recetas');

      // Elegirlo no lo hace más ancho (no empuja a los chips de al lado).
      expect(tester.getSize(chipOf('Recetas')).width, width);
      final chip = tester.widget<GroupChip>(chipOf('Recetas'));
      expect(chip.selected, isTrue);
      final box = tester.widget<AnimatedContainer>(find.descendant(
          of: chipOf('Recetas'), matching: find.byType(AnimatedContainer)));
      final fill = (box.decoration! as ShapeDecoration).color!;
      // Relleno tenue (transparente) del mismo color del texto, no blanco.
      expect(fill.a, lessThan(0.3));
      expect(fill.withValues(alpha: 1), chip.color.withValues(alpha: 1));
    });

    testWidgets('la hoja marca lo que se ve y cuenta las notas',
        (tester) async {
      await showList(tester, notes: notes, groups: groups);
      await openPanel(tester);

      ListTile tile(String label) => tester.widget<ListTile>(tileOf(label));
      expect(tile('Todas').selected, isTrue);
      expect(tile('Recetas').selected, isFalse);
      expect(find.descendant(of: tileOf('Todas'), matching: find.text('3')),
          findsOneWidget);
    });

    testWidgets('buscar en la hoja filtra los grupos', (tester) async {
      await showList(tester, notes: notes, groups: groups);
      await openPanel(tester);

      await tester.enterText(inPanel(find.byType(TextField)), 'rec');
      await tester.pump();
      expect(tileOf('Recetas'), findsOneWidget);
      expect(tileOf('Cartas'), findsNothing);

      await tester.enterText(inPanel(find.byType(TextField)), 'xyz');
      await tester.pump();
      expect(find.text('Ningún grupo con ese nombre'), findsOneWidget);
    });

    testWidgets('al abrir, muestra el grupo que se estaba viendo',
        (tester) async {
      await settings.setSelectedGroup(const GroupFilter.group('Cartas'));
      await showList(tester, notes: notes, groups: groups);
      expect(find.text('Querida tía'), findsOneWidget);
      expect(find.text('Tacos'), findsNothing);
    });

    testWidgets('si el grupo recordado ya no existe, vuelve a "Todas"',
        (tester) async {
      await settings.setSelectedGroup(const GroupFilter.group('Borrado'));
      await showList(tester, notes: notes, groups: groups);
      expect(settings.selectedGroup, GroupFilter.all);
      expect(find.text('Suelta'), findsOneWidget);
    });

    testWidgets('barrita y nombre del grupo solo en Todas',
        (tester) async {
      await showList(tester, notes: notes, groups: groups);
      expect(groupBars, findsNWidgets(2)); // Tacos y la carta
      expect(groupLabels, findsNWidgets(2));

      await choose(tester, 'Recetas');
      expect(groupBars, findsNothing);
      expect(groupLabels, findsNothing);

      await choose(tester, 'Sin grupo');
      expect(groupBars, findsNothing);
    });

    testWidgets('crear un grupo con el botón del panel y quedar dentro',
        (tester) async {
      final storage = await showList(tester, notes: notes);

      await tester.tap(inPanel(find.byTooltip('Nuevo grupo')));
      await tester.pumpAndSettle();
      await tester.enterText(dialogField(), 'Frases');
      await tester.tap(find.text('Crear'));
      await tester.pumpAndSettle();

      expect(storage.groups.map((c) => c.name), ['Frases']);
      expect(settings.selectedGroup, const GroupFilter.group('Frases'));
      expect(
          find.text(
              'Aquí todavía no hay notas.\nToca "Nueva nota" para crear una.'),
          findsOneWidget);
    });

    testWidgets('un carácter no permitido no se escribe y se avisa',
        (tester) async {
      await showList(tester);
      await tester.tap(inPanel(find.byTooltip('Nuevo grupo')));
      await tester.pumpAndSettle();

      await tester.enterText(dialogField(), 'a/b');
      await tester.pump();
      expect(tester.widget<TextField>(dialogField()).controller!.text, 'ab');
      expect(find.textContaining('no puede contener'), findsOneWidget);

      // El aviso se quita solo.
      await tester.pump(const Duration(seconds: 4));
      expect(find.textContaining('no puede contener'), findsNothing);
    });

    testWidgets('un nombre repetido se avisa sin cerrar el diálogo',
        (tester) async {
      await showList(tester, groups: groups);
      await tester.tap(inPanel(find.byTooltip('Nuevo grupo')));
      await tester.pumpAndSettle();

      await tester.enterText(dialogField(), 'recetas');
      await tester.tap(find.text('Crear'));
      await tester.pumpAndSettle();
      expect(find.text('Ya existe un grupo con ese nombre.'), findsOneWidget);
      expect(find.byType(AlertDialog), findsOneWidget);
    });

    testWidgets('borrar un grupo desde su menú ⋮ en el panel', (tester) async {
      final storage = await showList(tester, notes: notes, groups: groups);
      await openPanel(tester);

      await tester.tap(find.descendant(
          of: tileOf('Recetas'), matching: find.byTooltip('Opciones del grupo')));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Borrar'));
      await tester.pumpAndSettle();

      expect(find.text('¿Borrar el grupo "Recetas"?'), findsOneWidget);
      expect(find.text('Tiene 1 nota. ¿Qué quieres hacer con ella?'),
          findsOneWidget);

      await tester.tap(find.text('Pasar a "Sin grupo"'));
      await tester.pumpAndSettle();
      expect(storage.groups.map((c) => c.name), ['Cartas']);
      expect(storage.notes.firstWhere((n) => n.title == 'Tacos').group, isNull);
      // El panel sigue abierto para seguir organizando.
      expect(scrim, findsOneWidget);
      expect(tileOf('Recetas'), findsNothing);
    });

    testWidgets('renombrar un grupo manteniendo presionado su chip',
        (tester) async {
      final storage = await showList(tester, notes: notes, groups: groups);

      await tester.longPress(chipOf('Cartas'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Renombrar'));
      await tester.pumpAndSettle();
      await tester.enterText(dialogField(), 'Correo');
      await tester.tap(find.text('Renombrar').last);
      await tester.pumpAndSettle();

      expect(storage.groups.map((c) => c.name), contains('Correo'));
      expect(chipOf('Correo'), findsOneWidget);
      expect(chipOf('Cartas'), findsNothing);
    });

    testWidgets('mover una nota desde su menú', (tester) async {
      final storage = await showList(tester, notes: notes, groups: groups);

      await tester.longPress(find.text('Suelta'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Mover a…'));
      await tester.pumpAndSettle();

      // En el diálogo, "Sin grupo" es la actual (marcada).
      final dialog = find.byType(SimpleDialog);
      expect(find.descendant(of: dialog, matching: find.byIcon(Icons.check)),
          findsOneWidget);
      await tester
          .tap(find.descendant(of: dialog, matching: find.text('Recetas')));
      await tester.pumpAndSettle();

      expect(storage.notes.firstWhere((n) => n.title == 'Suelta').group,
          'Recetas');
      expect(find.text('Nota movida a "Recetas"'), findsOneWidget);
    });

    testWidgets('mover a un grupo nuevo creado desde el diálogo',
        (tester) async {
      final storage = await showList(tester, notes: notes, groups: groups);

      await tester.longPress(find.text('Suelta'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Mover a…'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Nuevo grupo…'));
      await tester.pumpAndSettle();
      await tester.enterText(dialogField(), 'Frases');
      await tester.tap(find.text('Crear'));
      await tester.pumpAndSettle();

      expect(storage.groups.map((c) => c.name), contains('Frases'));
      expect(storage.notes.firstWhere((n) => n.title == 'Suelta').group,
          'Frases');
    });

    testWidgets('el botón "Nueva nota" dice dónde se creará la nota',
        (tester) async {
      await showList(tester, notes: notes, groups: groups);
      expect(find.byTooltip('Nueva nota'), findsOneWidget);
      expect(find.widgetWithText(FloatingActionButton, 'Nueva nota'),
          findsOneWidget);

      await choose(tester, 'Recetas');
      expect(find.byTooltip('Nueva nota en "Recetas"'), findsOneWidget);
    });
  });

  group('vista de PC (ventana ancha)', () {
    final notes = [
      _note(title: 'Suelta'),
      _note(title: 'Tacos', group: 'Recetas'),
      _note(title: 'Querida tía', group: 'Cartas'),
    ];
    const groups = [
      NoteGroup(name: 'Recetas', color: GroupColor.orange),
      NoteGroup(name: 'Cartas'),
    ];

    /// Simula una ventana de PC de 1280×800.
    void useWideWindow(WidgetTester tester) {
      tester.view.physicalSize = const Size(1280, 800);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);
    }

    Finder inSidebar(Finder finder) =>
        find.descendant(of: find.byType(GroupSidebar), matching: finder);

    testWidgets('barra lateral con los grupos y sus notas; sin panel abajo',
        (tester) async {
      useWideWindow(tester);
      await showList(tester, notes: notes, groups: groups);

      expect(find.byType(GroupSidebar), findsOneWidget);
      expect(find.byType(GroupPanel), findsNothing);
      for (final label in ['Todas', 'Sin grupo', 'Recetas', 'Cartas']) {
        expect(inSidebar(find.text(label)), findsOneWidget, reason: label);
      }
      expect(
          find.descendant(
              of: inSidebar(find.widgetWithText(ListTile, 'Todas')),
              matching: find.text('3')),
          findsOneWidget);
      expect(find.byKey(const ValueKey('wide-view-title')), findsOneWidget);
    });

    testWidgets('elegir un grupo en la barra lateral filtra la lista',
        (tester) async {
      useWideWindow(tester);
      await showList(tester, notes: notes, groups: groups);

      await tester.tap(inSidebar(find.text('Recetas')));
      await tester.pumpAndSettle();
      expect(find.text('Tacos'), findsOneWidget);
      expect(find.text('Suelta'), findsNothing);
      expect(settings.selectedGroup, const GroupFilter.group('Recetas'));
      expect(
          tester
              .widget<Text>(find.byKey(const ValueKey('wide-view-title')))
              .data,
          'Recetas');
      expect(find.byTooltip('Nueva nota en "Recetas" (Ctrl+N)'), findsOneWidget);
    });

    testWidgets('crear un grupo desde la barra lateral', (tester) async {
      useWideWindow(tester);
      final storage = await showList(tester, notes: notes, groups: groups);

      await tester.tap(inSidebar(find.byTooltip('Nuevo grupo (Ctrl+Shift+N)')));
      await tester.pumpAndSettle();
      await tester.enterText(
          find.descendant(
              of: find.byType(AlertDialog), matching: find.byType(TextField)),
          'Frases');
      await tester.tap(find.text('Crear'));
      await tester.pumpAndSettle();

      expect(storage.groups.map((g) => g.name), contains('Frases'));
      expect(inSidebar(find.text('Frases')), findsOneWidget);
      expect(settings.selectedGroup, const GroupFilter.group('Frases'));
    });

    testWidgets('clic derecho en un grupo: borrar', (tester) async {
      useWideWindow(tester);
      final storage = await showList(tester, notes: notes, groups: groups);

      await tester.tap(inSidebar(find.text('Cartas')),
          buttons: kSecondaryButton);
      await tester.pumpAndSettle();
      await tester.tap(find.text('Borrar'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Pasar a "Sin grupo"'));
      await tester.pumpAndSettle();

      expect(storage.groups.map((g) => g.name), ['Recetas']);
      expect(inSidebar(find.text('Cartas')), findsNothing);
    });

    /// Los campos del editor de la columna derecha: título y texto.
    Finder editorField(int index) => find
        .descendant(
            of: find.byType(NoteEditorScreen),
            matching: find.byType(TextField))
        .at(index);

    testWidgets('sin nota abierta, la columna del editor lo dice',
        (tester) async {
      useWideWindow(tester);
      await showList(tester, notes: notes, groups: groups);
      expect(find.byKey(const ValueKey('no-note-open')), findsOneWidget);
      expect(find.byType(NoteEditorScreen), findsNothing);
    });

    testWidgets('tocar una nota la abre a la derecha, junto a la lista',
        (tester) async {
      useWideWindow(tester);
      await showList(tester, notes: notes, groups: groups);

      await tester.tap(find.text('Tacos'));
      await tester.pumpAndSettle();
      expect(find.byType(NoteEditorScreen), findsOneWidget);
      expect(find.byType(GroupSidebar), findsOneWidget); // no cambió de pantalla
      expect(
          tester.widget<TextField>(editorField(0)).controller!.text, 'Tacos');
      // La fila de la nota abierta queda resaltada.
      expect(
          tester
              .widget<NoteRow>(find.widgetWithText(NoteRow, 'Tacos'))
              .selected,
          isTrue);
    });

    testWidgets('al abrir otra nota, la anterior se guarda primero',
        (tester) async {
      useWideWindow(tester);
      final storage = await showList(tester, notes: notes, groups: groups);

      await tester.tap(find.text('Tacos'));
      await tester.pumpAndSettle();
      await tester.enterText(editorField(1), 'con salsa');
      await tester.pump();

      await tester.tap(find.text('Suelta'));
      await tester.pumpAndSettle();
      expect(storage.notes.firstWhere((n) => n.title == 'Tacos').content,
          'con salsa');
      expect(
          tester.widget<TextField>(editorField(0)).controller!.text, 'Suelta');
    });

    testWidgets('"Nueva nota" abre una nota en blanco a la derecha',
        (tester) async {
      useWideWindow(tester);
      final storage = await showList(tester, notes: notes, groups: groups);

      await tester.tap(find.byTooltip('Nueva nota (Ctrl+N)'));
      await tester.pumpAndSettle();
      expect(find.byType(NoteEditorScreen), findsOneWidget);
      await tester.enterText(editorField(0), 'Idea');

      // Cerrar con la X guarda la nota nueva y la lista la muestra.
      await tester.tap(find.byTooltip('Cerrar nota (Esc)'));
      await tester.pumpAndSettle();
      expect(find.byType(NoteEditorScreen), findsNothing);
      expect(storage.notes.map((n) => n.title), contains('Idea'));
      expect(find.widgetWithText(NoteRow, 'Idea'), findsOneWidget);
    });

    testWidgets('el botón grande de la columna vacía crea una nota',
        (tester) async {
      useWideWindow(tester);
      await showList(tester, notes: notes, groups: groups);
      await tester.tap(inSidebar(find.text('Recetas')));
      await tester.pumpAndSettle();

      final big = find.byKey(const ValueKey('pane-new-note'));
      expect(find.descendant(of: big, matching: find.text('Nueva nota en')),
          findsOneWidget);
      expect(find.descendant(of: big, matching: find.text('Recetas')),
          findsOneWidget);
      await tester.tap(big);
      await tester.pumpAndSettle();
      expect(find.byType(NoteEditorScreen), findsOneWidget);
      expect(big, findsNothing);
    });

    testWidgets('con una nota abierta, al hacer angosta la ventana no se pierde',
        (tester) async {
      useWideWindow(tester);
      await showList(tester, notes: notes, groups: groups);
      await tester.tap(find.text('Tacos'));
      await tester.pumpAndSettle();
      await tester.enterText(editorField(1), 'sin guardar todavía');
      await tester.pump();

      tester.view.physicalSize = const Size(600, 800);
      await tester.pumpAndSettle();
      expect(find.byType(GroupSidebar), findsNothing);
      expect(tester.widget<TextField>(editorField(1)).controller!.text,
          'sin guardar todavía');
    });

    Future<void> ctrl(WidgetTester tester, LogicalKeyboardKey key,
        {bool shift = false}) async {
      await tester.sendKeyDownEvent(LogicalKeyboardKey.controlLeft);
      if (shift) await tester.sendKeyDownEvent(LogicalKeyboardKey.shiftLeft);
      await tester.sendKeyEvent(key);
      if (shift) await tester.sendKeyUpEvent(LogicalKeyboardKey.shiftLeft);
      await tester.sendKeyUpEvent(LogicalKeyboardKey.controlLeft);
      await tester.pumpAndSettle();
    }

    testWidgets('Ctrl+N abre una nota nueva y Esc la cierra', (tester) async {
      useWideWindow(tester);
      await showList(tester, notes: notes, groups: groups);

      await ctrl(tester, LogicalKeyboardKey.keyN);
      expect(find.byType(NoteEditorScreen), findsOneWidget);

      await tester.sendKeyEvent(LogicalKeyboardKey.escape);
      await tester.pumpAndSettle();
      expect(find.byType(NoteEditorScreen), findsNothing);

      // Después de cerrarla, los atajos siguen funcionando.
      await ctrl(tester, LogicalKeyboardKey.keyN);
      expect(find.byType(NoteEditorScreen), findsOneWidget);
    });

    testWidgets('Esc también cierra una nota abierta con el mouse',
        (tester) async {
      useWideWindow(tester);
      await showList(tester, notes: notes, groups: groups);
      await tester.tap(find.text('Tacos'));
      await tester.pumpAndSettle();

      await tester.sendKeyEvent(LogicalKeyboardKey.escape);
      await tester.pumpAndSettle();
      expect(find.byType(NoteEditorScreen), findsNothing);
    });

    testWidgets('Ctrl+Shift+N pide el nombre de un grupo nuevo',
        (tester) async {
      useWideWindow(tester);
      await showList(tester, notes: notes, groups: groups);

      await ctrl(tester, LogicalKeyboardKey.keyN, shift: true);
      expect(find.byType(AlertDialog), findsOneWidget);
      expect(find.text('Crear'), findsOneWidget);
    });

    /// ¿El foco del teclado está en (o dentro de) este widget?
    bool hasFocus(WidgetTester tester, Finder finder) =>
        Focus.of(tester.element(finder)).hasFocus;

    testWidgets('Tab en el título pasa al texto de la nota', (tester) async {
      useWideWindow(tester);
      await showList(tester, notes: notes, groups: groups);
      await tester.tap(find.text('Tacos'));
      await tester.pumpAndSettle();

      await tester.tap(editorField(0)); // escribir en el título
      await tester.pump();
      await tester.sendKeyEvent(LogicalKeyboardKey.tab);
      await tester.pump();

      final content = tester.widget<TextField>(editorField(1));
      expect(content.focusNode!.hasFocus, isTrue);
    });

    testWidgets('las flechas mueven el foco entre las notas; Enter abre',
        (tester) async {
      useWideWindow(tester);
      await showList(tester, notes: notes, groups: groups);

      // Foco del teclado en la primera nota de la lista.
      Focus.of(tester.element(find.text('Suelta'))).requestFocus();
      await tester.pump();
      expect(hasFocus(tester, find.text('Suelta')), isTrue);

      await tester.sendKeyEvent(LogicalKeyboardKey.arrowDown);
      await tester.pumpAndSettle();
      expect(hasFocus(tester, find.text('Tacos')), isTrue);
      expect(hasFocus(tester, find.text('Suelta')), isFalse);

      await tester.sendKeyEvent(LogicalKeyboardKey.enter);
      await tester.pumpAndSettle();
      expect(find.byType(NoteEditorScreen), findsOneWidget);
      expect(
          tester.widget<TextField>(editorField(0)).controller!.text, 'Tacos');
    });

    testWidgets('si la ventana se hace angosta, vuelve la vista de celular',
        (tester) async {
      useWideWindow(tester);
      await showList(tester, notes: notes, groups: groups);
      expect(find.byType(GroupSidebar), findsOneWidget);

      tester.view.physicalSize = const Size(600, 800);
      await tester.pumpAndSettle();
      expect(find.byType(GroupSidebar), findsNothing);
      expect(find.byType(GroupPanel), findsOneWidget);
    });
  });
}
