import 'package:flutter/material.dart';

import '../l10n/l10n.dart';
import '../models/group_filter.dart';
import '../models/note_group.dart';
import 'group_colors.dart';
import 'group_panel.dart' show GroupAction;

/// Barra lateral de grupos para pantallas anchas (PC), como en el diseño
/// "PC · Panel lateral + lista + editor" (lienzo de propuestas v1):
///
///   Synced Notes
///   Todas                 14
///   Sin grupo              4
///   GRUPOS            [📁+]
///   Frases                 4   ⋮
///   Recetas                3   ⋮
///   …
///   ⚙ Ajustes
///
/// Los grupos llevan su nombre en su color (igual que en el celular). Cada
/// grupo tiene ⋮ (al pasar el mouse) y clic derecho con Renombrar, Color y
/// Borrar.
class GroupSidebar extends StatelessWidget {
  const GroupSidebar({
    super.key,
    required this.groups,
    required this.selected,
    required this.totalNotes,
    required this.counts,
    required this.onSelect,
    required this.onCreate,
    required this.onGroupAction,
    required this.onOpenSettings,
  });

  final List<NoteGroup> groups;
  final GroupFilter selected;
  final int totalNotes;
  final Map<String?, int> counts;
  final ValueChanged<GroupFilter> onSelect;
  final VoidCallback onCreate;
  final void Function(GroupAction action, NoteGroup group) onGroupAction;
  final VoidCallback onOpenSettings;

  static const double width = 260;

  /// Distancia del borde derecho de los contadores al borde de la lista
  /// (4 de margen de la fila + 36 reservados para el ⋮).
  static const double _countRightEdge = 40;

  /// Mitad del ancho de un número de un dígito (para centrar el ícono de
  /// "Nuevo grupo" sobre los contadores).
  static const double _digitHalfWidth = 4;

  static const double _newGroupButton = 32;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;

    Widget item({
      required String label,
      required GroupFilter filter,
      required int notes,
      Color? color,
      NoteGroup? group,
    }) =>
        _SidebarItem(
          label: label,
          color: color,
          count: notes,
          selected: filter == selected,
          onTap: () => onSelect(filter),
          onAction: group == null
              ? null
              : (action) => onGroupAction(action, group),
        );

