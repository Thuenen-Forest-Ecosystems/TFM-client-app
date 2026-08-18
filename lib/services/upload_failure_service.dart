import 'dart:convert';

import 'package:terrestrial_forest_monitor/services/powersync.dart' as ps;

/// A single quarantined upload from the local-only `upload_failures` table —
/// an op the server rejected (fatal Postgres error) or silently ignored
/// (RLS-invisible row, 0-row update), preserved by [SupabaseConnector].
class UploadFailure {
  final String id;
  final String? createdAt;
  final String tableName;
  final String recordId;
  final String op; // put | patch | delete
  final Map<String, dynamic> opData;
  final String? reason;
  final String? errorCode;
  final String? errorMessage;

  /// Display context resolved from the local row (records only).
  final String? clusterName;
  final String? plotName;

  const UploadFailure({
    required this.id,
    required this.tableName,
    required this.recordId,
    required this.op,
    required this.opData,
    this.createdAt,
    this.reason,
    this.errorCode,
    this.errorMessage,
    this.clusterName,
    this.plotName,
  });
}

/// Inspect and recover quarantined uploads.
///
/// Recovery re-applies the preserved column values to the active local
/// database *through the PowerSync view*, so the write re-enters the CRUD
/// queue and is uploaded again on the next sync. If the server still rejects
/// it, the connector quarantines it again — visibly, never silently.
///
/// Distinct from [LegacyDatabaseService]: that one reads rows stranded in the
/// legacy shared db *file*; this one reads ops dropped from the active db's
/// own upload queue. The two never touch the same storage.
class UploadFailureService {
  UploadFailureService._();

  static final RegExp _identifier = RegExp(r'^[a-zA-Z_][a-zA-Z0-9_]*$');

  static const String _listSql = '''
    SELECT uf.id, uf.created_at, uf.table_name, uf.record_id, uf.op,
           uf.op_data, uf.reason, uf.error_code, uf.error_message,
           r.cluster_name, r.plot_name
    FROM upload_failures uf
    LEFT JOIN records r ON uf.table_name = 'records' AND r.id = uf.record_id
    ORDER BY uf.created_at DESC
  ''';

  /// SQL used by the screen's live watch (same shape as [list]).
  static String get watchSql => _listSql;

  static UploadFailure rowToFailure(Map<String, dynamic> row) {
    Map<String, dynamic> data = const {};
    try {
      final decoded = jsonDecode(row['op_data'] as String? ?? '{}');
      if (decoded is Map<String, dynamic>) data = decoded;
    } catch (_) {}
    return UploadFailure(
      id: row['id'] as String,
      createdAt: row['created_at'] as String?,
      tableName: row['table_name'] as String? ?? '?',
      recordId: row['record_id'] as String? ?? '?',
      op: row['op'] as String? ?? 'patch',
      opData: data,
      reason: row['reason'] as String?,
      errorCode: row['error_code'] as String?,
      errorMessage: row['error_message'] as String?,
      clusterName: row['cluster_name'] as String?,
      plotName: row['plot_name'] as String?,
    );
  }

  static Future<List<UploadFailure>> list() async {
    final rows = await ps.db.getAll(_listSql);
    return rows.map((r) => rowToFailure({for (final k in r.keys) k: r[k]})).toList();
  }

  /// Re-applies [failure] to the active local database and removes the
  /// quarantine entry. Throws with a readable message when the entry cannot
  /// be applied (unknown table/columns, empty payload).
  static Future<void> restore(UploadFailure failure) async {
    final table = failure.tableName;
    if (!_identifier.hasMatch(table)) {
      throw ArgumentError('Ungültiger Tabellenname: $table');
    }

    final active = ps.db;

    if (failure.op == 'delete') {
      await active.execute('DELETE FROM $table WHERE id = ?', [failure.recordId]);
    } else {
      final data = Map<String, dynamic>.of(failure.opData)..remove('id');
      if (data.isEmpty) {
        throw StateError('Eintrag enthält keine Daten (op_data leer).');
      }
      final columns = data.keys.toList();
      for (final c in columns) {
        if (!_identifier.hasMatch(c)) {
          throw ArgumentError('Ungültiger Spaltenname: $c');
        }
      }

      final existing = await active.getOptional('SELECT id FROM $table WHERE id = ?', [
        failure.recordId,
      ]);
      if (existing == null) {
        final allColumns = ['id', ...columns];
        final placeholders = List.filled(allColumns.length, '?').join(', ');
        await active.execute(
          'INSERT INTO $table (${allColumns.join(', ')}) VALUES ($placeholders)',
          [failure.recordId, ...columns.map((c) => data[c])],
        );
      } else {
        final setClause = columns.map((c) => '$c = ?').join(', ');
        await active.execute('UPDATE $table SET $setClause WHERE id = ?', [
          ...columns.map((c) => data[c]),
          failure.recordId,
        ]);
      }
    }

    await active.execute('DELETE FROM upload_failures WHERE id = ?', [failure.id]);
  }

  /// Permanently deletes a quarantine entry without re-applying it.
  static Future<void> discard(UploadFailure failure) async {
    await ps.db.execute('DELETE FROM upload_failures WHERE id = ?', [failure.id]);
  }

  /// Restores all entries, oldest first so op order is preserved when several
  /// ops touch the same record (e.g. save followed by completion). Returns the
  /// error messages of entries that could not be applied.
  static Future<List<String>> restoreAll(List<UploadFailure> failures) async {
    final errors = <String>[];
    final ordered = failures.toList()
      ..sort((a, b) => (a.createdAt ?? '').compareTo(b.createdAt ?? ''));
    for (final f in ordered) {
      try {
        await restore(f);
      } catch (e) {
        errors.add('${f.tableName} ${f.recordId}: $e');
      }
    }
    return errors;
  }
}
