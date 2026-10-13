import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart' show RenderAbstractViewport;

import '../l10n/l10n.dart';
import '../models/group_filter.dart';
import '../models/note_group.dart';
import 'group_colors.dart';

/// Qué se pidió hacer con un grupo desde el panel.
enum GroupAction { rename, color, delete }

/// Panel de grupos de la lista (diseño v2 del celular, tablero "Final" del
/// lienzo "Propuestas v2").
///
/// Cerrado, solo se ve abajo:
///        ───            ← asa
///   Grupos de notas
///   [📁+] [Todas] [Sin grupo] [Recetas] [Rutinas] …   ← se desliza de lado
///
/// Al deslizarlo hacia arriba **sigue al dedo** y, al soltar, termina de
/// abrirse o de cerrarse solo, con animación. Abierto muestra además un
/// buscador y todos los grupos (con cuántas notas tiene cada uno y su ⋮ con
/// Renombrar, Color y Borrar). Tocar el asa (o "Grupos de notas") lo abre o
/// lo cierra; tocar fuera, o el botón Atrás, lo cierra.
///
/// Mantener presionado (o clic derecho) un chip de grupo: el mismo menú
/// que el ⋮.
///
/// Va como último hijo de un `Stack` que ocupa el cuerpo de la pantalla:
/// así, abierto, queda encima de la lista y del botón "Nueva nota".
class GroupPanel extends StatefulWidget {
  const GroupPanel({
    super.key,
    required this.groups,
    required this.selected,
    required this.totalNotes,
    required this.counts,
    required this.onSelect,
    required this.onCreate,
    required this.onGroupAction,
  });

  final List<NoteGroup> groups;
  final GroupFilter selected;

  /// Cuántas notas hay en total y por grupo (clave `null` = sin grupo).
  final int totalNotes;
  final Map<String?, int> counts;

  final ValueChanged<GroupFilter> onSelect;
  final VoidCallback onCreate;
  final void Function(GroupAction action, NoteGroup group) onGroupAction;

  /// Alto del panel cerrado (sin contar el borde inferior del sistema).
  static const double collapsedHeight = 112;

  /// Alto del panel cerrado, contando el borde inferior del sistema (la
  /// barra de gestos de Android). La lista deja este espacio libre abajo.
  static double collapsedHeightOf(BuildContext context) =>
      collapsedHeight + MediaQuery.paddingOf(context).bottom;

  @override
  State<GroupPanel> createState() => _GroupPanelState();
}

class _GroupPanelState extends State<GroupPanel> {
  final DraggableScrollableController _sheet = DraggableScrollableController();
  final TextEditingController _search = TextEditingController();
  /// Una llave fija por chip (por lo que muestra), para encontrar el chip
  /// elegido. Antes había una sola llave que pasaba de un chip a otro, y el
  /// chip recién elegido arrancaba con el color del anterior por un instante.
  final Map<String, GlobalKey> _chipKeys = {};

  GlobalKey _chipKey(GroupFilter filter) =>
      _chipKeys.putIfAbsent(filter.encode(), GlobalKey.new);
  final ScrollController _chips = ScrollController();

  static const double _maxSize = 0.88;
  static const Duration _animation = Duration(milliseconds: 300);

  double _minSize = 0.2;

  /// Alto disponible (para convertir lo que se mueve el dedo en tamaño).
  double _height = 1;

  /// Qué tan abierto está: 0 = cerrado, 1 = abierto del todo.
  /// Se actualiza en cada cuadro mientras el panel se mueve; solo lo
  /// escucha el fondo oscurecido, para no reconstruir todo el panel en cada
  /// cuadro (eso lo hacía sentirse pesado).
  final ValueNotifier<double> _openness = ValueNotifier<double>(0);

  /// Abierto o cerrado: solo cambia al cruzar el umbral.
  bool _isOpen = false;


  @override
  void initState() {
    super.initState();
    _revealSelectedChip(animate: false);
  }

