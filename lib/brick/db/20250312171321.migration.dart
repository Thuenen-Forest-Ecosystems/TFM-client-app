// GENERATED CODE EDIT WITH CAUTION
// THIS FILE **WILL NOT** BE REGENERATED
// This file should be version controlled and can be manually edited.
part of 'schema.g.dart';

// While migrations are intelligently created, the difference between some commands, such as
// DropTable vs. RenameTable, cannot be determined. For this reason, please review migrations after
// they are created to ensure the correct inference was made.

// The migration version must **always** mirror the file name

const List<MigrationCommand> _migration_20250312171321_up = [
  DropColumn('cluster_name', onTable: 'Plot'),
  InsertColumn('cluster_id', Column.integer, onTable: 'Plot')
];

const List<MigrationCommand> _migration_20250312171321_down = [
  DropColumn('cluster_id', onTable: 'Plot')
];

//
// DO NOT EDIT BELOW THIS LINE
//

@Migratable(
  version: '20250312171321',
  up: _migration_20250312171321_up,
  down: _migration_20250312171321_down,
)
class Migration20250312171321 extends Migration {
  const Migration20250312171321()
    : super(
        version: 20250312171321,
        up: _migration_20250312171321_up,
        down: _migration_20250312171321_down,
      );
}
