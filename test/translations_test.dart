import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

/// Revisa los archivos de traducción (lib/l10n/app_*.arb).
/// Sirve sobre todo cuando se agregue un idioma nuevo: si le falta un texto,
/// le sobra uno o se le olvidó un {dato} como {error}, esta prueba lo dice.
void main() {
  final folder = Directory('lib/l10n');
  final template = _readArb(File('lib/l10n/app_en.arb'));
  final templateKeys = _messageKeys(template);

  final translations = folder
      .listSync()
      .whereType<File>()
      .where((f) => RegExp(r'app_\w+\.arb$').hasMatch(f.path))
      .toList();

  test('hay al menos inglés y español', () {
    final names = translations.map((f) => f.uri.pathSegments.last).toSet();
    expect(names, containsAll(['app_en.arb', 'app_es.arb']));
  });

  for (final file in translations) {
    final name = file.uri.pathSegments.last;
    final arb = _readArb(file);

    test('$name tiene exactamente los mismos textos que app_en.arb', () {
      final keys = _messageKeys(arb);
      expect(templateKeys.difference(keys), isEmpty,
          reason: 'Le faltan textos a $name');
      expect(keys.difference(templateKeys), isEmpty,
          reason: '$name tiene textos que no existen en app_en.arb');
    });

    test('$name conserva los {datos} de cada texto', () {
      for (final key in templateKeys) {
        final meta = template['@$key'];
        if (meta is! Map || meta['placeholders'] is! Map) continue;
        final placeholders = meta['placeholders'] as Map;
        for (final placeholder in placeholders.keys) {
          // Algunos datos son opcionales (ej. la hora: reloj de 12 o de 24).
          final description = '${placeholders[placeholder]['description']}';
          if (description.contains('(optional')) continue;
          expect(arb[key], contains('{$placeholder}'),
              reason: '"$key" en $name debe incluir {$placeholder}');
        }
      }
    });

    test('$name tiene los 12 meses en dateMonthsShort', () {
      final months = (arb['dateMonthsShort'] as String).split('|');
      expect(months, hasLength(12));
      expect(months.where((m) => m.trim().isEmpty), isEmpty);
    });

    test('$name usa reloj de 12 horas (hour12 + period) o de 24 (hour24)', () {
      final time = arb['timeOfDay'] as String;
      final uses12 = time.contains('{hour12}') && time.contains('{period}');
      final uses24 = time.contains('{hour24}');
      expect(uses12 != uses24, isTrue,
          reason: 'timeOfDay en $name debe usar solo uno de los dos relojes');
      expect(time, contains('{minute}'));
    });
  }
}

Map<String, dynamic> _readArb(File file) =>
    jsonDecode(file.readAsStringSync()) as Map<String, dynamic>;

Set<String> _messageKeys(Map<String, dynamic> arb) =>
    arb.keys.where((k) => !k.startsWith('@')).toSet();
