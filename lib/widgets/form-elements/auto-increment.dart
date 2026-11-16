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

  /// Closes the gap left by deleting a row numbered [deletedValue] (#507).
  ///
  /// [values] holds the remaining rows' values of [key]; [renumberable] says
  /// per row whether it may be renumbered (rows created in the app – never
  /// rows preset from or matched to the previous inventory). Renumberable
  /// rows numbered above [deletedValue] move down, in their current order,
  /// to the smallest free numbers. A number is free when no other row,
  /// [reservedValues] entry (e.g. filter-hidden rows) or previous-inventory
  /// row uses it, and it lies above every fixed number – the same floor
  /// [next] respects, so a gap inside the previous numbering is never filled.
  /// Numbers only ever decrease.
  ///
  /// Returns the new value per row index; rows that keep their number are
  /// absent.
  static Map<int, int> compactAfterDelete(
    String key, {
    required dynamic deletedValue,
    required List<dynamic> values,
    required List<bool> renumberable,
    Iterable<dynamic> reservedValues = const [],
    List<dynamic>? previousData,
    bool Function(Map<String, dynamic> row)? previousFilter,
  }) {
    assert(values.length == renumberable.length);
    final deleted = _parseInt(deletedValue);
    if (deleted == null) return const {};

    final candidates = <int>[];
    final taken = <int>{};
    int? floor;

    void fix(int? value) {
      if (value == null) return;
      taken.add(value);
      if (floor == null || value > floor!) floor = value;
    }

    for (var i = 0; i < values.length; i++) {
      final value = _parseInt(values[i]);
      if (value == null) continue;
      if (!renumberable[i]) {
        fix(value);
      } else if (value > deleted) {
        candidates.add(i);
      } else {
        taken.add(value);
      }
    }
    reservedValues.map(_parseInt).forEach(fix);
    for (final prev in previousData ?? const []) {
      if (prev is! Map) continue;
      final row = prev.cast<String, dynamic>();
      if (previousFilter != null && !previousFilter(row)) continue;
      fix(_parseInt(row[key]));
    }

    candidates.sort((a, b) => _parseInt(values[a])!.compareTo(_parseInt(values[b])!));

    final result = <int, int>{};
    var next = floor == null || deleted > floor! ? deleted : floor! + 1;
    for (final index in candidates) {
      final current = _parseInt(values[index])!;
      while (taken.contains(next)) {
        next++;
      }
      if (next < current) {
        result[index] = next;
        taken.add(next);
        next++;
      } else {
        // No free number below this row: keep it, later rows go above it.
        taken.add(current);
        if (next <= current) next = current + 1;
      }
    }
    return result;
  }
}