  @override
  void didUpdateWidget(GroupPanel oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.selected != widget.selected) _revealSelectedChip();
  }

  @override
  void dispose() {
    _sheet.dispose();
    _search.dispose();
    _openness.dispose();
    _chips.dispose();
    super.dispose();
  }

  /// Si el chip elegido quedó fuera de la vista, desliza la fila de chips
  /// hasta él. Solo mueve la fila (de lado): `Scrollable.ensureVisible`
  /// movía también el panel hacia abajo y escondía el asa.
  void _revealSelectedChip({bool animate = true}) {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final chip =
          _chipKey(widget.selected).currentContext?.findRenderObject();
      if (chip == null || !mounted || !_chips.hasClients) return;
      final viewport = RenderAbstractViewport.maybeOf(chip);
      if (viewport == null) return;
      final position = _chips.position;
      final target = viewport
          .getOffsetToReveal(chip, 0.5)
          .offset
          .clamp(position.minScrollExtent, position.maxScrollExtent);
      if (animate) {
        _chips.animateTo(target,
            duration: const Duration(milliseconds: 250), curve: Curves.easeOut);
      } else {
        _chips.jumpTo(target);
      }
    });
  }

  void _animateTo(double size) {
    if (!_sheet.isAttached) return;
    _sheet.animateTo(size, duration: _animation, curve: Curves.easeOutCubic);
  }

  void _open() => _animateTo(_maxSize);

  void _close() {
    FocusScope.of(context).unfocus();
    if (_search.text.isNotEmpty) setState(_search.clear);
    _animateTo(_minSize);
  }

  void _toggle() => _isOpen ? _close() : _open();

  // Arrastre sobre el asa y los chips: el panel sigue al dedo y, al soltar,
  // termina de abrirse o cerrarse según la velocidad o qué tan abierto quedó.
  // (Se maneja aquí y no con el desplazamiento de la lista para que siempre
  // responda igual, aunque la lista de grupos esté desplazada.)
  void _onDragUpdate(DragUpdateDetails details) {
    if (!_sheet.isAttached) return;
    final size =
        (_sheet.size - details.delta.dy / _height).clamp(_minSize, _maxSize);
    _sheet.jumpTo(size);
  }

  void _onDragEnd(DragEndDetails details) {
    if (!_sheet.isAttached) return;
    final velocity = details.primaryVelocity ?? 0; // positiva = hacia abajo
    if (velocity < -300) {
      _open();
    } else if (velocity > 300) {
      _close();
    } else if (_sheet.size - _minSize > _maxSize - _sheet.size) {
      _open();
    } else {
      _close();
    }
  }

  void _select(GroupFilter filter) {
    widget.onSelect(filter);
    if (_isOpen) _close();
  }

  bool _onSheetMoved(DraggableScrollableNotification n) {
    final range = n.maxExtent - n.minExtent;
    final openness =
        range <= 0 ? 0.0 : ((n.extent - n.minExtent) / range).clamp(0.0, 1.0);
    _openness.value = openness;
    final isOpen = openness > 0.01;
    if (isOpen != _isOpen) setState(() => _isOpen = isOpen);
    return false;
  }

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(builder: (context, constraints) {
      final height = constraints.maxHeight;
      _height = height;
      final collapsed = GroupPanel.collapsedHeightOf(context);
      _minSize = (collapsed / height).clamp(0.05, _maxSize);

      return PopScope(
        // Abierto, el botón Atrás primero lo cierra.
        canPop: !_isOpen,
        onPopInvokedWithResult: (didPop, _) {
          if (!didPop) _close();
        },
        child: Stack(
          children: [
            // Fondo oscurecido (según qué tan abierto esté). Tocarlo cierra.
            if (_isOpen)
              Positioned.fill(
                child: GestureDetector(
                  key: const ValueKey('group-panel-scrim'),
                  behavior: HitTestBehavior.opaque,
                  onTap: _close,
                  child: ValueListenableBuilder<double>(
                    valueListenable: _openness,
                    builder: (context, openness, _) => ColoredBox(
                      color: Colors.black.withValues(alpha: 0.5 * openness),
                    ),
                  ),
                ),
              ),
            NotificationListener<DraggableScrollableNotification>(
              onNotification: _onSheetMoved,
              child: DraggableScrollableSheet(
                controller: _sheet,
                initialChildSize: _minSize,
                minChildSize: _minSize,
                maxChildSize: _maxSize,
                snap: true,
                snapAnimationDuration: _animation,
                shouldCloseOnMinExtent: false,
                builder: _buildSheet,
              ),
            ),
          ],
        ),
      );
    });
  }

  Widget _buildSheet(BuildContext context, ScrollController scroll) {
    final l10n = context.l10n;
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final query = _search.text.trim().toLowerCase();
    final searching = query.isNotEmpty;
    final matches = widget.groups
        .where((g) => g.name.toLowerCase().contains(query))
        .toList();

    Color colorOf(NoteGroup group) => group.color == null
        ? scheme.onSurface
        : displayColor(group.color!, theme.brightness);

    return Material(
      color: scheme.surfaceContainer,
      elevation: _isOpen ? 8 : 0,
      clipBehavior: Clip.antiAlias,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      child: CustomScrollView(
        controller: scroll,
        slivers: [
          SliverToBoxAdapter(
            child: GestureDetector(
              behavior: HitTestBehavior.opaque,
              onVerticalDragUpdate: _onDragUpdate,
              onVerticalDragEnd: _onDragEnd,
              child: Column(
                children: [
                  _buildHandle(context),
                  _buildChips(context, colorOf),
                ],
              ),
            ),
          ),
          // Lo de abajo solo se ve con el panel abierto.
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 8),
              child: TextField(
                controller: _search,
                onChanged: (_) => setState(() {}),
                onTap: _open,
                decoration: InputDecoration(
                  hintText: l10n.searchGroupsHint,
                  prefixIcon: const Icon(Icons.search),
                  filled: true,
                  fillColor: scheme.surfaceContainerHighest,
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(24),
                    borderSide: BorderSide.none,
                  ),
                  contentPadding: const EdgeInsets.symmetric(vertical: 12),
                ),
              ),
            ),
          ),
          SliverPadding(
            padding: EdgeInsets.fromLTRB(
                8, 0, 8, 24 + MediaQuery.paddingOf(context).bottom),
            sliver: SliverList.list(children: [
              if (!searching) ...[
                _tile(
                  label: l10n.groupsAll,
                  filter: GroupFilter.all,
                  notes: widget.totalNotes,
                ),
                _tile(
                  label: l10n.groupsNone,
                  filter: GroupFilter.none,
                  notes: widget.counts[null] ?? 0,
                ),
                if (widget.groups.isNotEmpty)
                  const Divider(indent: 12, endIndent: 12),
              ],
              for (final group in matches)
                _tile(
                  label: group.name,
                  color: group.color == null ? null : colorOf(group),
                  filter: GroupFilter.group(group.name),
                  notes: widget.counts[group.name] ?? 0,
                  group: group,
                ),
              if (searching && matches.isEmpty)
                Padding(
                  padding: const EdgeInsets.all(24),
                  child: Text(
                    l10n.noGroupsFound,
                    textAlign: TextAlign.center,
                    style: theme.textTheme.bodyMedium
                        ?.copyWith(color: scheme.onSurfaceVariant),
                  ),
                ),
            ]),
          ),
        ],
      ),
    );
  }

  /// Asa + "Grupos de notas". Tocarlos abre o cierra el panel.
  Widget _buildHandle(BuildContext context) {
    final l10n = context.l10n;
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    return Semantics(
      button: true,
      label: l10n.showAllGroups,
      excludeSemantics: true,
      child: InkWell(
        onTap: _toggle,
        // Todo el ancho del panel se puede tocar, no solo el texto...
        child: SizedBox(
          width: double.infinity,
          height: 44,
          child: Center(
            // ...pero el tooltip (en PC, al pasar el mouse) solo aparece
            // sobre el asa y el texto.
            child: Tooltip(
              message: l10n.showAllGroups,
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 8),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Container(
                      width: 36,
                      height: 4,
                      decoration: BoxDecoration(
                        color: scheme.outline,
                        borderRadius: BorderRadius.circular(2),
                      ),
                    ),
                    const SizedBox(height: 6),
                    Text(
                      l10n.noteGroupsTitle,
                      style: theme.textTheme.bodyMedium
                          ?.copyWith(color: scheme.onSurfaceVariant),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  /// [📁+] [Todas] [Sin grupo] [grupos…], deslizable de lado.
  Widget _buildChips(
      BuildContext context, Color Function(NoteGroup) colorOf) {
    final l10n = context.l10n;
    final scheme = Theme.of(context).colorScheme;
    final selected = widget.selected;

    Widget chip({
      required String label,
      required GroupFilter filter,
      required Color color,
      FontWeight weight = FontWeight.w600,
      NoteGroup? group,
    }) {
      final isSelected = filter == selected;
      return GroupChip(
        key: _chipKey(filter),
        label: label,
        color: color,
        weight: weight,
        selected: isSelected,
        onTap: () => _select(filter),
        onMenu: group == null
            ? null
            : (position) => _showGroupMenu(group, position),
      );
    }

    final chips = <Widget>[
      chip(
        label: l10n.groupsAll,
        filter: GroupFilter.all,
        color: scheme.onSurface,
      ),
      // "Sin grupo" solo tiene sentido cuando ya existe algún grupo.
      if (widget.groups.isNotEmpty)
        chip(
          label: l10n.groupsNone,
          filter: GroupFilter.none,
          color: scheme.onSurfaceVariant,
          weight: FontWeight.w500,
        ),
      for (final group in widget.groups)
        chip(
          label: group.name,
          filter: GroupFilter.group(group.name),
          color: colorOf(group),
          group: group,
        ),
    ];

    return SizedBox(
      height: GroupPanel.collapsedHeight - 44,
      child: Align(
        alignment: Alignment.topCenter,
        child: SizedBox(
          height: 60,
          child: ListView(
            controller: _chips,
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.fromLTRB(12, 8, 12, 8),
            children: [
              _NewGroupButton(onPressed: widget.onCreate),
              for (final c in chips) ...[const SizedBox(width: 8), c],
            ],
          ),
        ),
      ),
    );
  }

  /// Una fila de la lista completa de grupos (panel abierto).
  Widget _tile({
    required String label,
    required GroupFilter filter,
    required int notes,
    Color? color,
    NoteGroup? group,
  }) {
    final l10n = context.l10n;
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final isSelected = filter == widget.selected;
    return ListTile(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      selected: isSelected,
      selectedColor: scheme.onSurface,
      selectedTileColor: scheme.secondaryContainer,
      title: Text(
        label,
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
        style: color == null
            ? null
            : TextStyle(color: color, fontWeight: FontWeight.w600),
      ),
      trailing: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text('$notes',
              style: theme.textTheme.bodyMedium
                  ?.copyWith(color: scheme.onSurfaceVariant)),
          if (group != null)
            PopupMenuButton<GroupAction>(
              tooltip: l10n.groupOptions,
              icon: const Icon(Icons.more_vert),
              onSelected: (action) => widget.onGroupAction(action, group),
              itemBuilder: (context) => _menuItems(context),
            )
          else
            const SizedBox(width: 48),
        ],
      ),
      onTap: () => _select(filter),
    );
  }

  List<PopupMenuEntry<GroupAction>> _menuItems(BuildContext context) {
    final l10n = context.l10n;
    return [
      PopupMenuItem(value: GroupAction.rename, child: Text(l10n.rename)),
      PopupMenuItem(value: GroupAction.color, child: Text(l10n.groupColor)),
      PopupMenuItem(value: GroupAction.delete, child: Text(l10n.delete)),
    ];
  }

  /// Menú de un chip de grupo (mantener presionado o clic derecho), en la
  /// posición del dedo.
  Future<void> _showGroupMenu(NoteGroup group, Offset position) async {
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
    if (action != null) widget.onGroupAction(action, group);
  }
}

/// Botón redondo con carpeta y "+": crea un grupo nuevo.
class _NewGroupButton extends StatelessWidget {
  const _NewGroupButton({required this.onPressed});

  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return IconButton(
      tooltip: context.l10n.newGroup,
      onPressed: onPressed,
      icon: const Icon(Icons.create_new_folder_outlined, size: 22),
      style: IconButton.styleFrom(
        fixedSize: const Size(44, 44),
        minimumSize: const Size(44, 44),
        backgroundColor: scheme.surfaceContainerHigh,
        foregroundColor: scheme.onSurface,
        side: BorderSide(color: scheme.outline),
      ),
    );
  }
}

/// Un chip de la fila de grupos: píldora de 44 px de alto con el nombre en
/// el color del grupo. El elegido se sombrea con un tono tenue de ese mismo
/// color (y su contorno se nota un poco más); su tamaño no cambia.
class GroupChip extends StatelessWidget {
  const GroupChip({
    super.key,
    required this.label,
    required this.color,
    required this.selected,
    required this.onTap,
    this.weight = FontWeight.w600,
    this.onMenu,
  });

  final String label;
  final Color color;
  final bool selected;
  final VoidCallback onTap;
  final FontWeight weight;

  /// Menú del grupo (mantener presionado o clic derecho). `null` = sin menú.
  final void Function(Offset position)? onMenu;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final shape = StadiumBorder(
      side: BorderSide(
        color: selected ? color.withValues(alpha: 0.55) : scheme.outline,
      ),
    );
    final menu = onMenu;
    return Semantics(
      selected: selected,
      child: GestureDetector(
        onLongPressStart:
            menu == null ? null : (details) => menu(details.globalPosition),
        onSecondaryTapUp:
            menu == null ? null : (details) => menu(details.globalPosition),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          decoration: ShapeDecoration(
            shape: shape,
            color: selected
                ? color.withValues(alpha: 0.18)
                : Colors.transparent,
          ),
          child: Material(
            type: MaterialType.transparency,
            child: InkWell(
              customBorder: shape,
              onTap: onTap,
              child: Container(
                height: 44,
                padding: const EdgeInsets.symmetric(horizontal: 16),
                alignment: Alignment.center,
                child: Text(
                  label,
                  maxLines: 1,
                  style: TextStyle(
                    fontSize: 15,
                    // El mismo grosor elegido o no: si el elegido fuera más
                    // grueso, el chip se ensancharía y empujaría a los demás.
                    fontWeight: weight,
                    color: color,
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
