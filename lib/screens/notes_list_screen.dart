import 'dart:math' as math;

import 'package:flutter/gestures.dart' show HitTestResult;
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart' show RenderMetaData;
import 'package:flutter/scheduler.dart';
import 'package:flutter/services.dart';

import '../l10n/l10n.dart';
import '../models/note_group.dart';
import '../models/group_filter.dart';
import '../models/note.dart';
import '../services/app_settings.dart';
import '../services/note_storage.dart';
import '../utils/note_order.dart';
import '../utils/note_search.dart';
import '../widgets/app_message.dart';
import '../widgets/group_colors.dart';
import '../widgets/group_dialogs.dart';
import '../widgets/group_panel.dart';
import '../widgets/group_sidebar.dart';
import '../widgets/note_row.dart';
import '../widgets/search_options_toggles.dart';
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

/// Encabezados de la lista cuando hay notas fijadas.
enum _Section { pinned, others }

/// Encabezado de un grupo en el orden "Por grupo" (`group` null = Sin
/// grupo).
class _GroupSection {
  const _GroupSection(this.group, this.count);
  final String? group;

  /// Cuántas notas hay en la sección.
  final int count;
}

class _NotesListScreenState extends State<NotesListScreen>
    with SingleTickerProviderStateMixin {
  List<Note>? _notes; // null = cargando
  List<NoteGroup> _groups = const [];

  /// Notas fijadas de cada vista: vista ([GroupFilter.encode]) → ids
  /// ([NoteStorage.noteId]).
  Map<String, Set<String>> _pins = const {};

  /// ¿Está fijada [note] en lo que se ve?
  bool _isPinned(Note note) => _isPinnedIn(note, _scope);
  bool _isPinnedIn(Note note, GroupFilter view) =>
      _pins[view.encode()]?.contains(NoteStorage.noteId(note)) ?? false;
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

  // Búsqueda ------------------------------------------------------------------

  /// Lo que se escribió en el buscador.
  final TextEditingController _searchText = TextEditingController();
  final FocusNode _searchFocus = FocusNode(debugLabel: 'buscador');

  /// Celular: la barra de arriba está en modo búsqueda.
  bool _searchOpen = false;

  /// Dónde se busca, si es distinto de lo que se está viendo ("Buscar en
  /// todas"). `null` = en lo que se ve. Elegir un grupo en el menú del
  /// buscador cambia lo que se ve (como tocar su chip), no esto.
  GroupFilter? _searchScope;

  /// Dónde se busca ahora.
  GroupFilter get _scope => _searchScope ?? _filter;

  NoteSearch get _search => NoteSearch(_searchText.text,
      options: widget.settings.searchOptions);

  Future<void> _setSearchOptions(SearchOptions options) async {
    await widget.settings.setSearchOptions(options);
    if (!mounted) return;
    setState(() {
      // Cambian los resultados: todo vuelve a plegarse.
      _expandedMatches.clear();
      _shownMatches.clear();
    });
  }

  /// Resultados con varias coincidencias: cuáles están desplegados y cuántas
  /// coincidencias se ven de cada uno (de 10 en 10). Clave: [_noteKey].
  final Set<String> _expandedMatches = {};
  final Map<String, int> _shownMatches = {};
  static const int _matchesPage = 10;
  String _lastQuery = '';

  /// Con qué abrir "Buscar en esta nota" en la columna del editor (PC).
  ({String query, int match})? _paneFind;

  static String _noteKey(Note note) =>
      '${note.group ?? ''}/${note.fileName ?? ''}';

  void _onSearchChanged() {
    final query = _searchText.text;
    setState(() {
      // Al cambiar lo buscado, todo vuelve a plegarse.
      if (query != _lastQuery) {
        _lastQuery = query;
        _expandedMatches.clear();
        _shownMatches.clear();
      }
    });
  }

  void _toggleMatches(Note note) {
    final key = _noteKey(note);
    setState(() {
      if (!_expandedMatches.remove(key)) {
        _expandedMatches.add(key);
        _shownMatches[key] = _matchesPage;
      }
    });
  }

  void _showMoreMatches(Note note) {
    final key = _noteKey(note);
    setState(() =>
        _shownMatches[key] = (_shownMatches[key] ?? _matchesPage) + _matchesPage);
  }

  @override
  void dispose() {
    FocusManager.instance.removeListener(_keepShortcutsListening);
    _shortcutsFocus.dispose();
    _searchText.dispose();
    _searchFocus.dispose();
    _dragTicker?.dispose();
    _pages?.dispose();
    for (final c in _listControllers.values) {
      c.dispose();
    }
    super.dispose();
  }

  void _openSearch() {
    setState(() {
      _searchOpen = true;
      _selection = {};
    });
    _searchFocus.requestFocus();
  }

  void _closeSearch() {
    _searchText.clear();
    setState(() {
      _searchOpen = false;
      _searchScope = null;
    });
    _shortcutsFocus.requestFocus();
  }

  /// Las notas que se ven: las de donde se busca ([_scope]: lo que se está
  /// viendo, o lo elegido en el buscador) y, si hay algo escrito, solo las
  /// que coinciden (primero las que coinciden en el título). Con el
  /// buscador vacío se ven todas las de ese lugar: así, al cambiar a "Buscar
  /// en todas", la lista cambia de inmediato.
  ///
  /// [view]: otra vista (las páginas de al lado, al deslizar).
  List<Note> _visibleNotes([GroupFilter? view]) {
    final all = _notes ?? const <Note>[];
    final search = _search;
    final scope = view ?? _scope;
    final order = _effectiveOrderFor(scope);
    bool isPinned(Note n) => _isPinnedIn(n, scope);
    final scoped = sortNotes(
      all.where(scope.matches),
      order,
      opened: order == NoteOrder.opened
          ? widget.settings.noteOpenedTimes()
          : const {},
      groupOrder: [for (final g in _groups) g.name],
    );
    // Sin buscar: las fijadas de esta vista, arriba. Buscando, los pins no
    // cuentan (primero las que coinciden en el título).
    if (search.isEmpty) {
      return [
        ...scoped.where(isPinned),
        ...scoped.where((n) => !isPinned(n)),
      ];
    }
    final found = scoped.where(search.matches).toList();
    return [
      ...found.where(search.matchesTitle),
      ...found.where((n) => !search.matchesTitle(n)),
    ];
  }

  /// El orden que se usa aquí: "Por grupo" solo tiene sentido en "Todas"
  /// y sin buscar; en lo demás se ordena por editadas recientemente.
  NoteOrder _effectiveOrderFor(GroupFilter scope) {
    final order = widget.settings.noteOrder;
    if (order == NoteOrder.byGroup && (!scope.isAll || !_search.isEmpty)) {
      return NoteOrder.edited;
    }
    return order;
  }

  String _orderLabel(NoteOrder order, AppLocalizations l10n) =>
      switch (order) {
        NoteOrder.edited => l10n.orderEdited,
        NoteOrder.opened => l10n.orderOpened,
        NoteOrder.created => l10n.orderCreated,
        NoteOrder.byGroup => l10n.orderByGroup,
        NoteOrder.titleAz => l10n.orderTitleAz,
        NoteOrder.titleZa => l10n.orderTitleZa,
      };

  String _orderShortLabel(NoteOrder order, AppLocalizations l10n) =>
      switch (order) {
        NoteOrder.edited => l10n.orderEditedShort,
        NoteOrder.opened => l10n.orderOpenedShort,
        NoteOrder.created => l10n.orderCreatedShort,
        NoteOrder.byGroup => l10n.orderByGroup,
        NoteOrder.titleAz => l10n.orderTitleAzShort,
        NoteOrder.titleZa => l10n.orderTitleZaShort,
      };

  /// "↕ Editadas": muestra el orden de la lista y, al tocarlo, un menú para
  /// cambiarlo (el actual, marcado). Se puede cambiar en cualquier momento.
  Widget _buildOrderButton(BuildContext context) {
    final l10n = context.l10n;
    final theme = Theme.of(context);
    final muted = theme.colorScheme.onSurfaceVariant;
    final current = widget.settings.noteOrder;
    return PopupMenuButton<NoteOrder>(
      key: const ValueKey('note-order-button'),
      tooltip: l10n.orderMenuTooltip,
      initialValue: current,
      onSelected: (order) async {
        await widget.settings.setNoteOrder(order);
        if (mounted) setState(() {});
      },
      itemBuilder: (context) => [
        for (final order in NoteOrder.values)
          CheckedPopupMenuItem<NoteOrder>(
            value: order,
            checked: order == current,
            child: Text(_orderLabel(order, l10n)),
          ),
      ],
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.swap_vert, size: 18, color: muted),
            const SizedBox(width: 4),
            Flexible(
              child: Text(
                _orderShortLabel(current, l10n),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: theme.textTheme.bodyMedium?.copyWith(color: muted),
              ),
            ),
          ],
        ),
      ),
    );
  }

  /// Nombre de un lugar donde buscar (Todas / Sin grupo / un grupo).
  String _filterLabel(GroupFilter filter, AppLocalizations l10n) {
    if (filter.isAll) return l10n.groupsAll;
    if (filter.isNone) return l10n.groupsNone;
    return filter.name!;
  }

  /// Color de un grupo (para su carpetita y el subrayado). `null` = no es un
  /// grupo o no tiene color.
  Color? _colorOfFilter(GroupFilter filter, ThemeData theme) {
    if (!filter.isGroup) return null;
    for (final g in _groups) {
      if (g.name == filter.name && g.color != null) {
        return displayColor(g.color!, theme.brightness);
      }
    }
    return null;
  }

  /// "Buscando en Recetas ▾   [Buscar en todas]".
  ///
  /// Antes del nombre va la carpetita del color del grupo (una pista de
  /// dónde se busca). Al tocarlo se despliega un menú para cambiar de grupo
  /// sin salir de la búsqueda (como los chips); el actual va marcado.
  /// "Buscar en todas" (o "Solo en Recetas") queda como atajo a un lado.
  Widget _buildSearchScope(BuildContext context) {
    final l10n = context.l10n;
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final style = theme.textTheme.bodySmall
        ?.copyWith(color: scheme.onSurfaceVariant);
    final scope = _scope;

    // "Buscando en 📁 Recetas": la carpetita con el color del grupo es la
    // pista de dónde se busca (igual que en la lista y los chips).
    final Widget text;
    if (scope.isAll) {
      text = Text(
        l10n.searchingAll,
        key: const ValueKey('search-scope'),
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
        style: style,
      );
    } else {
      final name = _filterLabel(scope, l10n);
      final full = l10n.searchingIn(name);
      final at = full.lastIndexOf(name);
      text = Text.rich(
        TextSpan(children: [
          TextSpan(text: full.substring(0, at)),
          if (scope.isGroup)
            WidgetSpan(
              alignment: PlaceholderAlignment.middle,
              child: Padding(
                padding: const EdgeInsetsDirectional.only(end: 4),
                child: GroupFolderIcon(
                  _colorOfFilter(scope, theme),
                  key: const ValueKey('search-scope-folder'),
                  size: 14,
                ),
              ),
            ),
          TextSpan(
            text: name,
            style: TextStyle(color: scheme.onSurface),
          ),
          TextSpan(text: full.substring(at + name.length)),
        ]),
        key: const ValueKey('search-scope'),
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
        style: style,
      );
    }

    PopupMenuEntry<GroupFilter> item(GroupFilter filter, String label) {
      return CheckedPopupMenuItem<GroupFilter>(
        value: filter,
        checked: filter == scope,
        child: Row(
          children: [
            if (filter.isGroup) ...[
              GroupFolderIcon(_colorOfFilter(filter, theme), size: 18),
              const SizedBox(width: 10),
            ],
            Flexible(
              child: Text(label, maxLines: 1, overflow: TextOverflow.ellipsis),
            ),
          ],
        ),
      );
    }

    final picker = PopupMenuButton<GroupFilter>(
      key: const ValueKey('search-scope-menu'),
      tooltip: l10n.searchScopeChoose,
      // Como tocar su chip: se cambia de grupo sin salir de la búsqueda (y
      // al salir de ella se queda ahí).
      onSelected: _select,
      itemBuilder: (context) => [
        item(GroupFilter.all, l10n.scopeAllNotes),
        if (_groups.isNotEmpty) item(GroupFilter.none, l10n.groupsNone),
        for (final g in _groups)
          item(GroupFilter.group(g.name), g.name),
      ],
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 6),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Flexible(child: text),
            Icon(Icons.arrow_drop_down,
                size: 18, color: scheme.onSurfaceVariant),
          ],
        ),
      ),
    );

    final Widget? shortcut;
    if (!scope.isAll) {
      shortcut = TextButton(
        style: TextButton.styleFrom(
          visualDensity: VisualDensity.compact,
          padding: const EdgeInsets.symmetric(horizontal: 8),
        ),
        onPressed: () => setState(() => _searchScope = GroupFilter.all),
        child: Text(l10n.searchAllInstead),
      );
    } else if (!_filter.isAll) {
      shortcut = TextButton(
        style: TextButton.styleFrom(
          visualDensity: VisualDensity.compact,
          padding: const EdgeInsets.symmetric(horizontal: 8),
        ),
        onPressed: () => setState(() => _searchScope = null),
        child: Text(l10n.searchOnlyIn(_viewLabel(l10n))),
      );
    } else {
      shortcut = null;
    }

    return Row(
      children: [
        Flexible(child: picker),
        if (shortcut != null) shortcut,
      ],
    );
  }

  /// El campo de búsqueda (en la barra del celular o arriba de la lista
  /// en PC). Esc: si hay texto, lo borra; si no, cierra la búsqueda.
  Widget _buildSearchField(BuildContext context, {required bool wide}) {
    final l10n = context.l10n;
    final theme = Theme.of(context);
    final field = TextField(
      key: const ValueKey('search-field'),
      controller: _searchText,
      focusNode: _searchFocus,
      textInputAction: TextInputAction.search,
      style: wide ? theme.textTheme.bodyMedium : theme.textTheme.titleMedium,
      decoration: InputDecoration(
        hintText: wide ? '${l10n.searchNotes} (Ctrl+F)' : l10n.searchNotes,
        isDense: wide,
        filled: wide,
        fillColor: theme.colorScheme.surfaceContainerHighest,
        prefixIcon: wide ? const Icon(Icons.search, size: 20) : null,
        // Opciones Aa / á / ab (como VS Code) y, si hay texto, borrarlo.
        suffixIcon: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            SearchOptionsToggles(
              options: widget.settings.searchOptions,
              onChanged: _setSearchOptions,
            ),
            if (_searchText.text.isNotEmpty)
              IconButton(
                tooltip: l10n.clearSearch,
                icon: const Icon(Icons.close, size: 20),
                onPressed: _searchText.clear,
              )
            else
              const SizedBox(width: 8),
          ],
        ),
        border: wide
            ? OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: BorderSide.none,
              )
            : InputBorder.none,
      ),
    );
    return CallbackShortcuts(
      bindings: {
        const SingleActivator(LogicalKeyboardKey.escape): () {
          if (_searchText.text.isNotEmpty) {
            _searchText.clear();
          } else if (wide) {
            _shortcutsFocus.requestFocus();
          } else {
            _closeSearch();
          }
        },
      },
      child: field,
    );
  }

  /// Lo que se está viendo. Se recuerda en los ajustes.
  GroupFilter get _filter => widget.settings.selectedGroup;

  @override
  void initState() {
    super.initState();
    _searchText.addListener(_onSearchChanged);
    FocusManager.instance.addListener(_keepShortcutsListening);
    _load();
  }

  /// Al hacer clic en un área vacía después de escribir en un campo, el
  /// campo suelta el foco y Flutter lo deja en el "fondo" de la pantalla
  /// (el FocusScope de la ruta), que está por encima de los atajos: Ctrl+F,
  /// Ctrl+N, etc. dejaban de funcionar. Aquí el foco regresa a los atajos.
  void _keepShortcutsListening() {
    final primary = FocusManager.instance.primaryFocus;
    if (!mounted ||
        primary == null ||
        primary == _shortcutsFocus ||
        primary is! FocusScopeNode ||
        !_shortcutsFocus.canRequestFocus) {
      return;
    }
    // Solo si ese "fondo" es el de esta pantalla (no el de un diálogo o el
    // de otra pantalla encima).
    if (_shortcutsFocus.ancestors.contains(primary)) {
      _shortcutsFocus.requestFocus();
    }
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
      final pins = await widget.storage.listPins();
      if (!mounted) return;
      final ids = {for (final n in notes) _selectionKey(n)};
      setState(() {
        _notes = notes;
        _groups = groups;
        _pins = pins;
        _selection = _selection.where(ids.contains).toSet();
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

  /// Se reacomodaron los grupos (arrastrando su agarradera): se ven así de
  /// inmediato y se guarda el orden (viaja con la sincronización).
  Future<void> _reorderGroups(List<NoteGroup> groups) async {
    setState(() => _groups = groups);
    try {
      await widget.storage.reorderGroups([for (final g in groups) g.name]);
    } catch (e) {
      _showError(e);
      await _load();
    }
  }

  // Deslizar la lista para cambiar de grupo ------------------------------
  //
  // Las vistas están una junto a otra, como fotos en una galería: la lista
  // sigue al dedo y se ve la de al lado entrando.

  /// Las páginas (una por vista, en el orden de los chips). Se crea al
  /// mostrar la lista por primera vez.
  PageController? _pages;

  /// Mientras la lista va sola a la página de un chip que se tocó: las
  /// páginas que pasa en medio no cambian la vista.
  int? _pageTarget;

  /// Las vistas en el orden de los chips: Todas, Sin grupo (si hay
  /// grupos) y cada grupo.
  List<GroupFilter> get _viewsInOrder => [
        GroupFilter.all,
        if (_groups.isNotEmpty) GroupFilter.none,
        for (final g in _groups) GroupFilter.group(g.name),
      ];

  /// Se deslizó a otra página (al pasar la mitad): esa es la vista.
  void _onPageChanged(int index) {
    if (_pageTarget != null) return;
    final views = _viewsInOrder;
    if (index < views.length && views[index] != _filter) {
      _select(views[index], movePage: false);
    }
  }

  /// Si las páginas no están en la vista elegida (ej. se agregó o borró un
  /// grupo antes), se acomodan sin animación.
  void _syncPage() {
    final pages = _pages;
    if (pages == null || !pages.hasClients || _pageTarget != null) return;
    final position = pages.position;
    if (position.isScrollingNotifier.value) return;
    final want = _viewsInOrder.indexOf(_filter);
    final page = pages.page;
    if (want < 0 || page == null || page.round() == want) return;
    pages.jumpToPage(want);
  }

  /// Lleva las páginas a la vista [index] (se tocó un chip): se desliza
  /// como si se hubiera arrastrado.
  void _animateToPage(int index) {
    final pages = _pages;
    if (pages == null || !pages.hasClients) return;
    final page = pages.page;
    if (page == null || page.round() == index) return;
    _pageTarget = index;
    pages
        .animateToPage(index,
            duration: const Duration(milliseconds: 320),
            curve: Curves.easeOutCubic)
        .whenComplete(() {
      if (_pageTarget == index) _pageTarget = null;
    });
  }

  /// Cambia la vista. [movePage]: también desliza las páginas hasta ella
  /// (no hace falta si se llegó deslizando).
  Future<void> _select(GroupFilter filter, {bool movePage = true}) async {
    _selection = {};
    _lastChecked = null;
    _searchScope = null; // la búsqueda vuelve a ser "en lo que se ve"
    final done = widget.settings.setSelectedGroup(filter);
    if (movePage) {
      final index = _viewsInOrder.indexOf(filter);
      if (index >= 0) _animateToPage(index);
    }
    await done;
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
  Future<void> _openInPane(Note note,
      {({String query, int match})? find}) async {
    if (_isOpenInPane(note)) {
      // Ya está abierta: solo ir a esa coincidencia.
      if (find != null) {
        _editorKey?.currentState?.findAt(find.query, find.match);
      }
      return;
    }
    if (!await _closePane()) return;
    if (!mounted) return;
    setState(() {
      _openNote = note;
      _paneFind = find;
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

  /// Abre una nota. Si hay una búsqueda y la nota tiene coincidencias, llega
  /// con "Buscar en esta nota" puesta en la coincidencia número [match]
  /// (0 = la primera).
  Future<void> _open(Note note, {int match = 0}) async {
    // Se anota siempre (aunque el orden no sea "Abiertas recientemente"):
    // así, al elegirlo, la lista ya refleja lo que se abrió antes.
    if (note.isSaved) {
      // Sin esperar a que se escriba: el orden ya lo ve de inmediato.
      widget.settings.markNoteOpened(NoteStorage.noteId(note));
    }
    final search = _search;
    final find = !search.isEmpty && search.matchesIn(note).isNotEmpty
        ? (query: _searchText.text.trim(), match: match)
        : null;
    if (_isWide) return _openInPane(note, find: find);
    // Si el teclado del buscador estaba escondido, al regresar no debe
    // volver a abrirse solo: se suelta el foco del buscador antes de salir.
    if (_searchFocus.hasFocus && MediaQuery.viewInsetsOf(context).bottom == 0) {
      _searchFocus.unfocus();
    }
    // Si dentro de la nota se cierra la barra de búsqueda (✕ o Esc), al
    // regresar también se cierra la búsqueda de la lista.
    var findDismissed = false;
    await Navigator.of(context).push(MaterialPageRoute<void>(
      builder: (_) => NoteEditorScreen(
        note: note,
        storage: widget.storage,
        settings: widget.settings,
        initialFind: find,
        onFindDismissed: () => findDismissed = true,
      ),
    ));
    if (findDismissed && mounted) _closeSearch();
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

  // ---------------------------------------------------------------------------
  // Notas
  // ---------------------------------------------------------------------------

  // Selección de varias notas (mantener presionada una nota) ---------------

  /// Notas seleccionadas (ver [_selectionKey]). Vacío = no se está
  /// seleccionando.
  Set<String> _selection = {};
  /// (Mientras se arrastra desmarcando se sigue seleccionando aunque ya no
  /// quede ninguna marcada; al soltar, si no queda ninguna, se sale.)
  bool get _selecting => _selection.isNotEmpty || _dragView != null;

  bool _isChecked(Note note) => _selection.contains(_selectionKey(note));

  /// Grupo + archivo: identifica la nota aunque dos tengan la misma fecha
  /// de creación.
  static String _selectionKey(Note note) =>
      '${note.group ?? ''}/${note.fileName}';

  /// Las notas seleccionadas que se ven (en el orden de la lista).
  List<Note> get _selectedNotes =>
      [for (final n in _visibleNotes()) if (_isChecked(n)) n];

  /// Mantener presionada una nota (o clic derecho / Ctrl+clic en PC): se
  /// selecciona o deja de estarlo. Arriba aparecen Fijar, Mover y Borrar.
  void _toggleSelection(Note note) {
    final id = _selectionKey(note);
    setState(() {
      _selection = {..._selection};
      if (_selection.remove(id)) {
        if (_lastChecked == id) _lastChecked = null;
      } else {
        _selection.add(id);
        _lastChecked = id;
      }
    });
  }

  void _clearSelection() {
    _lastChecked = null;
    if (_selecting) setState(() => _selection = {});
  }

  /// La última nota que se marcó: desde ahí se marca un rango al mantener
  /// presionada otra.
  String? _lastChecked;

  // Arrastrar para seleccionar: después de mantener presionada una nota,
  // sin soltar, deslizar el dedo marca todas las notas por donde pasa
  // (desde la presionada hasta donde está el dedo). Cerca de la orilla de
  // arriba o de abajo, la lista se mueve sola.

  /// La vista donde se está arrastrando (`null` = no se arrastra).
  GroupFilter? _dragView;
  String? _dragAnchor;
  String? _dragCurrent;
  Set<String> _dragBase = {};

  /// Se empezó sobre una nota ya marcada: arrastrar desmarca.
  bool _dragUnchecks = false;
  Offset? _dragPointer;
  Ticker? _dragTicker;
  Duration _dragLastTick = Duration.zero;

  /// Una lista con su propio scroll por vista (para moverla sola al
  /// arrastrar).
  final Map<String, ScrollController> _listControllers = {};
  ScrollController _listController(GroupFilter view) =>
      _listControllers.putIfAbsent(view.encode(), ScrollController.new);

  /// Mantener presionada una nota en [view]:
  /// - Sin seleccionar nada: se selecciona.
  /// - Seleccionando, si no estaba marcada: se marca todo el rango desde la
  ///   última que se marcó hasta esta.
  /// En los dos casos, sin soltar, se puede arrastrar para marcar más.
  void _onLongPressNote(Note note, GroupFilter view, Offset position) {
    HapticFeedback.mediumImpact();
    final key = _selectionKey(note);
    final keys = [for (final n in _visibleNotes(view)) _selectionKey(n)];
    final unchecks = _selecting && _selection.contains(key);
    setState(() {
      if (unchecks) {
        // Ya estaba marcada: se desmarca, y arrastrando se desmarcan las
        // demás por donde pase el dedo.
        _dragBase = {..._selection};
        _selection = {..._selection}..remove(key);
        if (_lastChecked == key) _lastChecked = null;
      } else if (!_selecting) {
        _selection = {key};
      } else if (!_selection.contains(key)) {
        final from = _lastChecked == null ? -1 : keys.indexOf(_lastChecked!);
        final to = keys.indexOf(key);
        _selection = {
          ..._selection,
          if (from >= 0 && to >= 0)
            ...keys.sublist(math.min(from, to), math.max(from, to) + 1)
          else
            key,
        };
      }
      if (!unchecks) _lastChecked = key;
      _dragView = view;
    });
    _dragUnchecks = unchecks;
    _dragAnchor = key;
    _dragCurrent = key;
    if (!unchecks) _dragBase = {..._selection};
    _dragPointer = position;
    _dragLastTick = Duration.zero;
    final ticker = _dragTicker ??= createTicker(_onDragTick);
    if (!ticker.isActive) ticker.start();
  }

  void _onDragPointerMove(PointerMoveEvent event) {
    if (_dragView == null) return;
    _dragPointer = event.position;
    _updateDragSelection();
  }

  void _endDragSelection([PointerEvent? _]) {
    if (_dragView == null) return;
    // Si se desmarcaron todas, aquí se sale de la selección.
    setState(() => _dragView = null);
    _dragAnchor = null;
    _dragCurrent = null;
    _dragPointer = null;
    _dragUnchecks = false;
    _dragTicker?.stop();
  }

  /// La nota bajo el dedo (si hay una).
  Note? _noteAt(Offset position) {
    final result = HitTestResult();
    WidgetsBinding.instance
        .hitTestInView(result, position, View.of(context).viewId);
    for (final entry in result.path) {
      final target = entry.target;
      if (target is RenderMetaData && target.metaData is _NoteHit) {
        return (target.metaData as _NoteHit).note;
      }
    }
    return null;
  }

  void _updateDragSelection() {
    final view = _dragView, pointer = _dragPointer, anchor = _dragAnchor;
    if (view == null || pointer == null || anchor == null) return;
    final note = _noteAt(pointer);
    if (note == null) return;
    final key = _selectionKey(note);
    if (key == _dragCurrent) return;
    final keys = [for (final n in _visibleNotes(view)) _selectionKey(n)];
    final from = keys.indexOf(anchor), to = keys.indexOf(key);
    if (from < 0 || to < 0) return;
    _dragCurrent = key;
    HapticFeedback.selectionClick();
    final range = keys.sublist(math.min(from, to), math.max(from, to) + 1);
    setState(() {
      if (_dragUnchecks) {
        _selection = _dragBase.difference(range.toSet());
      } else {
        _selection = {..._dragBase, ...range};
        _lastChecked = key;
      }
    });
  }

  /// Zona de las orillas (arriba y abajo) donde la lista se mueve sola.
  static const double _dragEdge = 72;

  void _onDragTick(Duration elapsed) {
    final dt = (elapsed - _dragLastTick).inMicroseconds / 1e6;
    _dragLastTick = elapsed;
    final view = _dragView, pointer = _dragPointer;
    if (view == null || pointer == null || dt <= 0) return;
    final controller = _listControllers[view.encode()];
    if (controller == null || !controller.hasClients) return;
    final position = controller.position;
    final box = position.context.notificationContext?.findRenderObject();
    if (box is! RenderBox || !box.hasSize) return;
    final y = box.globalToLocal(pointer).dy;
    final height = box.size.height;
    double depth = 0; // 0 = fuera de la zona, 1 = en la orilla
    if (y < _dragEdge) {
      depth = -((_dragEdge - y) / _dragEdge).clamp(0.0, 1.0);
    } else if (y > height - _dragEdge) {
      depth = ((y - (height - _dragEdge)) / _dragEdge).clamp(0.0, 1.0);
    }
    if (depth == 0) return;
    // Más rápido mientras más cerca de la orilla.
    final speed = 150 + 1650 * depth * depth;
    final target = (position.pixels + depth.sign * speed * dt)
        .clamp(position.minScrollExtent, position.maxScrollExtent);
    if (target == position.pixels) return;
    controller.jumpTo(target);
    _updateDragSelection();
  }

  void _selectAll() =>
      setState(() => _selection = {
            for (final n in _visibleNotes()) _selectionKey(n),
          });

  /// Fija las seleccionadas en lo que se ve (o, si ya están todas
  /// fijadas, las desfija).
  Future<void> _pinSelected() async {
    final notes = _selectedNotes;
    final pin = !notes.every(_isPinned);
    for (final note in notes) {
      await _setPinned(note, pin);
    }
    _clearSelection();
  }

  Future<void> _moveSelected() async {
    var notes = _selectedNotes;
    if (notes.isEmpty) return;
    // Si una está abierta en el editor, primero se guarda y se cierra.
    if (notes.any(_isOpenInPane)) {
      final latest = _openNote!;
      if (!await _closePane()) return;
      notes = [for (final n in notes) _isSameNote(n, latest) ? latest : n];
    }
    if (!mounted) return;
    final groups = {for (final n in notes) n.group};
    final target = await pickGroupForMove(
      context,
      storage: widget.storage,
      current: groups.length == 1 ? groups.single : null,
      hasCurrent: groups.length == 1,
    );
    if (target == null || !mounted) return;
    final messenger = ScaffoldMessenger.of(context);
    final l10n = context.l10n;
    final name = target.group;
    var moved = 0;
    try {
      for (final note in notes) {
        if (note.group == name) continue;
        await widget.storage.moveNote(note, name);
        moved++;
      }
      if (moved == 1 && notes.length == 1) {
        messenger.showMessage(
            name == null ? l10n.noteMovedToNone : l10n.noteMovedTo(name));
      } else if (moved > 0) {
        messenger.showMessage(name == null
            ? l10n.notesMovedToNone(moved)
            : l10n.notesMovedTo(moved, name));
      }
    } catch (e) {
      _showError(e);
    }
    _clearSelection();
    await _load();
  }

  Future<void> _deleteSelected() async {
    final notes = _selectedNotes;
    if (notes.isEmpty) return;
    final l10n = context.l10n;
    final confirmed = notes.length == 1
        ? await confirmDeleteNote(context, l10n.displayTitle(notes.single))
        : await confirmDeleteNotes(context, notes.length);
    if (!confirmed || !mounted) return;
    // Si una está abierta en el editor, se cierra sin preguntar: se borra.
    if (notes.any(_isOpenInPane)) {
      setState(() {
        _openNote = null;
        _editorKey = null;
      });
    }
    final messenger = ScaffoldMessenger.of(context);
    var deleted = 0;
    try {
      for (final note in notes) {
        await widget.storage.deleteNote(note.fileName!, group: note.group);
        deleted++;
      }
      messenger.showMessage(
          deleted == 1 ? l10n.noteDeleted : l10n.notesDeleted(deleted));
    } catch (e) {
      messenger.showMessage(l10n.deleteError(l10n.errorText(e)),
          isError: true);
    }
    _clearSelection();
    await _load();
  }

  bool _isSameNote(Note a, Note b) =>
      a.fileName == b.fileName && a.group == b.group;

  /// Los botones de la selección: Fijar/Desfijar, Mover, Borrar y
  /// Seleccionar todas.
  List<Widget> _selectionActions(BuildContext context) {
    final l10n = context.l10n;
    final notes = _selectedNotes;
    final allPinned = notes.isNotEmpty && notes.every(_isPinned);
    return [
      IconButton(
        key: const ValueKey('selection-pin'),
        tooltip: allPinned ? l10n.unpinSelected : l10n.pinSelected,
        icon: Icon(allPinned ? Icons.push_pin : Icons.push_pin_outlined),
        onPressed: _pinSelected,
      ),
      IconButton(
        key: const ValueKey('selection-move'),
        tooltip: l10n.moveSelected,
        icon: const Icon(Icons.drive_file_move_outline),
        onPressed: _moveSelected,
      ),
      IconButton(
        key: const ValueKey('selection-delete'),
        tooltip: l10n.deleteSelected,
        icon: const Icon(Icons.delete_outline),
        onPressed: _deleteSelected,
      ),
      IconButton(
        key: const ValueKey('selection-all'),
        tooltip: l10n.selectAll,
        icon: const Icon(Icons.select_all),
        onPressed: _selectAll,
      ),
    ];
  }

  /// Fija (o desfija) una nota en lo que se ve. La lista cambia de
  /// inmediato; si no se pudo guardar, se avisa y se vuelve a leer.
  Future<void> _setPinned(Note note, bool pinned) async {
    final view = _scope;
    final id = NoteStorage.noteId(note);
    final ids = {...?_pins[view.encode()]};
    pinned ? ids.add(id) : ids.remove(id);
    setState(() => _pins = {..._pins, view.encode(): ids});
    try {
      await widget.storage.setPinned(view, note, pinned);
    } catch (e) {
      _showError(e);
      final pins = await widget.storage.listPins();
      if (mounted) setState(() => _pins = pins);
    }
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
        // Ctrl+F: buscar.
        const SingleActivator(LogicalKeyboardKey.keyF, control: true): () {
          if (!loaded) return;
          if (_isWide) {
            _searchFocus.requestFocus();
          } else {
            _openSearch();
          }
        },
        // Esc: cerrar la nota abierta en la columna del editor (si el foco
        // está dentro del editor, el propio editor atiende el Esc).
        const SingleActivator(LogicalKeyboardKey.escape): () => _selecting
            ? _clearSelection()
            : _editorKey?.currentState?.close(),
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
        initialFind: _paneFind,
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
    final searching =
        loaded && (_searchOpen || _searchText.text.isNotEmpty);
    if (searching) return _buildNarrowSearch(context);
    final l10n = context.l10n;
    final theme = Theme.of(context);
    final visible = _visibleNotes().length;
    // Seleccionando, "atrás" primero cancela la selección.
    return PopScope(
      canPop: !_selecting,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop) _clearSelection();
      },
      child: Scaffold(
      // El teclado no encoge esta pantalla: aquí solo lo abre el buscador
      // del panel de grupos, que queda arriba, a la vista. Si la pantalla se
      // encogiera, el panel calcularía su tamaño "cerrado" con el alto
      // pequeño y, al irse el teclado, quedaba cerrado a medias (y se hacía
      // más alto al tocar su buscador).
      resizeToAvoidBottomInset: false,
      appBar: _selecting
          ? AppBar(
              key: const ValueKey('selection-bar'),
              leading: IconButton(
                tooltip: l10n.cancelSelection,
                icon: const Icon(Icons.close),
                onPressed: _clearSelection,
              ),
              title: Text(l10n.selectedCount(_selectedNotes.length)),
              actions: [..._selectionActions(context), const SizedBox(width: 4)],
              // Sin "Todas · 59 notas" pero con la misma altura que sin
              // seleccionar: la lista no se mueve.
              bottom: const PreferredSize(
                preferredSize: Size.fromHeight(_summaryBarHeight),
                child: SizedBox.shrink(),
              ),
            )
          : AppBar(
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
          if (loaded)
            IconButton(
              tooltip: l10n.searchNotes,
              icon: const Icon(Icons.search),
              onPressed: _openSearch,
            ),
          // Por si cambiaste archivos desde el explorador con la app abierta.
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
        bottom: !loaded ? null : _buildSummaryBar(context, visible),
      ),
      body: !loaded
          ? _buildBody(context, bottomSpace: 0)
          : Stack(
              children: [
                Positioned.fill(child: _buildPager(context)),
                // "Nueva nota", a la derecha, justo arriba del panel.
                // Seleccionando no están ni el botón ni el panel.
                if (!_selecting)
                PositionedDirectional(
                  end: 16,
                  bottom: GroupPanel.collapsedHeightOf(context) + 16,
                  child: _buildNewNoteButton(context),
                ),
                // El panel va al final: abierto, queda encima de todo.
                if (!_selecting)
                Positioned.fill(
                  child: GroupPanel(
                    groups: _groups,
                    selected: _filter,
                    totalNotes: _notes!.length,
                    counts: _countsByGroup(),
                    onSelect: _select,
                    onCreate: _createGroup,
                    onGroupAction: _onGroupAction,
                    onReorder: _reorderGroups,
                  ),
                ),
              ],
            ),
    ),
    );
  }

  /// Las listas de todas las vistas, una junto a otra: deslizar de lado
  /// cambia de grupo (en el orden de los chips). Seleccionando no.
  Widget _buildPager(BuildContext context) {
    final views = _viewsInOrder;
    // Si la lista se quitó un rato (ej. el buscador o la vista de PC), se
    // vuelve a crear en la vista de ahora.
    if (_pages?.hasClients == false) {
      _pages!.dispose();
      _pages = null;
    }
    final pages = _pages ??= PageController(
        initialPage: math.max(0, views.indexOf(_filter)), keepPage: false);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) _syncPage();
    });
    // Espacio para el panel de grupos y "Nueva nota", para que no tapen la
    // última nota.
    final bottomSpace = GroupPanel.collapsedHeightOf(context) + 92;
    return PageView.builder(
      key: const ValueKey('notes-pager'),
      controller: pages,
      physics: _selecting ? const NeverScrollableScrollPhysics() : null,
      itemCount: views.length,
      onPageChanged: _onPageChanged,
      itemBuilder: (context, index) => _buildBody(context,
          view: views[index], bottomSpace: bottomSpace),
    );
  }

  static const double _summaryBarHeight = 32;

  /// Debajo del título: "Todas · 59 notas" y el orden.
  PreferredSizeWidget _buildSummaryBar(BuildContext context, int visible) {
    final l10n = context.l10n;
    final theme = Theme.of(context);
    return PreferredSize(
      preferredSize: const Size.fromHeight(_summaryBarHeight),
      child: Padding(
        padding: const EdgeInsetsDirectional.fromSTEB(20, 0, 10, 4),
        child: Row(
          children: [
            Expanded(
              child: Text(
                l10n.listSummary(
                    _viewLabel(l10n), l10n.notesCount(visible)),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: theme.textTheme.bodyMedium?.copyWith(
                    color: theme.colorScheme.onSurfaceVariant),
              ),
            ),
            _buildOrderButton(context),
          ],
        ),
      ),
    );
  }

  /// Celular buscando: la barra de arriba es el buscador (con flecha para
  /// salir) y, debajo, dónde se busca. Mientras, sin panel de grupos ni
  /// "Nueva nota": la pantalla es solo para los resultados.
  Widget _buildNarrowSearch(BuildContext context) {
    final l10n = context.l10n;
    return PopScope(
      canPop: false, // Atrás primero sale de la búsqueda
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop) _closeSearch();
      },
      child: Scaffold(
        appBar: AppBar(
          leading: IconButton(
            tooltip: l10n.closeSearch,
            icon: const Icon(Icons.arrow_back),
            onPressed: _closeSearch,
          ),
          titleSpacing: 0,
          title: _buildSearchField(context, wide: false),
          bottom: PreferredSize(
            preferredSize: const Size.fromHeight(36),
            child: Padding(
              padding: const EdgeInsetsDirectional.fromSTEB(20, 0, 12, 4),
              child: _buildSearchScope(context),
            ),
          ),
        ),
        body: _buildBody(context, bottomSpace: 24),
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
            onReorder: _reorderGroups,
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
  /// PC seleccionando: ✕ · "3 seleccionadas" · Fijar · Mover · Borrar.
  Widget _buildWideSelectionHeader(BuildContext context) {
    final l10n = context.l10n;
    final theme = Theme.of(context);
    return SafeArea(
      bottom: false,
      left: false,
      child: Padding(
        key: const ValueKey('selection-bar'),
        padding: const EdgeInsetsDirectional.fromSTEB(8, 16, 16, 8),
        child: Row(
          children: [
            IconButton(
              tooltip: '${l10n.cancelSelection} (Esc)',
              icon: const Icon(Icons.close),
              onPressed: _clearSelection,
            ),
            const SizedBox(width: 4),
            Expanded(
              child: Text(
                l10n.selectedCount(_selectedNotes.length),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: theme.textTheme.titleLarge
                    ?.copyWith(fontWeight: FontWeight.w700),
              ),
            ),
            ..._selectionActions(context),
          ],
        ),
      ),
    );
  }

  Widget _buildWideHeader(BuildContext context) {
    if (!_selecting) return _buildWideNormalHeader(context);
    // Seleccionando, el encabezado conserva su altura (el de siempre queda
    // invisible debajo): la lista no se mueve.
    return Stack(
      children: [
        Visibility(
          visible: false,
          maintainSize: true,
          maintainAnimation: true,
          maintainState: true,
          child: _buildWideNormalHeader(context),
        ),
        Positioned.fill(child: _buildWideSelectionHeader(context)),
      ],
    );
  }

  Widget _buildWideNormalHeader(BuildContext context) {
    final l10n = context.l10n;
    final theme = Theme.of(context);
    final visible = _visibleNotes().length;
    final background = _newNoteColor(theme);
    return SafeArea(
      bottom: false,
      left: false,
      child: Padding(
        padding: const EdgeInsetsDirectional.fromSTEB(20, 16, 16, 8),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
        Row(
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
                  // En su propio renglón: la columna de la lista puede ser
                  // angosta (junto a "Nueva nota").
                  Transform.translate(
                    offset: const Offset(-6, 0),
                    child: _buildOrderButton(context),
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
            const SizedBox(height: 12),
            _buildSearchField(context, wide: true),
            if (!_search.isEmpty)
              Padding(
                padding: const EdgeInsetsDirectional.only(start: 4, top: 2),
                child: _buildSearchScope(context),
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
  /// La lista de notas de [view] (por omisión, lo que se ve o donde se
  /// busca).
  Widget _buildBody(BuildContext context,
      {required double bottomSpace, GroupFilter? view}) {
    final scope = view ?? _scope;
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

    final search = _search;
    final notes = _visibleNotes(scope);
    if (notes.isEmpty) {
      return Center(
        child: Padding(
          padding: EdgeInsets.fromLTRB(24, 24, 24, 24 + bottomSpace / 2),
          child: Text(
            !search.isEmpty
                ? l10n.noSearchResults(_searchText.text.trim())
                : allNotes.isEmpty
                    ? l10n.emptyNotes
                    : l10n.emptyFilter,
            textAlign: TextAlign.center,
            style: theme.textTheme.bodyLarge
                ?.copyWith(color: theme.colorScheme.onSurfaceVariant),
          ),
        ),
      );
    }

    // "Por grupo" (en Todas, sin buscar): una sección por grupo.
    final bySections =
        search.isEmpty && _effectiveOrderFor(scope) == NoteOrder.byGroup;
    // El grupo de cada nota se muestra cuando la lista mezcla grupos (en
    // secciones ya lo dice su encabezado).
    final showGroup = scope.isAll && !bySections;
    // Con notas fijadas (y sin buscar): "Fijadas" arriba y "Otras" abajo.
    final pinnedCount =
        search.isEmpty
        ? notes.takeWhile((n) => _isPinnedIn(n, scope)).length
        : 0;
    final items = <Object>[
      if (pinnedCount > 0) _Section.pinned,
      ...notes.take(pinnedCount),
      if (bySections) ...[
        for (final (i, note) in notes.skip(pinnedCount).indexed) ...[
          if (i == 0 || notes[pinnedCount + i - 1].group != note.group)
            _GroupSection(
              note.group,
              notes
                  .skip(pinnedCount)
                  .where((n) => n.group == note.group)
                  .length,
            ),
          note,
        ],
      ] else ...[
        if (pinnedCount > 0 && pinnedCount < notes.length) _Section.others,
        ...notes.skip(pinnedCount),
      ],
    ];
    // Escucha el dedo para "arrastrar para seleccionar" (ver
    // [_onLongPressNote]).
    return Listener(
      onPointerMove: _onDragPointerMove,
      onPointerUp: _endDragSelection,
      onPointerCancel: _endDragSelection,
      child: ListView.builder(
      controller: _listController(scope),
      padding: EdgeInsets.fromLTRB(8, 4, 8, bottomSpace),
      itemCount: items.length,
      itemBuilder: (context, index) {
        final item = items[index];
        if (item is _Section) {
          final pinnedHeader = item == _Section.pinned;
          return Padding(
            padding: EdgeInsetsDirectional.fromSTEB(
                22, pinnedHeader ? 8 : 16, 12, 4),
            child: Text(
              pinnedHeader ? l10n.pinnedNotes : l10n.otherNotes,
              key: ValueKey(pinnedHeader ? 'pinned-header' : 'others-header'),
              style: theme.textTheme.labelLarge?.copyWith(
                  color: theme.colorScheme.onSurfaceVariant),
            ),
          );
        }
        if (item is _GroupSection) {
          // Carpetita + nombre (como antes) · cuántas notas ───── (línea
          // del color del grupo que se desvanece hacia la derecha, diseño 39).
          final name = item.group;
          final muted = theme.colorScheme.onSurfaceVariant;
          final color = name == null ? muted : _colorOf(name, theme);
          final label =
              theme.textTheme.labelLarge?.copyWith(color: muted);
          return Padding(
            key: ValueKey('group-section-${name ?? ''}'),
            padding: const EdgeInsetsDirectional.fromSTEB(22, 16, 12, 4),
            child: Row(
              children: [
                if (name != null) ...[
                  GroupFolderIcon(color, size: 16),
                  const SizedBox(width: 8),
                ],
                Flexible(
                  child: Text(
                    name ?? l10n.groupsNone,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: label,
                  ),
                ),
                Text(
                  ' · ${item.count}',
                  key: ValueKey('group-section-count-${name ?? ''}'),
                  style: label,
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Container(
                    height: 1.5,
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(1),
                      gradient: LinearGradient(
                        colors: [color, color.withValues(alpha: 0)],
                      ),
                    ),
                  ),
                ),
              ],
            ),
          );
        }
        final note = item as Note;
        final group = note.group;
        return MetaData(
          metaData: _NoteHit(note),
          behavior: HitTestBehavior.translucent,
          child: NoteRow(
          pinned: _isPinnedIn(note, scope),
          note: note,
          groupColor: group == null ? null : _colorOf(group, theme),
          showGroup: showGroup,
          selected: _isOpenInPane(note),
          search: search.isEmpty ? null : search,
          matchesExpanded: _expandedMatches.contains(_noteKey(note)),
          matchesShown: _shownMatches[_noteKey(note)] ?? _matchesPage,
          onToggleMatches: () => _toggleMatches(note),
          onShowMoreMatches: () => _showMoreMatches(note),
          onOpenMatch: (match) => _open(note, match: match),
          selectionMode: _selecting,
          checked: _isChecked(note),
          // Seleccionando: tocar marca o desmarca. En PC, Ctrl+clic también
          // selecciona.
          onTap: () => _selecting ||
                  HardwareKeyboard.instance.isControlPressed
              ? _toggleSelection(note)
              : _open(note),
          onMenu: (_) => _toggleSelection(note),
          onLongPress: (position) => _onLongPressNote(note, scope, position),
        ),
        );
      },
    ),
    );
  }
}

/// Marca cada fila de nota en la lista, para saber qué nota está bajo el
/// dedo al arrastrar para seleccionar.
class _NoteHit {
  const _NoteHit(this.note);
  final Note note;
}
