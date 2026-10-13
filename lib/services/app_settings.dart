import 'package:flutter/material.dart' show ThemeMode;
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../models/group_filter.dart';

/// Ajustes de la app que se recuerdan entre sesiones:
/// - si el autoguardado está activado;
/// - el idioma elegido a mano (o ninguno = idioma del sistema);
/// - qué grupo se estaba viendo en la lista;
/// - el tema (claro, oscuro o el del sistema).
class AppSettings extends ChangeNotifier {
  AppSettings._(this._prefs);

  final SharedPreferences _prefs;

  static const String _autosaveKey = 'autosave_enabled';
  static const String _languageKey = 'language_code';
  static const String _selectedGroupKey = 'selected_group';
  static const String _themeModeKey = 'theme_mode';

  static Future<AppSettings> load() async =>
      AppSettings._(await SharedPreferences.getInstance());

  /// Autoguardado: activado por defecto.
  bool get autosave => _prefs.getBool(_autosaveKey) ?? true;

  Future<void> setAutosave(bool enabled) async {
    await _prefs.setBool(_autosaveKey, enabled);
    notifyListeners();
  }

  /// Código del idioma elegido a mano ("es", "en"…).
  /// `null` (lo normal) = usar el idioma del sistema.
  String? get languageCode => _prefs.getString(_languageKey);

  Future<void> setLanguageCode(String? code) async {
    if (code == null) {
      await _prefs.remove(_languageKey);
    } else {
      await _prefs.setString(_languageKey, code);
    }
    notifyListeners();
  }

  /// Lo que se estaba viendo en la lista (Todas, Sin grupo o un
  /// grupo). Se recuerda al cerrar la app. Por defecto: Todas.
  GroupFilter get selectedGroup =>
      GroupFilter.decode(_prefs.getString(_selectedGroupKey));

  Future<void> setSelectedGroup(GroupFilter filter) async {
    await _prefs.setString(_selectedGroupKey, filter.encode());
    notifyListeners();
  }

  /// Tema: claro, oscuro o el del sistema (por defecto).
  /// Se guarda como texto ("system", "light", "dark") para que en el futuro
  /// se puedan agregar más temas sin perder lo que ya eligió el usuario.
  ThemeMode get themeMode => switch (_prefs.getString(_themeModeKey)) {
        'light' => ThemeMode.light,
        'dark' => ThemeMode.dark,
        _ => ThemeMode.system,
      };

  Future<void> setThemeMode(ThemeMode mode) async {
    await _prefs.setString(_themeModeKey, mode.name);
    notifyListeners();
  }
}
