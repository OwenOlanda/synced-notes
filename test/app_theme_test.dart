import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:synced_notes/theme/app_theme.dart';

void main() {
  /// ¿Es un gris? (rojo, verde y azul casi iguales: sin tinte de color.
  /// Se permite un toque mínimo, como el azulado casi invisible de #A0A0AB.)
  bool isNeutral(Color c) {
    final channels = [c.r, c.g, c.b].map((v) => (v * 255).round()).toList();
    final spread = channels.reduce((a, b) => a > b ? a : b) -
        channels.reduce((a, b) => a < b ? a : b);
    return spread <= 12;
  }

  for (final (name, theme) in [
    ('oscuro', AppTheme.dark()),
    ('claro', AppTheme.light()),
  ]) {
    test('tema $name: fondo, texto y botón principal sin tinte de color', () {
      final scheme = theme.colorScheme;
      for (final color in [
        scheme.surface,
        scheme.onSurface,
        scheme.onSurfaceVariant,
        scheme.primary,
        scheme.secondaryContainer,
        theme.scaffoldBackgroundColor,
      ]) {
        expect(isNeutral(color), isTrue, reason: '$color tiene tinte');
      }
    });

    test('tema $name: el texto se lee bien sobre el fondo', () {
      final scheme = theme.colorScheme;
      double contrast(Color a, Color b) {
        final la = a.computeLuminance(), lb = b.computeLuminance();
        final hi = la > lb ? la : lb, lo = la > lb ? lb : la;
        return (hi + 0.05) / (lo + 0.05);
      }

      expect(contrast(scheme.onSurface, scheme.surface), greaterThan(7));
      expect(contrast(scheme.onSurfaceVariant, scheme.surface),
          greaterThan(4.5));
      expect(contrast(scheme.onPrimary, scheme.primary), greaterThan(7));
    });
  }

  test('claro es claro y oscuro es oscuro', () {
    expect(AppTheme.light().brightness, Brightness.light);
    expect(AppTheme.dark().brightness, Brightness.dark);
  });
}
