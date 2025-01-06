// GENERATED CODE DO NOT EDIT
// This file should be version controlled
import 'package:brick_sqlite/db.dart';
part '20241216145555.migration.dart';
part '20241216145630.migration.dart';
part '20241216154353.migration.dart';

/// All intelligently-generated migrations from all `@Migratable` classes on disk
final migrations = <Migration>{
  const Migration20241216145555(),
  const Migration20241216145630(),
  const Migration20241216154353()
};

/// A consumable database structure including the latest generated migration.
final schema =
    Schema(20241216154353, generatorVersion: 1, tables: <SchemaTable>{
  SchemaTable('Schemas', columns: <SchemaColumn>{
    SchemaColumn('_brick_id', Column.integer,
        autoincrement: true, nullable: false, isPrimaryKey: true),
    SchemaColumn('interval_name', Column.varchar),
    SchemaColumn('is_visible', Column.boolean),
    SchemaColumn('id', Column.varchar, unique: true)
  }, indices: <SchemaIndex>{
    SchemaIndex(columns: ['id'], unique: true)
  }),
  SchemaTable('Cluster', columns: <SchemaColumn>{
    SchemaColumn('_brick_id', Column.integer,
        autoincrement: true, nullable: false, isPrimaryKey: true),
    SchemaColumn('cluster_name', Column.varchar),
    SchemaColumn('id', Column.varchar, unique: true)
  }, indices: <SchemaIndex>{
    SchemaIndex(columns: ['id'], unique: true)
  })
});
