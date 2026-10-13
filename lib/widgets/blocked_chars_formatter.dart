import 'dart:async';

import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';

/// Filtro para campos de texto: no deja escribir (ni pegar) los caracteres
/// de [blocked], y avisa con [onBlocked] cada vez que quita alguno, para que
/// la pantalla muestre un mensaje. Así el usuario entiende por qué no se
/// escribió lo que tecleó.
///
/// Lo usan el título de la nota y el nombre de un grupo, para que
/// ambos se comporten igual.
class BlockedCharsFormatter extends TextInputFormatter {
  BlockedCharsFormatter(RegExp blocked, {required this.onBlocked})
      : _deny = FilteringTextInputFormatter.deny(blocked);

  final FilteringTextInputFormatter _deny;
  final VoidCallback onBlocked;

  @override
  TextEditingValue formatEditUpdate(
      TextEditingValue oldValue, TextEditingValue newValue) {
    final filtered = _deny.formatEditUpdate(oldValue, newValue);
    if (filtered.text != newValue.text) onBlocked();
    return filtered;
  }
}

/// Aviso temporal: se muestra y se quita solo después de [duration].
/// Para el mensaje de "ese carácter no se permite".
class TemporaryHint {
  TemporaryHint(this._onChange, {this.duration = const Duration(seconds: 3)});

  final VoidCallback _onChange;
  final Duration duration;
  Timer? _timer;
  bool _visible = false;

  /// ¿Se está mostrando?
  bool get visible => _visible;

  /// Muestra el aviso (o reinicia su tiempo si ya estaba).
  void show() {
    _timer?.cancel();
    _timer = Timer(duration, hide);
    if (!_visible) {
      _visible = true;
      _onChange();
    }
  }

  /// Lo quita ya.
  void hide() {
    _timer?.cancel();
    if (_visible) {
      _visible = false;
      _onChange();
    }
  }

  void dispose() => _timer?.cancel();
}
