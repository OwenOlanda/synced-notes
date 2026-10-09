import 'package:flutter/material.dart';

import '../l10n/l10n.dart';

/// Pregunta antes de borrar una nota. Devuelve `true` solo si el usuario
/// confirma. La usan la lista y el editor.
Future<bool> confirmDeleteNote(BuildContext context, String displayTitle) async {
  final colors = Theme.of(context).colorScheme;
  final l10n = context.l10n;
  final result = await showDialog<bool>(
    context: context,
    builder: (context) => AlertDialog(
      title: Text(l10n.deleteNoteQuestion),
      content: Text(l10n.deleteNoteWarning(displayTitle)),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context, false),
          child: Text(l10n.cancel),
        ),
        FilledButton(
          style: FilledButton.styleFrom(
            backgroundColor: colors.error,
            foregroundColor: colors.onError,
          ),
          onPressed: () => Navigator.pop(context, true),
          child: Text(l10n.delete),
        ),
      ],
    ),
  );
  return result ?? false;
}
