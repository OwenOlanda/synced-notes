import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../l10n/l10n.dart';
import '../models/note.dart';
import '../services/app_settings.dart' show NoteOpenPosition;
import '../utils/date_text.dart';
import '../utils/note_search.dart';
import 'group_colors.dart';

/// Una nota de la lista (la usan la vista de celular y la de PC):
///   ▍ Título                     18:44
///   ▍ inicio del texto…     Recetas 📁
///
/// El nombre del grupo va en gris y la carpetita a su derecha lleva el
/// color: así las carpetitas quedan alineadas en una columna a la orilla.
/// [groupColor] y el nombre del grupo solo se muestran si [showGroup] (en
/// "Todas"): dentro de un grupo ya se sabe de cuál es cada nota.
///
/// Buscando, si la nota tiene 2 o más coincidencias, abajo aparece una
/// píldora "7 coincidencias" que despliega una línea por coincidencia (con
/// su pedazo de texto), de 10 en 10. Tocar una abre la nota ahí.
class NoteRow extends StatelessWidget {
  const NoteRow({
    super.key,
    required this.note,
    required this.groupColor,
    required this.showGroup,
    required this.onTap,
    required this.onMenu,
    this.onLongPress,
    this.selected = false,
    this.pinned = false,
    this.selectionMode = false,
    this.checked = false,
    this.preview = NoteOpenPosition.start,
    this.fromChar,
    this.search,
    this.matchesExpanded = false,
    this.matchesShown = 10,
    this.onToggleMatches,
    this.onShowMoreMatches,
    this.onOpenMatch,
  });

  final Note note;

  /// Color del grupo de la nota (`null` = sin grupo).
  final Color? groupColor;
  final bool showGroup;
  final VoidCallback onTap;

  /// Menú de la nota (mantener presionado o clic derecho), en esa posición.
  final void Function(Offset position) onMenu;

  /// Mantener presionada (si no se da, abre [onMenu]).
  final void Function(Offset position)? onLongPress;

  /// La nota abierta en el editor (vista de PC): fondo resaltado.
  final bool selected;

  /// Fijada en lo que se ve: alfiler junto a la fecha.
  final bool pinned;

  /// Seleccionando notas (mantener presionado): cada fila lleva un círculo
  /// a la izquierda, marcado si [checked].
  final bool selectionMode;
  final bool checked;

  /// Qué parte del texto se ve (sin buscar): el principio, el final o
  /// ([NoteOpenPosition.cursor] / [NoteOpenPosition.scroll]) desde el
  /// renglón de la letra [fromChar]
  /// (donde se dejó el cursor o lo que estaba arriba en pantalla; si no se
  /// sabe, el principio).
  final NoteOpenPosition preview;
  final int? fromChar;

  /// Buscando: las coincidencias están desplegadas, y cuántas se ven.
  final bool matchesExpanded;
  final int matchesShown;

  /// Tocar la píldora "N coincidencias". `null` = sin píldora.
  final VoidCallback? onToggleMatches;

  /// Tocar "Mostrar N más".
  final VoidCallback? onShowMoreMatches;

  /// Tocar una coincidencia (su número, desde 0).
  final ValueChanged<int>? onOpenMatch;

  /// Búsqueda en curso: resalta las palabras encontradas y, si están a media
  /// nota, la vista previa muestra ese pedazo.
  final NoteSearch? search;

