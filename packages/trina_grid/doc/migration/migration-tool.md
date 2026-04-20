# TrinaGrid Migration Tool

TrinaGrid includes a powerful migration tool that helps you automatically update your codebase when migrating from PlutoGrid.

## Quick Start

```bash
# Add trina_grid to your pubspec.yaml and run flutter pub get

# Run a dry run to see what changes would be made
flutter pub run trina_grid --migrate-from-pluto-grid --dry-run

# Apply the changes
flutter pub run trina_grid --migrate-from-pluto-grid
```

## Command Options

| Option | Description |
|--------|-------------|
| `--dry-run` | Show changes without applying them |
| `--dir`, `-d` | Specify the directory to migrate (defaults to current directory) |
| `--verbose`, `-v` | Show detailed output |
| `--scan-all` | Scan all directories, including build and platform-specific directories |
| `--help`, `-h` | Show help message |

## Examples

### Dry Run

```bash
flutter pub run trina_grid --migrate-from-pluto-grid --dry-run
```

This will scan your project and show what changes would be made without actually applying them.

### Migrate a Specific Directory

```bash
flutter pub run trina_grid --migrate-from-pluto-grid --dir=lib/screens
```

This will only scan and migrate files in the specified directory.

### Verbose Output

```bash
flutter pub run trina_grid --migrate-from-pluto-grid --verbose
```

This will show detailed information about each replacement made.

### Scan All Directories

```bash
flutter pub run trina_grid --migrate-from-pluto-grid --scan-all
```

By default, the migration tool skips certain directories like `build`, `.dart_tool`, and platform-specific directories. This option forces the tool to scan all directories.

## How It Works

The migration tool:

1. Scans your project for files with `.dart`, `.yaml`, and `.json` extensions
2. Searches for PlutoGrid references in these files
3. Replaces them with their TrinaGrid equivalents
4. Cleans up any redundant imports

## Troubleshooting

### Common Issues

- **No changes detected**: Make sure you're running the command from your project root directory.
- **Missing replacements**: Use the `--scan-all` flag to ensure all directories are scanned.
- **Build errors after migration**: Check that all PlutoGrid references have been replaced.

### Getting Help

If you encounter any issues with the migration tool:

- Check the [full migration guide](pluto-to-trina.md)
- Open an issue on the [TrinaGrid GitHub repository](https://github.com/doonfrs/trina_grid/issues)
- Reach out to the maintainer [Feras Abdulrahman](https://github.com/doonfrs) 