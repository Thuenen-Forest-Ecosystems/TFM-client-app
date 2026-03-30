# Migrating from PlutoGrid to TrinaGrid

This guide will help you migrate your existing PlutoGrid implementation to TrinaGrid. TrinaGrid is a maintained and enhanced version of PlutoGrid, offering improved performance, additional features, and ongoing support.

## Automatic Migration Tool

TrinaGrid includes a migration tool that automatically replaces PlutoGrid references with their TrinaGrid equivalents in your codebase. For a quick reference, see the [Migration Tool Guide](migration-tool.md).

### Using the Migration Tool

1. First, add TrinaGrid to your `pubspec.yaml`:

```yaml
dependencies:
  trina_grid: <latest_version>
```

2. Run `flutter pub get` to install the package.

3. Run the migration tool with a dry run to see what changes would be made:

```bash
flutter pub run trina_grid --migrate-from-pluto-grid --dry-run
```

4. Apply the changes:

```bash
flutter pub run trina_grid --migrate-from-pluto-grid
```

5. For more thorough scanning (including build and platform-specific directories):

```bash
flutter pub run trina_grid --migrate-from-pluto-grid --scan-all
```

### Migration Tool Options

- `--dry-run`: Show changes without applying them
- `--dir`, `-d`: Specify the directory to migrate (defaults to current directory)
- `--verbose`, `-v`: Show detailed output
- `--scan-all`: Scan all directories, including build and platform-specific directories
- `--help`, `-h`: Show help message

## What Gets Replaced

The migration tool automatically replaces:

- Package imports:
  - `import 'package:pluto_grid/pluto_grid.dart'` → `import 'package:trina_grid/trina_grid.dart'`
  - `import 'package:pluto_grid_plus/pluto_grid_plus.dart'` → `import 'package:trina_grid/trina_grid.dart'`

- Package references in pubspec.yaml:
  - `pluto_grid:` → `trina_grid:`
  - `pluto_grid_plus:` → `trina_grid:`

- Class names and components:
  - `PlutoGrid` → `TrinaGrid`
  - `PlutoColumn` → `TrinaColumn`
  - `PlutoRow` → `TrinaRow`
  - `PlutoCell` → `TrinaCell`
  - And many more (see complete list below)

## Complete Class Mapping

### Main Components

- `PlutoGrid` → `TrinaGrid`

### Column Related

- `PlutoColumn` → `TrinaColumn`
- `PlutoColumnGroup` → `TrinaColumnGroup`
- `PlutoColumnType` → `TrinaColumnType`
- `PlutoColumnSort` → `TrinaColumnSort`
- `PlutoColumnFreeze` → `TrinaColumnFreeze`
- `PlutoColumnTextAlign` → `TrinaColumnTextAlign`

### Row Related

- `PlutoRow` → `TrinaRow`
- `PlutoRowType` → `TrinaRowType`
- `PlutoRowColorContext` → `TrinaRowColorContext`

### Cell Related

- `PlutoCell` → `TrinaCell`
- `PlutoCellDisplayType` → `TrinaCellDisplayType`

### State Management

- `PlutoGridStateManager` → `TrinaGridStateManager`
- `PlutoNotifierEvent` → `TrinaNotifierEvent`
- `PlutoGridEventManager` → `TrinaGridEventManager`

### Selection

- `PlutoGridSelectingMode` → `TrinaGridSelectingMode`

### Other Components

- `PlutoGridConfiguration` → `TrinaGridConfiguration`
- `PlutoGridScrollbarConfig` → `TrinaGridScrollbarConfig`
- `PlutoGridStyleConfig` → `TrinaGridStyleConfig`
- `PlutoGridLocaleText` → `TrinaGridLocaleText`
- `PlutoGridKeyManager` → `TrinaGridKeyManager`
- `PlutoGridKeyPressed` → `TrinaGridKeyPressed`

### Enums and Constants

- `PlutoGridMode` → `TrinaGridMode`
- `PlutoGridScrollUpdateEvent` → `TrinaGridScrollUpdateEvent`
- `PlutoGridScrollAnimationEvent` → `TrinaGridScrollAnimationEvent`
- `PlutoMoveDirection` → `TrinaMoveDirection`

### Widgets

- `PlutoBaseCell` → `TrinaBaseCell`
- `PlutoBaseColumn` → `TrinaBaseColumn`
- `PlutoBaseRow` → `TrinaBaseRow`

### Additional Components

- `
