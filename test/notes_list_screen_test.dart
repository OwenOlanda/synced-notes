import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:synced_notes/models/collection.dart';
import 'package:synced_notes/models/collection_filter.dart';
import 'package:synced_notes/models/note.dart';
import 'package:synced_notes/screens/notes_list_screen.dart';
import 'package:synced_notes/services/app_settings.dart';
import 'package:synced_notes/widgets/collection_colors.dart';

import 'helpers/fake_storage.dart';
import 'helpers/localized_app.dart';

Note _note({String title = '', String content = '', String? collection}) {
  final date = DateTime(2026, 10, 3, 20, 59, 12);
  return Note(
    fileName: '2026-10-03_20-59-12 $title.txt',
    collection: collection,
    title: title,
    content: content,
    createdAt: date,
    modifiedAt: date,
  );
}

/// El chip (no la etiqueta de una nota) con ese texto.
Finder chip(String label) => find.widgetWithText(ChoiceChip, label);

void main() {
  late AppSettings settings;

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    settings = await AppSettings.load();
  });

  Future<FakeStorage> showList(
    WidgetTester tester, {
    List<Note> notes = const [],
    List<Collection> collections = const [],
    Locale locale = const Locale('es'),
  }) async {
    final storage = FakeStorage(notes: notes, collections: collections);
    await tester.pumpWidget(localizedApp(
      NotesListScreen(storage: storage, settings: settings),
      locale: locale,
    ));
    await tester.pumpAndSettle();
    return storage;
  }

  testWidgets('sin notas: mensaje en el idioma de la app', (tester) async {
    await showList(tester);
    expect(find.text('Aún no tienes notas.\nToca + para crear una.'),
        findsOneWidget);

    await showList(tester, locale: const Locale('en'));
    expect(find.text("You don't have any notes yet.\nTap + to create one."),
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

  group('colecciones', () {
    final notes = [
      _note(title: 'Suelta'),
      _note(title: 'Tacos', collection: 'Recetas'),
      _note(title: 'Querida tía', collection: 'Cartas'),
    ];
    const collections = [
      Collection(name: 'Recetas', color: CollectionColor.orange),
      Collection(name: 'Cartas'),
    ];

    testWidgets('sin colecciones no aparece "Sin colección"', (tester) async {
      await showList(tester, notes: [_note(title: 'Suelta')]);
      expect(find.text('Todas'), findsOneWidget);
      expect(find.text('Sin colección'), findsNothing);
      expect(find.text('Nueva colección'), findsOneWidget);
    });

    testWidgets('los chips filtran las notas y la elección se recuerda',
        (tester) async {
      await showList(tester, notes: notes, collections: collections);
      expect(find.text('Suelta'), findsOneWidget);
      expect(find.text('Tacos'), findsOneWidget);
      expect(find.text('Querida tía'), findsOneWidget);

      await tester.tap(chip('Recetas'));
      await tester.pumpAndSettle();
      expect(find.text('Tacos'), findsOneWidget);
      expect(find.text('Suelta'), findsNothing);
      expect(find.text('Querida tía'), findsNothing);
      expect(settings.selectedCollection,
          const CollectionFilter.collection('Recetas'));

      await tester.tap(chip('Sin colección'));
      await tester.pumpAndSettle();
      expect(find.text('Suelta'), findsOneWidget);
      expect(find.text('Tacos'), findsNothing);
      expect(settings.selectedCollection, CollectionFilter.none);
    });

    testWidgets('al abrir, muestra la colección que se estaba viendo',
        (tester) async {
      await settings
          .setSelectedCollection(const CollectionFilter.collection('Cartas'));
      await showList(tester, notes: notes, collections: collections);
      expect(find.text('Querida tía'), findsOneWidget);
      expect(find.text('Tacos'), findsNothing);
    });

    testWidgets('si la colección recordada ya no existe, vuelve a "Todas"',
        (tester) async {
      await settings
          .setSelectedCollection(const CollectionFilter.collection('Borrada'));
      await showList(tester, notes: notes, collections: collections);
      expect(settings.selectedCollection, CollectionFilter.all);
      expect(find.text('Suelta'), findsOneWidget);
    });

    testWidgets('crear una colección desde el chip "+" y quedar dentro',
        (tester) async {
      final storage = await showList(tester, notes: notes);

      await tester.tap(find.text('Nueva colección'));
      await tester.pumpAndSettle();
      await tester.enterText(find.byType(TextField), 'Frases');
      await tester.tap(find.text('Crear'));
      await tester.pumpAndSettle();

      expect(storage.collections.map((c) => c.name), ['Frases']);
      expect(settings.selectedCollection,
          const CollectionFilter.collection('Frases'));
      expect(find.text('Aquí todavía no hay notas.\nToca + para crear una.'),
          findsOneWidget);
    });

    testWidgets('un carácter no permitido no se escribe y se avisa',
        (tester) async {
      await showList(tester);
      await tester.tap(find.text('Nueva colección'));
      await tester.pumpAndSettle();

      await tester.enterText(find.byType(TextField), 'a/b');
      await tester.pump();
      expect(tester.widget<TextField>(find.byType(TextField)).controller!.text,
          'ab');
      expect(find.textContaining('no puede contener'), findsOneWidget);

      // El aviso se quita solo.
      await tester.pump(const Duration(seconds: 4));
      expect(find.textContaining('no puede contener'), findsNothing);
    });

    testWidgets('un nombre repetido se avisa sin cerrar el diálogo',
        (tester) async {
      await showList(tester, collections: collections);
      await tester.tap(find.text('Nueva colección'));
      await tester.pumpAndSettle();

      await tester.enterText(find.byType(TextField), 'recetas');
      await tester.tap(find.text('Crear'));
      await tester.pumpAndSettle();
      expect(find.text('Ya existe una colección con ese nombre.'),
          findsOneWidget);
      expect(find.byType(AlertDialog), findsOneWidget);
    });

    testWidgets('borrar una colección con notas pregunta qué hacer con ellas',
        (tester) async {
      final storage =
          await showList(tester, notes: notes, collections: collections);

      await tester.longPress(chip('Recetas'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Borrar'));
      await tester.pumpAndSettle();

      expect(find.text('¿Borrar la colección "Recetas"?'), findsOneWidget);
      expect(find.text('Tiene 1 nota. ¿Qué quieres hacer con ella?'),
          findsOneWidget);

      await tester.tap(find.text('Pasar a "Sin colección"'));
      await tester.pumpAndSettle();
      expect(storage.collections.map((c) => c.name), ['Cartas']);
      expect(storage.notes.firstWhere((n) => n.title == 'Tacos').collection,
          isNull);
    });

    testWidgets('en "Todas" cada nota muestra su colección; dentro, no',
        (tester) async {
      await showList(tester, notes: notes, collections: collections);
      expect(find.byType(CollectionTag), findsNWidgets(2)); // Tacos y la carta

      await tester.tap(chip('Recetas'));
      await tester.pumpAndSettle();
      expect(find.byType(CollectionTag), findsNothing);
    });

    testWidgets('mover una nota desde su menú', (tester) async {
      final storage =
          await showList(tester, notes: notes, collections: collections);

      await tester.longPress(find.text('Suelta'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Mover a…'));
      await tester.pumpAndSettle();

      // En el diálogo, "Sin colección" es la actual (marcada).
      final dialog = find.byType(SimpleDialog);
      expect(find.descendant(of: dialog, matching: find.byIcon(Icons.check)),
          findsOneWidget);
      await tester.tap(
          find.descendant(of: dialog, matching: find.text('Recetas')));
      await tester.pumpAndSettle();

      expect(storage.notes.firstWhere((n) => n.title == 'Suelta').collection,
          'Recetas');
      expect(find.text('Nota movida a "Recetas"'), findsOneWidget);
    });

    testWidgets('mover a una colección nueva creada desde el diálogo',
        (tester) async {
      final storage =
          await showList(tester, notes: notes, collections: collections);

      await tester.longPress(find.text('Suelta'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Mover a…'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Nueva colección…'));
      await tester.pumpAndSettle();
      await tester.enterText(find.byType(TextField), 'Frases');
      await tester.tap(find.text('Crear'));
      await tester.pumpAndSettle();

      expect(storage.collections.map((c) => c.name), contains('Frases'));
      expect(storage.notes.firstWhere((n) => n.title == 'Suelta').collection,
          'Frases');
    });

    testWidgets('el botón + dice dónde se creará la nota', (tester) async {
      await showList(tester, notes: notes, collections: collections);
      expect(find.byTooltip('Nueva nota'), findsOneWidget);

      await tester.tap(chip('Recetas'));
      await tester.pumpAndSettle();
      expect(find.byTooltip('Nueva nota en "Recetas"'), findsOneWidget);
    });
  });
}
