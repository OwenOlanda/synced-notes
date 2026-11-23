import 'package:flutter/material.dart';

import '../l10n/l10n.dart';
import '../utils/note_search.dart';

/// Los tres botoncitos de opciones de búsqueda, como en VS Code / Sublime
/// Text: **Aa** (distinguir mayúsculas), **á** (distinguir acentos) y
/// **ab** (solo palabras completas). Van dentro del buscador de la lista y
/// de la barra "Buscar en esta nota".
class SearchOptionsToggles extends StatelessWidget {
  const SearchOptionsToggles({
    super.key,
    required this.options,
    required this.onChanged,
  });

  final SearchOptions options;
  final ValueChanged<SearchOptions> onChanged;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        _OptionToggle(
          id: 'case',
          label: 'Aa',
          tooltip: l10n.searchMatchCase,
          selected: options.matchCase,
          onChanged: (on) => onChanged(SearchOptions(
            matchCase: on,
            matchAccents: options.matchAccents,
            wholeWord: options.wholeWord,
          )),
        ),
        _OptionToggle(
          id: 'accents',
          label: 'á',
          tooltip: l10n.searchMatchAccents,
          selected: options.matchAccents,
          onChanged: (on) => onChanged(SearchOptions(
            matchCase: options.matchCase,
            matchAccents: on,
            wholeWord: options.wholeWord,
          )),
        ),
        _OptionToggle(
          id: 'word',
          label: 'ab',
          tooltip: l10n.searchWholeWord,
          selected: options.wholeWord,
          underline: true,
          onChanged: (on) => onChanged(SearchOptions(
            matchCase: options.matchCase,
            matchAccents: options.matchAccents,
            wholeWord: on,
          )),
        ),
      ],
    );
  }
}

/// Un botoncito que se prende y se apaga. Prendido: fondo tenue y contorno.
class _OptionToggle extends StatelessWidget {
  const _OptionToggle({
    required this.id,
    required this.label,
    required this.tooltip,
    required this.selected,
    required this.onChanged,
    this.underline = false,
  });

  final String id;
  final String label;
  final String tooltip;
  final bool selected;
  final ValueChanged<bool> onChanged;

  /// "ab" va subrayado (como en VS Code): palabra completa.
  final bool underline;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final shape = RoundedRectangleBorder(
      borderRadius: BorderRadius.circular(6),
      side: selected
          ? BorderSide(color: scheme.onSurface.withValues(alpha: 0.6))
          : BorderSide.none,
    );
    return Tooltip(
      message: tooltip,
      child: Semantics(
        button: true,
        toggled: selected,
        label: tooltip,
        excludeSemantics: true,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 1),
          child: Material(
            key: ValueKey('search-option-$id'),
            shape: shape,
            color: selected
                ? scheme.onSurface.withValues(alpha: 0.14)
                : Colors.transparent,
            child: InkWell(
              customBorder: shape,
              onTap: () => onChanged(!selected),
              child: SizedBox(
                width: 30,
                height: 30,
                child: Center(
                  child: Text(
                    label,
                    style: TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                      color: selected
                          ? scheme.onSurface
                          : scheme.onSurfaceVariant,
                      decoration: underline ? TextDecoration.underline : null,
                      decorationColor: selected
                          ? scheme.onSurface
                          : scheme.onSurfaceVariant,
                    ),
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
