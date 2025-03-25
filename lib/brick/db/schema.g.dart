// GENERATED CODE DO NOT EDIT
// This file should be version controlled
import 'package:brick_sqlite/db.dart';
part '20250310201838.migration.dart';
part '20250310223446.migration.dart';
part '20250311134024.migration.dart';
part '20250312150159.migration.dart';
part '20250312150815.migration.dart';
part '20250312165407.migration.dart';
part '20250312165645.migration.dart';
part '20250312171321.migration.dart';
part '20250312171535.migration.dart';
part '20250312171932.migration.dart';
part '20250312173221.migration.dart';
part '20250312173407.migration.dart';
part '20250312175744.migration.dart';

/// All intelligently-generated migrations from all `@Migratable` classes on disk
final migrations = <Migration>{
  const Migration20250310201838(),
  const Migration20250310223446(),
  const Migration20250311134024(),
  const Migration20250312150159(),
  const Migration20250312150815(),
  const Migration20250312165407(),
  const Migration20250312165645(),
  const Migration20250312171321(),
  const Migration20250312171535(),
  const Migration20250312171932(),
  const Migration20250312173221(),
  const Migration20250312173407(),
  const Migration20250312175744(),
};

/// A consumable database structure including the latest generated migration.
final schema = Schema(
  20250312175744,
  generatorVersion: 1,
  tables: <SchemaTable>{
    SchemaTable(
      'Plot',
      columns: <SchemaColumn>{
        SchemaColumn(
          '_brick_id',
          Column.integer,
          autoincrement: true,
          nullable: false,
          isPrimaryKey: true,
        ),
        SchemaColumn('cluster_id', Column.integer),
        SchemaColumn('id', Column.varchar, unique: true),
      },
      indices: <SchemaIndex>{
        SchemaIndex(columns: ['id'], unique: true),
      },
    ),
    SchemaTable(
      'Cluster',
      columns: <SchemaColumn>{
        SchemaColumn(
          '_brick_id',
          Column.integer,
          autoincrement: true,
          nullable: false,
          isPrimaryKey: true,
        ),
        SchemaColumn('cluster_name', Column.integer),
        SchemaColumn('id', Column.varchar, unique: true),
      },
      indices: <SchemaIndex>{
        SchemaIndex(columns: ['id'], unique: true),
      },
    ),
    SchemaTable(
      'PlotNestedJson',
      columns: <SchemaColumn>{
        SchemaColumn(
          '_brick_id',
          Column.integer,
          autoincrement: true,
          nullable: false,
          isPrimaryKey: true,
        ),
        SchemaColumn('cluster_id', Column.varchar),
        SchemaColumn('id', Column.varchar, unique: true),
      },
      indices: <SchemaIndex>{
        SchemaIndex(columns: ['id'], unique: true),
      },
    ),
  },
);
