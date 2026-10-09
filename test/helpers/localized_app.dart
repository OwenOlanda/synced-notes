import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:synced_notes/l10n/l10n.dart';

/// Envuelve una pantalla en una MaterialApp con las traducciones,
/// en el idioma que se indique (español por defecto).
Widget localizedApp(Widget home, {Locale locale = const Locale('es')}) {
  return MaterialApp(
    locale: locale,
    supportedLocales: AppLocalizations.supportedLocales,
    localizationsDelegates: const [
      AppLocalizations.delegate,
      GlobalMaterialLocalizations.delegate,
      GlobalWidgetsLocalizations.delegate,
      GlobalCupertinoLocalizations.delegate,
    ],
    home: home,
  );
}
