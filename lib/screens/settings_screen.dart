import 'dart:io';

import 'package:flutter/material.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:url_launcher/url_launcher.dart';

import '../services/app_settings.dart';

/// Pantalla de ajustes:
/// - Autoguardado (el mismo ajuste que está en el menú ⋮ del editor).
/// - Dónde están las notas (la ruta es fija; en Windows se puede abrir).
/// - Acerca de: versión, licencia, código fuente y licencias de terceros.
class SettingsScreen extends StatefulWidget {
  SettingsScreen({
    super.key,
    required this.settings,
    required this.notesFolder,
    bool? isWindows,
  }) : isWindows = isWindows ?? Platform.isWindows;

  final AppSettings settings;
  final Directory notesFolder;
  final bool isWindows;

  static final Uri repositoryUrl =
      Uri.parse('https://github.com/OwenOlanda/synced-notes');

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  late final Future<PackageInfo> _packageInfo = PackageInfo.fromPlatform();

  Future<void> _openNotesFolder() async {
    final messenger = ScaffoldMessenger.of(context);
    try {
      await widget.notesFolder.create(recursive: true);
      // explorer.exe a veces responde con código de error aunque sí abra
      // la carpeta, así que no se revisa su resultado.
      await Process.run('explorer.exe', [widget.notesFolder.path]);
    } catch (e) {
      messenger.showSnackBar(
          SnackBar(content: Text('No se pudo abrir la carpeta: $e')));
    }
  }

  Future<void> _openRepository() async {
    final messenger = ScaffoldMessenger.of(context);
    var opened = false;
    try {
      opened = await launchUrl(
        SettingsScreen.repositoryUrl,
        mode: LaunchMode.externalApplication,
      );
    } catch (_) {
      opened = false;
    }
    if (!opened) {
      messenger.showSnackBar(SnackBar(
        content: Text('No se pudo abrir el navegador. '
            'La dirección es ${SettingsScreen.repositoryUrl}'),
      ));
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Ajustes')),
      body: ListView(
        children: [
          const _SectionHeader('Guardado'),
          ListenableBuilder(
            listenable: widget.settings,
            builder: (context, _) => SwitchListTile(
              secondary: const Icon(Icons.save_outlined),
              title: const Text('Autoguardado'),
              subtitle: const Text(
                  'Guarda la nota automáticamente después de dejar de '
                  'escribir, al salir y al cerrar la app. El botón de '
                  'guardar siempre está disponible.'),
              value: widget.settings.autosave,
              onChanged: widget.settings.setAutosave,
            ),
          ),
          const Divider(),
          const _SectionHeader('Ubicación de las notas'),
          ListTile(
            leading: const Icon(Icons.folder_outlined),
            title: SelectableText(widget.notesFolder.path),
            subtitle: Text(widget.isWindows
                ? 'Cada nota es un archivo .txt dentro de esta carpeta.'
                : 'Las notas se guardan dentro de la app. Por ahora no se '
                    'ven desde el administrador de archivos del teléfono.'),
          ),
          if (widget.isWindows)
            Padding(
              padding: const EdgeInsets.fromLTRB(72, 0, 16, 8),
              child: Align(
                alignment: Alignment.centerLeft,
                child: OutlinedButton.icon(
                  icon: const Icon(Icons.open_in_new),
                  label: const Text('Abrir en el explorador'),
                  onPressed: _openNotesFolder,
                ),
              ),
            ),
          const Divider(),
          const _SectionHeader('Acerca de'),
          FutureBuilder<PackageInfo>(
            future: _packageInfo,
            builder: (context, snapshot) {
              final version = snapshot.hasData
                  ? 'Versión ${snapshot.data!.version}'
                  : snapshot.hasError
                      ? 'Versión desconocida'
                      : 'Versión…';
              return ListTile(
                leading: const Icon(Icons.info_outline),
                title: const Text('Synced Notes'),
                subtitle: Text(version),
              );
            },
          ),
          const ListTile(
            leading: Icon(Icons.gavel_outlined),
            title: Text('Licencia'),
            subtitle: Text('GPL-3.0: software libre y de código abierto.'),
          ),
          ListTile(
            leading: const Icon(Icons.code),
            title: const Text('Código fuente'),
            subtitle: const Text('github.com/OwenOlanda/synced-notes'),
            trailing: const Icon(Icons.open_in_new),
            onTap: _openRepository,
          ),
          ListTile(
            leading: const Icon(Icons.description_outlined),
            title: const Text('Licencias de terceros'),
            subtitle: const Text('Paquetes de código abierto que usa la app'),
            onTap: () => showLicensePage(
              context: context,
              applicationName: 'Synced Notes',
            ),
          ),
        ],
      ),
    );
  }
}

class _SectionHeader extends StatelessWidget {
  const _SectionHeader(this.text);
  final String text;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 4),
      child: Text(
        text,
        style: theme.textTheme.titleSmall
            ?.copyWith(color: theme.colorScheme.primary),
      ),
    );
  }
}
