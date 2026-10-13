import 'package:flutter/material.dart';

import '../l10n/l10n.dart';
import '../models/collection.dart';
import '../models/collection_filter.dart';
import '../models/note.dart';
import '../services/app_settings.dart';
import '../services/note_storage.dart';
import '../utils/date_text.dart';
import '../widgets/collection_bar.dart';
import '../widgets/collection_colors.dart';
import '../widgets/collection_dialogs.dart';
import '../widgets/confirm_delete_dialog.dart';
import '../widgets/move_note_dialog.dart';
import 'note_editor_screen.dart';
import 'settings_screen.dart';

/// Pantalla principal: la lista de notas.
/// - Arriba, chips para elegir qué ver: Todas, Sin colección o una colección.
///   El "+" de los chips crea una colección. Clic derecho o mantener
///   presionado sobre una colección: renombrar, color, borrar.
/// - Toca una nota para abrirla.
/// - Clic derecho (Windows) o mantener presionado (Android): mover a otra
///   colección o borrar.
/// - En "Todas", cada nota muestra la etiqueta de su colección.
/// - Botón + para una nota nueva (en la colección que se está viendo; dentro
///   de una colección con color, el botón toma ese color).
class NotesListScreen extends StatefulWidget {
  const NotesListScreen({
    super.key,
    required this.storage,
    required this.settings,
  });

  final NoteStorage storage;
  final AppSettings settings;

  @override
  State<NotesListScreen> createState() => _NotesListScreenState();
}

class _NotesListScreenState extends State<NotesListScreen> {
  List<Note>? _notes; // null = cargando
  List<Collection> _collections = const [];
  Object? _loadError; // el texto se arma en build(), en el idioma actual

