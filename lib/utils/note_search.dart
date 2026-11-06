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
    return '…${content.substring(start)}';
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
