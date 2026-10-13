import 'package:flutter/material.dart';

import '../l10n/l10n.dart';
import '../models/note_group.dart';
import '../services/note_storage.dart';
import 'app_message.dart';
import 'group_colors.dart';
import 'group_dialogs.dart';

/// Pregunta a qué grupo mover una nota:
///   Sin grupo / Recetas / Cartas / Nuevo grupo…
/// El grupo actual sale marcada y no se puede elegir.
/// "Nuevo grupo…" abre el diálogo de crear grupo (nombre y color)
/// y, si se crea, esa es la elegida.
///
/// Devuelve el grupo elegido (`group: null` = sin grupo),
/// o `null` si se canceló. Solo elige; mover lo hace quien llama.
Future<({String? group})?> pickGroupForMove(
  BuildContext context, {
  required NoteStorage storage,
  required String? current,
}) async {
  final l10n = context.l10n;
  final List<NoteGroup> groups;
  try {
    groups = await storage.listGroups();
  } catch (e) {
    if (context.mounted) {
      ScaffoldMessenger.of(context)
          .showMessage(l10n.errorText(e), isError: true);
    }
    return null;
  }
  if (!context.mounted) return null;

  const newGroup = '\u0000nueva'; // valor especial, no es un nombre válido
  const none = '\u0000ninguna';

  final choice = await showDialog<String>(
    context: context,
    builder: (context) {
      Widget option({
        required String value,
        required String label,
        required Widget leading,
        required bool isCurrent,
      }) =>
          ListTile(
            leading: leading,
            title: Text(label, maxLines: 1, overflow: TextOverflow.ellipsis),
            trailing: isCurrent ? const Icon(Icons.check) : null,
            enabled: !isCurrent,
            onTap: () => Navigator.of(context).pop(value),
          );

      return SimpleDialog(
        title: Text(l10n.moveNoteTitle),
        children: [
          option(
            value: none,
            label: l10n.groupsNone,
            leading: const Icon(Icons.inbox_outlined),
            isCurrent: current == null,
          ),
          for (final group in groups)
            option(
              value: group.name,
              label: group.name,
              leading: SizedBox(
                width: 24,
                child: Center(child: GroupDot(group.color, size: 14)),
              ),
              isCurrent: current == group.name,
            ),
          const Divider(),
          option(
            value: newGroup,
            label: l10n.newGroupEllipsis,
            leading: const Icon(Icons.add),
            isCurrent: false,
          ),
        ],
      );
    },
  );

  if (choice == null || !context.mounted) return null;
  if (choice == none) return (group: null);
  if (choice != newGroup) return (group: choice);

  String? created;
  final done = await showGroupNameDialog(
    context,
    title: l10n.newGroup,
    confirmLabel: l10n.create,
    showColor: true,
    onSubmit: (name, color) async {
      created = (await storage.createGroup(name, color: color)).name;
    },
  );
  return done ? (group: created) : null;
}
