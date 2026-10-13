import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../l10n/l10n.dart';
import '../models/note_group.dart';
import '../models/group_filter.dart';
import '../models/note.dart';
import '../services/app_settings.dart';
import '../services/note_storage.dart';
import '../widgets/app_message.dart';
import '../widgets/group_colors.dart';
import '../widgets/group_dialogs.dart';
import '../widgets/group_panel.dart';
import '../widgets/group_sidebar.dart';
import '../widgets/note_row.dart';
import '../widgets/confirm_delete_dialog.dart';
import '../widgets/move_note_dialog.dart';
import 'note_editor_screen.dart';
import 'settings_screen.dart';

/// Pantalla principal: la lista de notas (diseño v2 del celular, tablero
/// "Final" del lienzo "Propuestas v2"; ver el documento de contexto).
/// - Arriba: "Synced Notes" y, debajo, qué se ve y cuántas notas hay
///   ("Todas · 7 notas").
/// - Cada nota: título, fecha y vista previa. En "Todas", además, una
///   barrita delgada del color de su grupo a la izquierda y el nombre del
///   grupo en su color (nada de eso si la nota no tiene grupo).
/// - Toca una nota para abrirla. Clic derecho (Windows) o mantener
///   presionado (Android): mover a otro grupo o borrar.
/// - Abajo, el panel de grupos ([GroupPanel]): chips que se deslizan de
///   lado y botón para crear grupo. Deslizarlo hacia arriba (sigue al dedo)
///   o tocar "Grupos de notas" lo abre con todos los grupos.
/// - Botón "Nueva nota" a la derecha, sobre el panel (en el grupo que se
///   está viendo; dentro de un grupo con color, el botón toma ese color).
///
/// En pantallas anchas (PC; ver [wideLayoutWidth]) cambia a la vista de
/// escritorio: barra lateral de grupos ([GroupSidebar]) + lista, con
/// "Nueva nota" arriba de la lista. Toda la lógica (cargar, elegir grupo,
/// crear/renombrar/borrar, mover notas) es la misma en las dos vistas.
class NotesListScreen extends StatefulWidget {
  const NotesListScreen({
    super.key,
    required this.storage,
    required this.settings,
  });

  final NoteStorage storage;
  final AppSettings settings;

  /// A partir de este ancho (en px lógicos) se usa la vista de PC: barra
  /// lateral de grupos + lista. Más angosto (celular, o una ventana de PC
  /// angosta), la vista de celular con el panel de grupos abajo.
  /// 840 es donde Material 3 empieza las pantallas "expandidas".
  static const double wideLayoutWidth = 840;

  @override
  State<NotesListScreen> createState() => _NotesListScreenState();
}

class _NotesListScreenState extends State<NotesListScreen> {
  List<Note>? _notes; // null = cargando
  List<NoteGroup> _groups = const [];
  Object? _loadError; // el texto se arma en build(), en el idioma actual

  /// Vista de PC: la nota abierta en la columna del editor (`null` =
  /// ninguna) y la llave para pedirle a ese editor que guarde antes de
  /// cerrarla o abrir otra. La llave también permite que el editor
  /// sobreviva si la ventana se hace angosta (pasa a ocupar toda la
  /// pantalla, sin perder lo escrito).
  Note? _openNote;
  GlobalKey<NoteEditorScreenState>? _editorKey;

  /// Recibe los atajos de teclado (Ctrl+N, Ctrl+Shift+N, Esc) cuando nada
  /// más tiene el foco.
  final FocusNode _shortcutsFocus = FocusNode(debugLabel: 'atajos de la lista');

  @override
  void dispose() {
    _shortcutsFocus.dispose();
    super.dispose();
  }

  /// Lo que se está viendo. Se recuerda en los ajustes.
  GroupFilter get _filter => widget.settings.selectedGroup;

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void didUpdateWidget(NotesListScreen oldWidget) {
    super.didUpdateWidget(oldWidget);
    // Si cambia la carpeta de notas (otro almacenamiento), releer todo.
    if (oldWidget.storage != widget.storage) _load();
  }

