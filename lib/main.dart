import 'package:flutter/material.dart';

import 'screens/notes_list_screen.dart';
import 'services/app_settings.dart';
import 'services/note_storage.dart';
import 'services/notes_folder.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Antes de mostrar la app: qué carpeta usar y cuáles son los ajustes.
  final folder = await NotesFolder().resolve();
  final settings = await AppSettings.load();

  runApp(SyncedNotesApp(storage: NoteStorage(folder), settings: settings));
}

class SyncedNotesApp extends StatelessWidget {
  const SyncedNotesApp({super.key, required this.storage, required this.settings});

  final NoteStorage storage;
  final AppSettings settings;

  @override
  Widget build(BuildContext context) {
    const seed = Colors.teal;
    return MaterialApp(
      title: 'Synced Notes',
      debugShowCheckedModeBanner: false,
      // Sigue el tema claro/oscuro del sistema.
      themeMode: ThemeMode.system,
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: seed),
        useMaterial3: true,
      ),
      darkTheme: ThemeData(
        colorScheme: ColorScheme.fromSeed(
            seedColor: seed, brightness: Brightness.dark),
        useMaterial3: true,
      ),
      home: NotesListScreen(storage: storage, settings: settings),
    );
  }
}
