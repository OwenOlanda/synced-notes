import 'dart:async';
import 'dart:ui' show AppExitResponse;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../models/note.dart';
import '../services/app_settings.dart';
import '../services/note_storage.dart';
import '../widgets/confirm_delete_dialog.dart';

enum _LeaveChoice { save, discard, cancel }

/// Editor de una nota: título opcional arriba y el texto debajo.
///
/// Guardado:
/// - Botón de guardar (o Ctrl+S) siempre disponible.
/// - Con autoguardado activado: guarda 2 segundos después de dejar de
///   escribir, al salir del editor y al minimizar o cerrar la app.
/// - Con autoguardado desactivado: al salir con cambios pregunta qué hacer.
/// - Una nota nueva sin título ni texto nunca se guarda.
class NoteEditorScreen extends StatefulWidget {
  const NoteEditorScreen({
    super.key,
    required this.note,
    required this.storage,
    required this.settings,
  });

  final Note note;
  final NoteStorage storage;
  final AppSettings settings;

  @override
  State<NoteEditorScreen> createState() => _NoteEditorScreenState();
}

class _NoteEditorScreenState extends State<NoteEditorScreen> {
  static const Duration _autosaveDelay = Duration(seconds: 2);

  /// La nota tal como está guardada en disco (o en blanco si es nueva).
  late Note _note;
  late final TextEditingController _title;
  late final TextEditingController _content;
  final FocusNode _contentFocus = FocusNode();
  late final AppLifecycleListener _lifecycle;

