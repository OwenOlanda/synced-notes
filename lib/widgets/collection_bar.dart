import 'package:flutter/material.dart';

import '../l10n/l10n.dart';
import '../models/collection.dart';
import '../models/collection_filter.dart';
import 'collection_colors.dart';

/// Fila de chips arriba de la lista de notas:
///   [Todas] [Sin colección] [● Recetas] [● Cartas] [+ Nueva colección]
/// Se desliza de lado si no caben. "Sin colección" solo aparece cuando ya
/// hay colecciones (antes sería lo mismo que "Todas").
/// Clic derecho o mantener presionado sobre una colección → [onCollectionMenu].
class CollectionBar extends StatelessWidget {
  const CollectionBar({
    super.key,
    required this.collections,
    required this.selected,
    required this.onSelected,
    required this.onCreate,
    required this.onCollectionMenu,
  });

  final List<Collection> collections;
  final CollectionFilter selected;
  final ValueChanged<CollectionFilter> onSelected;
  final VoidCallback onCreate;
  final void Function(Collection collection, Offset position) onCollectionMenu;

  /// Alto de la barra (para ponerla debajo del AppBar).
  static const double height = 56;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final theme = Theme.of(context);

    Widget chip({
      required String label,
      required CollectionFilter filter,
      Widget? avatar,
      Color? tint,
    }) {
      final isSelected = filter == selected;
      return ChoiceChip(
        label: Text(label),
        avatar: avatar,
        selected: isSelected,
        // Al estar seleccionada, una colección con color tiñe su chip.
        selectedColor: tint?.withValues(alpha: 0.3),
        showCheckmark: false,
        onSelected: (_) => onSelected(filter),
      );
    }

    final chips = <Widget>[
      chip(label: l10n.collectionsAll, filter: CollectionFilter.all),
      if (collections.isNotEmpty)
        chip(label: l10n.collectionsNone, filter: CollectionFilter.none),
      for (final collection in collections)
        GestureDetector(
          onSecondaryTapUp: (details) =>
              onCollectionMenu(collection, details.globalPosition),
          onLongPressStart: (details) =>
              onCollectionMenu(collection, details.globalPosition),
          child: chip(
            label: collection.name,
            filter: CollectionFilter.collection(collection.name),
            avatar: CollectionDot(collection.color),
            tint: collection.color == null
                ? null
                : displayColor(collection.color!, theme.brightness),
          ),
        ),
      ActionChip(
        avatar: const Icon(Icons.add),
        label: Text(l10n.newCollection),
        tooltip: l10n.newCollection,
        onPressed: onCreate,
      ),
    ];

    return SizedBox(
      height: height,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        itemCount: chips.length,
        separatorBuilder: (context, index) => const SizedBox(width: 8),
        itemBuilder: (context, index) => chips[index],
      ),
    );
  }
}
