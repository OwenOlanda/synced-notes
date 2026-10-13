import 'package:flutter/material.dart';

import '../l10n/l10n.dart';
import '../models/collection.dart';
import '../services/note_storage.dart';
import 'collection_colors.dart';
import 'collection_dialogs.dart';

/// Pregunta a qué colección mover una nota:
///   Sin colección / Recetas / Cartas / Nueva colección…
/// La colección actual sale marcada y no se puede elegir.
/// "Nueva colección…" abre el diálogo de crear colección (nombre y color)
/// y, si se crea, esa es la elegida.
///
/// Devuelve la colección elegida (`collection: null` = sin colección),
/// o `null` si se canceló. Solo elige; mover lo hace quien llama.
Future<({String? collection})?> pickCollectionForMove(
  BuildContext context, {
  required NoteStorage storage,
  required String? current,
}) async {
  final l10n = context.l10n;
  final List<Collection> collections;
  try {
    collections = await storage.listCollections();
  } catch (e) {
    if (context.mounted) {
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text(l10n.errorText(e))));
    }
    return null;
  }
  if (!context.mounted) return null;

  const newCollection = '\u0000nueva'; // valor especial, no es un nombre válido
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
            label: l10n.collectionsNone,
            leading: const Icon(Icons.inbox_outlined),
            isCurrent: current == null,
          ),
          for (final collection in collections)
            option(
              value: collection.name,
              label: collection.name,
              leading: SizedBox(
                width: 24,
                child: Center(child: CollectionDot(collection.color, size: 14)),
              ),
              isCurrent: current == collection.name,
            ),
          const Divider(),
          option(
            value: newCollection,
            label: l10n.newCollectionEllipsis,
            leading: const Icon(Icons.add),
            isCurrent: false,
          ),
        ],
      );
    },
  );

  if (choice == null || !context.mounted) return null;
  if (choice == none) return (collection: null);
  if (choice != newCollection) return (collection: choice);

  String? created;
  final done = await showCollectionNameDialog(
    context,
    title: l10n.newCollection,
    confirmLabel: l10n.create,
    showColor: true,
    onSubmit: (name, color) async {
      created = (await storage.createCollection(name, color: color)).name;
    },
  );
  return done ? (collection: created) : null;
}
