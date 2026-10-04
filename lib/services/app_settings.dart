import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Ajustes de la app que se recuerdan entre sesiones.
/// Por ahora solo uno: si el autoguardado está activado.
class AppSettings extends ChangeNotifier {
  AppSettings._(this._prefs);

  final SharedPreferences _prefs;

  static const String _autosaveKey = 'autosave_enabled';

  static Future<AppSettings> load() async =>
      AppSettings._(await SharedPreferences.getInstance());

  /// Autoguardado: activado por defecto.
  bool get autosave => _prefs.getBool(_autosaveKey) ?? true;

  Future<void> setAutosave(bool enabled) async {
    await _prefs.setBool(_autosaveKey, enabled);
    notifyListeners();
  }
}
