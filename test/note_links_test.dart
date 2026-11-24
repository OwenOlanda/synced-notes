import 'package:flutter_test/flutter_test.dart';
import 'package:synced_notes/utils/note_links.dart';

void main() {
  List<String> found(String text) => [for (final l in findLinks(text)) l.text];
  List<String> uris(String text) =>
      [for (final l in findLinks(text)) l.uri.toString()];

  test('páginas: con http(s) o www., sin el punto o paréntesis de afuera', () {
    expect(found('Mira https://example.com/a?b=1.'),
        ['https://example.com/a?b=1']);
    expect(uris('Ve a www.google.com, luego'), ['https://www.google.com']);
    expect(found('(ver http://x.org/página)'), ['http://x.org/página']);
    expect(found('wiki: https://es.wikipedia.org/wiki/Flutter_(software)'),
        ['https://es.wikipedia.org/wiki/Flutter_(software)']);
    expect(found('no es enlace: www. ni http://'), isEmpty);
  });

  test('correos', () {
    expect(found('Escríbeme a owen.brito+notas@gmail.com hoy'),
        ['owen.brito+notas@gmail.com']);
    expect(uris('a@b.mx'), ['mailto:a@b.mx']);
  });

  test('teléfonos: de 8 a 15 dígitos, con espacios, guiones o paréntesis',
      () {
    expect(found('Llama al 55 1234 5678 o al +52 (55) 1234-5678'),
        ['55 1234 5678', '+52 (55) 1234-5678']);
    expect(uris('Tel: +52 55 1234 5678'), ['tel:+525512345678']);
    expect(found('Casa 1234-5678.'), ['1234-5678']);
  });

  test('no son teléfonos: fechas, números cortos o dentro de palabras', () {
    expect(found('Fecha 2026-11-23 y 23.11.2026'), isEmpty);
    expect(found('Página 327 de 1200'), isEmpty);
    expect(found('Código ABC12345678'), isEmpty);
    expect(found('Un número enorme 1234567890123456789'), isEmpty);
    expect(found('Uno por renglón 1234\n5678'), isEmpty);
  });

  test('lo que se muestra en "Abrir …"', () {
    expect(findLinks('https://www.example.com/x').single.display,
        'example.com');
    expect(findLinks('a@b.mx').single.display, 'a@b.mx');
    expect(findLinks('55 1234 5678').single.display, '55 1234 5678');
  });

  test('linkAt: el enlace donde está el cursor (incluye las orillas)', () {
    final links = findLinks('ve a www.x.com ya');
    expect(linkAt(links, 5)?.text, 'www.x.com');
    expect(linkAt(links, 14)?.text, 'www.x.com');
    expect(linkAt(links, 2), isNull);
  });
}