  /// [text] con las palabras de la búsqueda resaltadas.
  Widget _highlighted(
    BuildContext context,
    String text, {
    required TextStyle? style,
    int maxLines = 1,
    Key? key,
  }) {
    final ranges = search?.rangesIn(text) ?? const <(int, int)>[];
    if (ranges.isEmpty) {
      return Text(text,
          key: key,
          maxLines: maxLines,
          overflow: TextOverflow.ellipsis,
          style: style);
    }
    final scheme = Theme.of(context).colorScheme;
    final mark = (style ?? const TextStyle()).copyWith(
      color: scheme.onSurface,
      fontWeight: FontWeight.w700,
      backgroundColor: scheme.onSurface.withValues(alpha: 0.16),
    );
    final spans = <TextSpan>[];
    var at = 0;
    for (final (start, end) in ranges) {
      if (start > at) spans.add(TextSpan(text: text.substring(at, start)));
      spans.add(TextSpan(text: text.substring(start, end), style: mark));
      at = end;
    }
    if (at < text.length) spans.add(TextSpan(text: text.substring(at)));
    return Text.rich(
      TextSpan(style: style, children: spans),
      key: key,
      maxLines: maxLines,
      overflow: TextOverflow.ellipsis,
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final l10n = context.l10n;
    final group = note.group;
    final muted = theme.colorScheme.onSurfaceVariant;
    final showGroupHere = showGroup && group != null && groupColor != null;
    return GestureDetector(
      onSecondaryTapUp: (details) => onMenu(details.globalPosition),
      onLongPressStart: (details) =>
          (onLongPress ?? onMenu)(details.globalPosition),
      child: Material(
        type: selected || checked
            ? MaterialType.canvas
            : MaterialType.transparency,
        color: checked
            ? theme.colorScheme.secondaryContainer
            : selected
                ? theme.colorScheme.surfaceContainerHighest
                : null,
        borderRadius: BorderRadius.circular(14),
        child: InkWell(
          borderRadius: BorderRadius.circular(14),
          onTap: onTap,
          child: Stack(
            children: [
              // Seleccionando: círculo (marcado o no) a la izquierda.
              if (selectionMode)
                PositionedDirectional(
                  start: 12,
                  top: 0,
                  bottom: 0,
                  child: Center(
                    child: Icon(
                      checked
                          ? Icons.check_circle
                          : Icons.radio_button_unchecked,
                      key: ValueKey(checked ? 'note-checked' : 'note-unchecked'),
                      size: 22,
                      color: checked
                          ? theme.colorScheme.primary
                          : theme.colorScheme.onSurfaceVariant,
                    ),
                  ),
                ),
              // Barrita del color del grupo (2 px).
              if (showGroupHere && !selectionMode)
                PositionedDirectional(
                  start: 8,
                  top: 12,
                  bottom: 12,
                  width: 2,
                  child: DecoratedBox(
                    key: const ValueKey('note-group-bar'),
                    decoration: BoxDecoration(
                      color: groupColor,
                      borderRadius: BorderRadius.circular(1),
                    ),
                  ),
                ),
              AnimatedPadding(
                duration: const Duration(milliseconds: 150),
                padding: EdgeInsetsDirectional.fromSTEB(
                    selectionMode ? 46 : 22, 12, 12, 12),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.baseline,
                      textBaseline: TextBaseline.alphabetic,
                      children: [
                        Expanded(
                          child: _highlighted(
                            context,
                            l10n.displayTitle(note),
                            style: theme.textTheme.titleMedium?.copyWith(
                              fontWeight: FontWeight.w600,
                              fontStyle:
                                  note.hasTitle ? null : FontStyle.italic,
                              color: note.hasTitle ? null : muted,
                            ),
                          ),
                        ),
                        const SizedBox(width: 8),
                        // Fecha (con el alfiler si está fijada): la fecha
                        // se alinea por línea base con el título; el
                        // alfiler, inclinado como 📌, se centra con la fecha.
                        Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            if (pinned) ...[
                              NoBaseline(
                                child: Transform.rotate(
                                  angle: math.pi / 4,
                                  child: Icon(
                                    Icons.push_pin,
                                    key: const ValueKey('note-pin-icon'),
                                    size: 17,
                                    color: muted,
                                    semanticLabel: l10n.pinnedNotes,
                                  ),
                                ),
                              ),
                              const SizedBox(width: 4),
                            ],
                            Text(
                              shortDate(note.modifiedAt, l10n),
                              style: theme.textTheme.bodySmall
                                  ?.copyWith(color: muted),
                            ),
                          ],
                        ),
                      ],
                    ),
                    const SizedBox(height: 4),
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.baseline,
                      textBaseline: TextBaseline.alphabetic,
                      children: [
                        Expanded(
                          child: _buildPreview(
                            context,
                            l10n,
                            theme.textTheme.bodyMedium?.copyWith(
                              color: muted,
                              fontStyle: note.content.trim().isEmpty
                                  ? FontStyle.italic
                                  : null,
                            ),
                          ),
                        ),
                        if (showGroupHere) ...[
                          const SizedBox(width: 8),
                          // Nombre + carpetita: el nombre se alinea por línea
                          // base con la vista previa; la carpetita (sin línea
                          // base) se centra en vertical con el nombre.
                          Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              // Un poco más chico que la vista previa, en gris.
                              Text(
                                group,
                                key: const ValueKey('note-group-label'),
                                maxLines: 1,
                                style: theme.textTheme.bodyMedium?.copyWith(
                                  fontSize: 12.5,
                                  color: muted,
                                  fontWeight: FontWeight.w500,
                                ),
                              ),
                              const SizedBox(width: 5),
                              GroupFolderIcon(
                                groupColor,
                                key: const ValueKey('note-group-folder'),
                                size: 14,
                              ),
                            ],
                          ),
                        ],
                      ],
                    ),
                    ..._buildMatches(context),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  /// La píldora "N coincidencias" y, desplegada, una línea por coincidencia.
  List<Widget> _buildMatches(BuildContext context) {
    final search = this.search;
    final toggle = onToggleMatches;
    if (search == null || toggle == null) return const [];
    final matches = search.matchesIn(note);
    if (matches.length < 2) return const [];
    final l10n = context.l10n;
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final small = theme.textTheme.bodySmall?.copyWith(
      fontSize: 12.5,
      color: scheme.onSurface,
      fontWeight: FontWeight.w500,
    );
    final shown = matchesExpanded
        ? (matchesShown < matches.length ? matchesShown : matches.length)
        : 0;
    final remaining = matches.length - shown;
    final pill = StadiumBorder(side: BorderSide(color: scheme.outline));
    return [
      const SizedBox(height: 8),
      Material(
        key: const ValueKey('note-matches-pill'),
        shape: pill,
        color: scheme.surfaceContainerHighest,
        child: InkWell(
          customBorder: pill,
          onTap: toggle,
          child: Padding(
            padding: const EdgeInsetsDirectional.fromSTEB(10, 4, 6, 4),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(l10n.matchesCount(matches.length), style: small),
                const SizedBox(width: 2),
                Icon(
                  matchesExpanded ? Icons.expand_less : Icons.expand_more,
                  size: 18,
                  color: scheme.onSurfaceVariant,
                ),
              ],
            ),
          ),
        ),
      ),
      if (shown > 0) const SizedBox(height: 6),
      for (var i = 0; i < shown; i++) _buildMatch(context, matches[i], i),
      if (matchesExpanded && remaining > 0)
        TextButton(
          key: const ValueKey('note-matches-more'),
          onPressed: onShowMoreMatches,
          style: TextButton.styleFrom(
            visualDensity: VisualDensity.compact,
            padding: const EdgeInsetsDirectional.only(start: 12, end: 12),
          ),
          child: Text(l10n.showMoreMatches(
              remaining < matchesShownStep ? remaining : matchesShownStep)),
        ),
    ];
  }

