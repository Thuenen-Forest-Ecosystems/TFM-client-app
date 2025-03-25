// GENERATED CODE EDIT WITH CAUTION
// THIS FILE **WILL NOT** BE REGENERATED
// This file should be version controlled and can be manually edited.
part of 'schema.g.dart';

// While migrations are intelligently created, the difference between some commands, such as
// DropTable vs. RenameTable, cannot be determined. For this reason, please review migrations after
// they are created to ensure the correct inference was made.

// The migration version must **always** mirror the file name

const List<MigrationCommand> _migration_20250310201838_up = [
  InsertTable('Plot'),
  InsertColumn('cluster_name', Column.varchar, onTable: 'Plot'),
  InsertColumn('id', Column.varchar, onTable: 'Plot', unique: true),
  CreateIndex(columns: ['id'], onTable: 'Plot', unique: true)
];

const List<MigrationCommand> _migration_20250310201838_down = [DropTable('Plot'), DropColumn('cluster_name', onTable: 'Plot'), DropColumn('id', onTable: 'Plot'), DropIndex('index_Plot_on_id')];

//
// DO NOT EDIT BELOW THIS LINE
//

@Migratable(
  version: '20250310201838',
  up: _migration_20250310201838_up,
  down: _migration_20250310201838_down,
)
class Migration20250310201838 extends Migration {
  const Migration20250310201838()
      : super(
          version: 20250310201838,
          up: _migration_20250310201838_up,
          down: _migration_20250310201838_down,
        );
}
