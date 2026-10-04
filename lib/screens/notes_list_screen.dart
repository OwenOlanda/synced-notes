import 'package:flutter/material.dart';

import '../models/note.dart';
import '../services/app_settings.dart';
import '../services/note_storage.dart';
import '../utils/date_text.dart';
import '../widgets/confirm_delete_dialog.dart';
import 'note_editor_screen.dart';

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
  String? _error;

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
        _error = null;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _error = 'No se pudo abrir la carpeta de notas:\n'
            '${widget.storage.folder.path}\n\n$e';
      });
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

  Future<void> _showNoteMenu(Note note, Offset position) async {
    final overlay = Overlay.of(context).context.findRenderObject()! as RenderBox;
    final choice = await showMenu<String>(
      context: context,
      position: RelativeRect.fromRect(
        position & const Size(1, 1),
        Offset.zero & overlay.size,
      ),
      items: const [
        PopupMenuItem(value: 'delete', child: Text('Borrar')),
      ],
    );
    if (choice == 'delete') await _delete(note);
  }

  Future<void> _delete(Note note) async {
    final confirmed = await confirmDeleteNote(context, note.displayTitle);
    if (!confirmed || !mounted) return;
    final messenger = ScaffoldMessenger.of(context);
    try {
      await widget.storage.deleteNote(note.fileName!);
      messenger.showSnackBar(const SnackBar(content: Text('Nota borrada')));
    } catch (e) {
      messenger.showSnackBar(SnackBar(content: Text('No se pudo borrar: $e')));
    }
    await _load();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Synced Notes'),
        actions: [
          // Por si cambiaste archivos desde el explorador con la app abierta.
          IconButton(
            tooltip: 'Actualizar lista',
            icon: const Icon(Icons.refresh),
            onPressed: _load,
          ),
        ],
      ),
      body: _buildBody(context),
      floatingActionButton: FloatingActionButton(
        tooltip: 'Nueva nota',
        onPressed: () => _open(Note.blank()),
        child: const Icon(Icons.add),
      ),
    );
  }

  Widget _buildBody(BuildContext context) {
    final theme = Theme.of(context);

    if (_error != null) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(_error!, textAlign: TextAlign.center),
              const SizedBox(height: 16),
              FilledButton(onPressed: _load, child: const Text('Reintentar')),
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
          'Aún no tienes notas.\nToca + para crear una.',
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
              note.displayTitle,
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
              _preview(note),
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
            ),
            trailing: Text(
              shortDate(note.modifiedAt),
              style: theme.textTheme.bodySmall,
            ),
            onTap: () => _open(note),
          ),
        );
      },
    );
  }

  /// Inicio del texto, en una sola línea.
  String _preview(Note note) {
    final text = note.content.trim();
    if (text.isEmpty) return 'Sin texto';
    final start = text.length > 200 ? text.substring(0, 200) : text;
    return start.replaceAll(RegExp(r'\s*\n\s*'), ' · ');
  }
}
