import 'package:flutter/material.dart';
import 'package:terrestrial_forest_monitor/services/powersync.dart';
import 'package:wakelock_plus/wakelock_plus.dart';

/// Manages app lifecycle to ensure PowerSync continues syncing
/// even when app is backgrounded or device is sleeping
class AppLifecycleManager extends WidgetsBindingObserver {
  bool _isSyncInProgress = false;
  bool _keepSyncActive = false;

  /// Initialize the lifecycle manager
  /// Call this in main() after initializing PowerSync
  Future<void> initialize() async {
    WidgetsBinding.instance.addObserver(this);

    // Listen to PowerSync status to detect long-running syncs
    db.statusStream.listen((status) {
      final wasSyncing = _isSyncInProgress;
      _isSyncInProgress = status.downloading || status.uploading;

      // If sync just started and will take a while, enable wake lock
      if (!wasSyncing && _isSyncInProgress) {
        _enableWakeLock();
      }
      // If sync completed, disable wake lock
      else if (wasSyncing && !_isSyncInProgress) {
        _disableWakeLock();
      }
    });

    debugPrint('AppLifecycleManager: Initialized');
  }

  /// Enable wake lock to keep device awake during sync
  Future<void> _enableWakeLock() async {
    if (!_keepSyncActive) {
      _keepSyncActive = true;
      try {
        await WakelockPlus.enable();
        debugPrint('AppLifecycleManager: Wake lock enabled');
      } catch (e) {
        debugPrint('AppLifecycleManager: Failed to enable wake lock: $e');
      }
    }
  }

  /// Disable wake lock after sync completes
  Future<void> _disableWakeLock() async {
    if (_keepSyncActive) {
      _keepSyncActive = false;
      try {
        await WakelockPlus.disable();
        debugPrint('AppLifecycleManager: Wake lock disabled');
      } catch (e) {
        debugPrint('AppLifecycleManager: Failed to disable wake lock: $e');
      }
    }
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    debugPrint('AppLifecycleManager: App state changed to $state');

    switch (state) {
      case AppLifecycleState.resumed:
        // App came back to foreground
        debugPrint('AppLifecycleManager: App resumed - PowerSync will continue syncing');
        // PowerSync automatically reconnects if needed
        break;

      case AppLifecycleState.inactive:
        // App is transitioning (e.g., incoming call, switching apps)
        debugPrint('AppLifecycleManager: App inactive - maintaining PowerSync connection');
        // Keep PowerSync connected during transitions
        break;

      case AppLifecycleState.paused:
        // App is in background
        debugPrint(
          'AppLifecycleManager: App paused - PowerSync will continue syncing in background',
        );
        // PowerSync connection stays alive
        // On Android: sync continues as long as device is awake
        // On iOS: sync continues for a limited time, then system decides
        break;

      case AppLifecycleState.detached:
        // App is about to be terminated
        debugPrint('AppLifecycleManager: App detached - cleaning up');
        _disableWakeLock();
        break;

      case AppLifecycleState.hidden:
        // App is hidden (iOS only)
        debugPrint('AppLifecycleManager: App hidden - maintaining PowerSync connection');
        break;
    }
  }

  /// Cleanup when disposing
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _disableWakeLock();
    debugPrint('AppLifecycleManager: Disposed');
  }
}

/// Global instance of the lifecycle manager
final appLifecycleManager = AppLifecycleManager();