  /// Lo que se está viendo. Se recuerda en los ajustes.
  CollectionFilter get _filter => widget.settings.selectedCollection;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    try {
      final notes = await widget.storage.listNotes();
      final collections = await widget.storage.listCollections();
      if (!mounted) return;
      setState(() {
        _notes = notes;
        _collections = collections;
        _loadError = null;
      });
      // La colección que se estaba viendo ya no existe (ej. se borró desde
      // el explorador): volver a "Todas".
      final filter = _filter;
      if (filter.isCollection &&
          !collections.any((c) => c.name == filter.name)) {
        await _select(CollectionFilter.all);
      }
    } catch (e) {
      if (!mounted) return;
      setState(() => _loadError = e);
    }
  }

  Future<void> _select(CollectionFilter filter) async {
    await widget.settings.setSelectedCollection(filter);
    if (mounted) setState(() {});
  }

  void _showError(Object error) {
    if (!mounted) return;
    final l10n = context.l10n;
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(content: Text(l10n.errorText(error))));
  }

  Future<void> _open(Note note) async {
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
    final target = await pickCollectionForMove(
      context,
      storage: widget.storage,
      current: note.collection,
    );
    if (target == null || !mounted) return;
    final messenger = ScaffoldMessenger.of(context);
    final l10n = context.l10n;
    try {
      await widget.storage.moveNote(note, target.collection);
      final name = target.collection;
      messenger
        ..hideCurrentSnackBar()
        ..showSnackBar(SnackBar(
            content: Text(name == null
                ? l10n.noteMovedToNone
                : l10n.noteMovedTo(name))));
    } catch (e) {
      _showError(e);
    }
    await _load();
  }

  Future<void> _delete(Note note) async {
    final confirmed =
        await confirmDeleteNote(context, context.l10n.displayTitle(note));
    if (!confirmed || !mounted) return;
    final messenger = ScaffoldMessenger.of(context);
    final l10n = context.l10n;
    try {
      await widget.storage
          .deleteNote(note.fileName!, collection: note.collection);
      messenger.showSnackBar(SnackBar(content: Text(l10n.noteDeleted)));
    } catch (e) {
      messenger.showSnackBar(
          SnackBar(content: Text(l10n.deleteError(l10n.errorText(e)))));
    }
    await _load();
  }

  // ---------------------------------------------------------------------------
  // Colecciones
  // ---------------------------------------------------------------------------

  Future<void> _createCollection() async {
    final l10n = context.l10n;
    String? created;
    final done = await showCollectionNameDialog(
      context,
      title: l10n.newCollection,
      confirmLabel: l10n.create,
      showColor: true,
      onSubmit: (name, color) async {
        created =
            (await widget.storage.createCollection(name, color: color)).name;
      },
    );
    if (!done) return;
    await _load();
    // Recién creada: se abre para empezar a llenarla.
    await _select(CollectionFilter.collection(created!));
  }

  Future<void> _showCollectionMenu(
      Collection collection, Offset position) async {
    final l10n = context.l10n;
    final choice = await _menuAt(position, [
      PopupMenuItem(value: 'rename', child: Text(l10n.rename)),
      PopupMenuItem(value: 'color', child: Text(l10n.collectionColor)),
      PopupMenuItem(value: 'delete', child: Text(l10n.delete)),
    ]);
    switch (choice) {
      case 'rename':
        await _renameCollection(collection);
      case 'color':
        await _changeColor(collection);
      case 'delete':
        await _deleteCollection(collection);
    }
  }

  Future<void> _renameCollection(Collection collection) async {
    final l10n = context.l10n;
    String? newName;
    final done = await showCollectionNameDialog(
      context,
      title: l10n.renameCollection,
      confirmLabel: l10n.rename,
      initialName: collection.name,
      onSubmit: (name, _) async {
        newName =
            (await widget.storage.renameCollection(collection.name, name)).name;
      },
    );
    if (!done) return;
    // Si era la que se estaba viendo, seguir viéndola con su nombre nuevo.
    if (_filter == CollectionFilter.collection(collection.name)) {
      await _select(CollectionFilter.collection(newName!));
    }
    await _load();
  }

  Future<void> _changeColor(Collection collection) async {
    final choice = await showCollectionColorDialog(
      context,
      collectionName: collection.name,
      current: collection.color,
    );
    if (choice == null) return;
    try {
      await widget.storage.setCollectionColor(collection.name, choice.color);
    } catch (e) {
      _showError(e);
    }
    await _load();
  }

  Future<void> _deleteCollection(Collection collection) async {
    final noteCount = (_notes ?? const <Note>[])
        .where((n) => n.collection == collection.name)
        .length;
    final choice = await showDeleteCollectionDialog(
      context,
      collectionName: collection.name,
      noteCount: noteCount,
    );
    if (choice == null || !mounted) return;
    final messenger = ScaffoldMessenger.of(context);
    final l10n = context.l10n;
    try {
      await widget.storage.deleteCollection(
        collection.name,
        deleteNotes: choice == DeleteCollectionChoice.deleteNotes,
      );
      messenger.showSnackBar(SnackBar(content: Text(l10n.collectionDeleted)));
      if (_filter == CollectionFilter.collection(collection.name)) {
        // Si sus notas pasaron a "Sin colección", mostrarlas ahí.
        await _select(choice == DeleteCollectionChoice.moveNotes
            ? CollectionFilter.none
            : CollectionFilter.all);
      }
    } catch (e) {
      _showError(e);
    }
    await _load();
  }

  // ---------------------------------------------------------------------------
  // Pantalla
  // ---------------------------------------------------------------------------

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    return Scaffold(
      appBar: AppBar(
        title: const Text('Synced Notes'), // el nombre no se traduce
        actions: [
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
        ],
        bottom: _notes == null
            ? null
            : PreferredSize(
                preferredSize: const Size.fromHeight(CollectionBar.height),
                child: CollectionBar(
                  collections: _collections,
                  selected: _filter,
                  onSelected: _select,
                  onCreate: _createCollection,
                  onCollectionMenu: _showCollectionMenu,
                ),
              ),
      ),
      body: _buildBody(context),
      floatingActionButton: _buildNewNoteButton(context),
    );
  }

  /// Botón "+" (nota nueva). Dentro de una colección, la nota nace ahí: el
  /// tooltip lo dice y, si la colección tiene color, el botón lo toma.
  Widget _buildNewNoteButton(BuildContext context) {
    final l10n = context.l10n;
    final theme = Theme.of(context);
    final collectionName = _filter.collectionForNewNote;
    CollectionColor? color;
    for (final c in _collections) {
      if (c.name == collectionName) color = c.color;
    }
    final background =
        color == null ? null : displayColor(color, theme.brightness);
    return FloatingActionButton(
      tooltip: collectionName == null
          ? l10n.newNote
          : l10n.newNoteIn(collectionName),
      backgroundColor: background,
      foregroundColor: background == null
          ? null
          : (ThemeData.estimateBrightnessForColor(background) ==
                  Brightness.dark
              ? Colors.white
              : Colors.black),
      onPressed: () => _open(Note.blank(collection: collectionName)),
      child: const Icon(Icons.note_add_outlined),
    );
  }

  Widget _buildBody(BuildContext context) {
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
    final showTags = _filter.isAll;
    final colors = {for (final c in _collections) c.name: c.color};
    if (notes.isEmpty) {
      return Center(
        child: Text(
          allNotes.isEmpty ? l10n.emptyNotes : l10n.emptyFilter,
          textAlign: TextAlign.center,
          style: theme.textTheme.bodyLarge
              ?.copyWith(color: theme.colorScheme.onSurfaceVariant),
        ),
      );
    }

    return ListView.separated(
      padding: const EdgeInsets.only(bottom: 88), // espacio para el botón +
      itemCount: notes.length,
      separatorBuilder: (context, index) => const Divider(height: 1),
      itemBuilder: (context, index) {
        final note = notes[index];
        return GestureDetector(
          onSecondaryTapUp: (details) =>
              _showNoteMenu(note, details.globalPosition),
          onLongPressStart: (details) =>
              _showNoteMenu(note, details.globalPosition),
          child: ListTile(
            title: Text(
              l10n.displayTitle(note),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: note.hasTitle
                  ? null
                  : TextStyle(
                      fontStyle: FontStyle.italic,
                      color: theme.colorScheme.onSurfaceVariant,
                    ),
            ),
            subtitle: showTags && note.collection != null
                ? Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        _preview(note, l10n),
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                      ),
                      const SizedBox(height: 6),
                      CollectionTag(
                        name: note.collection!,
                        color: colors[note.collection],
                      ),
                    ],
                  )
                : Text(
                    _preview(note, l10n),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
            trailing: Text(
              shortDate(note.modifiedAt, l10n),
              style: theme.textTheme.bodySmall,
            ),
            onTap: () => _open(note),
          ),
        );
      },
    );
  }

  /// Inicio del texto, en una sola línea.
  String _preview(Note note, AppLocalizations l10n) {
    final text = note.content.trim();
    if (text.isEmpty) return l10n.noPreview;
    final start = text.length > 200 ? text.substring(0, 200) : text;
    return start.replaceAll(RegExp(r'\s*\n\s*'), ' · ');
  }
}
