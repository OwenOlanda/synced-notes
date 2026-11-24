import 'package:flutter/material.dart';

import '../utils/note_links.dart';

/// Controlador del texto de la nota que, además:
/// - pinta los resultados de "Buscar en esta nota": todos con un sombreado
///   tenue y el actual en amarillo (como en los navegadores);
/// - si [detectLinks], subraya los enlaces (páginas, correos, teléfonos)
///   con el color principal.
///
/// Solo cambia cómo se dibuja: el texto y la selección son los mismos.
class FindHighlightController extends TextEditingController {
  FindHighlightController({super.text, this.detectLinks = false});

  final bool detectLinks;

  /// Rangos [inicio, fin) a resaltar, ordenados y sin encimarse.
  List<(int, int)> _highlights = const [];

  /// Cuál de [_highlights] es el actual (-1 = ninguno).
  int _current = -1;

  List<(int, int)> get highlights => _highlights;
  int get current => _current;

  /// Color de fondo del resultado actual (se lee bien en claro y oscuro).
  static const Color currentColor = Color(0xFFF2C94C);

  /// Cambia lo resaltado. Quien llama reconstruye el campo (setState).
  void setHighlights(List<(int, int)> ranges, int current) {
    _highlights = ranges;
    _current = current;
  }

  void clearHighlights() => setHighlights(const [], -1);

  String? _linksText;
  List<NoteLink> _links = const [];

  /// Los enlaces del texto actual (se buscan de nuevo solo si cambió).
  List<NoteLink> get links {
    if (!detectLinks) return const [];
    if (!identical(_linksText, text)) {
      _linksText = text;
      _links = findLinks(text);
    }
    return _links;
  }

  @override
  TextSpan buildTextSpan({
    required BuildContext context,
    TextStyle? style,
    required bool withComposing,
  }) {
    final text = this.text;
    final composing = withComposing && value.isComposingRangeValid
        ? value.composing
        : null;
    // Mientras el teclado compone una palabra (sugerencias, acentos), los
    // resultados de búsqueda no se pintan, para no estorbarle; los enlaces
    // sí (si no, aparecerían y desaparecerían al escribir).
    final highlights = composing == null ? _highlights : const <(int, int)>[];
    final links = this.links;
    if (highlights.isEmpty && links.isEmpty) {
      return super.buildTextSpan(
          context: context, style: style, withComposing: withComposing);
    }

    final scheme = Theme.of(context).colorScheme;
    // Cortes: donde empieza o termina un resultado, un enlace o lo que se
    // está componiendo.
    final cuts = <int>{0, text.length};
    void cut(int start, int end) {
      cuts.add(start.clamp(0, text.length));
      cuts.add(end.clamp(0, text.length));
    }

    for (final (start, end) in highlights) {
      cut(start, end);
    }
    for (final l in links) {
      cut(l.start, l.end);
    }
    if (composing != null) cut(composing.start, composing.end);
    final points = cuts.toList()..sort();

    final spans = <TextSpan>[];
    for (var i = 0; i + 1 < points.length; i++) {
      final a = points[i], b = points[i + 1];
      if (a >= b) continue;
      bool inside(int start, int end) => a >= start && b <= end;
      final inLink = links.any((l) => inside(l.start, l.end));
      final inComposing =
          composing != null && inside(composing.start, composing.end);
      var hit = -1;
      for (var h = 0; h < highlights.length; h++) {
        if (inside(highlights[h].$1, highlights[h].$2)) hit = h;
      }
      TextStyle? s;
      if (inLink || inComposing) {
        s = TextStyle(
          color: inLink ? scheme.primary : null,
          decoration: TextDecoration.underline,
          decorationColor: inLink ? scheme.primary : null,
        );
      }
      if (hit >= 0) {
        final mark = hit == _current
            ? const TextStyle(backgroundColor: currentColor, color: Colors.black)
            : TextStyle(
                backgroundColor: scheme.onSurface.withValues(alpha: 0.18));
        s = s == null ? mark : s.merge(mark);
      }
      spans.add(TextSpan(text: text.substring(a, b), style: s));
    }
    return TextSpan(style: style, children: spans);
  }
}
