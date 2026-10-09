import 'dart:async';
import 'dart:ui' show AppExitResponse;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../l10n/l10n.dart';
import '../models/note.dart';
import '../services/app_settings.dart';
import '../services/note_storage.dart';
import '../widgets/confirm_delete_dialog.dart';

enum _LeaveChoice { save, discard, cancel }

/// Un error del editor. Se guarda qué pasó (y el detalle técnico), no el
/// texto: el mensaje se arma al mostrarlo, en el idioma actual.
class _EditorError {
  const _EditorError.save(this.detail) : _isSave = true;
  const _EditorError.delete(this.detail) : _isSave = false;

  final bool _isSave;
  final Object detail;

  String message(AppLocalizations l10n) {
    final text = l10n.errorText(detail);
    return _isSave ? l10n.saveError(text) : l10n.deleteError(text);
  }
}

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
  _EditorError? _error;

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

  String _status(AppLocalizations l10n) {
    if (_saving) return l10n.statusSaving;
    if (_error != null) return l10n.statusSaveError;
    if (_isEmptyNew) return l10n.statusNewNote;
    if (_hasUnsavedChanges) return l10n.statusUnsaved;
    return l10n.statusSaved;
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
      _error = _EditorError.save(e);
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  Future<void> _saveIfAutosave() async {
    if (widget.settings.autosave) await _save();
  }

  Future<void> _manualSave() async {
    final messenger = ScaffoldMessenger.of(context);
    final l10n = context.l10n;
    if (_isEmptyNew) {
      messenger
        ..hideCurrentSnackBar()
        ..showSnackBar(SnackBar(content: Text(l10n.emptyNoteNotSaved)));
      return;
    }
    await _save();
    if (_error == null) {
      messenger
        ..hideCurrentSnackBar()
        ..showSnackBar(SnackBar(
          content: Text(l10n.noteSaved),
          duration: const Duration(seconds: 1),
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
      builder: (context) {
        final l10n = context.l10n;
        return AlertDialog(
          title: Text(l10n.unsavedChangesQuestion),
          content: Text(l10n.unsavedChangesMessage),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context, _LeaveChoice.cancel),
              child: Text(l10n.cancel),
            ),
            TextButton(
              onPressed: () => Navigator.pop(context, _LeaveChoice.discard),
              child: Text(l10n.discard),
            ),
            FilledButton(
              onPressed: () => Navigator.pop(context, _LeaveChoice.save),
              child: Text(l10n.save),
            ),
          ],
        );
      },
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
      builder: (context) {
        final l10n = context.l10n;
        return AlertDialog(
          title: Text(l10n.saveFailedTitle),
          content: Text(_error!.message(l10n)),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context, true),
              child: Text(l10n.leaveWithoutSaving),
            ),
            FilledButton(
              onPressed: () => Navigator.pop(context, false),
              child: Text(l10n.stay),
            ),
          ],
        );
      },
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
    final confirmed =
        await confirmDeleteNote(context, context.l10n.displayTitle(_note));
    if (!confirmed) return;
    _autosaveTimer?.cancel();
    await _saveQueue; // esperar a que termine cualquier guardado en curso
    try {
      await widget.storage.deleteNote(_note.fileName!);
      _deleted = true;
      if (mounted) Navigator.of(context).pop();
    } catch (e) {
      if (mounted) setState(() => _error = _EditorError.delete(e));
    }
  }

  // ---------------------------------------------------------------------------
  // Pantalla
  // ---------------------------------------------------------------------------

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colors = theme.colorScheme;
    final l10n = context.l10n;

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
              _status(l10n),
              style: theme.textTheme.bodyMedium?.copyWith(
                color: _error != null ? colors.error : colors.onSurfaceVariant,
              ),
            ),
            actions: [
              IconButton(
                tooltip: l10n.saveTooltip,
                icon: const Icon(Icons.save_outlined),
                onPressed: _manualSave,
              ),
              PopupMenuButton<String>(
                tooltip: l10n.moreOptions,
                onSelected: (value) {
                  if (value == 'autosave') _toggleAutosave();
                  if (value == 'delete') _delete();
                },
                itemBuilder: (context) => [
                  CheckedPopupMenuItem(
                    value: 'autosave',
                    checked: widget.settings.autosave,
                    child: Text(l10n.autosaveTitle),
                  ),
                  if (_note.isSaved)
                    PopupMenuItem(
                      value: 'delete',
                      child: Text(l10n.deleteNote),
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
                      child: Text(_error!.message(l10n),
                          style: TextStyle(color: colors.error)),
                    ),
                  TextField(
                    controller: _title,
                    autofocus: !_note.isSaved, // nota nueva: empieza en el título
                    style: theme.textTheme.headlineSmall,
                    decoration: InputDecoration(
                      hintText: l10n.titleHint,
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
                      decoration: InputDecoration(
                        hintText: l10n.contentHint,
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
