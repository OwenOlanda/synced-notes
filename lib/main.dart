import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';

import 'l10n/l10n.dart';
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
    // Se reconstruye cuando cambian los ajustes, para que un cambio de
    // idioma se vea al instante, sin reiniciar la app.
    return ListenableBuilder(
      listenable: settings,
      builder: (context, _) => MaterialApp(
        title: 'Synced Notes',
        debugShowCheckedModeBanner: false,
        // Idioma: el elegido en Ajustes, o (null) el del sistema.
        locale: localeForLanguageCode(settings.languageCode),
        supportedLocales: AppLocalizations.supportedLocales,
        localizationsDelegates: const [
          AppLocalizations.delegate,
          // Textos propios de Flutter (copiar/pegar, "Atrás", etc.).
          GlobalMaterialLocalizations.delegate,
          GlobalWidgetsLocalizations.delegate,
          GlobalCupertinoLocalizations.delegate,
        ],
        // Si el sistema está en un idioma que la app no tiene: inglés.
        localeListResolutionCallback: resolveAppLocale,
        // Claro, oscuro o el del sistema (se elige en Ajustes).
        themeMode: settings.themeMode,
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
      ),
    );
  }
}
