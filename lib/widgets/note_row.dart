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
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  /// Inicio del texto (o [text], si se da: un pedazo), en una sola línea.
  static String previewOf(Note note, AppLocalizations l10n, {String? text}) {
    text = (text ?? note.content).trim();
    if (text.isEmpty) return l10n.noPreview;
    final start = text.length > 200 ? text.substring(0, 200) : text;
    return start.replaceAll(RegExp(r'\s*\n\s*'), ' · ');
  }
}
