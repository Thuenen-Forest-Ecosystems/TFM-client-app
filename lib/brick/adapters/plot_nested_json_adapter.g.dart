// GENERATED CODE DO NOT EDIT
part of '../brick.g.dart';

Future<PlotNestedJson> _$PlotNestedJsonFromSupabase(
  Map<String, dynamic> data, {
  required SupabaseProvider provider,
  OfflineFirstWithSupabaseRepository? repository,
}) async {
  return PlotNestedJson(
    cluster_id:
        data['cluster_id'] == null ? null : data['cluster_id'] as String?,
    id: data['id'] as String?,
  );
}

Future<Map<String, dynamic>> _$PlotNestedJsonToSupabase(
  PlotNestedJson instance, {
  required SupabaseProvider provider,
  OfflineFirstWithSupabaseRepository? repository,
}) async {
  return {'cluster_id': instance.cluster_id, 'id': instance.id};
}

Future<PlotNestedJson> _$PlotNestedJsonFromSqlite(
  Map<String, dynamic> data, {
  required SqliteProvider provider,
  OfflineFirstWithSupabaseRepository? repository,
}) async {
  return PlotNestedJson(
    cluster_id:
        data['cluster_id'] == null ? null : data['cluster_id'] as String?,
    id: data['id'] as String,
  )..primaryKey = data['_brick_id'] as int;
}

Future<Map<String, dynamic>> _$PlotNestedJsonToSqlite(
  PlotNestedJson instance, {
  required SqliteProvider provider,
  OfflineFirstWithSupabaseRepository? repository,
}) async {
  return {'cluster_id': instance.cluster_id, 'id': instance.id};
}

/// Construct a [PlotNestedJson]
class PlotNestedJsonAdapter
    extends OfflineFirstWithSupabaseAdapter<PlotNestedJson> {
  PlotNestedJsonAdapter();

  @override
  final supabaseTableName = 'plot_nested_json';
  @override
  final defaultToNull = true;
  @override
  final fieldsToSupabaseColumns = {
    'cluster_id': const RuntimeSupabaseColumnDefinition(
      association: false,
      columnName: 'cluster_id',
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
    'cluster_id': const RuntimeSqliteColumnDefinition(
      association: false,
      columnName: 'cluster_id',
      iterable: false,
      type: String,
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
    PlotNestedJson instance,
    DatabaseExecutor executor,
  ) async {
    final results = await executor.rawQuery(
      '''
        SELECT * FROM `PlotNestedJson` WHERE id = ? LIMIT 1''',
      [instance.id],
    );

    // SQFlite returns [{}] when no results are found
    if (results.isEmpty || (results.length == 1 && results.first.isEmpty)) {
      return null;
    }

    return results.first['_brick_id'] as int;
  }

  @override
  final String tableName = 'PlotNestedJson';

  @override
  Future<PlotNestedJson> fromSupabase(
    Map<String, dynamic> input, {
    required provider,
    covariant OfflineFirstWithSupabaseRepository? repository,
  }) async => await _$PlotNestedJsonFromSupabase(
    input,
    provider: provider,
    repository: repository,
  );
  @override
  Future<Map<String, dynamic>> toSupabase(
    PlotNestedJson input, {
    required provider,
    covariant OfflineFirstWithSupabaseRepository? repository,
  }) async => await _$PlotNestedJsonToSupabase(
    input,
    provider: provider,
    repository: repository,
  );
  @override
  Future<PlotNestedJson> fromSqlite(
    Map<String, dynamic> input, {
    required provider,
    covariant OfflineFirstWithSupabaseRepository? repository,
  }) async => await _$PlotNestedJsonFromSqlite(
    input,
    provider: provider,
    repository: repository,
  );
  @override
  Future<Map<String, dynamic>> toSqlite(
    PlotNestedJson input, {
    required provider,
    covariant OfflineFirstWithSupabaseRepository? repository,
  }) async => await _$PlotNestedJsonToSqlite(
    input,
    provider: provider,
    repository: repository,
  );
}
