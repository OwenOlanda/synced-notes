import 'package:flutter/material.dart';

/// Avisos cortos de la app ("Nota guardada", "Grupo borrada"…).
///
/// Diseño: una píldora flotante centrada, con el texto centrado, que ocupa
/// como máximo la mitad del ancho de la pantalla (sin bajar de 240 px, para
/// que en un teléfono el texto no quede como una columna de palabras).
/// Los errores usan el color de error del tema.
///
/// Uso: `ScaffoldMessenger.of(context).showMessage('Nota guardada')`.
/// Se llama sobre el messenger (no sobre el context) para poder guardarlo
/// antes de una espera (`await`) y usarlo después sin riesgo.
extension AppMessages on ScaffoldMessengerState {
  void showMessage(
    String message, {
    bool isError = false,
    Duration duration = const Duration(seconds: 3),
  }) {
    final colors = Theme.of(context).colorScheme;
    final screenWidth = MediaQuery.sizeOf(context).width;
    final width = (screenWidth * 0.5).clamp(240.0, screenWidth - 32);
    final background = isError ? colors.error : colors.inverseSurface;
    final foreground = isError ? colors.onError : colors.onInverseSurface;

    hideCurrentSnackBar();
    showSnackBar(SnackBar(
      behavior: SnackBarBehavior.floating,
      width: width,
      duration: duration,
      backgroundColor: background,
      elevation: 2,
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
      content: Text(
        message,
        textAlign: TextAlign.center,
        style: TextStyle(
          color: foreground,
          fontSize: 14,
          fontWeight: FontWeight.w500,
        ),
      ),
    ));
  }
}
