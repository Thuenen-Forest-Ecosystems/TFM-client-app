/// Reads the `options.filterBy` contract of the layout style-map.
///
/// Several components share one record array – `plot_support_points` holds the
/// GNSS helping point, the versetzte Markierung and the markante Geländepunkte
/// side by side – and each component owns the rows of exactly one
/// `point_type`. The style declares that ownership:
///
/// ```json
/// "options": { "filterBy": { "point_type": 5 } }
/// ```
///
/// Keeping the mapping in the style (instead of a constant per widget) means
/// the split of a shared array is defined in one place. Every reader falls
/// back to its own default when the style does not declare one, so a style
/// that predates this option keeps working.
class LayoutFilter {
  LayoutFilter._();

  /// The `filterBy` map declared by a layout item, or `{}` when absent.
  static Map<String, dynamic> of(Map<String, dynamic>? layoutOptions) {
    final raw = layoutOptions?['filterBy'];
    return raw is Map ? Map<String, dynamic>.from(raw) : const {};
  }

  /// The single `point_type` a component owns, or null when the style does not
  /// declare one.
  static int? pointType(Map<String, dynamic>? layoutOptions) {
    final value = of(layoutOptions)['point_type'];
    if (value is int) return value;
    if (value is num) return value.toInt();
    if (value is String) return int.tryParse(value);
    return null;
  }

  /// The filter a list component applies to the array it is bound to.
  ///
  /// Primary source is the style. When the style declares no `filterBy` – it
  /// predates the option – fall back to the hidden constant fields the list
  /// stamps on every row it creates itself: `columnItems` entries that are
  /// `"display": false` and carry a `"default"`. A row that does not carry
  /// them was written by another component, and is not this list's to render,
  /// to count against `maxRows`, or to delete.
  static Map<String, dynamic> forList({
    Map<String, dynamic>? layoutOptions,
    List<dynamic>? columnItems,
  }) {
    final declared = of(layoutOptions);
    if (declared.isNotEmpty) return declared;
    return _hiddenConstantFields(columnItems);
  }

  static Map<String, dynamic> _hiddenConstantFields(List<dynamic>? columnItems) {
    final implicit = <String, dynamic>{};
    if (columnItems == null) return implicit;

    void visit(Map<String, dynamic> item) {
      final name = item['name'] as String?;
      final defaultValue = item['default'];
      if (name != null && item['display'] == false && defaultValue != null) {
        implicit[name] = defaultValue;
      }
      final children = item['items'] as List?;
      if (children != null) {
        for (final child in children) {
          if (child is Map<String, dynamic>) visit(child);
        }
      }
    }

    for (final item in columnItems) {
      if (item is Map<String, dynamic>) visit(item);
    }
    return implicit;
  }
}
