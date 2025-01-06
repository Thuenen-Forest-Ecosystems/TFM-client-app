// GENERATED CODE DO NOT EDIT
part of '../brick.g.dart';

Future<Schemas> _$SchemasFromSupabase(Map<String, dynamic> data,
    {required SupabaseProvider provider,
    OfflineFirstWithSupabaseRepository? repository}) async {
  return Schemas(
      interval_name: data['interval_name'] as String,
      is_visible: data['is_visible'] as bool,
      id: data['id'] as String?);
}

Future<Map<String, dynamic>> _$SchemasToSupabase(Schemas instance,
    {required SupabaseProvider provider,
    OfflineFirstWithSupabaseRepository? repository}) async {
  return {
    'interval_name': instance.interval_name,
    'is_visible': instance.is_visible,
    'id': instance.id
  };
}

Future<Schemas> _$SchemasFromSqlite(Map<String, dynamic> data,
    {required SqliteProvider provider,
    OfflineFirstWithSupabaseRepository? repository}) async {
  return Schemas(
      interval_name: data['interval_name'] as String,
      is_visible: data['is_visible'] == 1,
      id: data['id'] as String)
    ..primaryKey = data['_brick_id'] as int;
}

Future<Map<String, dynamic>> _$SchemasToSqlite(Schemas instance,
    {required SqliteProvider provider,
    OfflineFirstWithSupabaseRepository? repository}) async {
  return {
    'interval_name': instance.interval_name,
    'is_visible': instance.is_visible ? 1 : 0,
    'id': instance.id
  };
}

/// Construct a [Schemas]
class SchemasAdapter extends OfflineFirstWithSupabaseAdapter<Schemas> {
  SchemasAdapter();

  @override
  final supabaseTableName = 'schemas';
  @override
  final defaultToNull = true;
  @override
  final fieldsToSupabaseColumns = {
    'interval_name': const RuntimeSupabaseColumnDefinition(
      association: false,
      columnName: 'interval_name',
    ),
    'is_visible': const RuntimeSupabaseColumnDefinition(
      association: false,
      columnName: 'is_visible',
    ),
    'id': const RuntimeSupabaseColumnDefinition(
      association: false,
      columnName: 'id',
    )
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
    'interval_name': const RuntimeSqliteColumnDefinition(
      association: false,
      columnName: 'interval_name',
      iterable: false,
      type: String,
    ),
    'is_visible': const RuntimeSqliteColumnDefinition(
      association: false,
      columnName: 'is_visible',
      iterable: false,
      type: bool,
    ),
    'id': const RuntimeSqliteColumnDefinition(
      association: false,
      columnName: 'id',
      iterable: false,
      type: String,
    )
  };
  @override
  Future<int?> primaryKeyByUniqueColumns(
      Schemas instance, DatabaseExecutor executor) async {
    final results = await executor.rawQuery('''
        SELECT * FROM `Schemas` WHERE id = ? LIMIT 1''', [instance.id]);

    // SQFlite returns [{}] when no results are found
    if (results.isEmpty || (results.length == 1 && results.first.isEmpty)) {
      return null;
    }

    return results.first['_brick_id'] as int;
  }

  @override
  final String tableName = 'Schemas';

  @override
  Future<Schemas> fromSupabase(Map<String, dynamic> input,
          {required provider,
          covariant OfflineFirstWithSupabaseRepository? repository}) async =>
      await _$SchemasFromSupabase(input,
          provider: provider, repository: repository);
  @override
  Future<Map<String, dynamic>> toSupabase(Schemas input,
          {required provider,
          covariant OfflineFirstWithSupabaseRepository? repository}) async =>
      await _$SchemasToSupabase(input,
          provider: provider, repository: repository);
  @override
  Future<Schemas> fromSqlite(Map<String, dynamic> input,
          {required provider,
          covariant OfflineFirstWithSupabaseRepository? repository}) async =>
      await _$SchemasFromSqlite(input,
          provider: provider, repository: repository);
  @override
  Future<Map<String, dynamic>> toSqlite(Schemas input,
          {required provider,
          covariant OfflineFirstWithSupabaseRepository? repository}) async =>
      await _$SchemasToSqlite(input,
          provider: provider, repository: repository);
}
