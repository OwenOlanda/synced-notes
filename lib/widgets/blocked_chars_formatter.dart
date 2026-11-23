import 'dart:async';

import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';

/// Filtro para campos de texto: no deja escribir (ni pegar) los caracteres
/// de [blocked], y avisa con [onBlocked] cada vez que quita alguno, para que
/// la pantalla muestre un mensaje. Así el usuario entiende por qué no se
/// escribió lo que tecleó. [onAllowed] avisa cuando se escribe algo que sí
/// se permite: el mensaje se quita en ese momento (como en la mayoría de
/// las apps), para que no parezca que lo nuevo también está prohibido.
///
/// Lo usan el título de la nota y el nombre de un grupo, para que
/// ambos se comporten igual.
class BlockedCharsFormatter extends TextInputFormatter {
  BlockedCharsFormatter(RegExp blocked,
      {required this.onBlocked, this.onAllowed})
      : _deny = FilteringTextInputFormatter.deny(blocked);

  final FilteringTextInputFormatter _deny;
  final VoidCallback onBlocked;
  final VoidCallback? onAllowed;

  @override
  TextEditingValue formatEditUpdate(
      TextEditingValue oldValue, TextEditingValue newValue) {
    final filtered = _deny.formatEditUpdate(oldValue, newValue);
    if (filtered.text != newValue.text) {
      onBlocked();
    } else if (newValue.text != oldValue.text) {
      onAllowed?.call();
    }
    return filtered;
  }
}

/// Aviso temporal: se muestra y se quita solo después de [duration].
/// Para el mensaje de "ese carácter no se permite".
class TemporaryHint {
  TemporaryHint(this._onChange, {this.duration = const Duration(seconds: 4)});

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
