import 'package:powersync/powersync.dart';
import 'package:terrestrial_forest_monitor/services/powersync.dart' as ps;
import 'package:terrestrial_forest_monitor/services/schema.dart';

/// Summary of what is sitting in the legacy shared `tfm.db`.
class LegacyDataSummary {
  /// Total rows in the `records` table.
  final int recordCount;

  /// Local changes that were never uploaded (still in the PowerSync CRUD
  /// queue). These are the truly at-risk rows — the rest also live on the
  /// server and sync back into the per-user db on their own.
  final int pendingUploadCount;

  const LegacyDataSummary({required this.recordCount, required this.pendingUploadCount});

  bool get hasData => recordCount > 0 || pendingUploadCount > 0;
}

/// A single record read from the legacy db, trimmed to the fields shown in the
/// inspection modal.
class LegacyRecord {
  final String id;
  final String? clusterName;
  final String? plotName;
  final String? schemaName;
  final String? updatedAt;
  final bool isValid;
  final String? note;
  final String? properties;

  const LegacyRecord({
    required this.id,
    this.clusterName,
    this.plotName,
    this.schemaName,
    this.updatedAt,
    this.isValid = false,
    this.note,
    this.properties,
  });
}

/// Read-only access to the legacy shared `tfm.db`, used to show the user any
/// data that was written there before per-user database isolation.
///
/// Nothing here mutates application data: the legacy file is opened in its own
/// short-lived [PowerSyncDatabase] instance (never connected to PowerSync) and
/// closed again after each query.
class LegacyDatabaseService {
  LegacyDatabaseService._();
  static final LegacyDatabaseService instance = LegacyDatabaseService._();

  /// Cached for the app session so re-mounting the banner doesn't reopen the
  /// db every build. Reset via [invalidate] after the data has been handled.
  LegacyDataSummary? _cachedSummary;
  bool _checked = false;

  void invalidate() {
    _cachedSummary = null;
    _checked = false;
  }

  /// Opens the legacy db (if present & not the active db), runs [action], then
  /// always closes it. Returns null when there is no legacy db to inspect.
  Future<T?> _withLegacyDb<T>(Future<T> Function(PowerSyncDatabase db) action) async {
    final path = await ps.getLegacyDatabasePathIfPresent();
    if (path == null) return null;

    final legacyDb = PowerSyncDatabase(schema: schema, path: path);
    try {
      await legacyDb.initialize();
      return await action(legacyDb);
    } finally {
      await legacyDb.close();
    }
  }

  /// Counts records and pending uploads in the legacy db. Cached per session.
  Future<LegacyDataSummary> getSummary({bool forceRefresh = false}) async {
    if (_checked && !forceRefresh) {
      return _cachedSummary ?? const LegacyDataSummary(recordCount: 0, pendingUploadCount: 0);
    }

    final summary = await _withLegacyDb((db) async {
      int recordCount = 0;
      int pendingUploadCount = 0;
      try {
        final r = await db.get('SELECT count(*) AS c FROM records');
        recordCount = (r['c'] as int?) ?? 0;
      } catch (_) {}
      try {
        // Public PowerSync API for the local upload-queue count (rows that
        // were never uploaded) — avoids depending on the internal ps_crud
        // table name.
        pendingUploadCount = (await db.getUploadQueueStats()).count;
      } catch (_) {}
      return LegacyDataSummary(recordCount: recordCount, pendingUploadCount: pendingUploadCount);
    });

    _cachedSummary = summary ?? const LegacyDataSummary(recordCount: 0, pendingUploadCount: 0);
    _checked = true;
    return _cachedSummary!;
  }

  /// Whether there is any leftover data worth surfacing a banner for.
  Future<bool> hasLegacyData() async => (await getSummary()).hasData;

  /// Fetches records from the legacy db for the inspection modal.
  Future<List<LegacyRecord>> getRecords({int limit = 500}) async {
    final records = await _withLegacyDb((db) async {
      final rows = await db.getAll(
        'SELECT id, cluster_name, plot_name, schema_name, updated_at, '
        'local_updated_at, is_valid, note, properties '
        'FROM records ORDER BY local_updated_at DESC LIMIT ?',
        [limit],
      );
      return rows.map((row) {
        final isValidRaw = row['is_valid'];
        return LegacyRecord(
          id: row['id'] as String,
          clusterName: row['cluster_name'] as String?,
          plotName: row['plot_name'] as String?,
          schemaName: row['schema_name'] as String?,
          updatedAt: (row['updated_at'] ?? row['local_updated_at']) as String?,
          isValid: isValidRaw == 1 || isValidRaw == true,
          note: row['note'] as String?,
          properties: row['properties'] as String?,
        );
      }).toList();
    });
    return records ?? const [];
  }

  /// Copies a single record from the legacy db into the active per-user db,
  /// keeping the same primary key so it upserts (instead of duplicating) when
  /// it syncs to the server. The legacy row is left in place (non-destructive)
  /// so recovery can be retried. Returns true when a row was copied, false
  /// when that id no longer exists in the legacy db.
  Future<bool> recoverRecord(String id) async {
    final row = await _withLegacyDb<Map<String, Object?>>((legacy) async {
      final r = await legacy.getOptional('SELECT * FROM records WHERE id = ?', [id]);
      if (r == null) return <String, Object?>{};
      return {for (final key in r.keys) key: r[key]};
    });

    if (row == null || row.isEmpty) return false;

    final active = ps.db;
    final columns = row.keys.toList();
    final existing = await active.getOptional('SELECT id FROM records WHERE id = ?', [id]);

    if (existing == null) {
      final placeholders = List.filled(columns.length, '?').join(', ');
      await active.execute(
        'INSERT INTO records (${columns.join(', ')}) VALUES ($placeholders)',
        columns.map((c) => row[c]).toList(),
      );
    } else {
      final setColumns = columns.where((c) => c != 'id').toList();
      final setClause = setColumns.map((c) => '$c = ?').join(', ');
      await active.execute(
        'UPDATE records SET $setClause WHERE id = ?',
        [...setColumns.map((c) => row[c]), id],
      );
    }
    return true;
  }
}