  Future<void> _load() async {
    try {
      final notes = await widget.storage.listNotes();
      final groups = await widget.storage.listGroups();
      if (!mounted) return;
      setState(() {
        _notes = notes;
        _groups = groups;
        _loadError = null;
      });
      // El grupo que se estaba viendo ya no existe (ej. se borró desde
      // el explorador): volver a "Todas".
      final filter = _filter;
      if (filter.isGroup &&
          !groups.any((c) => c.name == filter.name)) {
        await _select(GroupFilter.all);
      }
    } catch (e) {
      if (!mounted) return;
      setState(() => _loadError = e);
    }
  }

  Future<void> _select(GroupFilter filter) async {
    await widget.settings.setSelectedGroup(filter);
    if (mounted) setState(() {});
  }

  void _showError(Object error) {
    if (!mounted) return;
    final l10n = context.l10n;
    ScaffoldMessenger.of(context)
        .showMessage(l10n.errorText(error), isError: true);
  }

  bool get _isWide =>
      MediaQuery.sizeOf(context).width >= NotesListScreen.wideLayoutWidth;

  /// ¿Es la nota que está abierta en la columna del editor?
  bool _isOpenInPane(Note note) {
    final open = _openNote;
    return open != null &&
        open.isSaved &&
        open.fileName == note.fileName &&
        open.group == note.group;
  }

  /// Vista de PC: abre la nota en la columna del editor. Si ya había otra
  /// abierta, primero resuelve sus cambios (con autoguardado, se guardan;
  /// sin él, pregunta). Si se cancela, no cambia nada.
  Future<void> _openInPane(Note note) async {
    if (_isOpenInPane(note)) return;
    if (!await _closePane()) return;
    if (!mounted) return;
    setState(() {
      _openNote = note;
      _editorKey = GlobalKey<NoteEditorScreenState>();
    });
  }

  /// Cierra la nota de la columna del editor, resolviendo antes sus
  /// cambios. Devuelve `false` si el usuario decidió quedarse.
  Future<bool> _closePane() async {
    final editor = _editorKey?.currentState;
    if (editor != null && !await editor.prepareToLeave()) return false;
    if (mounted && _openNote != null) {
      setState(() {
        _openNote = null;
        _editorKey = null;
      });
      _shortcutsFocus.requestFocus(); // para que los atajos sigan funcionando
      await _load();
    }
    return true;
  }

  /// El editor de la columna se cerró solo (ya resolvió sus cambios).
  void _onPaneClosed() {
    setState(() {
      _openNote = null;
      _editorKey = null;
    });
    _shortcutsFocus.requestFocus(); // para que los atajos sigan funcionando
    _load();
  }

  Future<void> _open(Note note) async {
    if (_isWide) return _openInPane(note);
    await Navigator.of(context).push(MaterialPageRoute<void>(
      builder: (_) => NoteEditorScreen(
        note: note,
        storage: widget.storage,
        settings: widget.settings,
      ),
    ));
    await _load(); // al regresar, la lista refleja lo que se guardó o borró
  }

  Future<void> _openSettings() async {
    await Navigator.of(context).push(MaterialPageRoute<void>(
      builder: (_) => SettingsScreen(
        settings: widget.settings,
        notesFolder: widget.storage.folder,
      ),
    ));
  }

  /// Menú en la posición del clic (o del dedo).
  Future<String?> _menuAt(Offset position, List<PopupMenuEntry<String>> items) {
    final overlay = Overlay.of(context).context.findRenderObject()! as RenderBox;
    return showMenu<String>(
      context: context,
      position: RelativeRect.fromRect(
        position & const Size(1, 1),
        Offset.zero & overlay.size,
      ),
      items: items,
    );
  }

  // ---------------------------------------------------------------------------
  // Notas
  // ---------------------------------------------------------------------------

