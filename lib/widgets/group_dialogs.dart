import 'package:flutter/material.dart';

import '../l10n/l10n.dart';
import '../models/note_group.dart';
import '../services/note_storage.dart';
import 'blocked_chars_formatter.dart';
import 'group_colors.dart';

/// Diálogo para escribir el nombre de un grupo (crear o renombrar).
///
/// - Avisa al momento si el nombre tiene algo no permitido (ej. "/").
/// - [onSubmit] hace el trabajo (crear o renombrar). Si falla (ej. ya existe
///   un grupo con ese nombre), el error se muestra en el mismo diálogo y
///   se puede corregir sin volver a empezar.
/// - [showColor]: muestra también el selector de color (al crear).
/// Devuelve `true` si se completó; `false` si se canceló.
Future<bool> showGroupNameDialog(
  BuildContext context, {
  required String title,
  required String confirmLabel,
  String initialName = '',
  bool showColor = false,
  required Future<void> Function(String name, GroupColor? color) onSubmit,
}) async {
  final result = await showDialog<bool>(
    context: context,
    builder: (context) => _GroupNameDialog(
      title: title,
      confirmLabel: confirmLabel,
      initialName: initialName,
      showColor: showColor,
      onSubmit: onSubmit,
    ),
  );
  return result ?? false;
}

class _GroupNameDialog extends StatefulWidget {
  const _GroupNameDialog({
    required this.title,
    required this.confirmLabel,
    required this.initialName,
    required this.showColor,
    required this.onSubmit,
  });

  final String title;
  final String confirmLabel;
  final String initialName;
  final bool showColor;
  final Future<void> Function(String name, GroupColor? color) onSubmit;

  @override
  State<_GroupNameDialog> createState() => _GroupNameDialogState();
}

class _GroupNameDialogState extends State<_GroupNameDialog> {
  late final TextEditingController _name =
      TextEditingController(text: widget.initialName)
        ..selection = TextSelection(
            baseOffset: 0, extentOffset: widget.initialName.length);
  GroupColor? _color;
  String? _error;
  bool _busy = false;

  /// Aviso al teclear un carácter prohibido (que no se escribe), igual que
  /// en el título de una nota.
  late final TemporaryHint _forbiddenHint = TemporaryHint(() {
    if (mounted) setState(() {});
  });
  late final BlockedCharsFormatter _formatter = BlockedCharsFormatter(
    NoteStorage.forbiddenTitleChars,
    onBlocked: _forbiddenHint.show,
  );

  @override
  void dispose() {
    _forbiddenHint.dispose();
    _name.dispose();
    super.dispose();
  }

  /// Revisa el nombre mientras se escribe (ej. "CON" o un punto al inicio).
  /// "Vacío" no se marca hasta que se intenta confirmar (no tiene caso
  /// regañar antes de escribir).
  void _onChanged(String value) {
    final problem = NoteStorage.validateGroupName(value);
    setState(() {
      _error = problem == null || problem == NoteError.groupNameEmpty
          ? null
          : context.l10n.noteError(problem);
    });
  }

  Future<void> _submit() async {
    if (_busy) return;
    final l10n = context.l10n;
    final problem = NoteStorage.validateGroupName(_name.text);
    if (problem != null) {
      setState(() => _error = l10n.noteError(problem));
      return;
    }
    setState(() => _busy = true);
    try {
      await widget.onSubmit(_name.text.trim(), _color);
      if (mounted) Navigator.of(context).pop(true);
    } catch (e) {
      if (mounted) {
        setState(() {
          _busy = false;
          _error = l10n.errorText(e);
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    return AlertDialog(
      title: Text(widget.title),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            TextField(
              controller: _name,
              autofocus: true,
              maxLength: NoteStorage.maxTitleLength,
              decoration: InputDecoration(
                hintText: l10n.groupNameHint,
                errorText: _forbiddenHint.visible
                    ? l10n.errorGroupNameForbiddenChars
                    : _error,
                errorMaxLines: 3,
                counterText: '',
              ),
              inputFormatters: [_formatter],
              onChanged: _onChanged,
              onSubmitted: (_) => _submit(),
            ),
            if (widget.showColor) ...[
              const SizedBox(height: 16),
              Text(l10n.groupColor,
                  style: Theme.of(context).textTheme.labelLarge),
              const SizedBox(height: 8),
              GroupColorPicker(
                selected: _color,
                noColorLabel: l10n.colorNone,
                onChanged: (color) => setState(() => _color = color),
              ),
            ],
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: _busy ? null : () => Navigator.of(context).pop(false),
          child: Text(l10n.cancel),
        ),
        FilledButton(
          onPressed: _busy ? null : _submit,
          child: Text(widget.confirmLabel),
        ),
      ],
    );
  }
}

/// Lo que se eligió en el diálogo de color.
class ColorChoice {
  const ColorChoice(this.color);

  /// `null` = sin color.
  final GroupColor? color;
}

/// Diálogo para elegir el color de un grupo. Se cierra al tocar un
/// color. Devuelve `null` si se cerró sin elegir.
Future<ColorChoice?> showGroupColorDialog(
  BuildContext context, {
  required String groupName,
  required GroupColor? current,
}) {
  return showDialog<ColorChoice>(
    context: context,
    builder: (context) {
      final l10n = context.l10n;
      return AlertDialog(
        title: Text('${l10n.groupColor}: $groupName'),
        content: GroupColorPicker(
          selected: current,
          noColorLabel: l10n.colorNone,
          onChanged: (color) => Navigator.of(context).pop(ColorChoice(color)),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: Text(l10n.cancel),
          ),
        ],
      );
    },
  );
}

/// Qué hacer con las notas al borrar un grupo.
enum DeleteGroupChoice {
  /// Pasarlas a "Sin grupo".
  moveNotes,

  /// Borrarlas también.
  deleteNotes,
}

/// Pregunta antes de borrar un grupo. Si tiene notas, pregunta qué
/// hacer con ellas. Devuelve `null` si se canceló.
Future<DeleteGroupChoice?> showDeleteGroupDialog(
  BuildContext context, {
  required String groupName,
  required int noteCount,
}) {
  return showDialog<DeleteGroupChoice>(
    context: context,
    builder: (context) {
      final l10n = context.l10n;
      final colors = Theme.of(context).colorScheme;
      final hasNotes = noteCount > 0;
      return AlertDialog(
        title: Text(l10n.deleteGroupQuestion(groupName)),
        content: Text(hasNotes
            ? l10n.deleteGroupWithNotes(noteCount)
            : l10n.deleteEmptyGroupMessage),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: Text(l10n.cancel),
          ),
          if (hasNotes) ...[
            TextButton(
              style: TextButton.styleFrom(foregroundColor: colors.error),
              onPressed: () => Navigator.of(context)
                  .pop(DeleteGroupChoice.deleteNotes),
              child: Text(l10n.deleteNotesToo),
            ),
            FilledButton(
              onPressed: () =>
                  Navigator.of(context).pop(DeleteGroupChoice.moveNotes),
              child: Text(l10n.moveNotesToNone),
            ),
          ] else
            // Vacía: "mover" es lo más seguro por si alguien acaba de
            // meter una nota desde fuera de la app.
            FilledButton(
              style: FilledButton.styleFrom(
                backgroundColor: colors.error,
                foregroundColor: colors.onError,
              ),
              onPressed: () =>
                  Navigator.of(context).pop(DeleteGroupChoice.moveNotes),
              child: Text(l10n.delete),
            ),
        ],
      );
    },
  );
}