  /// De cuántas en cuántas se despliegan las coincidencias.
  static const int matchesShownStep = 10;

  /// Una coincidencia desplegada: su número y el pedazo de texto donde está.
  Widget _buildMatch(
      BuildContext context, (bool, int, int) match, int index) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final (inTitle, start, _) = match;
    final excerpt = inTitle
        ? note.title
        : NoteSearch.excerptAround(note.content, start);
    return InkWell(
      key: ValueKey('note-match-$index'),
      borderRadius: BorderRadius.circular(8),
      onTap: onOpenMatch == null ? null : () => onOpenMatch!(index),
      child: Container(
        margin: const EdgeInsetsDirectional.only(start: 2),
        padding: const EdgeInsetsDirectional.fromSTEB(10, 7, 4, 7),
        decoration: BoxDecoration(
          border: BorderDirectional(
            start: BorderSide(color: scheme.outlineVariant),
          ),
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.baseline,
          textBaseline: TextBaseline.alphabetic,
          children: [
            SizedBox(
              width: 22,
              child: Text(
                '${index + 1}',
                style: theme.textTheme.bodySmall
                    ?.copyWith(color: scheme.onSurfaceVariant),
              ),
            ),
            Expanded(
              child: _highlighted(
                context,
                excerpt,
                style: theme.textTheme.bodyMedium
                    ?.copyWith(color: scheme.onSurfaceVariant),
              ),
            ),
          ],
        ),
      ),
    );
  }

  /// La vista previa: buscando, el pedazo que coincide; si no, según
  /// [preview].
  Widget _buildPreview(
      BuildContext context, AppLocalizations l10n, TextStyle? style) {
    final content = note.content;
    if (search != null || content.trim().isEmpty) {
      return _highlighted(
          context, previewOf(note, l10n, text: search?.snippetOf(note)),
          style: style);
    }
    String? text;
    switch (preview) {
      case NoteOpenPosition.start:
        text = previewOf(note, l10n);
      case NoteOpenPosition.cursor:
      case NoteOpenPosition.scroll:
        final at = fromChar;
        // Sin posición guardada: el principio. En un renglón vacío al
        // final: el final.
        text = at == null ? previewOf(note, l10n) : previewFromLine(content, at);
      case NoteOpenPosition.end:
        break;
    }
    if (text != null) {
      return Text(text,
          key: const ValueKey('note-preview'),
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: style);
    }
    return _TailPreview(content, style: style);
  }

  /// Desde el principio del renglón donde está [cursor] ("… " si hay texto
  /// antes). `null` si de ahí en adelante no hay nada (entonces conviene
  /// mostrar el final).
  static String? previewFromLine(String content, int cursor) {
    cursor = cursor.clamp(0, content.length);
    final lineStart =
        cursor == 0 ? 0 : content.lastIndexOf('\n', cursor - 1) + 1;
    final rest = content.substring(lineStart).trim();
    if (rest.isEmpty) return null;
    final before = content.substring(0, lineStart).trim().isNotEmpty;
    final start = rest.length > 200
        ? rest.substring(0, NoteSearch.safeCut(rest, 200))
        : rest;
    return '${before ? '… ' : ''}${oneLine(start)}';
  }

  /// Los renglones unidos con " · ".
  static String oneLine(String text) =>
      text.replaceAll(RegExp(r'\s*\n\s*'), ' · ');

  /// Inicio del texto (o [text], si se da: un pedazo), en una sola línea.
  static String previewOf(Note note, AppLocalizations l10n, {String? text}) {
    text = (text ?? note.content).trim();
    if (text.isEmpty) return l10n.noPreview;
    final start = text.length > 200
        ? text.substring(0, NoteSearch.safeCut(text, 200))
        : text;
    return oneLine(start);
  }
}

