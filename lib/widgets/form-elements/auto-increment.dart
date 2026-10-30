/// Computes the next value of an auto-increment field (tree_number,
/// edge_number, …).
///
/// Numbers already used in the previous inventory must never be handed out
/// again: a new tree that reuses a previous tree's number is paired with that
/// tree by the plausibility checks and the delete guard (#437). This happens
/// whenever `properties` lacks rows that `previous_properties` has, e.g. a
/// corner without trees in 2022 whose previous data comes from 2012.
class AutoIncrement {
  AutoIncrement._();

  static int? _parseInt(dynamic value) {
    if (value is int) return value;
    if (value is num) return value.toInt();
    if (value is String) return int.tryParse(value.trim());
    return null;
  }

  /// Highest value of [key] across [currentValues] and the rows of
  /// [previousData], plus one. Returns [defaultValue] when neither holds a
  /// number.
  static int next(
    String key, {
    Iterable<dynamic> currentValues = const [],
    List<dynamic>? previousData,
    bool Function(Map<String, dynamic> row)? previousFilter,
    int defaultValue = 1,
  }) {
    int? maxValue;

    void consider(dynamic value) {
      final intValue = _parseInt(value);
      if (intValue != null && (maxValue == null || intValue > maxValue!)) {
        maxValue = intValue;
      }
    }

    currentValues.forEach(consider);

    for (final prev in previousData ?? const []) {
      if (prev is! Map) continue;
      final row = prev.cast<String, dynamic>();
      if (previousFilter != null && !previousFilter(row)) continue;
      consider(row[key]);
    }

    return maxValue == null ? defaultValue : maxValue! + 1;
  }
}
