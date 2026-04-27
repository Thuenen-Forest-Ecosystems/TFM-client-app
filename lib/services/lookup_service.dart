import 'package:flutter/foundation.dart';
import 'package:terrestrial_forest_monitor/services/powersync.dart';
import 'package:terrestrial_forest_monitor/services/schema.dart';

/// Caches all lookup table data from the local PowerSync database so that
/// enum labels (name_de) can be resolved synchronously during widget builds.
///
/// The validation.json no longer ships `$tfm.name_de` arrays for fields that
/// are backed by a lookup table.  Instead it includes `$tfm.lookup_table`
/// (e.g. `"lookup_tree_status"`).  This service:
///   1. Is initialised once (call [load]) after the DB is ready.
///   2. Provides [getNameDe] / [getNameDeList] for synchronous access.
///
/// Usage:
/// ```dart
/// // Boot-time (after db is open):
/// await LookupService.instance.load();
///
/// // In a widget build:
/// final label = LookupService.instance.getNameDe('lookup_tree_status', 2);
/// ```
class LookupService {
  LookupService._();

  static final LookupService instance = LookupService._();

  // table_name → { code_value → name_de }
  final Map<String, Map<dynamic, String>> _cache = {};

  bool _loaded = false;
  bool get isLoaded => _loaded;

  /// Load (or reload) all lookup tables from the local DB.
  /// Safe to call multiple times – subsequent calls will refresh the cache.
  Future<void> load() async {
    _loaded = false;
    _cache.clear();

    // Query every table that starts with "lookup_" (all are small).
    // We use a single getAll per table to keep it simple.
    final tableNames = await _getLookupTableNames();

    for (final tableName in tableNames) {
      try {
        final rows = await db.getAll('SELECT code, name_de FROM "$tableName"');
        final map = <dynamic, String>{};
        for (final row in rows) {
          final code = row['code'];
          final nameDe = row['name_de'];
          if (code != null && nameDe != null) {
            // Store with the natural type of the code column (String in SQLite,
            // but enum values in schemas can be int/double).  Store both so we
            // match regardless of how the caller passes the code.
            map[code] = nameDe as String;
            // Also store as int/double for numeric codes
            final asInt = int.tryParse(code.toString());
            if (asInt != null) map[asInt] = nameDe;
            final asDouble = double.tryParse(code.toString());
            if (asDouble != null && asDouble != asInt) map[asDouble] = nameDe;
          }
        }
        _cache[tableName] = map;
      } catch (e) {
        debugPrint('LookupService: failed to load $tableName: $e');
      }
    }

    _loaded = true;

    // Diagnostic: count total entries to detect empty cache
    final totalEntries = _cache.values.fold<int>(
      0,
      (sum, m) => sum + m.length ~/ 3,
    ); // divide by 3: stored as str+int+double
    debugPrint(
      'LookupService: loaded ${_cache.length} tables, ~$totalEntries unique entries total',
    );
    // Sample first table with data
    for (final entry in _cache.entries) {
      if (entry.value.isNotEmpty) {
        debugPrint(
          '  sample [${entry.key}]: first entry key=${entry.value.keys.first} val=${entry.value.values.first}',
        );
        break;
      }
    }
    if (totalEntries == 0) {
      debugPrint(
        'LookupService WARNING: all lookup tables are empty! Enum labels will not be shown.',
      );
    }
  }

  /// Return the German display name for [code] in [tableName], or null if
  /// unknown.
  String? getNameDe(String tableName, dynamic code) {
    if (!_loaded) return null;
    final table = _cache[tableName];
    if (table == null) return null;
    return table[code] ?? table[code.toString()];
  }

  /// Build a name_de list parallel to [enumValues] from the given lookup
  /// table.  Entries without a match are null.
  List<String?> getNameDeList(String tableName, List enumValues) {
    return enumValues.map((v) => v == null ? null : getNameDe(tableName, v)).toList();
  }

  /// Return the interval string for [code] in [tableName], or null if unknown.
  /// (Interval data is not cached separately – kept for API symmetry; callers
  /// that previously used `$tfm.interval` can migrate to this.)
  Future<String?> getInterval(String tableName, dynamic code) async {
    try {
      final row = await db.get('SELECT interval FROM "$tableName" WHERE code = ?', [
        code.toString(),
      ]);
      return row['interval'] as String?;
    } catch (_) {
      return null;
    }
  }

  /// Retrieve all rows for a lookup table as a list of {code, name_de} maps.
  List<Map<dynamic, String>> getAllEntries(String tableName) {
    final table = _cache[tableName];
    if (table == null) return [];
    // Deduplicate: only include entries where key type matches the stored code
    // (we stored int/double aliases, so filter to String keys).
    return table.entries.where((e) => e.key is String).map((e) => {e.key: e.value}).toList();
  }

  Future<List<String>> _getLookupTableNames() async {
    // Use the compile-time constant list from schema.dart.
    // PowerSync implements tables as SQLite views, so querying
    // sqlite_master with type='table' would return nothing.
    // Also include lookup_tree_species which is defined separately in schema.dart
    // (with extra columns) and therefore not in listOfLookupTables.
    return [...listOfLookupTables, 'lookup_tree_species'];
  }
}
