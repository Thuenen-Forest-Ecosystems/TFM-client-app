// GENERATED CODE EDIT WITH CAUTION
// THIS FILE **WILL NOT** BE REGENERATED
// This file should be version controlled and can be manually edited.
part of 'schema.g.dart';

// While migrations are intelligently created, the difference between some commands, such as
// DropTable vs. RenameTable, cannot be determined. For this reason, please review migrations after
// they are created to ensure the correct inference was made.

// The migration version must **always** mirror the file name

const List<MigrationCommand> _migration_20250312150159_up = [
  InsertTable('PlotNestedJson'),
  InsertColumn('cluster_name', Column.integer, onTable: 'PlotNestedJson'),
  InsertColumn('id', Column.varchar, onTable: 'PlotNestedJson', unique: true),
  CreateIndex(columns: ['id'], onTable: 'PlotNestedJson', unique: true)
];

const List<MigrationCommand> _migration_20250312150159_down = [
  DropTable('PlotNestedJson'),
  DropColumn('cluster_name', onTable: 'PlotNestedJson'),
  DropColumn('id', onTable: 'PlotNestedJson'),
  DropIndex('index_PlotNestedJson_on_id')
];

//
// DO NOT EDIT BELOW THIS LINE
//

@Migratable(
  version: '20250312150159',
  up: _migration_20250312150159_up,
  down: _migration_20250312150159_down,
)
class Migration20250312150159 extends Migration {
  const Migration20250312150159()
    : super(
        version: 20250312150159,
        up: _migration_20250312150159_up,
        down: _migration_20250312150159_down,
      );
}