    return Material(
      color: scheme.surfaceContainerLow,
      child: SafeArea(
        right: false,
        child: SizedBox(
          width: width,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(20, 20, 16, 16),
                // Nombre de la app: no se traduce.
                child: Text(
                  'Synced Notes',
                  style: theme.textTheme.titleLarge
                      ?.copyWith(fontWeight: FontWeight.w700),
                ),
              ),
              Expanded(
                child: ListView(
                  padding: const EdgeInsets.symmetric(horizontal: 10),
                  children: [
                    item(
                      label: l10n.groupsAll,
                      filter: GroupFilter.all,
                      notes: totalNotes,
                    ),
                    // "Sin grupo" solo tiene sentido cuando ya hay grupos.
                    if (groups.isNotEmpty)
                      item(
                        label: l10n.groupsNone,
                        filter: GroupFilter.none,
                        notes: counts[null] ?? 0,
                        color: scheme.onSurfaceVariant,
                      ),
                    Padding(
                      padding: const EdgeInsetsDirectional.fromSTEB(
                          10, 16, 0, 4),
                      child: Row(
                        children: [
                          Expanded(
                            child: Text(
                              l10n.noteGroupsTitle.toUpperCase(),
                              style: theme.textTheme.labelSmall?.copyWith(
                                color: scheme.onSurfaceVariant,
                                fontWeight: FontWeight.w600,
                                letterSpacing: 0.6,
                              ),
                            ),
                          ),
                          // En la misma columna que los contadores de las
                          // filas: su borde derecho queda a 40 px (4 de margen
                          // + 36 del lugar del ⋮), y el ícono se centra sobre
                          // ellos.
                          IconButton(
                            tooltip: '${l10n.newGroup} (Ctrl+Shift+N)',
                            onPressed: onCreate,
                            iconSize: 20,
                            style: IconButton.styleFrom(
                              fixedSize: const Size.square(_newGroupButton),
                              minimumSize: const Size.square(_newGroupButton),
                              padding: EdgeInsets.zero,
                              tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                            ),
                            icon:
                                const Icon(Icons.create_new_folder_outlined),
                          ),
                          const SizedBox(
                              width: _countRightEdge - _newGroupButton / 2 +
                                  _digitHalfWidth),
                        ],
                      ),
                    ),
                    for (final group in groups)
                      item(
                        label: group.name,
                        filter: GroupFilter.group(group.name),
                        notes: counts[group.name] ?? 0,
                        color: group.color == null
                            ? null
                            : displayColor(group.color!, theme.brightness),
                        group: group,
                      ),
                  ],
                ),
              ),
              const Divider(height: 1),
              Padding(
                padding: const EdgeInsets.all(10),
                child: _SidebarItem(
                  label: l10n.settingsTitle,
                  icon: Icons.settings_outlined,
                  color: scheme.onSurfaceVariant,
                  selected: false,
                  onTap: onOpenSettings,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Una fila de la barra lateral: nombre, contador y (en los grupos) ⋮.
class _SidebarItem extends StatefulWidget {
  const _SidebarItem({
    required this.label,
    required this.selected,
    required this.onTap,
    this.color,
    this.count,
    this.icon,
    this.onAction,
  });

  final String label;
  final bool selected;
  final VoidCallback onTap;
  final Color? color;
  final int? count;
  final IconData? icon;

  /// Menú del grupo. `null` = no es un grupo (Todas, Sin grupo, Ajustes).
  final void Function(GroupAction action)? onAction;

  @override
  State<_SidebarItem> createState() => _SidebarItemState();
}

class _SidebarItemState extends State<_SidebarItem> {
  bool _hovered = false;

  List<PopupMenuEntry<GroupAction>> _menuItems(BuildContext context) {
    final l10n = context.l10n;
    return [
      PopupMenuItem(value: GroupAction.rename, child: Text(l10n.rename)),
      PopupMenuItem(value: GroupAction.color, child: Text(l10n.groupColor)),
      PopupMenuItem(value: GroupAction.delete, child: Text(l10n.delete)),
    ];
  }

  Future<void> _menuAt(Offset position) async {
    final onAction = widget.onAction;
    if (onAction == null) return;
    final overlay =
        Overlay.of(context).context.findRenderObject()! as RenderBox;
    final action = await showMenu<GroupAction>(
      context: context,
      position: RelativeRect.fromRect(
        position & const Size(1, 1),
        Offset.zero & overlay.size,
      ),
      items: _menuItems(context),
    );
    if (action != null) onAction(action);
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final onAction = widget.onAction;
    final textColor = widget.color ?? scheme.onSurface;
    return MouseRegion(
      onEnter: (_) => setState(() => _hovered = true),
      onExit: (_) => setState(() => _hovered = false),
      child: GestureDetector(
        onSecondaryTapUp: onAction == null
            ? null
            : (details) => _menuAt(details.globalPosition),
        onLongPressStart: onAction == null
            ? null
            : (details) => _menuAt(details.globalPosition),
        child: Material(
          type: MaterialType.transparency,
          child: ListTile(
            dense: true,
            visualDensity: VisualDensity.compact,
            contentPadding: const EdgeInsetsDirectional.only(start: 10, end: 4),
            minTileHeight: 40,
            shape:
                RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
            selected: widget.selected,
            selectedTileColor: scheme.secondaryContainer,
            leading: widget.icon == null
                ? null
                : Icon(widget.icon, size: 20, color: textColor),
            minLeadingWidth: 0,
            horizontalTitleGap: 10,
            title: Text(
              widget.label,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: theme.textTheme.bodyMedium?.copyWith(
                color: textColor,
                fontWeight: widget.color != null && widget.onAction != null
                    ? FontWeight.w600
                    : FontWeight.w500,
              ),
            ),
            trailing: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                if (widget.count != null)
                  Text(
                    '${widget.count}',
                    style: theme.textTheme.bodySmall
                        ?.copyWith(color: scheme.onSurfaceVariant),
                  ),
                // Lugar del ⋮: siempre reservado, para que los contadores no
                // se muevan al pasar el mouse.
                SizedBox(
                  width: 36,
                  child: onAction == null || !(_hovered || widget.selected)
                      ? null
                      : PopupMenuButton<GroupAction>(
                          tooltip: context.l10n.groupOptions,
                          iconSize: 18,
                          padding: EdgeInsets.zero,
                          icon: const Icon(Icons.more_vert),
                          onSelected: onAction,
                          itemBuilder: _menuItems,
                        ),
                ),
              ],
            ),
            onTap: widget.onTap,
          ),
        ),
      ),
    );
  }
}
