import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:terrestrial_forest_monitor/services/powersync.dart';
import 'package:wakelock_plus/wakelock_plus.dart';

/// Manages app lifecycle to ensure PowerSync continues syncing
/// even when app is backgrounded or device is sleeping
class AppLifecycleManager extends WidgetsBindingObserver {
  bool _isSyncInProgress = false;
  bool _keepSyncActive = false;

  /// True when running on a desktop OS (Windows / macOS / Linux).
  /// Desktop OSes manage their own power policy; wake locks are unnecessary
  /// and prevent the system from sleeping during idle sync activity.
  static bool get _isDesktop =>
      !kIsWeb && (Platform.isWindows || Platform.isMacOS || Platform.isLinux);

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

  }

  /// Enable wake lock to keep device awake during sync.
  /// Skipped on desktop (Windows/macOS/Linux) — the OS manages power policy
  /// itself and a perpetual wake lock would prevent sleep during idle sync.
  Future<void> _enableWakeLock() async {
    if (!_keepSyncActive) {
      _keepSyncActive = true;
      if (!_isDesktop) {
        try {
          await WakelockPlus.enable();
        } catch (e) {
        }
      }
    }
  }

  /// Disable wake lock after sync completes.
  Future<void> _disableWakeLock() async {
    if (_keepSyncActive) {
      _keepSyncActive = false;
      if (!_isDesktop) {
        try {
          await WakelockPlus.disable();
        } catch (e) {
        }
      }
    }
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {

    switch (state) {
      case AppLifecycleState.resumed:
        // App came back to foreground
        // PowerSync automatically reconnects if needed
        break;

      case AppLifecycleState.inactive:
        // App is transitioning (e.g., incoming call, switching apps)
        // Keep PowerSync connected during transitions
        break;

      case AppLifecycleState.paused:
        // App is in background
        // PowerSync connection stays alive
        // On Android: sync continues as long as device is awake
        // On iOS: sync continues for a limited time, then system decides
        break;

      case AppLifecycleState.detached:
        // App is about to be terminated
        _disableWakeLock();
        break;

      case AppLifecycleState.hidden:
        // App is hidden (iOS only)
        break;
    }
  }

  /// Cleanup when disposing
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _disableWakeLock();
  }
}

/// Global instance of the lifecycle manager
final appLifecycleManager = AppLifecycleManager();
