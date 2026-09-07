import 'package:flutter/material.dart';
import 'package:terrestrial_forest_monitor/widgets/form-elements/array-filter-dialog.dart';

/// Read-only count of the rows of one record array, declared by the style-map.
///
/// The style names the array, which of its rows count and the caption; this
/// widget only counts and renders. It writes nothing and flags nothing — the
/// number is an orientation aid while recording (TFM-client-app#348), not a
/// plausibility rule, so it is never coloured as an error.
///
/// Activated via `"component": "array_summary"`:
///
/// ```json
/// {
///   "id": "wzp4_tree_count",
///   "type": "object",
///   "component": "array_summary",
///   "property": "tree",
///   "label": "Probebäume in der WZP4",
///   "icon": "forest",
///   "options": {
///     "description": "Bäume mit PK 0 oder 1",
///     "filter": [{ "field": "tree_status", "operator": "in", "values": [0, 1] }]
///   }
/// }
/// ```
///
/// `options.filter` uses the same `field`/`operator`/`values` rules the array
/// grids already parse ([ArrayFilterRule]). Every declared rule has to match,
/// so a row whose field is absent is not counted. Without a filter the widget
/// counts every row of the array.
class ArraySummary extends StatelessWidget {
  /// The array the style points at, as it currently stands in the form data.
  final List<dynamic>? rows;

  /// Caption from the style; falls back to the layout item id.
  final String label;

  /// Layout options of the style item, read for `filter`, `description` and
  /// `margin`.
  final Map<String, dynamic>? layoutOptions;

  /// Icon resolved from the style item's `icon` name by the caller.
  final IconData? icon;

  const ArraySummary({
    super.key,
    required this.rows,
    required this.label,
    this.layoutOptions,
    this.icon,
  });

  List<ArrayFilterRule> _rules() {
    final raw = layoutOptions?['filter'];
    if (raw is! List) return const [];
    return raw
        .whereType<Map<String, dynamic>>()
        .map((config) => ArrayFilterRule.fromJson(config))
        .toList();
  }

  int _count() {
    final list = rows;
    if (list == null) return 0;
    final rules = _rules();
    return list
        .whereType<Map<String, dynamic>>()
        .where((row) => rules.every((rule) => rule.matches(row[rule.field])))
        .length;
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final description = layoutOptions?['description'] as String?;
    final margin = (layoutOptions?['margin'] as num?)?.toDouble() ?? 10.0;

    return Card(
      margin: EdgeInsets.all(margin),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 12.0),
        child: Row(
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(label, style: theme.textTheme.bodyMedium),
                  if (description != null)
                    Text(
                      description,
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: theme.colorScheme.onSurfaceVariant,
                      ),
                    ),
                ],
              ),
            ),
            const SizedBox(width: 12),
            Text(
              '${_count()}',
              style: theme.textTheme.headlineSmall?.copyWith(
                fontWeight: FontWeight.bold,
                color: theme.colorScheme.primary,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
