# Enable Actual Download Progress Percentage

Currently, the app shows an indeterminate progress indicator when downloading data. To show the actual download percentage (0-100%), you need to upgrade the PowerSync dependency.

## Steps to Enable Progress Percentage:

### 1. Update pubspec.yaml

Change the PowerSync version from `^1.12.2` to `^1.5.1` or higher (note: version 1.5.1 introduced `downloadProgress`, but check for the latest stable version):

```yaml
dependencies:
  powersync: ^1.5.1  # Or use the latest version
```

### 2. Update the code in schema-selection.dart

Replace the `_calculateDownloadProgress` method with:

```dart
double _calculateDownloadProgress(SyncStatus status) {
  if (!status.downloading) {
    return 0.0;
  }

  final downloadProgress = status.downloadProgress;
  
  if (downloadProgress == null) {
    return 0.0;
  }

  // downloadedFraction returns a value from 0.0 to 1.0
  // Convert to percentage (0-100)
  final progress = downloadProgress.downloadedFraction * 100;
  return progress.clamp(0.0, 100.0);
}
```

### 3. Run flutter pub get

```bash
flutter pub get
```

### 4. Test

The circular progress indicator will now show the actual download percentage when syncing data.

## API Documentation

- [SyncDownloadProgress API](https://pub.dev/documentation/powersync/latest/powersync/SyncDownloadProgress-extension-type.html)
- [Usage Example](https://docs.powersync.com/client-sdk-references/flutter/usage-examples#report-sync-download-progress)

## Alternative: Show Operation Counts

If you prefer to show "X out of Y operations", use:

```dart
Text('${progress.downloadedOperations} out of ${progress.totalOperations}')
```
