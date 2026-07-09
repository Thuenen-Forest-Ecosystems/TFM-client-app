/// Decides whether an array row (tree, edge, deadwood, …) is protected
/// against deletion.
///
/// The old check compared the row against `previous_properties` with plain
/// `==`, which failed open in two real-world situations:
///  * `previous_properties` not yet filled/synced on the device → every row
///    (including preset trees) became deletable,
///  * identifier type mismatch ("1" vs 1) → no match found → deletable.
///
/// This guard closes both holes:
///  1. Rows that carry an inventory-archive UUID in `id` were preset by the
///     server (`fill_properties`) and are protected unconditionally — no
///     matter whether previous data is available on the device.
///  2. Previous-inventory matching uses type-normalized comparison.
class RowDeleteGuard {
  RowDeleteGuard._();

  static final RegExp _uuidPattern = RegExp(
    r'^[0-9a-fA-F]{8}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{12}$',
  );

  /// Identifier fields used to pair a row with its previous-inventory
  /// counterpart when no explicit identifierField is configured.
  static const List<String> fallbackIdentifierFields = [
    'tree_number',
    'edge_number',
    'row_number',
    'id',
  ];

  /// True when the row was preset by the server: preset rows carry the
  /// inventory-archive UUID in their `id` field, while rows created in the
  /// app never do.
  static bool isArchiveRow(Map<String, dynamic> rowData) {
    final id = rowData['id'];
    return id is String && _uuidPattern.hasMatch(id);
  }

  /// Type-normalized identifier equality: 1 == 1.0 == "1" == " 1 ".
  /// Null never equals anything (a row without an identifier cannot be
  /// matched, not even to a previous row that also lacks one).
  static bool identifiersEqual(dynamic a, dynamic b) {
    if (a == null || b == null) return false;
    if (a == b) return true;
    final na = num.tryParse(a.toString().trim());
    final nb = num.tryParse(b.toString().trim());
    if (na != null && nb != null) return na == nb;
    return a.toString().trim() == b.toString().trim();
  }

  /// Find the previous-inventory row matching [rowData] via
  /// [identifierField] (or the common fallbacks), using normalized equality.
  static Map<String, dynamic>? findMatchingPreviousRow(
    Map<String, dynamic> rowData,
    List<dynamic>? previousData, {
    String? identifierField,
  }) {
    if (previousData == null) return null;

    final identifierFields = identifierField != null
        ? [identifierField]
        : fallbackIdentifierFields;

    for (final idField in identifierFields) {
      final currentId = rowData[idField];
      if (currentId == null) continue;

      for (final prev in previousData) {
        if (prev is Map && identifiersEqual(prev[idField], currentId)) {
          return Map<String, dynamic>.from(prev);
        }
      }
    }

    return null;
  }

  /// Whether the row must not be deletable: preset by the server (archive
  /// UUID) or carried over from the previous inventory.
  static bool isProtected(
    Map<String, dynamic> rowData, {
    List<dynamic>? previousData,
    String? identifierField,
  }) {
    if (isArchiveRow(rowData)) return true;
    return findMatchingPreviousRow(
          rowData,
          previousData,
          identifierField: identifierField,
        ) !=
        null;
  }
}
