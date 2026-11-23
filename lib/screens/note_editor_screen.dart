import 'dart:async';
import 'dart:math' as math;
import 'dart:ui' show AppExitResponse;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../l10n/l10n.dart';
import '../models/note.dart';
import '../services/app_settings.dart';
import '../services/note_storage.dart';
import '../utils/note_search.dart';
import '../widgets/app_message.dart';
import '../widgets/blocked_chars_formatter.dart';
import '../widgets/confirm_delete_dialog.dart';
import '../widgets/find_highlight_controller.dart';
import '../widgets/search_options_toggles.dart';
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
    this.initialFind,
    this.onFindDismissed,
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

  /// Abrir con "Buscar en esta nota" ya puesta: lo buscado y en qué
  /// coincidencia empezar (0 = la primera; primero cuentan las del título).
  /// Se usa al abrir una nota desde los resultados de la búsqueda.
  final ({String query, int match})? initialFind;

  /// Se cerró (con la ✕ o Esc) la barra de búsqueda que venía de
  /// [initialFind]: quien abrió la nota puede cerrar también su búsqueda.
  final VoidCallback? onFindDismissed;

  @override
  State<NoteEditorScreen> createState() => NoteEditorScreenState();
}

class NoteEditorScreenState extends State<NoteEditorScreen> {
  // Orden de Tab dentro del editor.
  static const double _titleOrder = 1;
  static const double _contentOrder = 2;
  static const double _closeOrder = 3;
  static const double _findOrder = 3.5;
  static const double _saveOrder = 4;
  static const double _menuOrder = 5;

  static const Duration _autosaveDelay = Duration(seconds: 2);

  /// La nota tal como está guardada en disco (o en blanco si es nueva).
  late Note _note;
  late final FindHighlightController _title;
  late final FindHighlightController _content;
  final FocusNode _contentFocus = FocusNode();
  final FocusNode _titleFocus = FocusNode(debugLabel: 'título');

  /// Para encontrar el campo del texto y desplazarlo hasta un resultado.
  final GlobalKey _contentKey = GlobalKey();

  // Buscar en esta nota -------------------------------------------------------

  /// La barra "Buscar en esta nota" está abierta.
  bool _findOpen = false;

  /// La barra se abrió sola al llegar desde los resultados de la lista.
  bool _findFromList = false;
  final TextEditingController _findText = TextEditingController();
  final FocusNode _findFocus = FocusNode(debugLabel: 'buscar en esta nota');

  /// Dónde aparece lo buscado: primero en el título y luego en el texto.
  /// Cada uno: (¿en el título?, inicio, fin). [_current]: el actual
  /// (-1 = ninguno).
  List<(bool, int, int)> _matches = const [];
  int _current = -1;
  late final AppLifecycleListener _lifecycle;

