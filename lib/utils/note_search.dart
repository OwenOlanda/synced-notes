import '../models/note.dart';

/// Opciones de búsqueda, como los botones de VS Code / Sublime Text:
/// **Aa** (distinguir mayúsculas), **á** (distinguir acentos) y **ab** (solo
/// palabras completas). Por defecto, todas apagadas. Las mismas para la
/// búsqueda de la lista y para "Buscar en esta nota"; se recuerdan en los
/// ajustes.
class SearchOptions {
  const SearchOptions({
    this.matchCase = false,
    this.matchAccents = false,
    this.wholeWord = false,
  });

  final bool matchCase;
  final bool matchAccents;
  final bool wholeWord;

  @override
  bool operator ==(Object other) =>
      other is SearchOptions &&
      other.matchCase == matchCase &&
      other.matchAccents == matchAccents &&
      other.wholeWord == wholeWord;

  @override
  int get hashCode => Object.hash(matchCase, matchAccents, wholeWord);
}

/// Búsqueda de notas por título y texto.
///
/// Reglas (23 nov, como en un editor de texto de PC):
/// - Se busca **la frase tal cual**, con sus espacios: "ante s" encuentra
///   "ante sus ojos", no "ante" y "s" por separado. Los espacios al inicio
///   y al final no cuentan (el teclado del celular suele agregar uno).
/// - Por defecto, sin importar mayúsculas ni acentos: "cancion" encuentra
///   "Canción". Con [SearchOptions] se puede pedir que sí importen, o que
///   solo cuenten palabras completas ("sal" ya no encuentra "salsa").
/// - Una búsqueda vacía (o solo espacios) no filtra nada.
///
/// Todo es texto puro, sin pantallas: se prueba en test/note_search_test.dart.
class NoteSearch {
  NoteSearch(String query, {this.options = const SearchOptions()})
      : _needle = query.trim().isEmpty ? '' : fold(query.trim(), options);

  final SearchOptions options;

  /// Lo buscado, ya preparado según [options].
  final String _needle;

  bool get isEmpty => _needle.isEmpty;

  /// ¿Aparece en el título o en el texto?
  bool matches(Note note) =>
      isEmpty || _first(note.title) >= 0 || _first(note.content) >= 0;

  /// ¿Aparece en el título? (Esas notas van primero.)
  bool matchesTitle(Note note) => !isEmpty && _first(note.title) >= 0;

  /// Pedazo del texto para la vista previa: si lo buscado aparece en el
  /// texto más adelante, empieza un poco antes (con "…"), para que se vea
  /// dónde está. Si no, `null` (vista previa normal, desde el principio).
  String? snippetOf(Note note, {int before = 24}) {
    if (isEmpty) return null;
    final content = note.content;
    final first = _first(content);
    if (first <= before) return null; // no está, o ya se ve al principio
    var start = first - before;
    // Empezar en el inicio de una palabra, no a la mitad.
    final space = content.lastIndexOf(RegExp(r'\s'), start);
    if (space >= 0 && first - space <= before + 12) start = space + 1;
    return '…${content.substring(safeCut(content, start))}';
  }

  /// Dónde empieza la primera coincidencia en [text] (-1 = no está).
  int _first(String text) {
    final ranges = rangesIn(text, limit: 1);
    return ranges.isEmpty ? -1 : ranges.first.$1;
  }

  /// Todas las coincidencias de una nota, en el mismo orden que la barra
  /// "Buscar en esta nota": primero las del título y luego las del texto.
  /// Cada una: (¿en el título?, inicio, fin).
  List<(bool, int, int)> matchesIn(Note note) => [
        for (final (s, e) in rangesIn(note.title)) (true, s, e),
        for (final (s, e) in rangesIn(note.content)) (false, s, e),
      ];

  /// Pedazo de [text] alrededor de una coincidencia que empieza en [start]:
  /// un poco antes (desde el inicio de una palabra, con "…" si no es el
  /// principio) y en una sola línea (los saltos de línea se ven como " · ").
  static String excerptAround(String text, int start,
      {int before = 24, int length = 160}) {
    var from = start - before;
    if (from <= 0) {
      from = 0;
    } else {
      // Empezar en el inicio de una palabra, no a la mitad.
      final space = text.lastIndexOf(RegExp(r'\s'), from);
      if (space >= 0 && start - space <= before + 12) from = space + 1;
    }
    from = safeCut(text, from);
    final to = safeCut(
        text, from + length < text.length ? from + length : text.length);
    final piece = text
        .substring(from, to)
        .trim()
        .replaceAll(RegExp(r'\s*\n\s*'), ' · ');
    return from > 0 ? '…$piece' : piece;
  }