/// El final del texto en una sola línea: "… lo último que se escribió".
/// Se mide cuánto cabe para que se corte al principio y no al final.
class _TailPreview extends StatelessWidget {
  const _TailPreview(this.content, {required this.style});

  final String content;
  final TextStyle? style;

  /// Cuánto del final se considera (de sobra para un renglón).
  static const int _window = 400;

  @override
  Widget build(BuildContext context) {
    final text = content.trim();
    var start = math.max(0, text.length - _window);
    // No partir un emoji (par de mitades UTF-16).
    if (start > 0 && _isLowSurrogate(text.codeUnitAt(start))) start++;
    final tail = NoteRow.oneLine(text.substring(start));
    final cut = start > 0;
    final effective = DefaultTextStyle.of(context).style.merge(style);
    final scaler = MediaQuery.textScalerOf(context);
    final direction = Directionality.of(context);
    return LayoutBuilder(builder: (context, constraints) {
      final painter = TextPainter(
        textDirection: direction,
        textScaler: scaler,
        maxLines: 1,
      );
      bool fits(String s) {
        painter.text = TextSpan(text: s, style: effective);
        painter.layout();
        return painter.width <= constraints.maxWidth;
      }

      String shown;
      if (!cut && fits(tail)) {
        shown = tail;
      } else {
        // El pedazo más largo del final que cabe después de "… ".
        var lo = 0, hi = tail.length;
        while (lo < hi) {
          final mid = (lo + hi) ~/ 2;
          if (fits('… ${tail.substring(mid)}')) {
            hi = mid;
          } else {
            lo = mid + 1;
          }
        }
        if (lo < tail.length && _isLowSurrogate(tail.codeUnitAt(lo))) lo++;
        shown = '… ${tail.substring(lo).trimLeft()}';
      }
      painter.dispose();
      return Text(shown,
          key: const ValueKey('note-preview'),
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: style);
    });
  }

  static bool _isLowSurrogate(int unit) => unit >= 0xDC00 && unit <= 0xDFFF;
}
