import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../models/collection_filter.dart';

/// Ajustes de la app que se recuerdan entre sesiones:
/// - si el autoguardado está activado;
/// - el idioma elegido a mano (o ninguno = idioma del sistema);
/// - qué colección se estaba viendo en la lista.
class AppSettings extends ChangeNotifier {
  AppSettings._(this._prefs);

  final SharedPreferences _prefs;

  static const String _autosaveKey = 'autosave_enabled';
  static const String _languageKey = 'language_code';
  static const String _selectedCollectionKey = 'selected_collection';

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

  /// Lo que se estaba viendo en la lista (Todas, Sin colección o una
  /// colección). Se recuerda al cerrar la app. Por defecto: Todas.
  CollectionFilter get selectedCollection =>
      CollectionFilter.decode(_prefs.getString(_selectedCollectionKey));

  Future<void> setSelectedCollection(CollectionFilter filter) async {
    await _prefs.setString(_selectedCollectionKey, filter.encode());
    notifyListeners();
  }
}
