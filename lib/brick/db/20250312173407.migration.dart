// GENERATED CODE EDIT WITH CAUTION
// THIS FILE **WILL NOT** BE REGENERATED
// This file should be version controlled and can be manually edited.
part of 'schema.g.dart';

// While migrations are intelligently created, the difference between some commands, such as
// DropTable vs. RenameTable, cannot be determined. For this reason, please review migrations after
// they are created to ensure the correct inference was made.

// The migration version must **always** mirror the file name

const List<MigrationCommand> _migration_20250312173407_up = [
  DropColumn('plot', onTable: 'PlotNestedJson')
];

const List<MigrationCommand> _migration_20250312173407_down = [
  
];

//
// DO NOT EDIT BELOW THIS LINE
//

@Migratable(
  version: '20250312173407',
  up: _migration_20250312173407_up,
  down: _migration_20250312173407_down,
)
class Migration20250312173407 extends Migration {
  const Migration20250312173407()
    : super(
        version: 20250312173407,
        up: _migration_20250312173407_up,
        down: _migration_20250312173407_down,
      );
}
