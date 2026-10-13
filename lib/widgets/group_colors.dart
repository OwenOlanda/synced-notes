import 'package:flutter/material.dart';

import '../models/note_group.dart';

/// Color en pantalla de un [GroupColor]: un tono más oscuro en el tema
/// claro y uno más claro en el oscuro, para que se lea bien en ambos.
Color displayColor(GroupColor color, Brightness brightness) {
  final MaterialColor base = switch (color) {
    GroupColor.red => Colors.red,
    GroupColor.orange => Colors.orange,
    GroupColor.amber => Colors.amber,
    GroupColor.green => Colors.green,
    GroupColor.teal => Colors.teal,
    GroupColor.blue => Colors.blue,
    GroupColor.indigo => Colors.indigo,
    GroupColor.purple => Colors.purple,
    GroupColor.pink => Colors.pink,
    GroupColor.brown => Colors.brown,
    GroupColor.grey => Colors.blueGrey,
  };
  return brightness == Brightness.dark ? base.shade300 : base.shade600;
}

/// Puntito de color de un grupo. Sin color: un círculo vacío.
class GroupDot extends StatelessWidget {
  const GroupDot(this.color, {super.key, this.size = 12});

  final GroupColor? color;
  final double size;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final c = color;
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: c == null ? null : displayColor(c, theme.brightness),
        border: c == null
            ? Border.all(color: theme.colorScheme.outline, width: 1.5)
            : null,
      ),
    );
  }
}

/// Fila de círculos para elegir un color (o "sin color").
class GroupColorPicker extends StatelessWidget {
  const GroupColorPicker({
    super.key,
    required this.selected,
    required this.onChanged,
    required this.noColorLabel,
  });

  final GroupColor? selected;
  final ValueChanged<GroupColor?> onChanged;

  /// Texto (tooltip) de la opción "sin color".
  final String noColorLabel;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    Widget option(GroupColor? color, {String? tooltip}) {
      final isSelected = color == selected;
      final fill = color == null ? null : displayColor(color, theme.brightness);
      final circle = InkWell(
        customBorder: const CircleBorder(),
        onTap: () => onChanged(color),
        child: Container(
          width: 36,
          height: 36,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: fill,
            border: Border.all(
              color: isSelected
                  ? theme.colorScheme.onSurface
                  : (color == null
                      ? theme.colorScheme.outline
                      : Colors.transparent),
              width: isSelected ? 3 : 1.5,
            ),
          ),
          child: isSelected
              ? Icon(Icons.check,
                  size: 20,
                  color: fill == null
                      ? theme.colorScheme.onSurface
                      : (ThemeData.estimateBrightnessForColor(fill) ==
                              Brightness.dark
                          ? Colors.white
                          : Colors.black))
              : (color == null
                  ? Icon(Icons.block,
                      size: 18, color: theme.colorScheme.outline)
                  : null),
        ),
      );
      return tooltip == null ? circle : Tooltip(message: tooltip, child: circle);
    }

    return Wrap(
      spacing: 8,
      runSpacing: 8,
      children: [
        option(null, tooltip: noColorLabel),
        for (final color in GroupColor.values) option(color),
      ],
    );
  }
}

/// Etiqueta pequeña con el nombre de un grupo, en su color.
/// Se muestra en cada nota cuando se están viendo "Todas".
class GroupTag extends StatelessWidget {
  const GroupTag({super.key, required this.name, this.color});

  final String name;
  final GroupColor? color;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final c = color;
    final accent = c == null
        ? theme.colorScheme.onSurfaceVariant
        : displayColor(c, theme.brightness);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
      decoration: BoxDecoration(
        color: accent.withValues(alpha: 0.15),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: accent.withValues(alpha: 0.5)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          GroupDot(c, size: 8),
          const SizedBox(width: 4),
          Flexible(
            child: Text(
              name,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: theme.textTheme.labelSmall,
            ),
          ),
        ],
      ),
    );
  }
}
