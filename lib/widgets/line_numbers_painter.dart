import 'dart:math' as math;
import 'dart:ui' show FontFeature;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart' show RenderEditable;

/// Dónde empieza cada renglón del texto (0 y después de cada salto de
/// línea). Un renglón largo que se parte en pantalla sigue siendo uno.
List<int> lineStartsOf(String text) {
  final starts = <int>[0];
  for (var i = 0; i < text.length; i++) {
    if (text.codeUnitAt(i) == 10) starts.add(i + 1);
  }
  return starts;
}

/// En qué renglón (desde 0) está [offset].
int lineIndexOf(List<int> starts, int offset) {
  var low = 0, high = starts.length - 1;
  while (low < high) {
    final mid = (low + high + 1) ~/ 2;
    if (starts[mid] <= offset) {
      low = mid;
    } else {
      high = mid - 1;
    }
  }
  return low;
}

/// Tamaño de letra de los números: un poco más chicos que el texto, crecen
/// un poco con el zoom (con tope) y, si no caben en el margen, se encogen.
double lineNumberFontSize({
  required double zoom,
  required double digitsWidthAt10,
  required double available,
}) {
  final wanted = (11.5 * zoom).clamp(10.0, 14.0).toDouble();
  final width = digitsWidthAt10 * wanted / 10;
  if (width <= available || width == 0) return wanted;
  return math.max(6.0, wanted * available / width);
}

/// Dibuja los números de línea en el margen izquierdo del texto, alineados
/// a la derecha (pegados al texto) y centrados con su renglón. Solo dibuja:
/// los toques pasan al campo (va dentro de un IgnorePointer).
class LineNumbersPainter extends CustomPainter {
  LineNumbersPainter({
    required this.controller,
    required this.editable,
    required this.self,
    required this.zoom,
    required this.color,
    required this.currentColor,
    required Listenable repaint,
  }) : super(repaint: repaint);

  final TextEditingController controller;

  /// El campo del texto (para saber dónde queda cada renglón).
  final RenderEditable? Function() editable;

  /// La caja donde se dibuja (para pasar de coordenadas del campo a las
  /// propias).
  final RenderBox? Function() self;

  final double zoom;
  final Color color;

  /// El número del renglón donde está el cursor.
  final Color currentColor;

  /// Espacio entre los números y el texto.
  static const double gap = 5;

  String? _startsText;
  List<int> _starts = const [0];

  List<int> _startsFor(String text) {
    if (!identical(_startsText, text)) {
      _startsText = text;
      _starts = lineStartsOf(text);
    }
    return _starts;
  }

  TextPainter _number(String label, double size, Color c, bool bold) =>
      TextPainter(
        text: TextSpan(
          text: label,
          style: TextStyle(
            fontSize: size,
            color: c,
            fontWeight: bold ? FontWeight.w600 : FontWeight.w400,
            fontFeatures: const [FontFeature.tabularFigures()],
          ),
        ),
        textDirection: TextDirection.ltr,
      )..layout();

  @override
  void paint(Canvas canvas, Size size) {
    final field = editable();
    final box = self();
    if (field == null ||
        box == null ||
        !field.attached ||
        !box.attached ||
        !field.hasSize ||
        !box.hasSize) {
      return;
    }
    // Dónde queda el campo dentro de esta caja (solo hay desplazamiento).
    final origin = box.globalToLocal(field.localToGlobal(Offset.zero));
    final right = origin.dx - gap;
    final available = right - 1;
    if (available < 6) return;

    final text = controller.text;
    final starts = _startsFor(text);
    final digits = '${starts.length}'.length;
    final fontSize = lineNumberFontSize(
      zoom: zoom,
      digitsWidthAt10: _number('0' * digits, 10, color, true).width,
      available: available,
    );

    final selection = controller.selection;
    final current =
        selection.isValid ? lineIndexOf(starts, selection.baseOffset) : -1;
    // Desde el primer renglón visible hacia abajo, hasta salir de la vista.
    final top = field
        .getPositionForPoint(field.localToGlobal(const Offset(1, 1)))
        .offset;
    canvas.save();
    canvas.clipRect(Offset.zero & size);
    for (var i = lineIndexOf(starts, top); i < starts.length; i++) {
      final caret =
          field.getLocalRectForCaret(TextPosition(offset: starts[i]));
      if (caret.top > field.size.height) break;
      if (caret.bottom < 0) continue;
      final isCurrent = i == current;
      final label = _number('${i + 1}', fontSize,
          isCurrent ? currentColor : color, isCurrent);
      final centerY = origin.dy + caret.center.dy;
      label.paint(
          canvas, Offset(right - label.width, centerY - label.height / 2));
    }
    canvas.restore();
  }

  @override
  bool shouldRepaint(LineNumbersPainter old) => true;
}