  Future<void> _showNoteMenu(Note note, Offset position) async {
    final l10n = context.l10n;
    final choice = await _menuAt(position, [
      PopupMenuItem(value: 'move', child: Text(l10n.moveTo)),
      PopupMenuItem(value: 'delete', child: Text(l10n.delete)),
    ]);
    switch (choice) {
      case 'move':
        await _move(note);
      case 'delete':
        await _delete(note);
    }
  }

  Future<void> _move(Note note) async {
    // Si está abierta en el editor, primero se guarda y se cierra.
    if (_isOpenInPane(note)) {
      final latest = _openNote!;
      if (!await _closePane()) return;
      note = latest;
    }
    if (!mounted) return;
    final target = await pickGroupForMove(
      context,
      storage: widget.storage,
      current: note.group,
    );
    if (target == null || !mounted) return;
    final messenger = ScaffoldMessenger.of(context);
    final l10n = context.l10n;
    try {
      await widget.storage.moveNote(note, target.group);
      final name = target.group;
      messenger.showMessage(
          name == null ? l10n.noteMovedToNone : l10n.noteMovedTo(name));
    } catch (e) {
      _showError(e);
    }
    await _load();
  }

  Future<void> _delete(Note note) async {
    final confirmed =
        await confirmDeleteNote(context, context.l10n.displayTitle(note));
    if (!confirmed || !mounted) return;
    // Si está abierta en el editor, se cierra sin preguntar: se va a borrar.
    if (_isOpenInPane(note)) {
      setState(() {
        _openNote = null;
        _editorKey = null;
      });
    }
    final messenger = ScaffoldMessenger.of(context);
    final l10n = context.l10n;
    try {
      await widget.storage
          .deleteNote(note.fileName!, group: note.group);
      messenger.showMessage(l10n.noteDeleted);
    } catch (e) {
      messenger.showMessage(l10n.deleteError(l10n.errorText(e)),
          isError: true);
    }
    await _load();
  }

  // ---------------------------------------------------------------------------
  // Grupos
  // ---------------------------------------------------------------------------

  /// Renombrar, cambiar color o borrar un grupo (desde su ⋮ en el panel
  /// abierto, o manteniendo presionado su chip).
  Future<void> _onGroupAction(GroupAction action, NoteGroup group) async {
    switch (action) {
      case GroupAction.rename:
        await _renameGroup(group);
      case GroupAction.color:
        await _changeColor(group);
      case GroupAction.delete:
        await _deleteGroup(group);
    }
  }

  Future<void> _createGroup() async {
    final l10n = context.l10n;
    String? created;
    final done = await showGroupNameDialog(
      context,
      title: l10n.newGroup,
      confirmLabel: l10n.create,
      showColor: true,
      onSubmit: (name, color) async {
        created =
            (await widget.storage.createGroup(name, color: color)).name;
      },
    );
    if (!done) return;
    await _load();
    // Recién creada: se abre para empezar a llenarla.
    await _select(GroupFilter.group(created!));
  }

  /// Si la nota abierta en el editor (vista de PC) está en ese grupo, la
  /// guarda y la cierra: renombrar o borrar el grupo mueve su archivo.
  Future<bool> _releaseGroup(String group) async {
    if (_openNote?.group != group) return true;
    return _closePane();
  }

  Future<void> _renameGroup(NoteGroup group) async {
    if (!await _releaseGroup(group.name) || !mounted) return;
    final l10n = context.l10n;
    String? newName;
    final done = await showGroupNameDialog(
      context,
      title: l10n.renameGroup,
      confirmLabel: l10n.rename,
      initialName: group.name,
      onSubmit: (name, _) async {
        newName =
            (await widget.storage.renameGroup(group.name, name)).name;
      },
    );
    if (!done) return;
    // Si era la que se estaba viendo, seguir viéndola con su nombre nuevo.
    if (_filter == GroupFilter.group(group.name)) {
      await _select(GroupFilter.group(newName!));
    }
    await _load();
  }

