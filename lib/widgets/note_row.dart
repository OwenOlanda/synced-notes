import 'package:flutter/material.dart';

import '../l10n/l10n.dart';
import '../models/note.dart';
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
    this.selected = false,
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

  /// La nota abierta en el editor (vista de PC): fondo resaltado.
  final bool selected;

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
      onLongPressStart: (details) => onMenu(details.globalPosition),
      child: Material(
        type: selected ? MaterialType.canvas : MaterialType.transparency,
        color: selected ? theme.colorScheme.surfaceContainerHighest : null,
        borderRadius: BorderRadius.circular(14),
        child: InkWell(
          borderRadius: BorderRadius.circular(14),
          onTap: onTap,
          child: Stack(
            children: [
              // Barrita del color del grupo (2 px).
              if (showGroupHere)
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
              Padding(
                padding: const EdgeInsetsDirectional.fromSTEB(22, 12, 12, 12),
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
                        Text(
                          shortDate(note.modifiedAt, l10n),
                          style:
                              theme.textTheme.bodySmall?.copyWith(color: muted),
                        ),
                      ],
                    ),
                    const SizedBox(height: 4),
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.baseline,
                      textBaseline: TextBaseline.alphabetic,
                      children: [
                        Expanded(
                          child: _highlighted(
                            context,
                            previewOf(note, l10n,
                                text: search?.snippetOf(note)),
                            style: theme.textTheme.bodyMedium?.copyWith(
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

  /// Inicio del texto (o [text], si se da: un pedazo), en una sola línea.
  static String previewOf(Note note, AppLocalizations l10n, {String? text}) {
    text = (text ?? note.content).trim();
    if (text.isEmpty) return l10n.noPreview;
    final start = text.length > 200
        ? text.substring(0, NoteSearch.safeCut(text, 200))
        : text;
    return start.replaceAll(RegExp(r'\s*\n\s*'), ' · ');
  }
}
