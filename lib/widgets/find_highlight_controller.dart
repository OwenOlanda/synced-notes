import 'package:flutter/material.dart';

/// Controlador del texto de la nota que, además, pinta los resultados de
/// "Buscar en esta nota": todos con un sombreado tenue y el actual en
/// amarillo (como en los navegadores), para que se distinga cuál es.
///
/// Solo cambia cómo se dibuja: el texto y la selección son los mismos.
class FindHighlightController extends TextEditingController {
  FindHighlightController({super.text});

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

  @override
  TextSpan buildTextSpan({
    required BuildContext context,
    TextStyle? style,
    required bool withComposing,
  }) {
    // Mientras el teclado está componiendo una palabra (sugerencias,
    // acentos), se dibuja normal para no estorbarle.
    if (_highlights.isEmpty ||
        (withComposing && value.isComposingRangeValid)) {
      return super.buildTextSpan(
          context: context, style: style, withComposing: withComposing);
    }
    final scheme = Theme.of(context).colorScheme;
    final mark = TextStyle(
      backgroundColor: scheme.onSurface.withValues(alpha: 0.18),
    );
    const currentMark = TextStyle(
      backgroundColor: currentColor,
      color: Colors.black,
    );
    final text = this.text;
    final spans = <TextSpan>[];
    var at = 0;
    for (var i = 0; i < _highlights.length; i++) {
      var (start, end) = _highlights[i];
      // Por si el texto cambió y los rangos aún no se recalculan.
      if (start < at || start >= text.length) continue;
      if (end > text.length) end = text.length;
      if (start > at) spans.add(TextSpan(text: text.substring(at, start)));
      spans.add(TextSpan(
        text: text.substring(start, end),
        style: i == _current ? currentMark : mark,
      ));
      at = end;
    }
    if (at < text.length) spans.add(TextSpan(text: text.substring(at)));
    return TextSpan(style: style, children: spans);
  }
}
