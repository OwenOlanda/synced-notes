import '../models/note.dart';

/// Búsqueda de notas por título y texto.
///
/// Reglas (fase "Organizar y buscar", 13 oct):
/// - Sin importar mayúsculas ni acentos: "cancion" encuentra "Canción".
/// - Varias palabras: la nota tiene que tener todas, en cualquier orden y en
///   cualquier parte (título o texto). "receta limon" encuentra una nota
///   titulada "Receta" cuyo texto dice "limón".
/// - Una búsqueda vacía (o solo espacios) no filtra nada.
///
/// Todo es texto puro, sin pantallas: se prueba en test/note_search_test.dart.
class NoteSearch {
  NoteSearch(String query) : terms = termsOf(query);

  /// Las palabras buscadas, ya normalizadas (minúsculas, sin acentos).
  final List<String> terms;

  bool get isEmpty => terms.isEmpty;

  /// ¿La nota tiene todas las palabras (en el título o en el texto)?
  bool matches(Note note) {
    if (isEmpty) return true;
    final title = normalize(note.title);
    final content = normalize(note.content);
    return terms.every((t) => title.contains(t) || content.contains(t));
  }

  /// ¿Alguna palabra aparece en el título? (Esas notas van primero.)
  bool matchesTitle(Note note) {
    if (isEmpty) return false;
    final title = normalize(note.title);
    return terms.any(title.contains);
  }

  /// Pedazo del texto para la vista previa: si la primera palabra que
  /// aparece en el texto está más adelante, empieza un poco antes de ella
  /// (con "…"), para que se vea dónde está. Si no, `null` (vista previa
  /// normal, desde el principio).
  String? snippetOf(Note note, {int before = 24}) {
    if (isEmpty) return null;
    final content = note.content;
    final normalized = normalize(content);
    var first = -1;
    for (final term in terms) {
      final i = normalized.indexOf(term);
      if (i >= 0 && (first < 0 || i < first)) first = i;
    }
    if (first <= before) return null; // ya se ve al principio
    var start = first - before;
    // Empezar en el inicio de una palabra, no a la mitad.
    final space = content.lastIndexOf(RegExp(r'\s'), start);
    if (space >= 0 && first - space <= before + 12) start = space + 1;
    return '…${content.substring(safeCut(content, start))}';
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

  /// Dónde aparecen las palabras buscadas dentro de [text]: lista de
  /// rangos [inicio, fin) ordenados y sin encimarse, para resaltarlos.
  List<(int, int)> rangesIn(String text) {
    if (isEmpty || text.isEmpty) return const [];
    final normalized = normalize(text);
    final found = <(int, int)>[];
    for (final term in terms) {
      var from = 0;
      while (true) {
        final i = normalized.indexOf(term, from);
        if (i < 0) break;
        found.add((i, i + term.length));
        from = i + term.length;
      }
    }
    found.sort((a, b) => a.$1.compareTo(b.$1));
    // Unir los que se enciman (ej. "re" y "receta").
    final merged = <(int, int)>[];
    for (final r in found) {
      if (merged.isNotEmpty && r.$1 <= merged.last.$2) {
        final last = merged.removeLast();
        merged.add((last.$1, r.$2 > last.$2 ? r.$2 : last.$2));
      } else {
        merged.add(r);
      }
    }
    return merged;
  }

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

  /// Las palabras de una búsqueda, normalizadas.
  static List<String> termsOf(String query) => normalize(query)
      .split(RegExp(r'\s+'))
      .where((t) => t.isNotEmpty)
      .toList();

  /// Minúsculas y sin acentos, **letra por letra**: el resultado mide lo
  /// mismo que el original, así una posición en uno es la misma en el otro
  /// (sirve para resaltar en el texto original).
  static String normalize(String text) {
    final out = StringBuffer();
    for (final unit in text.codeUnits) {
      final char = String.fromCharCode(unit);
      final mapped = _plain[char];
      if (mapped != null) {
        out.write(mapped);
        continue;
      }
      final lower = char.toLowerCase();
      out.write(lower.length == 1 ? lower : char);
    }
    return out.toString();
  }

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
