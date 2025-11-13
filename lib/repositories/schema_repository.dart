import 'package:terrestrial_forest_monitor/services/powersync.dart';
import 'dart:convert';

class SchemaRepository {
  // Watch all visible schemas (reactive)
  Stream<List<SchemaModel>> watchVisible() {
    return db.watch('SELECT * FROM schemas WHERE is_visible = 1 ORDER BY interval_name DESC, created_at DESC').map((results) => results.map((row) => SchemaModel.fromJson(row)).toList());
  }

  // Watch all schemas (including hidden)
  Stream<List<SchemaModel>> watchAll() {
    return db.watch('SELECT * FROM schemas ORDER BY interval_name DESC, created_at DESC').map((results) => results.map((row) => SchemaModel.fromJson(row)).toList());
  }

  // Get single schema by ID
  Future<SchemaModel?> getById(String id) async {
    final results = await db.getAll('SELECT * FROM schemas WHERE id = ?', [id]);
    return results.isEmpty ? null : SchemaModel.fromJson(results.first);
  }

  // Get schemas by interval
  Stream<List<SchemaModel>> watchByInterval(String intervalName) {
    return db.watch('SELECT * FROM schemas WHERE interval_name = ? AND is_visible = 1 ORDER BY created_at DESC', parameters: [intervalName]).map((results) => results.map((row) => SchemaModel.fromJson(row)).toList());
  }

  // Search schemas by title or description
  Stream<List<SchemaModel>> search(String query) {
    return db
        .watch(
          '''SELECT * FROM schemas 
         WHERE (title LIKE ? OR description LIKE ?) 
         AND is_visible = 1 
         ORDER BY title''',
          parameters: ['%$query%', '%$query%'],
        )
        .map((results) => results.map((row) => SchemaModel.fromJson(row)).toList());
  }

  // Get schema JSON data
  Future<Map<String, dynamic>?> getSchemaJson(String id) async {
    final schema = await getById(id);
    return schema?.schemaData;
  }

  // Create new schema (syncs to server via PowerSync)
  Future<void> create(SchemaModel schema) async {
    await db.execute(
      '''INSERT INTO schemas (
        id, created_at, interval_name, title, description, is_visible,
        bucket_schema_file_name, bucket_plausability_file_name, schema, version, directory
      ) VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?)''',
      [
        schema.id,
        schema.createdAt.toIso8601String(),
        schema.intervalName,
        schema.title,
        schema.description,
        schema.isVisible ? 1 : 0,
        schema.bucketSchemaFileName,
        schema.bucketPlausabilityFileName,
        schema.schemaData != null ? jsonEncode(schema.schemaData) : null,
        schema.version,
        schema.directory,
      ],
    );
  }

  // Update schema
  Future<void> update(SchemaModel schema) async {
    await db.execute(
      '''UPDATE schemas 
         SET interval_name = ?, title = ?, description = ?, is_visible = ?,
             bucket_schema_file_name = ?, bucket_plausability_file_name = ?,
             schema = ?, version = ?, directory = ?
         WHERE id = ?''',
      [
        schema.intervalName,
        schema.title,
        schema.description,
        schema.isVisible ? 1 : 0,
        schema.bucketSchemaFileName,
        schema.bucketPlausabilityFileName,
        schema.schemaData != null ? jsonEncode(schema.schemaData) : null,
        schema.version,
        schema.directory,
        schema.id,
      ],
    );
  }

  // Toggle visibility
  Future<void> toggleVisibility(String id, bool isVisible) async {
    await db.execute('UPDATE schemas SET is_visible = ? WHERE id = ?', [isVisible ? 1 : 0, id]);
  }

  // Delete schema
  Future<void> delete(String id) async {
    await db.execute('DELETE FROM schemas WHERE id = ?', [id]);
  }

  // Get latest schema for interval
  Future<SchemaModel?> getLatestForInterval(String intervalName) async {
    final results = await db.getAll(
      '''SELECT * FROM schemas 
         WHERE interval_name = ? AND is_visible = 1 
         ORDER BY version DESC, created_at DESC 
         LIMIT 1''',
      [intervalName],
    );
    return results.isEmpty ? null : SchemaModel.fromJson(results.first);
  }

  // Watch unique intervals with their latest schema
  Stream<List<SchemaModel>> watchUniqueByInterval() {
    return db
        .watch('''SELECT * FROM schemas s1
         WHERE s1.created_at = (
           SELECT MAX(s2.created_at) 
           FROM schemas s2 
           WHERE s2.interval_name = s1.interval_name
         )
         ORDER BY s1.interval_name DESC''')
        .map((results) => results.map((row) => SchemaModel.fromJson(row)).toList());
  }

  // Get list of unique interval names
  Stream<List<String>> watchIntervalNames() {
    return db.watch('SELECT DISTINCT interval_name FROM schemas ORDER BY interval_name DESC').map((results) => results.map((row) => row['interval_name'] as String).toList());
  }
}

// Model class
class SchemaModel {
  final String id;
  final DateTime createdAt;
  final String intervalName;
  final String title;
  final String? description;
  final bool isVisible;
  final String? bucketSchemaFileName;
  final String? bucketPlausabilityFileName;
  final Map<String, dynamic>? schemaData;
  final int? version;
  final String? directory;

  SchemaModel({
    required this.id,
    required this.createdAt,
    required this.intervalName,
    required this.title,
    this.description,
    required this.isVisible,
    this.bucketSchemaFileName,
    this.bucketPlausabilityFileName,
    this.schemaData,
    this.version,
    this.directory,
  });

  factory SchemaModel.fromJson(Map<String, dynamic> json) {
    return SchemaModel(
      id: json['id'] as String,
      createdAt: DateTime.parse(json['created_at'] as String),
      intervalName: json['interval_name'] as String,
      title: json['title'] as String,
      description: json['description'] as String?,
      isVisible: (json['is_visible'] as int?) == 1,
      bucketSchemaFileName: json['bucket_schema_file_name'] as String?,
      bucketPlausabilityFileName: json['bucket_plausability_file_name'] as String?,
      schemaData: json['schema'] != null ? (json['schema'] is String ? jsonDecode(json['schema'] as String) : json['schema'] as Map<String, dynamic>) : null,
      version: json['version'] as int?,
      directory: json['directory'] as String?,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'created_at': createdAt.toIso8601String(),
      'interval_name': intervalName,
      'title': title,
      'description': description,
      'is_visible': isVisible,
      'bucket_schema_file_name': bucketSchemaFileName,
      'bucket_plausability_file_name': bucketPlausabilityFileName,
      'schema': schemaData,
      'version': version,
      'directory': directory,
    };
  }

  SchemaModel copyWith({
    String? id,
    DateTime? createdAt,
    String? intervalName,
    String? title,
    String? description,
    bool? isVisible,
    String? bucketSchemaFileName,
    String? bucketPlausabilityFileName,
    Map<String, dynamic>? schemaData,
    int? version,
    String? directory,
  }) {
    return SchemaModel(
      id: id ?? this.id,
      createdAt: createdAt ?? this.createdAt,
      intervalName: intervalName ?? this.intervalName,
      title: title ?? this.title,
      description: description ?? this.description,
      isVisible: isVisible ?? this.isVisible,
      bucketSchemaFileName: bucketSchemaFileName ?? this.bucketSchemaFileName,
      bucketPlausabilityFileName: bucketPlausabilityFileName ?? this.bucketPlausabilityFileName,
      schemaData: schemaData ?? this.schemaData,
      version: version ?? this.version,
      directory: directory ?? this.directory,
    );
  }
}
