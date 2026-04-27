import 'dart:convert';

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

  /// Increments every time [load] completes successfully.
  /// Widgets can listen to this to rebuild when lookup labels become available.
  static final versionNotifier = ValueNotifier<int>(0);

  // table_name → { code_value → name_de }
  final Map<String, Map<dynamic, String>> _cache = {};

  // table_name → { code_value → parsed interval List }
  final Map<String, Map<dynamic, dynamic>> _intervalCache = {};

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
        final rows = await db.getAll('SELECT code, name_de, interval FROM "$tableName"');
        final nameMap = <dynamic, String>{};
        final intervalMap = <dynamic, dynamic>{};
        for (final row in rows) {
          final code = row['code'];
          if (code == null) continue;
          final asInt = int.tryParse(code.toString());
          final asDouble = double.tryParse(code.toString());

          final nameDe = row['name_de'];
          if (nameDe != null) {
            nameMap[code] = nameDe as String;
            if (asInt != null) nameMap[asInt] = nameDe;
            if (asDouble != null && asDouble != asInt) nameMap[asDouble] = nameDe;
          }

          final intervalRaw = row['interval'];
          if (intervalRaw != null) {
            dynamic parsed;
            try {
              parsed = json.decode(intervalRaw as String);
            } catch (_) {
              parsed = [intervalRaw.toString()];
            }
            intervalMap[code] = parsed;
            if (asInt != null) intervalMap[asInt] = parsed;
            if (asDouble != null && asDouble != asInt) intervalMap[asDouble] = parsed;
          }
        }
        _cache[tableName] = nameMap;
        if (intervalMap.isNotEmpty) _intervalCache[tableName] = intervalMap;
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

    // Notify listeners (e.g. widgets) that lookup data has been (re)loaded.
    versionNotifier.value++;
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

  /// Build an interval list parallel to [enumValues] from the given lookup table.
  /// Returns null if no interval data is cached for this table, so callers can
  /// treat a null result as "show all values".
  /// Each entry is a parsed List (from the DB's JSON interval column) or null.
  List? getIntervalList(String tableName, List enumValues) {
    if (!_loaded) return null;
    final table = _intervalCache[tableName];
    if (table == null) return null;
    final result = enumValues
        .map((v) => v == null ? null : (table[v] ?? table[v.toString()]))
        .toList();
    // Return null if nothing matched (table has interval data but not for these values)
    if (result.every((e) => e == null)) return null;
    return result;
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
