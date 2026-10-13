import 'package:flutter/material.dart';

import '../l10n/l10n.dart';
import '../models/note.dart';
import '../utils/date_text.dart';

/// Una nota de la lista (la usan la vista de celular y la de PC):
///   ▍ Título                     18:44
///   ▍ inicio del texto…        Recetas
///
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
                          child: Text(
                            l10n.displayTitle(note),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
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
                          child: Text(
                            previewOf(note, l10n),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
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
                          // Un poco más chico que la vista previa.
                          Text(
                            group,
                            key: const ValueKey('note-group-label'),
                            maxLines: 1,
                            style: theme.textTheme.bodyMedium?.copyWith(
                              fontSize: 12.5,
                              color: groupColor,
                              fontWeight: FontWeight.w500,
                            ),
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

  /// Inicio del texto, en una sola línea.
  static String previewOf(Note note, AppLocalizations l10n) {
    final text = note.content.trim();
    if (text.isEmpty) return l10n.noPreview;
    final start = text.length > 200 ? text.substring(0, 200) : text;
    return start.replaceAll(RegExp(r'\s*\n\s*'), ' · ');
  }
}
