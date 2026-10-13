import 'dart:io';

import 'package:flutter/material.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:url_launcher/url_launcher.dart';

import '../l10n/l10n.dart';
import '../services/app_settings.dart';
import '../widgets/app_message.dart';

/// Pantalla de ajustes:
/// - Idioma (el del sistema, o uno elegido a mano).
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

  /// Valor que devuelve el selector para "idioma del sistema".
  /// (null no sirve: es lo que devuelve el diálogo si se cancela.)
  static const String _systemLanguage = 'system';

  Future<void> _chooseLanguage() async {
    final l10n = context.l10n;
    final current = widget.settings.languageCode ?? _systemLanguage;

    Widget option(String value, String label) => ListTile(
          title: Text(label),
          trailing: value == current ? const Icon(Icons.check) : null,
          onTap: () => Navigator.of(context).pop(value),
        );

    final choice = await showDialog<String>(
      context: context,
      builder: (context) => SimpleDialog(
        title: Text(l10n.languageTitle),
        children: [
          option(_systemLanguage, l10n.languageSystem),
          // Un renglón por cada idioma que tenga su archivo .arb.
          for (final locale in AppLocalizations.supportedLocales)
            option(locale.languageCode, languageNameOf(locale)),
        ],
      ),
    );
    if (choice == null) return; // cerró el diálogo sin elegir
    await widget.settings
        .setLanguageCode(choice == _systemLanguage ? null : choice);
  }

  Future<void> _chooseTheme() async {
    final l10n = context.l10n;
    final current = widget.settings.themeMode;

    Widget option(ThemeMode value, String label, IconData icon) => ListTile(
          leading: Icon(icon),
          title: Text(label),
          trailing: value == current ? const Icon(Icons.check) : null,
          onTap: () => Navigator.of(context).pop(value),
        );

    final choice = await showDialog<ThemeMode>(
      context: context,
      builder: (context) => SimpleDialog(
        title: Text(l10n.themeTitle),
        children: [
          option(ThemeMode.system, l10n.themeSystem,
              Icons.brightness_auto_outlined),
          option(ThemeMode.light, l10n.themeLight, Icons.light_mode_outlined),
          option(ThemeMode.dark, l10n.themeDark, Icons.dark_mode_outlined),
        ],
      ),
    );
    if (choice != null) await widget.settings.setThemeMode(choice);
  }

  /// Texto del tema actual, ej. "Del sistema (Oscuro)" o "Claro".
  String _currentThemeLabel(AppLocalizations l10n) {
    switch (widget.settings.themeMode) {
      case ThemeMode.light:
        return l10n.themeLight;
      case ThemeMode.dark:
        return l10n.themeDark;
      case ThemeMode.system:
        final dark =
            MediaQuery.platformBrightnessOf(context) == Brightness.dark;
        return l10n
            .themeSystemWithCurrent(dark ? l10n.themeDark : l10n.themeLight);
    }
  }

  /// Texto del idioma actual, ej. "Idioma del sistema (English)" o "Español".
  String _currentLanguageLabel(AppLocalizations l10n) {
    final chosen = localeForLanguageCode(widget.settings.languageCode);
    if (chosen != null) return languageNameOf(chosen);
    return l10n.languageSystemWithCurrent(l10n.languageName);
  }

  Future<void> _openNotesFolder() async {
    final messenger = ScaffoldMessenger.of(context);
    final l10n = context.l10n;
    try {
      await widget.notesFolder.create(recursive: true);
      // explorer.exe a veces responde con código de error aunque sí abra
      // la carpeta, así que no se revisa su resultado.
      await Process.run('explorer.exe', [widget.notesFolder.path]);
    } catch (e) {
      messenger.showMessage(l10n.openFolderError('$e'), isError: true);
    }
  }

  Future<void> _openRepository() async {
    final messenger = ScaffoldMessenger.of(context);
    final l10n = context.l10n;
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
      messenger.showMessage(
          l10n.browserOpenError(SettingsScreen.repositoryUrl.toString()),
          isError: true);
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    return Scaffold(
      appBar: AppBar(title: Text(l10n.settingsTitle)),
      body: ListView(
        children: [
          _SectionHeader(l10n.settingsSectionGeneral),
          ListenableBuilder(
            listenable: widget.settings,
            builder: (context, _) => ListTile(
              leading: const Icon(Icons.translate),
              title: Text(l10n.languageTitle),
              subtitle: Text(_currentLanguageLabel(l10n)),
              onTap: _chooseLanguage,
            ),
          ),
          ListenableBuilder(
            listenable: widget.settings,
            builder: (context, _) => ListTile(
              leading: const Icon(Icons.brightness_6_outlined),
              title: Text(l10n.themeTitle),
              subtitle: Text(_currentThemeLabel(l10n)),
              onTap: _chooseTheme,
            ),
          ),
          const Divider(),
          _SectionHeader(l10n.settingsSectionSaving),
          ListenableBuilder(
            listenable: widget.settings,
            builder: (context, _) => SwitchListTile(
              secondary: const Icon(Icons.save_outlined),
              title: Text(l10n.autosaveTitle),
              subtitle: Text(l10n.autosaveDescription),
              value: widget.settings.autosave,
              onChanged: widget.settings.setAutosave,
            ),
          ),
          const Divider(),
          _SectionHeader(l10n.settingsSectionNotesLocation),
          ListTile(
            leading: const Icon(Icons.folder_outlined),
            title: SelectableText(widget.notesFolder.path),
            subtitle: Text(widget.isWindows
                ? l10n.notesLocationWindows
                : l10n.notesLocationAndroid),
          ),
          if (widget.isWindows)
            Padding(
              padding: const EdgeInsets.fromLTRB(72, 0, 16, 8),
              child: Align(
                alignment: Alignment.centerLeft,
                child: OutlinedButton.icon(
                  icon: const Icon(Icons.open_in_new),
                  label: Text(l10n.openInExplorer),
                  onPressed: _openNotesFolder,
                ),
              ),
            ),
          const Divider(),
          _SectionHeader(l10n.settingsSectionAbout),
          FutureBuilder<PackageInfo>(
            future: _packageInfo,
            builder: (context, snapshot) {
              final version = snapshot.hasData
                  ? l10n.version(snapshot.data!.version)
                  : snapshot.hasError
                      ? l10n.versionUnknown
                      : l10n.versionLoading;
              return ListTile(
                leading: const Icon(Icons.info_outline),
                title: const Text('Synced Notes'),
                subtitle: Text(version),
              );
            },
          ),
          ListTile(
            leading: const Icon(Icons.gavel_outlined),
            title: Text(l10n.license),
            subtitle: Text(l10n.licenseDescription),
          ),
          ListTile(
            leading: const Icon(Icons.code),
            title: Text(l10n.sourceCode),
            subtitle: const Text('github.com/OwenOlanda/synced-notes'),
            trailing: const Icon(Icons.open_in_new),
            onTap: _openRepository,
          ),
          ListTile(
            leading: const Icon(Icons.description_outlined),
            title: Text(l10n.thirdPartyLicenses),
            subtitle: Text(l10n.thirdPartyLicensesDescription),
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
