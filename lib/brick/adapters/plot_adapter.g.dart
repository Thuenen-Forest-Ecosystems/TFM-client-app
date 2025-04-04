// GENERATED CODE DO NOT EDIT
part of '../brick.g.dart';

Future<Plot> _$PlotFromSupabase(
  Map<String, dynamic> data, {
  required SupabaseProvider provider,
  OfflineFirstWithSupabaseRepository? repository,
}) async {
  return Plot(cluster_id: data['cluster_id'] as int, id: data['id'] as String?);
}

Future<Map<String, dynamic>> _$PlotToSupabase(
  Plot instance, {
  required SupabaseProvider provider,
  OfflineFirstWithSupabaseRepository? repository,
}) async {
  return {'cluster_id': instance.cluster_id, 'id': instance.id};
}

Future<Plot> _$PlotFromSqlite(
  Map<String, dynamic> data, {
  required SqliteProvider provider,
  OfflineFirstWithSupabaseRepository? repository,
}) async {
  return Plot(cluster_id: data['cluster_id'] as int, id: data['id'] as String)
    ..primaryKey = data['_brick_id'] as int;
}

Future<Map<String, dynamic>> _$PlotToSqlite(
  Plot instance, {
  required SqliteProvider provider,
  OfflineFirstWithSupabaseRepository? repository,
}) async {
  return {'cluster_id': instance.cluster_id, 'id': instance.id};
}

/// Construct a [Plot]
class PlotAdapter extends OfflineFirstWithSupabaseAdapter<Plot> {
  PlotAdapter();

  @override
  final supabaseTableName = 'plot';
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
    Plot instance,
    DatabaseExecutor executor,
  ) async {
    final results = await executor.rawQuery(
      '''
        SELECT * FROM `Plot` WHERE id = ? LIMIT 1''',
      [instance.id],
    );

    // SQFlite returns [{}] when no results are found
    if (results.isEmpty || (results.length == 1 && results.first.isEmpty)) {
      return null;
    }

    return results.first['_brick_id'] as int;
  }

  @override
  final String tableName = 'Plot';

  @override
  Future<Plot> fromSupabase(
    Map<String, dynamic> input, {
    required provider,
    covariant OfflineFirstWithSupabaseRepository? repository,
  }) async => await _$PlotFromSupabase(
    input,
    provider: provider,
    repository: repository,
  );
  @override
  Future<Map<String, dynamic>> toSupabase(
    Plot input, {
    required provider,
    covariant OfflineFirstWithSupabaseRepository? repository,
  }) async =>
      await _$PlotToSupabase(input, provider: provider, repository: repository);
  @override
  Future<Plot> fromSqlite(
    Map<String, dynamic> input, {
    required provider,
    covariant OfflineFirstWithSupabaseRepository? repository,
  }) async =>
      await _$PlotFromSqlite(input, provider: provider, repository: repository);
  @override
  Future<Map<String, dynamic>> toSqlite(
    Plot input, {
    required provider,
    covariant OfflineFirstWithSupabaseRepository? repository,
  }) async =>
      await _$PlotToSqlite(input, provider: provider, repository: repository);
}
