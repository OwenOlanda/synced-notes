import 'dart:async';
import 'dart:ui' show AppExitResponse;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../l10n/l10n.dart';
import '../models/note.dart';
import '../services/app_settings.dart';
import '../services/note_storage.dart';
import '../widgets/app_message.dart';
import '../widgets/blocked_chars_formatter.dart';
import '../widgets/confirm_delete_dialog.dart';
import '../widgets/move_note_dialog.dart';

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
///
/// Dos formas de mostrarlo:
/// - Pantalla completa (celular): con su barra de arriba y flecha de
///   regresar.
/// - [embedded] (vista de PC): dentro de la tercera columna, con una barra
///   de herramientas propia y una X para cerrar ([onClose]). Quien lo
///   contiene puede pedirle con [NoteEditorScreenState.prepareToLeave] que
///   resuelva los cambios pendientes antes de abrir otra nota.
class NoteEditorScreen extends StatefulWidget {
  const NoteEditorScreen({
    super.key,
    required this.note,
    required this.storage,
    required this.settings,
    this.embedded = false,
    this.onSaved,
    this.onDeleted,
    this.onClose,
  });

  final Note note;
  final NoteStorage storage;
  final AppSettings settings;

  /// Dentro de otra pantalla (vista de PC), en vez de pantalla completa.
  final bool embedded;

  /// Se guardó (o se movió) la nota: así queda ahora.
  final ValueChanged<Note>? onSaved;

  /// Se borró la nota.
  final VoidCallback? onDeleted;

  /// Solo [embedded]: se pidió cerrar la nota y los cambios ya se
  /// resolvieron (guardados o descartados).
  final VoidCallback? onClose;

  @override
  State<NoteEditorScreen> createState() => NoteEditorScreenState();
}

class NoteEditorScreenState extends State<NoteEditorScreen> {
  // Orden de Tab dentro del editor.
  static const double _titleOrder = 1;
  static const double _contentOrder = 2;
  static const double _closeOrder = 3;
  static const double _saveOrder = 4;
  static const double _menuOrder = 5;

  static const Duration _autosaveDelay = Duration(seconds: 2);

  /// La nota tal como está guardada en disco (o en blanco si es nueva).
  late Note _note;
  late final TextEditingController _title;
  late final TextEditingController _content;
  final FocusNode _contentFocus = FocusNode();
  late final AppLifecycleListener _lifecycle;

