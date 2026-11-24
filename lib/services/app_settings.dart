import 'dart:convert';

import 'package:flutter/material.dart' show ThemeMode;
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../models/group_filter.dart';
import '../utils/note_search.dart';

/// Ajustes de la app que se recuerdan entre sesiones:
/// - si el autoguardado está activado;
/// - el idioma elegido a mano (o ninguno = idioma del sistema);
/// - qué grupo se estaba viendo en la lista;
/// - el tema (claro, oscuro o el del sistema);
/// - las opciones de búsqueda (Aa, á, ab);
/// - si el teclado empieza las oraciones con mayúscula;
/// - dónde se abre una nota y dónde se quedó cada una (en este dispositivo);
/// - el tamaño del texto de las notas (zoom, en este dispositivo).
class AppSettings extends ChangeNotifier {
  AppSettings._(this._prefs);

  final SharedPreferences _prefs;

  static const String _autosaveKey = 'autosave_enabled';
  static const String _languageKey = 'language_code';
  static const String _selectedGroupKey = 'selected_group';
  static const String _themeModeKey = 'theme_mode';
  static const String _autoCapitalizeKey = 'auto_capitalize';
  static const String _openPositionKey = 'note_open_position';
  static const String _positionsKey = 'note_positions';
  static const String _searchCaseKey = 'search_match_case';
  static const String _searchAccentsKey = 'search_match_accents';
  static const String _searchWholeWordKey = 'search_whole_word';
  static const String _textZoomKey = 'text_zoom';

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

  /// Opciones de búsqueda (Aa, á, ab), las mismas para la lista y para
  /// "Buscar en esta nota". Por defecto, todas apagadas.
  SearchOptions get searchOptions => SearchOptions(
        matchCase: _prefs.getBool(_searchCaseKey) ?? false,
        matchAccents: _prefs.getBool(_searchAccentsKey) ?? false,
        wholeWord: _prefs.getBool(_searchWholeWordKey) ?? false,
      );

  Future<void> setSearchOptions(SearchOptions options) async {
    await _prefs.setBool(_searchCaseKey, options.matchCase);
    await _prefs.setBool(_searchAccentsKey, options.matchAccents);
    await _prefs.setBool(_searchWholeWordKey, options.wholeWord);
    notifyListeners();
  }

  /// Mayúscula automática: el teclado empieza con mayúscula después de un
  /// punto o de un salto de línea (activado por defecto, como en la mayoría
  /// de las apps de notas).
  bool get autoCapitalize => _prefs.getBool(_autoCapitalizeKey) ?? true;

  Future<void> setAutoCapitalize(bool enabled) async {
    await _prefs.setBool(_autoCapitalizeKey, enabled);
    notifyListeners();
  }

  /// Dónde se abre una nota: al principio, al final o donde se quedó
  /// (por defecto).
  NoteOpenPosition get noteOpenPosition =>
      switch (_prefs.getString(_openPositionKey)) {
        'start' => NoteOpenPosition.start,
        'end' => NoteOpenPosition.end,
        _ => NoteOpenPosition.last,
      };

  Future<void> setNoteOpenPosition(NoteOpenPosition position) async {
    await _prefs.setString(_openPositionKey, position.name);
    notifyListeners();
  }

  /// Zoom del texto de las notas (título y texto): de [minTextZoom] a
  /// [maxTextZoom], en pasos de [textZoomStep]. 1.0 = 100 % (por defecto).
  /// Uno solo para todas las notas, en cada dispositivo.
  static const double minTextZoom = 0.7;
  static const double maxTextZoom = 2.0;
  static const double textZoomStep = 0.1;

  double get textZoom => clampTextZoom(_prefs.getDouble(_textZoomKey) ?? 1.0);

  Future<void> setTextZoom(double zoom) async {
    final value = snapTextZoom(zoom);
    if (value == textZoom) return;
    // Se avisa sin esperar a que se escriba en disco: el nuevo tamaño se
    // dibuja en el siguiente cuadro (y así la nota no "brinca").
    final saving = _prefs.setDouble(_textZoomKey, value);
    notifyListeners();
    await saving;
  }

  /// Mantiene el zoom dentro de los límites.
  static double clampTextZoom(double zoom) =>
      zoom.isFinite ? zoom.clamp(minTextZoom, maxTextZoom).toDouble() : 1.0;

  /// Dentro de los límites y en el paso de 10 % más cercano (1.234 → 1.2).
  static double snapTextZoom(double zoom) =>
      (clampTextZoom(zoom) * 10).round() / 10;

  /// Cuántas notas recuerdan su posición (las más recientes).
  static const int maxRememberedPositions = 300;

  /// Dónde se quedó una nota (en este dispositivo). `null` = no se sabe.
  NotePosition? notePositionOf(String noteId) {
    final entry = _positions()[noteId];
    if (entry is! List || entry.length != 2) return null;
    final [cursor, top] = entry;
    if (cursor is! int || top is! int) return null;
    return NotePosition(cursor: cursor, topChar: top);
  }

  /// Recuerda dónde se quedó una nota. Se guardan solo las
  /// [maxRememberedPositions] más recientes, para no crecer sin fin.
  Future<void> setNotePosition(String noteId, NotePosition position) async {
    final positions = _positions()
      ..remove(noteId) // al final = la más reciente
      ..[noteId] = [position.cursor, position.topChar];
    while (positions.length > maxRememberedPositions) {
      positions.remove(positions.keys.first);
    }
    await _prefs.setString(_positionsKey, jsonEncode(positions));
  }

  Map<String, dynamic> _positions() {
    final raw = _prefs.getString(_positionsKey);
    if (raw == null) return <String, dynamic>{};
    try {
      final decoded = jsonDecode(raw);
      return decoded is Map<String, dynamic> ? decoded : <String, dynamic>{};
    } on FormatException {
      return <String, dynamic>{}; // dañado: se empieza de nuevo
    }
  }
}

/// Dónde se abre una nota.
enum NoteOpenPosition { start, end, last }

/// Dónde se quedó una nota, en letras (no en píxeles): [cursor] es dónde
/// estaba el cursor y [topChar], la letra que se veía hasta arriba. Así
/// sirve aunque cambie el ancho de la ventana.
class NotePosition {
  const NotePosition({required this.cursor, required this.topChar});

  final int cursor;
  final int topChar;
}
