import 'package:flutter/material.dart';

import '../l10n/l10n.dart';
import '../models/note.dart';
import '../services/app_settings.dart';
import '../services/note_storage.dart';
import '../utils/date_text.dart';
import '../widgets/confirm_delete_dialog.dart';
import 'note_editor_screen.dart';
import 'settings_screen.dart';

/// Pantalla principal: la lista de notas.
/// - Toca una nota para abrirla.
/// - Clic derecho (Windows) o mantener presionado (Android) para borrar.
/// - Botón + para una nota nueva.
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
  Object? _loadError; // el texto se arma en build(), en el idioma actual

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    try {
      final notes = await widget.storage.listNotes();
      if (!mounted) return;
      setState(() {
        _notes = notes;
        _loadError = null;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() => _loadError = e);
    }
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

  Future<void> _showNoteMenu(Note note, Offset position) async {
    final overlay = Overlay.of(context).context.findRenderObject()! as RenderBox;
    final choice = await showMenu<String>(
      context: context,
      position: RelativeRect.fromRect(
        position & const Size(1, 1),
        Offset.zero & overlay.size,
      ),
      items: [
        PopupMenuItem(value: 'delete', child: Text(context.l10n.delete)),
      ],
    );
    if (choice == 'delete') await _delete(note);
  }

  Future<void> _delete(Note note) async {
    final confirmed =
        await confirmDeleteNote(context, context.l10n.displayTitle(note));
    if (!confirmed || !mounted) return;
    final messenger = ScaffoldMessenger.of(context);
    final l10n = context.l10n;
    try {
      await widget.storage.deleteNote(note.fileName!);
      messenger.showSnackBar(SnackBar(content: Text(l10n.noteDeleted)));
    } catch (e) {
      messenger.showSnackBar(
          SnackBar(content: Text(l10n.deleteError(l10n.errorText(e)))));
    }
    await _load();
  }

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
      ),
      body: _buildBody(context),
      floatingActionButton: FloatingActionButton(
        tooltip: l10n.newNote,
        onPressed: () => _open(Note.blank()),
        child: const Icon(Icons.add),
      ),
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

    final notes = _notes;
    if (notes == null) {
      return const Center(child: CircularProgressIndicator());
    }

    if (notes.isEmpty) {
      return Center(
        child: Text(
          l10n.emptyNotes,
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
            subtitle: Text(
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
