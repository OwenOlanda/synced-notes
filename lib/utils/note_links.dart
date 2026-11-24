/// Enlaces dentro del texto de una nota: páginas web, correos y teléfonos.
library;

/// Qué tipo de enlace es (cambia el ícono y con qué se abre).
enum NoteLinkKind { web, email, phone }

/// Un enlace encontrado en el texto: dónde está ([start], [end]) y a dónde
/// lleva ([uri]).
class NoteLink {
  const NoteLink({
    required this.start,
    required this.end,
    required this.kind,
    required this.text,
    required this.uri,
  });

  final int start;
  final int end;
  final NoteLinkKind kind;

  /// El enlace tal como está escrito.
  final String text;
  final Uri uri;

  /// Lo que se muestra en "Abrir …": el sitio (sin "www."), el correo o el
  /// teléfono.
  String get display => switch (kind) {
        NoteLinkKind.web => uri.host.startsWith('www.')
            ? uri.host.substring(4)
            : (uri.host.isEmpty ? text : uri.host),
        NoteLinkKind.email || NoteLinkKind.phone => text,
      };

  /// ¿El cursor en [offset] está sobre este enlace? (Incluye sus orillas.)
  bool contains(int offset) => offset >= start && offset <= end;

  @override
  String toString() => 'NoteLink($kind, $start–$end, $uri)';
}

final RegExp _web = RegExp(r'(?:https?://|www\.)[^\s<>"]+', caseSensitive: false);
final RegExp _email = RegExp(r'[\w.+-]+@[\w-]+(?:\.[\w-]+)+');
final RegExp _phone = RegExp(r'\+?\(?\d[\d \t().-]{5,}\d');
final RegExp _date = RegExp(r'^\d{1,4}[-.]\d{1,2}[-.]\d{1,4}$');

/// Signos que suelen ir pegados después de un enlace sin ser parte de él.
const String _trailing = '.,;:!?\'"»”’';

/// Busca los enlaces de [text], en orden y sin encimarse.
List<NoteLink> findLinks(String text) {
  final links = <NoteLink>[];
  bool overlaps(int start, int end) =>
      links.any((l) => start < l.end && end > l.start);

  for (final m in _web.allMatches(text)) {
    var end = m.end;
    // Quitar signos del final ("mira www.x.com." → sin el punto) y un ")"
    // que cierra un paréntesis de afuera.
    while (end > m.start) {
      final c = text[end - 1];
      final raw = text.substring(m.start, end);
      if (_trailing.contains(c) ||
          (c == ')' && '('.allMatches(raw).length < ')'.allMatches(raw).length)) {
        end--;
      } else {
        break;
      }
    }
    final raw = text.substring(m.start, end);
    if (raw.length <= 4 || !raw.contains('.')) continue;
    final uri = Uri.tryParse(
        raw.toLowerCase().startsWith('www.') ? 'https://$raw' : raw);
    if (uri == null || uri.host.isEmpty) continue;
    links.add(NoteLink(
        start: m.start, end: end, kind: NoteLinkKind.web, text: raw, uri: uri));
  }

  for (final m in _email.allMatches(text)) {
    if (overlaps(m.start, m.end)) continue;
    final raw = m.group(0)!;
    links.add(NoteLink(
        start: m.start,
        end: m.end,
        kind: NoteLinkKind.email,
        text: raw,
        uri: Uri(scheme: 'mailto', path: raw)));
  }

  for (final m in _phone.allMatches(text)) {
    final start = m.start, end = m.end;
    // No es teléfono si va pegado a letras o números (ej. dentro de una
    // palabra o de un número más largo).
    bool isWordChar(int i) =>
        i >= 0 && i < text.length && RegExp(r'[\w@]').hasMatch(text[i]);
    if (isWordChar(start - 1) || isWordChar(end)) continue;
    final raw = text.substring(start, end);
    final digits = raw.replaceAll(RegExp(r'\D'), '');
    // Entre 8 y 15 dígitos (como los números de teléfono) y que no sea una
    // fecha (2026-11-23).
    if (digits.length < 8 || digits.length > 15) continue;
    if (_date.hasMatch(raw)) continue;
    if (overlaps(start, end)) continue;
    links.add(NoteLink(
        start: start,
        end: end,
        kind: NoteLinkKind.phone,
        text: raw,
        uri: Uri(scheme: 'tel', path: (raw.startsWith('+') ? '+' : '') + digits)));
  }

  links.sort((a, b) => a.start.compareTo(b.start));
  return links;
}

/// El enlace donde está [offset] (el cursor), o `null`.
NoteLink? linkAt(List<NoteLink> links, int offset) {
  for (final l in links) {
    if (l.contains(offset)) return l;
  }
  return null;
}
