import 'package:flutter/material.dart';

/// Pregunta antes de borrar una nota. Devuelve `true` solo si el usuario
/// confirma. La usan la lista y el editor.
Future<bool> confirmDeleteNote(BuildContext context, String displayTitle) async {
  final colors = Theme.of(context).colorScheme;
  final result = await showDialog<bool>(
    context: context,
    builder: (context) => AlertDialog(
      title: const Text('¿Borrar nota?'),
      content: Text(
          '"$displayTitle" se borrará de la carpeta de notas. Esto no se puede deshacer.'),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context, false),
          child: const Text('Cancelar'),
        ),
        FilledButton(
          style: FilledButton.styleFrom(
            backgroundColor: colors.error,
            foregroundColor: colors.onError,
          ),
          onPressed: () => Navigator.pop(context, true),
          child: const Text('Borrar'),
        ),
      ],
    ),
  );
  return result ?? false;
}
