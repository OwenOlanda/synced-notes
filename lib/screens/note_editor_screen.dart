import 'dart:async';
import 'dart:math' as math;
import 'dart:ui' show AppExitResponse;

import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter/physics.dart' show Simulation;
import 'package:flutter/rendering.dart' show RenderEditable;
import 'package:flutter/scheduler.dart';
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

class NoteEditorScreenState extends State<NoteEditorScreen>
    with SingleTickerProviderStateMixin {
  // Orden de Tab dentro del editor.
  static const double _titleOrder = 1;
  static const double _contentOrder = 2;
  static const double _closeOrder = 3;
  static const double _undoOrder = 3.2;
  static const double _redoOrder = 3.3;
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

  // Deshacer / rehacer ----------------------------------------------------------

  /// Historial de cambios de cada campo (mientras la nota está abierta).
  final UndoHistoryController _titleUndo = UndoHistoryController();
  final UndoHistoryController _contentUndo = UndoHistoryController();

  /// El último campo donde se escribió (al que aplican ↶ ↷): `true` =
  /// título. Tocar los botones no le quita el foco al campo, pero por si
  /// acaso se recuerda.
  bool _lastFieldIsTitle = false;

  UndoHistoryController get _activeUndo =>
      _lastFieldIsTitle ? _titleUndo : _contentUndo;

  void _undo() => _activeUndo.undo();
  void _redo() => _activeUndo.redo();

  void _onFieldFocusChanged() {
    if (_titleFocus.hasFocus) _lastFieldIsTitle = true;
    if (_contentFocus.hasFocus) _lastFieldIsTitle = false;
    if (mounted) setState(() {}); // mostrar u ocultar la barrita del teclado
  }

  void _onUndoChanged() {
    if (mounted) setState(() {}); // habilitar ↶ ↷
  }

  // Desplazamiento: botón ir al inicio / al final y "donde me quedé" -------

  /// El desplazamiento del texto de la nota.
  final _NoteScrollController _contentScroll = _NoteScrollController();

  /// El botón redondo ↑/↓ se ve mientras se desplaza y se esconde solo.
  final ValueNotifier<bool> _jumpVisible = ValueNotifier(false);
  Timer? _jumpHideTimer;
  static const Duration _jumpVisibleFor = Duration(milliseconds: 2500);

  /// Dónde estaba la nota la última vez que se midió (se guarda al salir).
  NotePosition? _position;

  /// Con qué se identifica la nota para recordar su posición: su fecha de
  /// creación (no cambia aunque cambie el título).
  String get _positionId => _note.createdAt.toIso8601String();

  /// ¿Ya se midió el texto? (Antes, Flutter no sabe qué tan larga es la
  /// nota y preguntar por su largo falla.)
  bool get _scrollReady =>
      _contentScroll.hasClients &&
      _contentScroll.position.hasContentDimensions;

  void _onContentScroll() {
    if (_anchoring || !_scrollReady) return;
    if (_contentScroll.position.maxScrollExtent <= 0) return;
    _jumpVisible.value = true;
    _jumpHideTimer?.cancel();
    _jumpHideTimer =
        Timer(_jumpVisibleFor, () => _jumpVisible.value = false);
  }

  /// Arriba de la mitad: al final. Abajo de la mitad: al inicio.
  bool get _jumpGoesDown {
    if (!_scrollReady) return true;
    final position = _contentScroll.position;
    return position.pixels < position.maxScrollExtent / 2;
  }

  void _jumpToEdge() {
    if (!_scrollReady) return;
    final position = _contentScroll.position;
    _contentScroll.animateTo(
      _jumpGoesDown ? position.maxScrollExtent : 0,
      duration: const Duration(milliseconds: 400),
      curve: Curves.easeOutCubic,
    );
  }

  /// La letra que se ve hasta arriba del texto (`null` = aún no se sabe).
  int? _topChar() {
    final editable = _contentEditable()?.renderEditable;
    if (editable == null || !editable.attached || !editable.hasSize) {
      return null;
    }
    return editable
        .getPositionForPoint(editable.localToGlobal(const Offset(1, 1)))
        .offset;
  }

  /// Desplaza el texto para que la letra [char] quede hasta arriba.
  void _scrollToChar(int char) {
    if (!_scrollReady) return;
    final editable = _contentEditable()?.renderEditable;
    if (editable == null || !editable.hasSize) return;
    final text = _content.text;
    final top = NoteSearch.safeCut(text, char.clamp(0, text.length).toInt());
    final scroll = _contentScroll.position;
    // La primera letra: hasta arriba exacto (el cursor empieza un poquito
    // más abajo de su renglón y dejaba la nota movida una fracción).
    final y = top == 0
        ? 0.0
        : editable.getLocalRectForCaret(TextPosition(offset: top)).top +
            scroll.pixels;
    _anchoring = true;
    _contentScroll.jumpTo(y.clamp(0.0, scroll.maxScrollExtent).toDouble());
    _anchoring = false;
  }

  /// Se está desplazando el texto desde el código (no la persona): no se
  /// muestra el botón ↑/↓.
  bool _anchoring = false;

  /// Mide dónde está la nota: el cursor y la letra que se ve hasta arriba.
  void _measurePosition() {
    final top = _topChar();
    if (top == null) return;
    final selection = _content.selection;
    _position = NotePosition(
      cursor: selection.isValid ? selection.baseOffset : 0,
      topChar: top,
    );
  }

  /// Guarda dónde se quedó la nota (en este dispositivo).
  void _rememberPosition() {
    _measurePosition();
    final position = _position;
    if (position == null || !_note.isSaved) return;
    widget.settings.setNotePosition(_positionId, position);
  }

  /// Al abrir: al principio, al final o donde se quedó (Ajustes). Si se
  /// llega desde los resultados de una búsqueda, manda la búsqueda.
  void _restorePosition() {
    if (!mounted || !_note.isSaved || !_scrollReady) return;
    final text = _content.text;
    final scroll = _contentScroll.position;
    switch (widget.settings.noteOpenPosition) {
      case NoteOpenPosition.start:
        _content.selection = const TextSelection.collapsed(offset: 0);
        _contentScroll.jumpTo(0);
      case NoteOpenPosition.end:
        _content.selection = TextSelection.collapsed(offset: text.length);
        _contentScroll.jumpTo(scroll.maxScrollExtent);
      case NoteOpenPosition.last:
        final saved = widget.settings.notePositionOf(_positionId);
        if (saved == null) {
          _content.selection = const TextSelection.collapsed(offset: 0);
          return;
        }
        _content.selection = TextSelection.collapsed(
            offset: NoteSearch.safeCut(
                text, saved.cursor.clamp(0, text.length).toInt()));
        _scrollToChar(saved.topChar);
    }
  }

  // Zoom del texto: pellizcar (celular o touchpad), Ctrl + rueda, Ctrl ± 0 --

  /// El zoom mientras se pellizca (todavía sin guardar). `null` = no se
  /// está pellizcando: vale el de Ajustes.
  double? _pinchZoom;
  bool get _pinching => _pinchZoom != null;
  double get _zoom => _pinchZoom ?? widget.settings.textZoom;

  /// Dedos sobre la nota (solo pantalla táctil) y cómo empezó el pellizco.
  final Map<int, Offset> _touches = {};
  double _pinchStartDistance = 1;
  double _pinchStartZoom = 1;

  /// La letra que estaba hasta arriba al empezar a hacer zoom: se mantiene
  /// a la vista mientras el texto crece o se encoge. Se acomoda en el mismo
  /// cuadro en que cambia el tamaño (ver [_NoteScrollPhysics]): si se
  /// acomodara después, se vería un cuadro en el lugar equivocado (parpadeo).
  int? _zoomAnchor;
  RenderEditable? _zoomEditable;

  void _setAnchor() {
    _zoomAnchor = _topChar();
    _zoomEditable = _contentEditable()?.renderEditable;
  }

  /// Dónde debe quedar el desplazamiento para que [_zoomAnchor] siga hasta
  /// arriba. Flutter lo pregunta mientras acomoda el texto con su nuevo
  /// tamaño; [pixels] es el desplazamiento de antes. `null` = sin zoom.
  double? _anchorPixels(double pixels) {
    final anchor = _zoomAnchor;
    final editable = _zoomEditable;
    if (anchor == null || editable == null || !editable.attached) return null;
    if (anchor == 0) return 0;
    final text = _content.text;
    final top = NoteSearch.safeCut(text, anchor.clamp(0, text.length).toInt());
    if (top >= text.length) return null;
    // La caja de esa letra (no la del cursor: medir el cursor pregunta por
    // la posición en pantalla, y eso no se puede mientras se acomoda).
    final boxes = editable.getBoxesForSelection(TextSelection(
        baseOffset: top,
        extentOffset: NoteSearch.safeCut(text, top + 1) == top
            ? math.min(top + 2, text.length)
            : top + 1));
    if (boxes.isNotEmpty) return boxes.first.top + pixels;
    // Renglón vacío (solo el salto de línea): empieza donde termina la
    // letra anterior.
    if (top == 0) return null;
    final before = editable.getBoxesForSelection(TextSelection(
        baseOffset: NoteSearch.safeCut(text, top - 1), extentOffset: top));
    return before.isEmpty ? null : before.last.bottom + pixels;
  }

  /// Después del cuadro con el tamaño final, se suelta la letra de arriba
  /// (y se vuelve a medir la nota para que la barra de la derecha se
  /// ponga al día).
  void _releaseAnchorAfterFrame() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted || _pinching) return;
      final editable = _zoomEditable;
      _zoomAnchor = null;
      _zoomEditable = null;
      if (editable != null && editable.attached) editable.markNeedsLayout();
    });
  }

  /// La píldora "120%" se ve mientras se hace zoom y un segundo después.
  final ValueNotifier<bool> _zoomPillVisible = ValueNotifier(false);
  Timer? _zoomPillTimer;
  static const Duration _zoomPillFor = Duration(seconds: 1);

  void _showZoomPill({bool stay = false}) {
    _zoomPillVisible.value = true;
    _zoomPillTimer?.cancel();
    if (!stay) {
      _zoomPillTimer =
          Timer(_zoomPillFor, () => _zoomPillVisible.value = false);
    }
  }

  /// Ctrl + rueda, Ctrl + / Ctrl − y los botones: de 10 % en 10 %.
  void _zoomBy(double delta) => _setZoom(widget.settings.textZoom + delta);

  /// Ctrl + 0: tamaño normal.
  void _resetZoom() => _setZoom(1.0);

  void _setZoom(double zoom) {
    if (_pinching) return;
    _showZoomPill();
    final value = AppSettings.snapTextZoom(zoom);
    if (value == widget.settings.textZoom) return;
    if (_zoomAnchor == null) _setAnchor();
    widget.settings.setTextZoom(value);
    setState(() {});
    _releaseAnchorAfterFrame();
  }

  void _beginPinch() {
    _pinchStartZoom = widget.settings.textZoom;
    _setAnchor();
    setState(() => _pinchZoom = _pinchStartZoom);
    _showZoomPill(stay: true);
  }

  void _updatePinch(double scale) {
    final zoom = AppSettings.clampTextZoom(_pinchStartZoom * scale);
    if ((zoom - _zoom).abs() < 0.004) return;
    setState(() => _pinchZoom = zoom);
  }

  /// Al soltar: se acomoda en el 10 % más cercano y se guarda.
  void _endPinch() {
    final zoom = _pinchZoom;
    if (zoom == null) return;
    widget.settings.setTextZoom(zoom); // lo acomoda en pasos de 10 %
    setState(() => _pinchZoom = null);
    _releaseAnchorAfterFrame();
    _showZoomPill();
  }

  double get _touchDistance {
    final points = _touches.values.take(2).toList();
    return (points[0] - points[1]).distance;
  }

  void _onPointerDown(PointerDownEvent event) {
    if (event.kind != PointerDeviceKind.touch) return;
    _touches[event.pointer] = event.position;
    if (_touches.length == 2 && !_pinching) {
      _pinchStartDistance = math.max(_touchDistance, 1.0);
      _beginPinch();
    }
  }

  void _onPointerMove(PointerMoveEvent event) {
    if (!_touches.containsKey(event.pointer)) return;
    _touches[event.pointer] = event.position;
    if (_pinching && _touches.length >= 2) {
      _updatePinch(_touchDistance / _pinchStartDistance);
    }
  }

  void _onPointerUp(PointerEvent event) {
    if (_touches.remove(event.pointer) == null) return;
    if (_pinching && _touches.length < 2) _endPinch();
  }

  /// Ctrl + rueda del mouse (la rueda sola sigue desplazando el texto).
  void _onPointerSignal(PointerSignalEvent event) {
    if (event is! PointerScrollEvent) return;
    if (!HardwareKeyboard.instance.isControlPressed) return;
    GestureBinding.instance.pointerSignalResolver.register(event, (event) {
      final dy = (event as PointerScrollEvent).scrollDelta.dy;
      if (dy == 0) return;
      _zoomBy(dy < 0 ? AppSettings.textZoomStep : -AppSettings.textZoomStep);
    });
  }

  // Pellizcar en el touchpad de la laptop (llega como "pan/zoom").
  void _onPanZoomUpdate(PointerPanZoomUpdateEvent event) {
    if (!_pinching && (event.scale - 1).abs() > 0.03) _beginPinch();
    if (_pinching && _touches.isEmpty) _updatePinch(event.scale);
  }

  void _onPanZoomEnd(PointerPanZoomEndEvent event) {
    if (_pinching && _touches.isEmpty) _endPinch();
  }

  // Seleccionar más allá de lo que se ve ------------------------------------
  //
  // Al arrastrar un palito de selección (o al seleccionar manteniendo
  // presionado) cerca de la orilla de arriba o de abajo del texto, la nota
  // se desplaza sola y suave, aunque el dedo esté quieto, y la selección
  // sigue al dedo. Como en las apps de Android.

  /// El dedo que está seleccionando (uno solo) y dónde está.
  int? _selPointer;
  Offset _selDown = Offset.zero;
  Offset _selFinger = Offset.zero;

  /// La selección la última vez que cambió (para saber qué extremo se mueve).
  TextSelection? _selLast;

  /// Con este dedo ya cambió la selección: se está seleccionando (no
  /// desplazando la nota con el dedo).
  bool _selDragging = false;

  /// Qué extremo de la selección sigue al dedo: `true` = el inicio
  /// ([TextSelection.base]), `false` = el final ([TextSelection.extent]).
  bool? _selMovesBase;
  RenderEditable? _selEditable;

  Ticker? _edgeTickerOrNull;
  Ticker get _edgeTicker => _edgeTickerOrNull ??= createTicker(_onEdgeTick);
  Duration _lastEdgeTick = Duration.zero;

  /// Ve todos los dedos de la app (los palitos viven fuera del editor).
  void _onGlobalPointer(PointerEvent event) {
    if (event is PointerDownEvent) {
      if (_selPointer != null) return; // un segundo dedo (pellizco)
      if (event.kind != PointerDeviceKind.touch &&
          event.kind != PointerDeviceKind.stylus) {
        return;
      }
      _selPointer = event.pointer;
      _selDown = event.position;
      _selFinger = event.position;
      _selLast = _content.selection;
      _selDragging = false;
      _selMovesBase = null;
      return;
    }
    if (event.pointer != _selPointer) return;
    if (event is PointerMoveEvent) {
      _selFinger = event.position;
    } else if (event is PointerUpEvent || event is PointerCancelEvent) {
      _endSelectionDrag();
    }
  }

  /// La selección del texto cambió: si hay un dedo abajo, se está
  /// seleccionando con él.
  void _trackSelectionDrag() {
    if (_selPointer == null || _pinching || !_contentFocus.hasFocus) return;
    final selection = _content.selection;
    final last = _selLast;
    if (!selection.isValid || last == null || selection == last) return;
    if (selection.baseOffset != last.baseOffset &&
        selection.extentOffset == last.extentOffset) {
      _selMovesBase = true;
    } else if (selection.extentOffset != last.extentOffset) {
      _selMovesBase = false;
    }
    _selLast = selection;
    if (_selDragging) return;
    _selDragging = true;
    _selEditable = _contentEditable()?.renderEditable;
    // Mientras tanto, Flutter ya no "brinca" la nota hacia el palito: el
    // desplazamiento lo hace [_onEdgeTick], suave.
    _contentScroll.holdJumps = true;
    _lastEdgeTick = Duration.zero;
    if (!_edgeTicker.isActive) _edgeTicker.start();
  }

  void _endSelectionDrag() {
    _selPointer = null;
    _selDragging = false;
    _selMovesBase = null;
    _selEditable = null;
    _contentScroll.holdJumps = false;
    if (_edgeTickerOrNull?.isActive ?? false) _edgeTickerOrNull!.stop();
  }

  /// Velocidad (píxeles por segundo; negativa = hacia arriba) según qué
  /// tan cerca está el dedo de la orilla [box] del texto. Cerca de la orilla
  /// va despacio (para afinar); pasándose de ella, cada vez más rápido.
  static double edgeScrollSpeed(double y, Rect box, double lineHeight) {
    final zone = math.min(math.max(lineHeight * 1.5, 36.0), box.height / 4);
    if (y < box.top + zone) return -_speedAt(y - box.top, zone);
    if (y > box.bottom - zone) return _speedAt(box.bottom - y, zone);
    return 0;
  }

  static const double _slowSpeed = 40;
  static const double _edgeSpeed = 700;
  static const double _fastSpeed = 2400;

  /// [inside]: cuánto le falta al dedo para llegar a la orilla (negativo =
  /// ya se pasó).
  static double _speedAt(double inside, double zone) {
    if (inside >= 0) {
      // Curva que empieza despacio y acelera hacia la orilla (t²): al
      // entrar a la zona casi no se mueve; en la orilla llega a la misma
      // velocidad de antes.
      final t = 1 - math.min(inside / zone, 1.0);
      return _slowSpeed + t * t * (_edgeSpeed - _slowSpeed);
    }
    return math.min(_edgeSpeed + -inside * 15, _fastSpeed);
  }

  void _onEdgeTick(Duration elapsed) {
    final dt = ((elapsed - _lastEdgeTick).inMicroseconds / 1e6)
        .clamp(0.0, 0.05)
        .toDouble();
    _lastEdgeTick = elapsed;
    final editable = _selEditable;
    if (!_selDragging || _pinching || dt == 0 || !_scrollReady) return;
    if (editable == null || !editable.attached || !editable.hasSize) return;
    // Al tocar (sin mover el dedo) no se desplaza nada, aunque sea cerca
    // de la orilla: por ejemplo, al mantener presionada una palabra.
    if ((_selFinger - _selDown).distance < kTouchSlop) return;
    final box = editable.localToGlobal(Offset.zero) & editable.size;
    final speed =
        edgeScrollSpeed(_selFinger.dy, box, editable.preferredLineHeight);
    if (speed == 0) return;
    final position = _contentScroll.position;
    final target = (position.pixels + speed * dt)
        .clamp(position.minScrollExtent, position.maxScrollExtent)
        .toDouble();
    if (target == position.pixels) return;
    _anchoring = true;
    position.jumpTo(target);
    _anchoring = false;
    _followFinger(editable);
  }

  /// La selección llega hasta donde está el dedo (el extremo que se mueve).
  void _followFinger(RenderEditable editable) {
    final selection = _content.selection;
    final movesBase = _selMovesBase;
    if (!selection.isValid || movesBase == null) return;
    final at = NoteSearch.safeCut(
        _content.text, editable.getPositionForPoint(_selFinger).offset);
    final TextSelection next;
    if (selection.isCollapsed) {
      next = TextSelection.collapsed(offset: at); // el palito del cursor
    } else {
      next = movesBase
          ? TextSelection(baseOffset: at, extentOffset: selection.extentOffset)
          : TextSelection(baseOffset: selection.baseOffset, extentOffset: at);
      // Los palitos no se cruzan.
      if (next.isCollapsed ||
          (next.baseOffset < next.extentOffset) !=
              (selection.baseOffset < selection.extentOffset)) {
        return;
      }
    }
    if (next != selection) _content.selection = next;
  }

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
    // Con el cursor ya puesto (al final): Flutter solo guarda el texto
    // original en el historial de deshacer si el campo tiene una posición
    // de cursor válida; sin ella, lo guardaba hasta tocar el campo y un
    // cambio rápido ya no se podía deshacer hasta el original.
    _title = FindHighlightController(text: _note.title)
      ..selection = TextSelection.collapsed(offset: _note.title.length)
      ..addListener(_onChanged);
    _content = FindHighlightController(text: _note.content)
      ..selection = TextSelection.collapsed(offset: _note.content.length)
      ..addListener(_onChanged);
    _titleFocus.addListener(_onFieldFocusChanged);
    _contentFocus.addListener(_onFieldFocusChanged);
    _titleUndo.addListener(_onUndoChanged);
    _contentUndo.addListener(_onUndoChanged);
    GestureBinding.instance.pointerRouter.addGlobalRoute(_onGlobalPointer);
    _lifecycle = AppLifecycleListener(
      onPause: _saveIfAutosave, // Android: la app pasa a segundo plano
      onHide: _saveIfAutosave, // Windows: se minimiza la ventana
      onExitRequested: _onExitRequested, // se cierra la app
    );
    _contentScroll.addListener(_onContentScroll);
    final find = widget.initialFind;
    _findFromList = find != null;
    if (find == null) {
      WidgetsBinding.instance.addPostFrameCallback((_) => _restorePosition());
    }
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
    _titleUndo.dispose();
    _contentUndo.dispose();
    // Lo último que se midió (al desplazar o al salir).
    final position = _position;
    if (position != null && _note.isSaved) {
      widget.settings.setNotePosition(_positionId, position);
    }
    _jumpHideTimer?.cancel();
    _contentScroll.dispose();
    _jumpVisible.dispose();
    _zoomPillTimer?.cancel();
    _zoomPillVisible.dispose();
    GestureBinding.instance.pointerRouter.removeGlobalRoute(_onGlobalPointer);
    _edgeTickerOrNull?.dispose();
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
    _trackSelectionDrag();
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
    _rememberPosition(); // la app pasa a segundo plano o se cierra
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
    _rememberPosition();
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
      // En PC, ↶ ↷ en la barra (hay espacio). En el celular van en la
      // barrita sobre el teclado.
      if (widget.embedded) ...[
        FocusTraversalOrder(
          order: const NumericFocusOrder(_undoOrder),
          child: IconButton(
            key: const ValueKey('undo-button'),
            tooltip: '${l10n.undo} (Ctrl+Z)',
            icon: const Icon(Icons.undo),
            onPressed: _activeUndo.value.canUndo ? _undo : null,
          ),
        ),
        FocusTraversalOrder(
          order: const NumericFocusOrder(_redoOrder),
          child: IconButton(
            key: const ValueKey('redo-button'),
            tooltip: '${l10n.redo} (Ctrl+Y)',
            icon: const Icon(Icons.redo),
            onPressed: _activeUndo.value.canRedo ? _redo : null,
          ),
        ),
      ],
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

  /// [style] con el zoom del texto aplicado.
  TextStyle? _zoomed(TextStyle? style, double normalSize) =>
      (style ?? const TextStyle())
          .copyWith(fontSize: (style?.fontSize ?? normalSize) * _zoom);

  /// Título y texto de la nota.
  /// [side]: el margen a los lados, **dentro** de los campos: así un toque
  /// en el espacio en blanco a la izquierda de un renglón pone el cursor
  /// antes de su primera letra, y uno a la derecha, después de la última.
  Widget _buildFields(BuildContext context, {required EdgeInsets side}) {
    final fieldPadding =
        EdgeInsets.fromLTRB(side.left, 12, side.right, 12);
    final theme = Theme.of(context);
    final colors = theme.colorScheme;
    final l10n = context.l10n;
    // Mayúscula automática (Ajustes): el teclado empieza las oraciones con
    // mayúscula después de un punto o de un salto de línea.
    final capitalization = widget.settings.autoCapitalize
        ? TextCapitalization.sentences
        : TextCapitalization.none;
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
          undoController: _titleUndo,
          textCapitalization: capitalization,
          autofocus: !_note.isSaved, // nota nueva: empieza en el título
          style: _zoomed(theme.textTheme.headlineSmall, 24),
          decoration: InputDecoration(
            hintText: l10n.titleHint,
            border: InputBorder.none,
            contentPadding: fieldPadding,
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
            // Barra a la derecha (como VS Code / Sublime): dice en qué parte
            // de la nota vas y cuánto falta; se puede arrastrar.
            // El margen de la orilla va en el tema: Scrollbar no lo recibe.
            child: ScrollbarTheme(
              data: ScrollbarTheme.of(context).copyWith(crossAxisMargin: 3),
              child: Scrollbar(
              key: const ValueKey('content-scrollbar'),
              controller: _contentScroll,
              thumbVisibility: true,
              interactive: true,
              thickness: 5,
              radius: const Radius.circular(3),
              child: TextField(
            key: _contentKey,
            controller: _content,
            focusNode: _contentFocus,
            undoController: _contentUndo,
            scrollController: _contentScroll,
            textCapitalization: capitalization,
            maxLines: null,
            expands: true,
            keyboardType: TextInputType.multiline,
            textAlignVertical: TextAlignVertical.top,
            style: _zoomed(theme.textTheme.bodyLarge, 16),
            // Mientras se pellizca, el texto no se desplaza.
            scrollPhysics: _NoteScrollPhysics(
              frozen: () => _pinching,
              anchorPixels: _anchorPixels,
            ),
            decoration: InputDecoration(
              hintText: l10n.contentHint,
              border: InputBorder.none,
              contentPadding: fieldPadding,
            ),
          ),
            ),
            ),
          ),
        ),
      ],
    );
  }

  /// Los campos con el botón redondo ↑/↓ encima, abajo a la derecha. Se ve
  /// mientras se desplaza la nota (y unos segundos después); la flecha
  /// indica a dónde lleva: arriba de la mitad, al final; abajo, al inicio.
  /// Al terminar de desplazar se mide dónde quedó la nota.
  Widget _withJumpButton(BuildContext context, Widget fields,
      {required double right}) {
    final l10n = context.l10n;
    final scheme = Theme.of(context).colorScheme;
    final percent = (AppSettings.snapTextZoom(_zoom) * 100).round();
    return NotificationListener<ScrollEndNotification>(
      onNotification: (_) {
        _measurePosition();
        return false;
      },
      child: Stack(
        children: [
          Positioned.fill(
            // Zoom: dos dedos (pellizco), touchpad y Ctrl + rueda. El
            // Listener ve todos los dedos sin competir con los gestos del
            // texto; el reconocedor de dos dedos solo evita que, al
            // pellizcar, el texto crea que se está seleccionando.
            child: Listener(
              onPointerDown: _onPointerDown,
              onPointerMove: _onPointerMove,
              onPointerUp: _onPointerUp,
              onPointerCancel: _onPointerUp,
              onPointerSignal: _onPointerSignal,
              onPointerPanZoomUpdate: _onPanZoomUpdate,
              onPointerPanZoomEnd: _onPanZoomEnd,
              child: RawGestureDetector(
                gestures: {
                  _TwoFingerClaim:
                      GestureRecognizerFactoryWithHandlers<_TwoFingerClaim>(
                    _TwoFingerClaim.new,
                    (_) {},
                  ),
                },
                child: fields,
              ),
            ),
          ),
          // Píldora con el tamaño ("120%") mientras se hace zoom.
          Positioned(
            top: 8,
            left: 0,
            right: 0,
            child: Center(
              child: ValueListenableBuilder<bool>(
                valueListenable: _zoomPillVisible,
                builder: (context, visible, _) => IgnorePointer(
                  child: AnimatedOpacity(
                    opacity: visible ? 1 : 0,
                    duration: const Duration(milliseconds: 150),
                    child: Material(
                      key: const ValueKey('zoom-indicator'),
                      color: scheme.inverseSurface,
                      shape: const StadiumBorder(),
                      elevation: 2,
                      child: Padding(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 14, vertical: 6),
                        child: Text(
                          l10n.textZoomPercent(percent),
                          style: TextStyle(
                            color: scheme.onInverseSurface,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ),
          PositionedDirectional(
            end: right,
            bottom: 16,
            child: ValueListenableBuilder<bool>(
              valueListenable: _jumpVisible,
              builder: (context, visible, _) => IgnorePointer(
                ignoring: !visible,
                child: AnimatedOpacity(
                  opacity: visible ? 1 : 0,
                  duration: const Duration(milliseconds: 200),
                  child: ListenableBuilder(
                    listenable: _contentScroll,
                    builder: (context, _) {
                      final down = _jumpGoesDown;
                      return Material(
                        key: const ValueKey('scroll-jump-button'),
                        shape: const CircleBorder(),
                        color: scheme.surfaceContainerHighest
                            .withValues(alpha: 0.92),
                        elevation: 2,
                        child: IconButton(
                          tooltip: down ? l10n.scrollToBottom : l10n.scrollToTop,
                          icon: Icon(down
                              ? Icons.arrow_downward
                              : Icons.arrow_upward),
                          onPressed: _jumpToEdge,
                        ),
                      );
                    },
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  /// La barrita sobre el teclado (celular): solo mientras se escribe en el
  /// título o en el texto y el teclado está abierto.
  bool _showKeyboardBar(BuildContext context) =>
      (_titleFocus.hasFocus || _contentFocus.hasFocus) &&
      MediaQuery.viewInsetsOf(context).bottom > 0;

  /// Barrita pegada arriba del teclado con ↶ ↷ (como Google Keep). Se
  /// pueden agregar más botones aquí después.
  Widget _buildKeyboardBar(BuildContext context) {
    final l10n = context.l10n;
    final scheme = Theme.of(context).colorScheme;
    final undo = _activeUndo.value;
    return Material(
      key: const ValueKey('keyboard-bar'),
      color: scheme.surfaceContainer,
      child: SizedBox(
        height: 44,
        child: Row(
          children: [
            const SizedBox(width: 8),
            IconButton(
              key: const ValueKey('undo-button'),
              tooltip: l10n.undo,
              icon: const Icon(Icons.undo),
              onPressed: undo.canUndo ? _undo : null,
            ),
            IconButton(
              key: const ValueKey('redo-button'),
              tooltip: l10n.redo,
              icon: const Icon(Icons.redo),
              onPressed: undo.canRedo ? _redo : null,
            ),
          ],
        ),
      ),
    );
  }

  /// Márgenes del texto en el celular. A los lados, al menos la zona del
  /// gesto de "atrás" de Android: si el texto llega a la orilla, poner el
  /// cursor al inicio de un renglón o estirar una selección hasta ahí se
  /// confunde con ese gesto.
  EdgeInsets _phoneSides(BuildContext context) {
    final gestures = MediaQuery.systemGestureInsetsOf(context);
    return EdgeInsets.only(
      left: math.max(16.0, gestures.left + 4),
      right: math.max(16.0, gestures.right + 4),
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
                      padding: const EdgeInsets.only(top: 4, bottom: 16),
                      child: _withJumpButton(
                        context,
                        _buildFields(context,
                            side: const EdgeInsets.symmetric(horizontal: 32)),
                        right: 16,
                      ),
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
                  padding: const EdgeInsets.only(bottom: 16),
                  child: _withJumpButton(
                    context,
                    _buildFields(context, side: _phoneSides(context)),
                    right: 16,
                  ),
                ),
              ),
              if (_showKeyboardBar(context)) _buildKeyboardBar(context),
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
          // Ctrl+Y: rehacer (Ctrl+Z ya lo atiende el campo de texto).
          const SingleActivator(LogicalKeyboardKey.keyY, control: true): _redo,
          // Ctrl+F dentro de la nota: buscar en esta nota.
          const SingleActivator(LogicalKeyboardKey.keyF, control: true):
              _openFind,
          // Zoom del texto: Ctrl + / Ctrl − / Ctrl + 0 (como el navegador).
          // "+" puede ser su propia tecla (teclado en español), Shift + "="
          // (teclado en inglés) o el del teclado numérico.
          const SingleActivator(LogicalKeyboardKey.add, control: true): () =>
              _zoomBy(AppSettings.textZoomStep),
          const SingleActivator(LogicalKeyboardKey.add,
              control: true, shift: true): () =>
              _zoomBy(AppSettings.textZoomStep),
          const SingleActivator(LogicalKeyboardKey.equal, control: true): () =>
              _zoomBy(AppSettings.textZoomStep),
          const SingleActivator(LogicalKeyboardKey.equal,
              control: true, shift: true): () =>
              _zoomBy(AppSettings.textZoomStep),
          const SingleActivator(LogicalKeyboardKey.numpadAdd, control: true):
              () => _zoomBy(AppSettings.textZoomStep),
          const SingleActivator(LogicalKeyboardKey.minus, control: true): () =>
              _zoomBy(-AppSettings.textZoomStep),
          const SingleActivator(LogicalKeyboardKey.numpadSubtract,
              control: true): () => _zoomBy(-AppSettings.textZoomStep),
          const SingleActivator(LogicalKeyboardKey.digit0, control: true):
              _resetZoom,
          const SingleActivator(LogicalKeyboardKey.numpad0, control: true):
              _resetZoom,
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

/// Desplazamiento del texto de la nota: igual que siempre, salvo que
/// - mientras se pellizca ([frozen]), los dedos no lo desplazan;
/// - con Ctrl presionado, la rueda del mouse no desplaza (hace zoom);
/// - al cambiar el tamaño del texto (zoom), se queda arriba el mismo
///   renglón ([anchorPixels]), en el mismo cuadro, sin parpadeo.
class _NoteScrollPhysics extends ScrollPhysics {
  const _NoteScrollPhysics({
    super.parent,
    required this.frozen,
    required this.anchorPixels,
  });

  final bool Function() frozen;
  final double? Function(double pixels) anchorPixels;

  @override
  _NoteScrollPhysics applyTo(ScrollPhysics? ancestor) => _NoteScrollPhysics(
        parent: buildParent(ancestor),
        frozen: frozen,
        anchorPixels: anchorPixels,
      );

  @override
  double adjustPositionForNewDimensions({
    required ScrollMetrics oldPosition,
    required ScrollMetrics newPosition,
    required bool isScrolling,
    required double velocity,
  }) {
    final target = anchorPixels(newPosition.pixels);
    if (target != null) {
      return target
          .clamp(newPosition.minScrollExtent, newPosition.maxScrollExtent)
          .toDouble();
    }
    return super.adjustPositionForNewDimensions(
      oldPosition: oldPosition,
      newPosition: newPosition,
      isScrolling: isScrolling,
      velocity: velocity,
    );
  }

  @override
  bool shouldAcceptUserOffset(ScrollMetrics position) {
    // Solo para la rueda (llega fuera de los cuadros). Durante un cuadro
    // Flutter pregunta esto para decidir si se puede arrastrar el texto
    // (touchpad, pantalla táctil): ahí Ctrl no cuenta, si no el texto se
    // quedaba sin poder arrastrarse después de Ctrl + rueda.
    final inFrame = SchedulerBinding.instance.schedulerPhase ==
        SchedulerPhase.persistentCallbacks;
    if (!inFrame && HardwareKeyboard.instance.isControlPressed) return false;
    return super.shouldAcceptUserOffset(position);
  }

  @override
  double applyPhysicsToUserOffset(ScrollMetrics position, double offset) =>
      frozen() ? 0 : super.applyPhysicsToUserOffset(position, offset);

  @override
  Simulation? createBallisticSimulation(
          ScrollMetrics position, double velocity) =>
      frozen() ? null : super.createBallisticSimulation(position, velocity);
}

/// Se queda con los dedos en cuanto hay dos sobre la nota (un pellizco),
/// para que el texto no lo tome como seleccionar o mover el cursor. Con un
/// solo dedo nunca gana: tocar, desplazar y seleccionar funcionan igual.
class _TwoFingerClaim extends OneSequenceGestureRecognizer {
  _TwoFingerClaim()
      : super(supportedDevices: const {PointerDeviceKind.touch});

  final Set<int> _pointers = {};

  @override
  void addAllowedPointer(PointerDownEvent event) {
    super.addAllowedPointer(event);
    _pointers.add(event.pointer);
    if (_pointers.length >= 2) resolve(GestureDisposition.accepted);
  }

  @override
  void handleEvent(PointerEvent event) {
    if (event is PointerUpEvent || event is PointerCancelEvent) {
      _pointers.remove(event.pointer);
      stopTrackingPointer(event.pointer);
    }
  }

  @override
  void rejectGesture(int pointer) {
    _pointers.remove(pointer);
    stopTrackingPointer(pointer);
  }

  @override
  void didStopTrackingLastPointer(int pointer) {
    _pointers.clear();
    resolve(GestureDisposition.rejected);
  }

  @override
  String get debugDescription => 'pellizco';
}

/// El desplazamiento del texto de la nota. Mientras se selecciona con el
/// dedo ([holdJumps]), no deja que Flutter lo mueva de golpe hacia el palito:
/// de eso se encarga el desplazamiento suave en las orillas.
class _NoteScrollController extends ScrollController {
  bool holdJumps = false;

  @override
  void jumpTo(double value) {
    if (holdJumps) return;
    super.jumpTo(value);
  }
}