  Future<void> _changeColor(NoteGroup group) async {
    final choice = await showGroupColorDialog(
      context,
      groupName: group.name,
      current: group.color,
    );
    if (choice == null) return;
    try {
      await widget.storage.setGroupColor(group.name, choice.color);
    } catch (e) {
      _showError(e);
    }
    await _load();
  }

  Future<void> _deleteGroup(NoteGroup group) async {
    if (!await _releaseGroup(group.name) || !mounted) return;
    final noteCount = (_notes ?? const <Note>[])
        .where((n) => n.group == group.name)
        .length;
    final choice = await showDeleteGroupDialog(
      context,
      groupName: group.name,
      noteCount: noteCount,
    );
    if (choice == null || !mounted) return;
    final messenger = ScaffoldMessenger.of(context);
    final l10n = context.l10n;
    try {
      await widget.storage.deleteGroup(
        group.name,
        deleteNotes: choice == DeleteGroupChoice.deleteNotes,
      );
      messenger.showMessage(l10n.groupDeleted);
      if (_filter == GroupFilter.group(group.name)) {
        // Si sus notas pasaron a "Sin grupo", mostrarlas ahí.
        await _select(choice == DeleteGroupChoice.moveNotes
            ? GroupFilter.none
            : GroupFilter.all);
      }
    } catch (e) {
      _showError(e);
    }
    await _load();
  }

  // ---------------------------------------------------------------------------
  // Pantalla
  // ---------------------------------------------------------------------------

  /// Color de un grupo en pantalla. Sin color: el del texto.
  Color _colorOf(String group, ThemeData theme) {
    for (final c in _groups) {
      if (c.name == group && c.color != null) {
        return displayColor(c.color!, theme.brightness);
      }
    }
    return theme.colorScheme.onSurfaceVariant;
  }

  /// Cuántas notas hay en cada grupo (clave `null` = sin grupo).
  Map<String?, int> _countsByGroup() {
    final counts = <String?, int>{};
    for (final note in _notes ?? const <Note>[]) {
      counts[note.group] = (counts[note.group] ?? 0) + 1;
    }
    return counts;
  }

  /// Nombre de lo que se está viendo: "Todas", "Sin grupo" o el grupo.
  String _viewLabel(AppLocalizations l10n) {
    final filter = _filter;
    if (filter.isAll) return l10n.groupsAll;
    if (filter.isNone) return l10n.groupsNone;
    return filter.name!;
  }


  @override
  Widget build(BuildContext context) {
    final loaded = _notes != null && _loadError == null;
    final Widget page;
    if (loaded && _isWide) {
      page = _buildWide(context);
    } else if (loaded && _openNote != null) {
      // Había una nota abierta en la vista de PC y la ventana se hizo
      // angosta: el mismo editor (con lo escrito) pasa a ocupar toda la
      // pantalla.
      page = Scaffold(body: _buildPaneEditor());
    } else {
      page = _buildNarrow(context, loaded: loaded);
    }
    return CallbackShortcuts(
      bindings: {
        // Ctrl+N: nota nueva (en el grupo que se está viendo).
        const SingleActivator(LogicalKeyboardKey.keyN, control: true): () {
          if (loaded) _newNote();
        },
        // Ctrl+Shift+N: grupo nuevo.
        const SingleActivator(LogicalKeyboardKey.keyN,
            control: true, shift: true): () {
          if (loaded) _createGroup();
        },
        // Esc: cerrar la nota abierta en la columna del editor (si el foco
        // está dentro del editor, el propio editor atiende el Esc).
        const SingleActivator(LogicalKeyboardKey.escape): () =>
            _editorKey?.currentState?.close(),
      },
      child: Focus(
        focusNode: _shortcutsFocus,
        autofocus: true,
        // Invisible: solo escucha los atajos. Tab no se detiene aquí (antes
        // sí lo hacía y parecía que "desaparecía la selección").
        skipTraversal: true,
        child: page,
      ),
    );
  }

