// GENERATED CODE DO NOT EDIT
part of '../brick.g.dart';

Future<Cluster> _$ClusterFromSupabase(
  Map<String, dynamic> data, {
  required SupabaseProvider provider,
  OfflineFirstWithSupabaseRepository? repository,
}) async {
  return Cluster(
    cluster_name: data['cluster_name'] as int,
    id: data['id'] as String?,
  );
}

Future<Map<String, dynamic>> _$ClusterToSupabase(
  Cluster instance, {
  required SupabaseProvider provider,
  OfflineFirstWithSupabaseRepository? repository,
}) async {
  return {'cluster_name': instance.cluster_name, 'id': instance.id};
}

Future<Cluster> _$ClusterFromSqlite(
  Map<String, dynamic> data, {
  required SqliteProvider provider,
  OfflineFirstWithSupabaseRepository? repository,
}) async {
  return Cluster(
    cluster_name: data['cluster_name'] as int,
    id: data['id'] as String,
  )..primaryKey = data['_brick_id'] as int;
}

Future<Map<String, dynamic>> _$ClusterToSqlite(
  Cluster instance, {
  required SqliteProvider provider,
  OfflineFirstWithSupabaseRepository? repository,
}) async {
  return {'cluster_name': instance.cluster_name, 'id': instance.id};
}

/// Construct a [Cluster]
class ClusterAdapter extends OfflineFirstWithSupabaseAdapter<Cluster> {
  ClusterAdapter();

  @override
  final supabaseTableName = 'cluster';
  @override
  final defaultToNull = true;
  @override
  final fieldsToSupabaseColumns = {
    'cluster_name': const RuntimeSupabaseColumnDefinition(
      association: false,
      columnName: 'cluster_name',
    ),
    'id': const RuntimeSupabaseColumnDefinition(
      association: false,
      columnName: 'id',
    ),
  };
  @override
  final ignoreDuplicates = false;
  @override
  final uniqueFields = {'id'};
  @override
  final Map<String, RuntimeSqliteColumnDefinition> fieldsToSqliteColumns = {
    'primaryKey': const RuntimeSqliteColumnDefinition(
      association: false,
      columnName: '_brick_id',
      iterable: false,
      type: int,
    ),
    'cluster_name': const RuntimeSqliteColumnDefinition(
      association: false,
      columnName: 'cluster_name',
      iterable: false,
      type: int,
    ),
    'id': const RuntimeSqliteColumnDefinition(
      association: false,
      columnName: 'id',
      iterable: false,
      type: String,
    ),
  };
  @override
  Future<int?> primaryKeyByUniqueColumns(
    Cluster instance,
    DatabaseExecutor executor,
  ) async {
    final results = await executor.rawQuery(
      '''
        SELECT * FROM `Cluster` WHERE id = ? LIMIT 1''',
      [instance.id],
    );

    // SQFlite returns [{}] when no results are found
    if (results.isEmpty || (results.length == 1 && results.first.isEmpty)) {
      return null;
    }

    return results.first['_brick_id'] as int;
  }

  @override
  final String tableName = 'Cluster';

  @override
  Future<Cluster> fromSupabase(
    Map<String, dynamic> input, {
    required provider,
    covariant OfflineFirstWithSupabaseRepository? repository,
  }) async => await _$ClusterFromSupabase(
    input,
    provider: provider,
    repository: repository,
  );
  @override
  Future<Map<String, dynamic>> toSupabase(
    Cluster input, {
    required provider,
    covariant OfflineFirstWithSupabaseRepository? repository,
  }) async => await _$ClusterToSupabase(
    input,
    provider: provider,
    repository: repository,
  );
  @override
  Future<Cluster> fromSqlite(
    Map<String, dynamic> input, {
    required provider,
    covariant OfflineFirstWithSupabaseRepository? repository,
  }) async => await _$ClusterFromSqlite(
    input,
    provider: provider,
    repository: repository,
  );
  @override
  Future<Map<String, dynamic>> toSqlite(
    Cluster input, {
    required provider,
    covariant OfflineFirstWithSupabaseRepository? repository,
  }) async => await _$ClusterToSqlite(
    input,
    provider: provider,
    repository: repository,
  );
}