  /// Aviso "el título no puede contener…" al teclear un carácter prohibido.
  late final TemporaryHint _forbiddenHint = TemporaryHint(() {
    if (mounted) setState(() {});
  });
  late final BlockedCharsFormatter _titleFormatter = BlockedCharsFormatter(
    NoteStorage.forbiddenTitleChars,
    onBlocked: _forbiddenHint.show,
  );

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
    _forbiddenHint.dispose();
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
      widget.onSaved?.call(_note);
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
      messenger.showMessage(l10n.emptyNoteNotSaved);
      return;
    }
    await _save();
    if (_error == null) {
      messenger.showMessage(l10n.noteSaved,
          duration: const Duration(milliseconds: 1500));
    }
  }

  // ---------------------------------------------------------------------------
  // Mover a otro grupo
  // ---------------------------------------------------------------------------

  Future<void> _move() async {
    final target = await pickGroupForMove(
      context,
      storage: widget.storage,
      current: _note.group,
    );
    if (target == null || !mounted) return;
    final messenger = ScaffoldMessenger.of(context);
    final l10n = context.l10n;

    // El movimiento espera su turno detrás de cualquier guardado en curso,
    // para no mover el archivo mientras se está escribiendo.
    _autosaveTimer?.cancel();
    Object? error;
    _saveQueue = _saveQueue.then((_) async {
      if (_deleted) return;
      try {
        _note = await widget.storage.moveNote(_note, target.group);
        widget.onSaved?.call(_note);
      } catch (e) {
        error = e;
      }
    });
    await _saveQueue;
    if (!mounted) return;

    final name = target.group;
    if (error != null) {
      messenger.showMessage(l10n.errorText(error!), isError: true);
    } else {
      messenger.showMessage(
          name == null ? l10n.noteMovedToNone : l10n.noteMovedTo(name));
    }
    _onChanged(); // si quedaron cambios sin guardar, reanuda el autoguardado
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

  /// Resuelve los cambios pendientes (guarda, o pregunta si no hay
  /// autoguardado). Devuelve `true` si ya se puede cerrar la nota o abrir
  /// otra en su lugar.
  Future<bool> prepareToLeave() => _prepareToLeave();

  /// Cerrar la nota (como la X o la flecha de regresar), resolviendo antes
  /// sus cambios. La usa el atajo Esc de la vista de PC.
  void close() => _leave();

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
    if (!canLeave || !mounted) return;
    if (widget.embedded) {
      widget.onClose?.call();
    } else {
      Navigator.of(context).pop();
    }
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
      await widget.storage
          .deleteNote(_note.fileName!, group: _note.group);
      _deleted = true;
      if (widget.embedded) {
        widget.onDeleted?.call();
      } else {
        widget.onDeleted?.call();
        if (mounted) Navigator.of(context).pop();
      }
    } catch (e) {
      if (mounted) setState(() => _error = _EditorError.delete(e));
    }
  }

  // ---------------------------------------------------------------------------
  // Pantalla
  // ---------------------------------------------------------------------------

  /// Estado (Guardado, Sin guardar…) en gris, o en rojo si hubo error.
  Widget _buildStatus(BuildContext context) {
    final theme = Theme.of(context);
    final colors = theme.colorScheme;
    return Text(
      _status(context.l10n),
      style: theme.textTheme.bodyMedium?.copyWith(
        color: _error != null ? colors.error : colors.onSurfaceVariant,
      ),
    );
  }

  /// Guardar y menú ⋮ (Autoguardado, Mover a…, Borrar nota).
  List<Widget> _buildActions(BuildContext context) {
    final l10n = context.l10n;
    return [
      FocusTraversalOrder(
        order: const NumericFocusOrder(_saveOrder),
        child: IconButton(
          tooltip: l10n.saveTooltip,
          icon: const Icon(Icons.save_outlined),
          onPressed: _manualSave,
        ),
      ),
      FocusTraversalOrder(
        order: const NumericFocusOrder(_menuOrder),
        child: PopupMenuButton<String>(
        tooltip: l10n.moreOptions,
        onSelected: (value) {
          if (value == 'autosave') _toggleAutosave();
          if (value == 'move') _move();
          if (value == 'delete') _delete();
        },
        itemBuilder: (context) => [
          CheckedPopupMenuItem(
            value: 'autosave',
            checked: widget.settings.autosave,
            child: Text(l10n.autosaveTitle),
          ),
          PopupMenuItem(
            value: 'move',
            child: Text(l10n.moveTo),
          ),
          if (_note.isSaved)
            PopupMenuItem(
              value: 'delete',
              child: Text(l10n.deleteNote),
            ),
        ],
      ),
      ),
    ];
  }

  /// Título y texto de la nota.
  Widget _buildFields(BuildContext context) {
    final theme = Theme.of(context);
    final colors = theme.colorScheme;
    final l10n = context.l10n;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        if (_error != null)
          Padding(
            padding: const EdgeInsets.only(bottom: 8),
            child: Text(_error!.message(l10n),
                style: TextStyle(color: colors.error)),
          ),
        FocusTraversalOrder(
          order: const NumericFocusOrder(_titleOrder),
          child: TextField(
          controller: _title,
          autofocus: !_note.isSaved, // nota nueva: empieza en el título
          style: theme.textTheme.headlineSmall,
          decoration: InputDecoration(
            hintText: l10n.titleHint,
            border: InputBorder.none,
            errorBorder: InputBorder.none,
            focusedErrorBorder: InputBorder.none,
            counterText: '', // oculta el contador de caracteres
            errorText:
                _forbiddenHint.visible ? l10n.errorTitleForbiddenChars : null,
          ),
          maxLength: NoteStorage.maxTitleLength,
          // No deja escribir / \ : * ? " < > | y avisa.
          inputFormatters: [_titleFormatter],
          textInputAction: TextInputAction.next,
          onSubmitted: (_) => _contentFocus.requestFocus(),
        ),
        ),
        Expanded(
          child: FocusTraversalOrder(
            order: const NumericFocusOrder(_contentOrder),
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
        ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;

    Widget page;
    if (widget.embedded) {
      // Vista de PC: barra de herramientas propia + texto con ancho cómodo
      // para leer.
      page = Material(
        color: Theme.of(context).colorScheme.surface,
        child: SafeArea(
          left: false,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              SizedBox(
                height: 56,
                child: Row(
                  children: [
                    const SizedBox(width: 8),
                    if (widget.onClose != null)
                      FocusTraversalOrder(
                        order: const NumericFocusOrder(_closeOrder),
                        child: IconButton(
                          tooltip: '${l10n.closeNote} (Esc)',
                          icon: const Icon(Icons.close),
                          onPressed: _leave,
                        ),
                      ),
                    const SizedBox(width: 8),
                    Expanded(child: _buildStatus(context)),
                    ..._buildActions(context),
                    const SizedBox(width: 8),
                  ],
                ),
              ),
              const Divider(height: 1),
              Expanded(
                child: Align(
                  alignment: Alignment.topCenter,
                  child: ConstrainedBox(
                    constraints: const BoxConstraints(maxWidth: 760),
                    child: Padding(
                      padding: const EdgeInsets.fromLTRB(32, 16, 32, 16),
                      child: _buildFields(context),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      );
    } else {
      page = Scaffold(
        appBar: AppBar(
          title: _buildStatus(context),
          actions: _buildActions(context),
        ),
        body: SafeArea(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
            child: _buildFields(context),
          ),
        ),
      );
    }

    // Orden del teclado (Tab): título → texto → X → guardar → ⋮. Sin esto,
    // Tab desde el título saltaba a otra parte de la ventana.
    page = FocusTraversalGroup(
      policy: OrderedTraversalPolicy(),
      child: page,
    );

    return PopScope(
      canPop: false, // la salida pasa siempre por _leave()
      onPopInvokedWithResult: (didPop, result) {
        if (!didPop) _leave();
      },
      child: CallbackShortcuts(
        bindings: {
          const SingleActivator(LogicalKeyboardKey.keyS, control: true):
              _manualSave,
          // Esc cierra la nota (igual que la X o la flecha de regresar).
          const SingleActivator(LogicalKeyboardKey.escape): _leave,
        },
        child: page,
      ),
    );
  }
}