  /// El editor de la nota abierta en la vista de PC.
  Widget _buildPaneEditor() => NoteEditorScreen(
        key: _editorKey,
        note: _openNote!,
        storage: widget.storage,
        settings: widget.settings,
        embedded: true,
        onClose: _onPaneClosed,
        onDeleted: _onPaneClosed,
        onSaved: (note) {
          if (!mounted) return;
          setState(() => _openNote = note);
          _load(); // la lista refleja el título, el texto y el grupo nuevos
        },
      );

  // ---------------------------------------------------------------------------
  // Vista de celular (angosta)
  // ---------------------------------------------------------------------------

  Widget _buildNarrow(BuildContext context, {required bool loaded}) {
    final l10n = context.l10n;
    final theme = Theme.of(context);
    final visible = (_notes ?? const <Note>[]).where(_filter.matches).length;
    return Scaffold(
      appBar: AppBar(
        titleSpacing: 20,
        // Nombre de la app: no se traduce.
        title: Text(
          'Synced Notes',
          style: theme.textTheme.titleLarge?.copyWith(
            fontSize: 22,
            fontWeight: FontWeight.w700,
          ),
        ),
        actions: [
          // Por si cambiaste archivos desde el explorador con la app abierta.
          // (La lupa de buscar llega en la fase "Organizar y buscar".)
          IconButton(
            tooltip: l10n.refreshList,
            icon: const Icon(Icons.refresh),
            onPressed: _load,
          ),
          IconButton(
            tooltip: l10n.settingsTitle,
            icon: const Icon(Icons.settings_outlined),
            onPressed: _openSettings,
          ),
          const SizedBox(width: 4),
        ],
        bottom: !loaded
            ? null
            : PreferredSize(
                preferredSize: const Size.fromHeight(26),
                child: Align(
                  alignment: AlignmentDirectional.centerStart,
                  child: Padding(
                    padding: const EdgeInsetsDirectional.fromSTEB(20, 0, 20, 8),
                    child: Text(
                      l10n.listSummary(
                          _viewLabel(l10n), l10n.notesCount(visible)),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: theme.textTheme.bodyMedium?.copyWith(
                          color: theme.colorScheme.onSurfaceVariant),
                    ),
                  ),
                ),
              ),
      ),
      body: !loaded
          ? _buildBody(context, bottomSpace: 0)
          : Stack(
              children: [
                Positioned.fill(
                  child: _buildBody(
                    context,
                    // Espacio para el panel de grupos y "Nueva nota", para
                    // que no tapen la última nota.
                    bottomSpace: GroupPanel.collapsedHeightOf(context) + 92,
                  ),
                ),
                // "Nueva nota", a la derecha, justo arriba del panel.
                PositionedDirectional(
                  end: 16,
                  bottom: GroupPanel.collapsedHeightOf(context) + 16,
                  child: _buildNewNoteButton(context),
                ),
                // El panel va al final: abierto, queda encima de todo.
                Positioned.fill(
                  child: GroupPanel(
                    groups: _groups,
                    selected: _filter,
                    totalNotes: _notes!.length,
                    counts: _countsByGroup(),
                    onSelect: _select,
                    onCreate: _createGroup,
                    onGroupAction: _onGroupAction,
                  ),
                ),
              ],
            ),
    );
  }

  /// Color de fondo de "Nueva nota": el del grupo que se está viendo, si
  /// tiene. `null` = el normal del tema.
  Color? _newNoteColor(ThemeData theme) {
    final groupName = _filter.groupForNewNote;
    for (final c in _groups) {
      if (c.name == groupName && c.color != null) {
        return displayColor(c.color!, theme.brightness);
      }
    }
    return null;
  }

  Color? _onColor(Color? background) => background == null
      ? null
      : (ThemeData.estimateBrightnessForColor(background) == Brightness.dark
          ? Colors.white
          : Colors.black);

