# Background Sync Implementation

This document describes how the TFM app continues syncing data even when the app is in the background, device is sleeping, or another app is in focus.

## Overview

The app uses PowerSync for offline-first data synchronization. With the background sync implementation, PowerSync continues to sync data even when:

- The app is minimized or in the background
- The device screen is off/sleeping
- Another app is in the foreground
- The app is not actively being used

**Important:** The app must remain open (not force-closed) for background sync to work.

## How It Works

### 1. App Lifecycle Management

`lib/services/app_lifecycle_manager.dart` monitors the app's lifecycle and ensures PowerSync stays active:

- **App Resumed**: Normal operation, sync continues
- **App Inactive**: During transitions (e.g., incoming call), sync continues
- **App Paused**: When backgrounded, sync continues
- **App Detached**: When closing, cleanup is performed

### 2. Wake Lock

When a sync is in progress (especially long ones like initial sync), the app acquires a wake lock to prevent the device from sleeping and interrupting the sync:

```dart
// Wake lock is automatically enabled when sync starts
// and disabled when sync completes
```

### 3. Platform-Specific Configuration

#### Android

The following permissions and configurations are set in `android/app/src/main/AndroidManifest.xml`:

```xml
<!-- Keep device awake during sync -->
<uses-permission android:name="android.permission.WAKE_LOCK" />

<!-- Prevent battery optimization from killing sync -->
<uses-permission android:name="android.permission.REQUEST_IGNORE_BATTERY_OPTIMIZATIONS" />

<!-- Allow network in background -->
<uses-permission android:name="android.permission.FOREGROUND_SERVICE" />
<uses-permission android:name="android.permission.ACCESS_BACKGROUND_LOCATION" />
```

**Android Behavior:**

- Sync continues indefinitely while app is in background
- Wake lock keeps device awake during active sync
- Battery optimization may need to be disabled by user for best results

#### iOS

Background modes are configured in `ios/Runner/Info.plist`:

```xml
<key>UIBackgroundModes</key>
<array>
    <string>fetch</string>
    <string>processing</string>
    <string>remote-notification</string>
</array>
```

**iOS Behavior:**

- iOS is more restrictive about background activity
- Sync continues for a limited time when backgrounded
- iOS may suspend the app after ~30 seconds in background
- When app returns to foreground, sync automatically resumes

## Usage

### For Users

1. **Initial Sync**: Start the app and log in. The initial sync may take up to 1 hour.
2. **Background Operation**: You can minimize the app or lock your device - sync will continue.
3. **Battery Optimization**: On Android, you may need to disable battery optimization for the app:
   - Go to Settings > Apps > TFM > Battery > Unrestricted

### For Developers

#### Initialization

The background sync is automatically initialized in `main.dart`:

```dart
// Initialize app lifecycle manager
await appLifecycleManager.initialize();
```

#### Monitoring Sync Status

Use the sync status button to see real-time sync progress:

```dart
// In your widget
const SyncStatusButton()
```

#### Testing Background Sync

1. **Start Long Sync**: Trigger initial sync or large data sync
2. **Background App**: Press home button (don't force close)
3. **Monitor**: Check sync continues by viewing logs:
   ```bash
   flutter logs | grep "AppLifecycleManager\|PowerSync"
   ```
4. **Verify**: Return to app after several minutes - sync should have progressed

## Technical Details

### PowerSync Connection

PowerSync maintains a WebSocket connection to the server. The connection:

- Stays alive during background mode
- Automatically reconnects if network changes
- Handles authentication token refresh
- Queues local changes for upload

### Wake Lock Strategy

Wake lock is used conservatively:

- **Enabled**: When sync is actively downloading/uploading
- **Disabled**: When sync is idle or completed
- **Battery Impact**: Minimal - only active during sync operations

### Network Requirements

- Requires active internet connection
- Works on WiFi and mobile data
- Handles network switching (WiFi ↔ mobile)
- Supports offline mode - queues changes for later sync

## Troubleshooting

### Sync Stops When App Backgrounded (Android)

1. Check battery optimization settings
2. Ensure app has background data permission
3. Check if power saving mode is enabled
4. Verify network connectivity

### Sync Stops When App Backgrounded (iOS)

This is expected behavior on iOS. Solutions:

1. Keep app in foreground during long syncs
2. Return to app periodically to resume sync
3. iOS Background Refresh must be enabled in settings

### High Battery Usage

1. Check if sync is stuck in a loop
2. Verify sync actually completes
3. Ensure wake lock is being released (check logs)
4. Consider syncing only on WiFi + charging

## Performance Considerations

### Battery Life

- Wake lock only active during sync
- Minimal impact when sync is idle
- Consider disabling background sync for very large datasets

### Data Usage

- Full sync can use significant data
- Consider WiFi-only sync for large datasets
- Incremental syncs use minimal data

### Storage

- Local SQLite database stores all synced data
- Monitor database size for large datasets
- Implement data cleanup strategies if needed

## Future Improvements

Potential enhancements:

1. WiFi-only sync option
2. Charging-only sync option
3. Configurable sync intervals
4. Sync priority for critical data
5. Background sync progress notifications

## Related Files

- `lib/services/app_lifecycle_manager.dart` - Lifecycle management
- `lib/services/powersync.dart` - PowerSync configuration
- `lib/services/background_sync_service.dart` - WorkManager tasks
- `lib/widgets/sync-status-button.dart` - UI sync status
- `android/app/src/main/AndroidManifest.xml` - Android config
- `ios/Runner/Info.plist` - iOS config

## Dependencies

- `wakelock_plus` - Keep device awake during sync
- `workmanager` - Background task scheduling
- `connectivity_plus` - Network status monitoring
- `powersync` - Offline-first database sync