  /// Dónde aparece lo buscado dentro de [text]: lista de [inicio, fin)
  /// en el texto original, en orden y sin encimarse. [limit]: parar al
  /// encontrar esas (para solo saber si está).
  List<(int, int)> rangesIn(String text, {int? limit}) {
    if (isEmpty || text.isEmpty) return const [];
    final hay = fold(text, options);
    final found = <(int, int)>[];
    var from = 0;
    while (true) {
      final i = hay.indexOf(_needle, from);
      if (i < 0) break;
      final end = i + _needle.length;
      if (options.wholeWord && !_isWholeWord(text, i, end)) {
        from = i + 1;
        continue;
      }
      found.add((i, end));
      if (limit != null && found.length >= limit) break;
      from = end;
    }
    return found;
  }

  /// ¿[start, end) no está pegado a otras letras o números?
  static bool _isWholeWord(String text, int start, int end) {
    bool isWordChar(int index) =>
        index >= 0 &&
        index < text.length &&
        _wordChar.hasMatch(String.fromCharCode(text.codeUnitAt(index)));
    return !isWordChar(start - 1) && !isWordChar(end);
  }

  static final RegExp _wordChar = RegExp(r'[\p{L}\p{N}_]', unicode: true);

  /// Corrige una posición para no cortar a la mitad de un emoji (o de otro
  /// carácter que ocupa dos "piezas" UTF-16): si [index] cae entre las dos
  /// mitades, se recorre al inicio del carácter. Cortar ahí producía texto
  /// inválido ("string is not well-formed UTF-16") y la fila no se dibujaba.
  static int safeCut(String text, int index) {
    if (index <= 0 || index >= text.length) return index;
    final before = text.codeUnitAt(index - 1);
    final at = text.codeUnitAt(index);
    final splitsPair =
        before >= 0xD800 && before <= 0xDBFF && at >= 0xDC00 && at <= 0xDFFF;
    return splitsPair ? index - 1 : index;
  }

  /// Prepara un texto para comparar según [options], **letra por letra**:
  /// el resultado mide lo mismo que el original, así una posición en uno es
  /// la misma en el otro (sirve para resaltar en el texto original).
  /// Sin "Aa": todo en minúsculas. Sin "á": letras con acento → sin acento.
  static String fold(String text, SearchOptions options) {
    final out = StringBuffer();
    for (final unit in text.codeUnits) {
      var char = String.fromCharCode(unit);
      if (!options.matchAccents) {
        final plain = _plain[char];
        if (plain != null) {
          final upper = char != char.toLowerCase();
          char = options.matchCase && upper ? plain.toUpperCase() : plain;
        }
      }
      if (!options.matchCase) {
        final lower = char.toLowerCase();
        if (lower.length == 1) char = lower;
      }
      out.write(char);
    }
    return out.toString();
  }

  /// Minúsculas y sin acentos (las opciones por defecto).
  static String normalize(String text) =>
      fold(text, const SearchOptions());

  /// Letras con acento (o diéresis, tilde…) → su letra simple, en minúscula.
  static const Map<String, String> _plain = {
    'á': 'a', 'à': 'a', 'â': 'a', 'ä': 'a', 'ã': 'a', 'å': 'a',
    'Á': 'a', 'À': 'a', 'Â': 'a', 'Ä': 'a', 'Ã': 'a', 'Å': 'a',
    'é': 'e', 'è': 'e', 'ê': 'e', 'ë': 'e',
    'É': 'e', 'È': 'e', 'Ê': 'e', 'Ë': 'e',
    'í': 'i', 'ì': 'i', 'î': 'i', 'ï': 'i',
    'Í': 'i', 'Ì': 'i', 'Î': 'i', 'Ï': 'i',
    'ó': 'o', 'ò': 'o', 'ô': 'o', 'ö': 'o', 'õ': 'o',
    'Ó': 'o', 'Ò': 'o', 'Ô': 'o', 'Ö': 'o', 'Õ': 'o',
    'ú': 'u', 'ù': 'u', 'û': 'u', 'ü': 'u',
    'Ú': 'u', 'Ù': 'u', 'Û': 'u', 'Ü': 'u',
    'ñ': 'n', 'Ñ': 'n', 'ç': 'c', 'Ç': 'c',
  };
}