  Timer? _autosaveTimer;
  Future<void> _saveQueue = Future.value();
  bool _saving = false;
  bool _leaving = false;
  bool _deleted = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    _note = widget.note;
    _title = TextEditingController(text: _note.title)..addListener(_onChanged);
    _content = TextEditingController(text: _note.content)
      ..addListener(_onChanged);
    _lifecycle = AppLifecycleListener(
      onPause: _saveIfAutosave, // Android: la app pasa a segundo plano
      onHide: _saveIfAutosave, // Windows: se minimiza la ventana
      onExitRequested: _onExitRequested, // se cierra la app
    );
  }

  @override
  void dispose() {
    _autosaveTimer?.cancel();
    _lifecycle.dispose();
    _title.dispose();
    _content.dispose();
    _contentFocus.dispose();
    super.dispose();
  }

  // ---------------------------------------------------------------------------
  // Estado
  // ---------------------------------------------------------------------------

  bool get _isDirty =>
      _title.text.trim() != _note.title || _content.text != _note.content;

  /// Nota nueva que sigue en blanco: no hay nada que guardar.
  bool get _isEmptyNew =>
      !_note.isSaved &&
      _title.text.trim().isEmpty &&
      _content.text.trim().isEmpty;

  bool get _hasUnsavedChanges => _isDirty && !_isEmptyNew;

  String get _status {
    if (_saving) return 'Guardando…';
    if (_error != null) return 'Error al guardar';
    if (_isEmptyNew) return 'Nota nueva';
    if (_hasUnsavedChanges) return 'Sin guardar';
    return 'Guardado';
  }

  void _onChanged() {
    if (!mounted) return;
    setState(() {}); // actualiza el indicador de estado
    _autosaveTimer?.cancel();
    if (widget.settings.autosave && _hasUnsavedChanges) {
      _autosaveTimer = Timer(_autosaveDelay, _save);
    }
  }

  // ---------------------------------------------------------------------------
  // Guardar
  // ---------------------------------------------------------------------------

  /// Guarda en orden: si ya hay un guardado en curso, este espera su turno.
  Future<void> _save() {
    _autosaveTimer?.cancel();
    _saveQueue = _saveQueue.then((_) => _doSave());
    return _saveQueue;
  }

  Future<void> _doSave() async {
    if (_deleted || !_hasUnsavedChanges) return;
    final draft =
        _note.copyWith(title: _title.text.trim(), content: _content.text);
    if (mounted) setState(() => _saving = true);
    try {
      _note = await widget.storage.saveNote(draft);
      _error = null;
    } catch (e) {
      _error = 'No se pudo guardar: $e';
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  Future<void> _saveIfAutosave() async {
    if (widget.settings.autosave) await _save();
  }

  Future<void> _manualSave() async {
    final messenger = ScaffoldMessenger.of(context);
    if (_isEmptyNew) {
      messenger
        ..hideCurrentSnackBar()
        ..showSnackBar(const SnackBar(
            content: Text('Escribe un título o un texto para guardar la nota.')));
      return;
    }
    await _save();
    if (_error == null) {
      messenger
        ..hideCurrentSnackBar()
        ..showSnackBar(const SnackBar(
          content: Text('Nota guardada'),
          duration: Duration(seconds: 1),
        ));
    }
  }

  Future<void> _toggleAutosave() async {
    await widget.settings.setAutosave(!widget.settings.autosave);
    _onChanged(); // activa o cancela el temporizador según el nuevo ajuste
  }

  // ---------------------------------------------------------------------------
  // Salir
  // ---------------------------------------------------------------------------

  Future<_LeaveChoice> _askAboutUnsaved() async {
    final choice = await showDialog<_LeaveChoice>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('¿Guardar los cambios?'),
        content: const Text('Esta nota tiene cambios sin guardar.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, _LeaveChoice.cancel),
            child: const Text('Cancelar'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, _LeaveChoice.discard),
            child: const Text('Descartar'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, _LeaveChoice.save),
            child: const Text('Guardar'),
          ),
        ],
      ),
    );
    return choice ?? _LeaveChoice.cancel;
  }

  /// Resuelve los cambios pendientes. Devuelve `true` si ya se puede salir.
  Future<bool> _prepareToLeave() async {
    _autosaveTimer?.cancel();
    if (_deleted || !_hasUnsavedChanges) return true;

    if (!widget.settings.autosave) {
      switch (await _askAboutUnsaved()) {
        case _LeaveChoice.cancel:
          return false;
        case _LeaveChoice.discard:
          return true;
        case _LeaveChoice.save:
          break;
      }
    }

    await _save();
    if (_error == null || !mounted) return true;

    // No se pudo guardar: no salir sin avisar.
    final leaveAnyway = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('No se pudo guardar'),
        content: Text(_error!),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Salir sin guardar'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Quedarme'),
          ),
        ],
      ),
    );
    return leaveAnyway ?? false;
  }

  Future<void> _leave() async {
    if (_leaving) return;
    _leaving = true;
    final canLeave = await _prepareToLeave();
    _leaving = false;
    if (canLeave && mounted) Navigator.of(context).pop();
  }

  Future<AppExitResponse> _onExitRequested() async {
    final canLeave = await _prepareToLeave();
    return canLeave ? AppExitResponse.exit : AppExitResponse.cancel;
  }

  // ---------------------------------------------------------------------------
  // Borrar
  // ---------------------------------------------------------------------------

  Future<void> _delete() async {
    final confirmed = await confirmDeleteNote(context, _note.displayTitle);
    if (!confirmed) return;
    _autosaveTimer?.cancel();
    await _saveQueue; // esperar a que termine cualquier guardado en curso
    try {
      await widget.storage.deleteNote(_note.fileName!);
      _deleted = true;
      if (mounted) Navigator.of(context).pop();
    } catch (e) {
      if (mounted) setState(() => _error = 'No se pudo borrar: $e');
    }
  }

  // ---------------------------------------------------------------------------
  // Pantalla
  // ---------------------------------------------------------------------------

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colors = theme.colorScheme;

    return PopScope(
      canPop: false, // la salida pasa siempre por _leave()
      onPopInvokedWithResult: (didPop, result) {
        if (!didPop) _leave();
      },
      child: CallbackShortcuts(
        bindings: {
          const SingleActivator(LogicalKeyboardKey.keyS, control: true):
              _manualSave,
        },
        child: Scaffold(
          appBar: AppBar(
            title: Text(
              _status,
              style: theme.textTheme.bodyMedium?.copyWith(
                color: _error != null ? colors.error : colors.onSurfaceVariant,
              ),
            ),
            actions: [
              IconButton(
                tooltip: 'Guardar (Ctrl+S)',
                icon: const Icon(Icons.save_outlined),
                onPressed: _manualSave,
              ),
              PopupMenuButton<String>(
                tooltip: 'Más opciones',
                onSelected: (value) {
                  if (value == 'autosave') _toggleAutosave();
                  if (value == 'delete') _delete();
                },
                itemBuilder: (context) => [
                  CheckedPopupMenuItem(
                    value: 'autosave',
                    checked: widget.settings.autosave,
                    child: const Text('Autoguardado'),
                  ),
                  if (_note.isSaved)
                    const PopupMenuItem(
                      value: 'delete',
                      child: Text('Borrar nota'),
                    ),
                ],
              ),
            ],
          ),
          body: SafeArea(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  if (_error != null)
                    Padding(
                      padding: const EdgeInsets.only(bottom: 8),
                      child: Text(_error!, style: TextStyle(color: colors.error)),
                    ),
                  TextField(
                    controller: _title,
                    autofocus: !_note.isSaved, // nota nueva: empieza en el título
                    style: theme.textTheme.headlineSmall,
                    decoration: const InputDecoration(
                      hintText: 'Título',
                      border: InputBorder.none,
                      counterText: '', // oculta el contador de caracteres
                    ),
                    maxLength: NoteStorage.maxTitleLength,
                    // No deja escribir / \ : * ? " < > |
                    inputFormatters: [
                      FilteringTextInputFormatter.deny(
                          NoteStorage.forbiddenTitleChars),
                    ],
                    textInputAction: TextInputAction.next,
                    onSubmitted: (_) => _contentFocus.requestFocus(),
                  ),
                  Expanded(
                    child: TextField(
                      controller: _content,
                      focusNode: _contentFocus,
                      maxLines: null,
                      expands: true,
                      keyboardType: TextInputType.multiline,
                      textAlignVertical: TextAlignVertical.top,
                      style: theme.textTheme.bodyLarge,
                      decoration: const InputDecoration(
                        hintText: 'Escribe aquí…',
                        border: InputBorder.none,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
