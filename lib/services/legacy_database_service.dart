import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
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

/// One inactive database file of this app found on disk (the legacy shared
/// file or another user's per-user file), with its content summary.
class DatabaseFileInfo {
  final String path;
  final String fileName;

  /// True for the legacy shared file (`<base>.db`, no user suffix).
  final bool isShared;

  /// The user id encoded in a per-user file name, null for the shared file.
  final String? userId;

  /// Owner's display name / e-mail, read from `users_profile` inside the file
  /// itself. Null when the profile never synced into that file.
  final String? userName;
  final String? email;

  final int recordCount;
  final int pendingUploadCount;

  const DatabaseFileInfo({
    required this.path,
    required this.fileName,
    required this.isShared,
    required this.recordCount,
    required this.pendingUploadCount,
    this.userId,
    this.userName,
    this.email,
  });

  bool get hasData => recordCount > 0 || pendingUploadCount > 0;

  /// Short human-readable label for tabs: user name, else e-mail, else id.
  String get label {
    if (isShared) return 'Altdatenbank';
    if (userName != null && userName!.isNotEmpty) return userName!;
    if (email != null && email!.isNotEmpty) return email!;
    final id = userId ?? '?';
    return 'Benutzer ${id.length > 8 ? '${id.substring(0, 8)}…' : id}';
  }
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

/// Read-only access to inactive database files of this app: the legacy shared
/// `tfm.db` and other users' per-user files. Used to surface data that was
/// written there and never uploaded.
///
/// Nothing here mutates the inspected files: each file is opened in its own
/// short-lived [PowerSyncDatabase] instance (never connected to PowerSync) and
/// closed again after each query. Recovery copies rows into the ACTIVE
/// database, which re-enters them into its upload queue.
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

  /// Opens the database file at [path], runs [action], then always closes it.
  Future<T> _withDbAt<T>(String path, Future<T> Function(PowerSyncDatabase db) action) async {
    final inspectedDb = PowerSyncDatabase(schema: schema, path: path);
    try {
      await inspectedDb.initialize();
      return await action(inspectedDb);
    } finally {
      await inspectedDb.close();
    }
  }

  /// Opens the legacy db (if present & not the active db), runs [action], then
  /// always closes it. Returns null when there is no legacy db to inspect.
  Future<T?> _withLegacyDb<T>(Future<T> Function(PowerSyncDatabase db) action) async {
    final path = await ps.getLegacyDatabasePathIfPresent();
    if (path == null) return null;
    return _withDbAt(path, action);
  }

  /// Enumerates all database files of this app that are NOT the currently
  /// active one — the legacy shared file and other users' per-user files —
  /// each with record and pending-upload counts. Unreadable files are skipped.
  Future<List<DatabaseFileInfo>> listOtherDatabaseFiles() async {
    if (kIsWeb) return const [];

    final base = await ps.getDatabaseBaseName();
    final activePath = await ps.getActiveDatabasePath();
    final Directory dir;
    try {
      dir = await getApplicationSupportDirectory();
    } catch (_) {
      return const [];
    }

    final result = <DatabaseFileInfo>[];
    for (final entry in dir.listSync().whereType<File>()) {
      final name = p.basename(entry.path);
      final isSharedFile = name == '$base.db';
      final isUserFile = name.startsWith('${base}_') && name.endsWith('.db');
      if (!isSharedFile && !isUserFile) continue;
      if (p.equals(entry.path, activePath)) continue;

      final userId = isSharedFile ? null : name.substring('${base}_'.length, name.length - 3);
      int recordCount = 0;
      int pendingUploadCount = 0;
      String? userName;
      String? email;
      try {
        await _withDbAt(entry.path, (db) async {
          try {
            final r = await db.get('SELECT count(*) AS c FROM records');
            recordCount = (r['c'] as int?) ?? 0;
          } catch (_) {}
          try {
            pendingUploadCount = (await db.getUploadQueueStats()).count;
          } catch (_) {}
          // The file's own users_profile row names its owner.
          if (userId != null) {
            try {
              final profile = await db.getOptional(
                'SELECT user_name, email FROM users_profile WHERE id = ?',
                [userId],
              );
              userName = profile?['user_name'] as String?;
              email = profile?['email'] as String?;
            } catch (_) {}
          }
        });
      } catch (_) {
        continue;
      }

      result.add(
        DatabaseFileInfo(
          path: entry.path,
          fileName: name,
          isShared: isSharedFile,
          userId: userId,
          userName: userName,
          email: email,
          recordCount: recordCount,
          pendingUploadCount: pendingUploadCount,
        ),
      );
    }

    // Shared legacy file first, then per-user files by name.
    result.sort((a, b) {
      if (a.isShared != b.isShared) return a.isShared ? -1 : 1;
      return a.fileName.compareTo(b.fileName);
    });
    return result;
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

  /// Ids of records that still have un-uploaded changes in the CRUD queue of
  /// the file at [path] (defaults to the legacy db). These rows exist ONLY in
  /// that file — the server never received them.
  Future<Set<String>> getPendingRecordIds({String? path}) async {
    Future<Set<String>> query(PowerSyncDatabase db) async {
      final rows = await db.getAll(
        "SELECT DISTINCT json_extract(data, '\$.id') AS rid FROM ps_crud",
      );
      return rows.map((r) => r['rid']).whereType<String>().toSet();
    }

    try {
      if (path != null) return await _withDbAt(path, query);
      return await _withLegacyDb(query) ?? const {};
    } catch (_) {
      return const {};
    }
  }

  /// Fetches records from the file at [path] (defaults to the legacy db) for
  /// inspection.
  Future<List<LegacyRecord>> getRecords({int limit = 500, String? path}) async {
    Future<List<LegacyRecord>> query(PowerSyncDatabase db) async {
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
    }

    if (path != null) return _withDbAt(path, query);
    return await _withLegacyDb(query) ?? const [];
  }

  /// Copies a single record from the file at [path] (defaults to the legacy
  /// db) into the active per-user db, keeping the same primary key so it
  /// upserts (instead of duplicating) when it syncs to the server. The source
  /// row is left in place (non-destructive) so recovery can be retried.
  /// Returns true when a row was copied, false when that id no longer exists
  /// in the source db.
  Future<bool> recoverRecord(String id, {String? path}) async {
    Future<Map<String, Object?>> read(PowerSyncDatabase legacy) async {
      final r = await legacy.getOptional('SELECT * FROM records WHERE id = ?', [id]);
      if (r == null) return <String, Object?>{};
      return {for (final key in r.keys) key: r[key]};
    }

    final Map<String, Object?>? row;
    if (path != null) {
      row = await _withDbAt(path, read);
    } else {
      row = await _withLegacyDb(read);
    }

    if (row == null || row.isEmpty) return false;

    final active = ps.db;
    final columns = row.keys.toList();
    final existing = await active.getOptional('SELECT id FROM records WHERE id = ?', [id]);

    if (existing == null) {
      final placeholders = List.filled(columns.length, '?').join(', ');
      await active.execute(
        'INSERT INTO records (${columns.join(', ')}) VALUES ($placeholders)',
        columns.map((c) => row![c]).toList(),
      );
    } else {
      final setColumns = columns.where((c) => c != 'id').toList();
      final setClause = setColumns.map((c) => '$c = ?').join(', ');
      await active.execute(
        'UPDATE records SET $setClause WHERE id = ?',
        [...setColumns.map((c) => row![c]), id],
      );
    }
    return true;
  }
}
