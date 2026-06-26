import 'dart:async';
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:terrestrial_forest_monitor/services/powersync.dart';
import 'package:terrestrial_forest_monitor/services/validation_service_native.dart';
import 'package:wakelock_plus/wakelock_plus.dart';

/// Manages app lifecycle around PowerSync.
///
/// Mobile (Android/iOS): keeps the sync connection alive while backgrounded so
/// the OS-managed background window can finish in-progress syncs.
///
/// Desktop (Windows/macOS/Linux): when the window stays hidden/minimised the
/// live sync websocket and its periodic CRUD upload are pure idle drain, so we
/// drop the connection after a short grace period and transparently reconnect
/// on resume. Local writes keep queuing in the CRUD log meanwhile.
class AppLifecycleManager extends WidgetsBindingObserver {
  bool _isSyncInProgress = false;
  bool _keepSyncActive = false;

  /// Desktop-only: pending "drop the sync socket" timer and whether we actually
  /// disconnected, so resume only reconnects when we were the one who cut it.
  Timer? _backgroundDisconnectTimer;
  bool _didBackgroundDisconnect = false;

  /// Grace period before a hidden desktop window drops its sync connection.
  /// Long enough that briefly minimising/restoring doesn't thrash the socket.
  static const Duration _backgroundDisconnectDelay = Duration(seconds: 30);

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
        } catch (e) {}
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
        } catch (e) {}
      }
    }
  }

  /// Desktop only: after the window has been hidden for [_backgroundDisconnectDelay],
  /// drop the PowerSync connection so the idle websocket + CRUD-upload polling
  /// stop draining the battery. No-op on mobile (OS handles background power).
  void _scheduleBackgroundDisconnect() {
    if (!_isDesktop) return;
    _backgroundDisconnectTimer?.cancel();
    _backgroundDisconnectTimer = Timer(_backgroundDisconnectDelay, () async {
      if (!isLoggedIn()) return;
      try {
        await db.disconnect();
        _didBackgroundDisconnect = true;
      } catch (_) {
        // Disconnect is best-effort; a failure just leaves us connected.
      }
    });
  }

  /// Resume path: cancel any pending disconnect and, if we did cut the
  /// connection while hidden, reconnect with a fresh connector (its
  /// fetchCredentials reads the current Supabase session).
  Future<void> _reconnectAfterBackground() async {
    _backgroundDisconnectTimer?.cancel();
    _backgroundDisconnectTimer = null;
    if (!_didBackgroundDisconnect) return;
    _didBackgroundDisconnect = false;
    if (!isLoggedIn()) return;
    try {
      db.connect(connector: SupabaseConnector());
    } catch (_) {
      // If reconnect fails, the next auth/connectivity event will retry.
    }
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    switch (state) {
      case AppLifecycleState.resumed:
        // App came back to foreground. Reconnect PowerSync if we dropped it
        // while the desktop window was hidden.
        _reconnectAfterBackground();
        break;

      case AppLifecycleState.inactive:
        // App is transitioning (e.g., incoming call, switching apps)
        // Keep PowerSync connected during transitions
        break;

      case AppLifecycleState.paused:
        // App is in background.
        // On Android: sync continues as long as device is awake.
        // On iOS: sync continues for a limited time, then system decides.
        // Drop the in-process JS plausibility runtime; next validate()
        // transparently re-initializes from the remembered script.
        ValidationServiceNative.instance.handleAppPaused();
        // Desktop: schedule dropping the idle sync connection (see method).
        _scheduleBackgroundDisconnect();
        break;

      case AppLifecycleState.detached:
        // App is about to be terminated.
        _backgroundDisconnectTimer?.cancel();
        _disableWakeLock();
        break;

      case AppLifecycleState.hidden:
        // App is hidden (e.g. window minimized on desktop, app hidden on iOS).
        // Free the JS plausibility runtime; re-initialized lazily on next use.
        ValidationServiceNative.instance.handleAppPaused();
        // Desktop: schedule dropping the idle sync connection (see method).
        _scheduleBackgroundDisconnect();
        break;
    }
  }

  /// Cleanup when disposing
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _backgroundDisconnectTimer?.cancel();
    _disableWakeLock();
  }
}

/// Global instance of the lifecycle manager
final appLifecycleManager = AppLifecycleManager();