  /// Aviso "el título no puede contener…" al teclear un carácter prohibido.
  late final TemporaryHint _forbiddenHint = TemporaryHint(() {
    if (mounted) setState(() {});
  });
  late final BlockedCharsFormatter _titleFormatter = BlockedCharsFormatter(
    NoteStorage.forbiddenTitleChars,
    onBlocked: _forbiddenHint.show,
    onAllowed: _forbiddenHint.hide,
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
    _title = FindHighlightController(text: _note.title)
      ..addListener(_onChanged);
    _content = FindHighlightController(text: _note.content)
      ..addListener(_onChanged);
    _lifecycle = AppLifecycleListener(
      onPause: _saveIfAutosave, // Android: la app pasa a segundo plano
      onHide: _saveIfAutosave, // Windows: se minimiza la ventana
      onExitRequested: _onExitRequested, // se cierra la app
    );
    final find = widget.initialFind;
    _findFromList = find != null;
    if (find != null) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) findAt(find.query, find.match);
      });
    }
  }

  @override
  void dispose() {
    _autosaveTimer?.cancel();
    _forbiddenHint.dispose();
    _lifecycle.dispose();
    _title.dispose();
    _content.dispose();
    _contentFocus.dispose();
    _titleFocus.dispose();
    _findText.dispose();
    _findFocus.dispose();
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
    // Si se edita con la barra de búsqueda abierta, los resultados se
    // recalculan (se queda en el mismo número de resultado si aún existe).
    if (_findOpen) _updateMatches();
    setState(() {}); // actualiza el indicador de estado
    _autosaveTimer?.cancel();
    if (widget.settings.autosave && _hasUnsavedChanges) {
      _autosaveTimer = Timer(_autosaveDelay, _save);
    }
  }

  // ---------------------------------------------------------------------------
  // Buscar en esta nota
  // ---------------------------------------------------------------------------

  /// Abre la barra (o, si ya está abierta, vuelve a ella). Si hay texto
  /// seleccionado en la nota, se busca eso.
  void _openFind() {
    final selection = _content.selection;
    final selected = selection.isValid && !selection.isCollapsed
        ? selection.textInside(_content.text)
        : '';
    if (selected.isNotEmpty && !selected.contains('\n')) {
      _findText.text = selected;
    }
    _findText.selection =
        TextSelection(baseOffset: 0, extentOffset: _findText.text.length);
    setState(() => _findOpen = true);
    _updateMatches(fromStart: true);
    // Después del cuadro: la primera vez el campo aún no existe.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted && _findOpen) _findFocus.requestFocus();
    });
    _revealCurrent();
  }

  /// Abre "Buscar en esta nota" con [query] ya escrito y en la coincidencia
  /// número [match] (0 = la primera), resaltada y a la vista. Para llegar
  /// desde los resultados de la búsqueda de la lista.
  ///
  /// En el celular no enfoca el buscador (no abre el teclado): se llega a
  /// leer. En PC sí, para seguir con Enter.
  void findAt(String query, int match) {
    _findText.text = query;
    _findText.selection =
        TextSelection(baseOffset: 0, extentOffset: query.length);
    setState(() {
      _findOpen = true;
      _updateMatches(fromStart: true);
      if (_matches.isNotEmpty) {
        _current = match.clamp(0, _matches.length - 1);
        _applyHighlights();
      }
    });
    if (widget.embedded) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted && _findOpen) _findFocus.requestFocus();
      });
    }
    _revealCurrent();
  }

  /// Cierra la barra y quita el resaltado. En PC, el cursor queda sobre el
  /// resultado actual para seguir escribiendo ahí.
  void _closeFind() {
    if (!_findOpen) return;
    if (_findFromList) {
      _findFromList = false;
      widget.onFindDismissed?.call();
    }
    final match = _current >= 0 ? _matches[_current] : null;
    setState(() {
      _findOpen = false;
      _matches = const [];
      _current = -1;
      _title.clearHighlights();
      _content.clearHighlights();
    });
    if (widget.embedded) {
      if (match == null) {
        _contentFocus.requestFocus();
      } else {
        final (inTitle, start, end) = match;
        (inTitle ? _title : _content).selection =
            TextSelection(baseOffset: start, extentOffset: end);
        if (inTitle) {
          _titleFocus.requestFocus();
        } else {
          _contentFocus.requestFocus();
        }
      }
    } else {
      _findFocus.unfocus();
    }
  }

  /// Recalcula los resultados. [fromStart]: empezar por el primero (al
  /// cambiar lo buscado); si no, conservar el número actual si aún existe.
  void _updateMatches({bool fromStart = false}) {
    final search =
        NoteSearch(_findText.text, options: widget.settings.searchOptions);
    final matches = [
      for (final (s, e) in search.rangesIn(_title.text)) (true, s, e),
      for (final (s, e) in search.rangesIn(_content.text)) (false, s, e),
    ];
    var current = fromStart ? 0 : _current;
    if (matches.isEmpty) {
      current = -1;
    } else if (current < 0 || current >= matches.length) {
      current = 0;
    }
    _matches = matches;
    _current = current;
    _applyHighlights();
  }

  /// Pasa los resultados a cada campo (título y texto) para que los pinte.
  void _applyHighlights() {
    List<(int, int)> rangesOf(bool title) => [
          for (final (inTitle, s, e) in _matches)
            if (inTitle == title) (s, e),
        ];
    final inTitle = rangesOf(true);
    final current = _current;
    _title.setHighlights(
        inTitle, current >= 0 && current < inTitle.length ? current : -1);
    _content.setHighlights(
        rangesOf(false), current >= inTitle.length ? current - inTitle.length : -1);
  }

  /// Se cambió Aa / á / ab: se recalcula (y se recuerda para la próxima).
  Future<void> _setSearchOptions(SearchOptions options) async {
    await widget.settings.setSearchOptions(options);
    if (!mounted) return;
    setState(() => _updateMatches());
    _revealCurrent();
  }

  void _onFindChanged() {
    setState(() => _updateMatches(fromStart: true));
    _revealCurrent();
  }

  /// Ir al siguiente (+1) o al anterior (-1); al llegar al final, da la
  /// vuelta.
  void _goToMatch(int step) {
    if (_matches.isEmpty) return;
    setState(() {
      _current = (_current + step) % _matches.length;
      _applyHighlights();
    });
    _revealCurrent();
  }

  /// Desplaza el texto de la nota hasta que se vea el resultado actual (el
  /// título siempre se ve).
  void _revealCurrent() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted || _current < 0 || _current >= _matches.length) return;
      final (inTitle, start, _) = _matches[_current];
      if (inTitle) return;
      _contentEditable()?.bringIntoView(TextPosition(offset: start));
    });
  }

  /// El EditableText del campo del texto (lo que se desplaza).
  EditableTextState? _contentEditable() {
    EditableTextState? found;
    void visit(Element element) {
      if (found != null) return;
      if (element is StatefulElement && element.state is EditableTextState) {
        found = element.state as EditableTextState;
        return;
      }
      element.visitChildren(visit);
    }

    _contentKey.currentContext?.visitChildElements(visit);
    return found;
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
        order: const NumericFocusOrder(_findOrder),
        child: IconButton(
          tooltip: widget.embedded
              ? '${l10n.findInNote} (Ctrl+F)'
              : l10n.findInNote,
          icon: const Icon(Icons.search),
          onPressed: _openFind,
        ),
      ),
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
          focusNode: _titleFocus,
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
            key: _contentKey,
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

  /// Márgenes del texto en el celular. A los lados, al menos la zona del
  /// gesto de "atrás" de Android: si el texto llega a la orilla, poner el
  /// cursor al inicio de un renglón o estirar una selección hasta ahí se
  /// confunde con ese gesto.
  EdgeInsets _phonePadding(BuildContext context) {
    final gestures = MediaQuery.systemGestureInsetsOf(context);
    return EdgeInsets.fromLTRB(
      math.max(16.0, gestures.left + 4),
      0,
      math.max(16.0, gestures.right + 4),
      16,
    );
  }

  /// Barra "Buscar en esta nota":
  ///   [🔍 lo buscado      ]  2 de 5   ▲  ▼  ✕
  Widget _buildFindBar(BuildContext context) {
    final l10n = context.l10n;
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final keys = widget.embedded; // en PC, las pistas de teclas
    final String count;
    if (_findText.text.trim().isEmpty) {
      count = '';
    } else if (_matches.isEmpty) {
      count = l10n.findNoMatches;
    } else {
      count = l10n.findMatchCount(_current + 1, _matches.length);
    }
    final hasMatches = _matches.isNotEmpty;
    return Padding(
      padding: const EdgeInsetsDirectional.fromSTEB(12, 6, 4, 6),
      child: Row(
        children: [
          Expanded(
            child: CallbackShortcuts(
              bindings: {
                // Esc cierra la barra (no la nota).
                const SingleActivator(LogicalKeyboardKey.escape): _closeFind,
                const SingleActivator(LogicalKeyboardKey.enter, shift: true):
                    () => _goToMatch(-1),
              },
              child: TextField(
                key: const ValueKey('find-in-note-field'),
                controller: _findText,
                focusNode: _findFocus,
                textInputAction: TextInputAction.search,
                onChanged: (_) => _onFindChanged(),
                // Enter: siguiente, sin soltar el campo.
                onSubmitted: (_) {
                  _goToMatch(1);
                  _findFocus.requestFocus();
                },
                onEditingComplete: () {},
                decoration: InputDecoration(
                  hintText: l10n.findInNote,
                  // En el celular no cabe la lupa junto a Aa / á / ab.
                  prefixIcon: keys ? const Icon(Icons.search, size: 20) : null,
                  contentPadding: keys
                      ? const EdgeInsets.symmetric(vertical: 10)
                      : const EdgeInsets.fromLTRB(12, 10, 0, 10),
                  suffixIcon: Padding(
                    padding: const EdgeInsetsDirectional.only(end: 6),
                    child: SearchOptionsToggles(
                      options: widget.settings.searchOptions,
                      onChanged: _setSearchOptions,
                    ),
                  ),
                  isDense: true,
                  filled: true,
                  fillColor: scheme.surfaceContainerHighest,
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: BorderSide.none,
                  ),
                ),
              ),
            ),
          ),
          const SizedBox(width: 8),
          Text(
            count,
            key: const ValueKey('find-in-note-count'),
            style: theme.textTheme.bodyMedium
                ?.copyWith(color: scheme.onSurfaceVariant),
          ),
          IconButton(
            tooltip: keys
                ? '${l10n.findPrevious} (Shift+Enter)'
                : l10n.findPrevious,
            visualDensity: VisualDensity.compact,
            icon: const Icon(Icons.keyboard_arrow_up),
            onPressed: hasMatches ? () => _goToMatch(-1) : null,
          ),
          IconButton(
            tooltip: keys ? '${l10n.findNext} (Enter)' : l10n.findNext,
            visualDensity: VisualDensity.compact,
            icon: const Icon(Icons.keyboard_arrow_down),
            onPressed: hasMatches ? () => _goToMatch(1) : null,
          ),
          IconButton(
            tooltip: keys ? '${l10n.closeSearch} (Esc)' : l10n.closeSearch,
            visualDensity: VisualDensity.compact,
            icon: const Icon(Icons.close),
            onPressed: _closeFind,
          ),
        ],
      ),
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
              if (_findOpen) ...[
                _buildFindBar(context),
                const Divider(height: 1),
              ],
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
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              if (_findOpen) _buildFindBar(context),
              Expanded(
                child: Padding(
                  padding: _phonePadding(context),
                  child: _buildFields(context),
                ),
              ),
            ],
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
          // Ctrl+F dentro de la nota: buscar en esta nota.
          const SingleActivator(LogicalKeyboardKey.keyF, control: true):
              _openFind,
          // Esc cierra la nota (igual que la X o la flecha de regresar);
          // con la barra de búsqueda abierta, primero cierra la barra.
          const SingleActivator(LogicalKeyboardKey.escape): () =>
              _findOpen ? _closeFind() : _leave(),
        },
        child: page,
      ),
    );
  }
}