  String _newNoteTooltip(AppLocalizations l10n) {
    final groupName = _filter.groupForNewNote;
    return groupName == null ? l10n.newNote : l10n.newNoteIn(groupName);
  }

  void _newNote() => _open(Note.blank(group: _filter.groupForNewNote));

  /// Botón "Nueva nota" (celular). Dentro de un grupo, la nota nace ahí: el
  /// tooltip lo dice y, si el grupo tiene color, el botón lo toma.
  Widget _buildNewNoteButton(BuildContext context) {
    final l10n = context.l10n;
    final background = _newNoteColor(Theme.of(context));
    return FloatingActionButton.extended(
      tooltip: _newNoteTooltip(l10n),
      backgroundColor: background,
      foregroundColor: _onColor(background),
      onPressed: _newNote,
      icon: const Icon(Icons.note_add_outlined),
      label: Text(l10n.newNote),
    );
  }

  // ---------------------------------------------------------------------------
  // Vista de PC (ancha)
  // ---------------------------------------------------------------------------

  /// Ancho de la columna de la lista en la vista de PC.
  static const double _listWidth = 360;

  Widget _buildWide(BuildContext context) {
    final l10n = context.l10n;
    final theme = Theme.of(context);
    final width = MediaQuery.sizeOf(context).width;
    // En ventanas no tan anchas, la lista cede espacio al editor.
    final listWidth = width < 1100 ? 300.0 : _listWidth;
    return Scaffold(
      // Cada columna es un grupo para el teclado: Tab recorre una columna y
      // luego pasa a la siguiente; las flechas mueven el foco entre filas
      // (y a la izquierda o derecha, a la columna de al lado); Enter abre.
      body: Row(
        children: [
          FocusTraversalGroup(
            child: GroupSidebar(
            groups: _groups,
            selected: _filter,
            totalNotes: _notes!.length,
            counts: _countsByGroup(),
            onSelect: _select,
            onCreate: _createGroup,
            onGroupAction: _onGroupAction,
            onOpenSettings: _openSettings,
            ),
          ),
          const VerticalDivider(width: 1),
          FocusTraversalGroup(
            child: SizedBox(
              width: listWidth,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  _buildWideHeader(context),
                  Expanded(child: _buildBody(context, bottomSpace: 24)),
                ],
              ),
            ),
          ),
          const VerticalDivider(width: 1),
          Expanded(
            child: _openNote != null
                ? _buildPaneEditor()
                : Center(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          l10n.noNoteOpen,
                          key: const ValueKey('no-note-open'),
                          textAlign: TextAlign.center,
                          style: theme.textTheme.bodyLarge?.copyWith(
                              color: theme.colorScheme.onSurfaceVariant),
                        ),
                        const SizedBox(height: 28),
                        _buildBigNewNoteButton(context),
                      ],
                    ),
                  ),
          ),
        ],
      ),
    );
  }

  /// Botón grande y discreto para crear una nota, en la columna del editor
  /// cuando no hay ninguna abierta (idea del usuario): a la mano, pero sin
  /// competir con el resto. Contorno gris, ícono y texto apagados; al pasar
  /// el mouse se ilumina un poco.
  Widget _buildBigNewNoteButton(BuildContext context) {
    final l10n = context.l10n;
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final groupName = _filter.groupForNewNote;
    final shape = RoundedRectangleBorder(
      borderRadius: BorderRadius.circular(20),
      side: BorderSide(color: scheme.outlineVariant, width: 1.5),
    );
    return Material(
      key: const ValueKey('pane-new-note'),
      type: MaterialType.transparency,
      shape: shape,
      child: InkWell(
        customBorder: shape,
        onTap: _newNote,
        child: SizedBox(
          width: 260,
          height: 150,
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(Icons.note_add_outlined,
                  size: 40, color: scheme.onSurfaceVariant),
              const SizedBox(height: 12),
              // Dentro de un grupo: "Nueva nota en" y, abajo, el grupo.
              for (final line in groupName == null
                  ? [l10n.newNote]
                  : [l10n.newNoteInPrefix, groupName])
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  child: Text(
                    line,
                    textAlign: TextAlign.center,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: theme.textTheme.titleMedium?.copyWith(
                      color: scheme.onSurfaceVariant,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }

  /// Arriba de la lista: qué se ve, cuántas notas, Actualizar y Nueva nota.
  Widget _buildWideHeader(BuildContext context) {
    final l10n = context.l10n;
    final theme = Theme.of(context);
    final visible = _notes!.where(_filter.matches).length;
    final background = _newNoteColor(theme);
    return SafeArea(
      bottom: false,
      left: false,
      child: Padding(
        padding: const EdgeInsetsDirectional.fromSTEB(20, 16, 16, 12),
        child: Row(
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    _viewLabel(l10n),
                    key: const ValueKey('wide-view-title'),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: theme.textTheme.titleLarge
                        ?.copyWith(fontWeight: FontWeight.w700),
                  ),
                  Text(
                    l10n.notesCount(visible),
                    style: theme.textTheme.bodySmall?.copyWith(
                        color: theme.colorScheme.onSurfaceVariant),
                  ),
                ],
              ),
            ),
            // Por si cambiaste archivos desde el explorador con la app abierta.
            IconButton(
              tooltip: l10n.refreshList,
              icon: const Icon(Icons.refresh),
              onPressed: _load,
            ),
            const SizedBox(width: 8),
            Tooltip(
              message: '${_newNoteTooltip(l10n)} (Ctrl+N)',
              child: FilledButton.icon(
                style: FilledButton.styleFrom(
                  backgroundColor: background,
                  foregroundColor: _onColor(background),
                  minimumSize: const Size(0, 44),
                  padding: const EdgeInsets.symmetric(horizontal: 18),
                ),
                onPressed: _newNote,
                icon: const Icon(Icons.note_add_outlined),
                label: Text(l10n.newNote),
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ---------------------------------------------------------------------------
  // Lista (las dos vistas)
  // ---------------------------------------------------------------------------

  /// La lista de notas, o el mensaje de carga, error o lista vacía.
  /// [bottomSpace]: espacio libre al final (para lo que flota encima).
  Widget _buildBody(BuildContext context, {required double bottomSpace}) {
    final theme = Theme.of(context);
    final l10n = context.l10n;

    if (_loadError != null) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                l10n.notesFolderError(
                    widget.storage.folder.path, l10n.errorText(_loadError!)),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 16),
              FilledButton(onPressed: _load, child: Text(l10n.retry)),
            ],
          ),
        ),
      );
    }

    final allNotes = _notes;
    if (allNotes == null) {
      return const Center(child: CircularProgressIndicator());
    }

    final notes = allNotes.where(_filter.matches).toList();
    if (notes.isEmpty) {
      return Center(
        child: Padding(
          padding: EdgeInsets.fromLTRB(24, 24, 24, 24 + bottomSpace / 2),
          child: Text(
            allNotes.isEmpty ? l10n.emptyNotes : l10n.emptyFilter,
            textAlign: TextAlign.center,
            style: theme.textTheme.bodyLarge
                ?.copyWith(color: theme.colorScheme.onSurfaceVariant),
          ),
        ),
      );
    }

    final showGroup = _filter.isAll;
    return ListView.builder(
      padding: EdgeInsets.fromLTRB(8, 4, 8, bottomSpace),
      itemCount: notes.length,
      itemBuilder: (context, index) {
        final note = notes[index];
        final group = note.group;
        return NoteRow(
          note: note,
          groupColor: group == null ? null : _colorOf(group, theme),
          showGroup: showGroup,
          selected: _isOpenInPane(note),
          onTap: () => _open(note),
          onMenu: (position) => _showNoteMenu(note, position),
        );
      },
    );
  }
}
