// GENERATED CODE EDIT WITH CAUTION
// THIS FILE **WILL NOT** BE REGENERATED
// This file should be version controlled and can be manually edited.
part of 'schema.g.dart';

// While migrations are intelligently created, the difference between some commands, such as
// DropTable vs. RenameTable, cannot be determined. For this reason, please review migrations after
// they are created to ensure the correct inference was made.

// The migration version must **always** mirror the file name

const List<MigrationCommand> _migration_20241216145555_up = [
  InsertTable('Schemas'),
  InsertColumn('name', Column.varchar, onTable: 'Schemas'),
  InsertColumn('id', Column.varchar, onTable: 'Schemas', unique: true),
  CreateIndex(columns: ['id'], onTable: 'Schemas', unique: true)
];

const List<MigrationCommand> _migration_20241216145555_down = [
  DropTable('Schemas'),
  DropColumn('name', onTable: 'Schemas'),
  DropColumn('id', onTable: 'Schemas'),
  DropIndex('index_Schemas_on_id')
];

//
// DO NOT EDIT BELOW THIS LINE
//

@Migratable(
  version: '20241216145555',
  up: _migration_20241216145555_up,
  down: _migration_20241216145555_down,
)
class Migration20241216145555 extends Migration {
  const Migration20241216145555()
    : super(
        version: 20241216145555,
        up: _migration_20241216145555_up,
        down: _migration_20241216145555_down,
      );
}
