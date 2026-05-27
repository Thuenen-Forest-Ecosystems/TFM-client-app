import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:terrestrial_forest_monitor/services/powersync.dart';

// Import workmanager with web stub fallback
import 'package:workmanager/workmanager.dart'
    if (dart.library.html) 'background_sync_service_stub.dart';

class BackgroundSyncService {
  static const String syncTaskName = "powersync-background-sync";
  static const String syncTaskTag = "powersync-sync";

  /// Initialize background sync
  /// Call this in main() before runApp()
  static Future<void> initialize() async {
    // Skip workmanager initialization on web and desktop platforms (macOS, Windows, Linux)
    if (kIsWeb || Platform.isMacOS || Platform.isWindows || Platform.isLinux) {
      return;
    }

    // Initialize workmanager for mobile platforms (Android and iOS)
    await Workmanager().initialize(callbackDispatcher, isInDebugMode: kDebugMode);
  }

  /// Register periodic background sync
  /// Frequency: Every 1 hour
  static Future<void> registerPeriodicSync() async {
    if (kIsWeb || Platform.isMacOS || Platform.isWindows || Platform.isLinux) {
      return;
    }

    // Register periodic task for mobile platforms (Android and iOS)
    await Workmanager().registerPeriodicTask(
      syncTaskName,
      syncTaskTag,
      frequency: const Duration(hours: 1),
      constraints: Constraints(
        networkType: NetworkType.connected, // Only sync when connected
        requiresBatteryNotLow: true, // Don't drain battery
      ),
    );

  }

  /// Register one-time background sync
  static Future<void> registerOneTimeSync({Duration delay = Duration.zero}) async {
    if (kIsWeb || Platform.isMacOS || Platform.isWindows || Platform.isLinux) {
      return;
    }

    // Register one-time task for mobile platforms (Android and iOS)
    await Workmanager().registerOneOffTask(
      "$syncTaskName-onetime",
      syncTaskTag,
      initialDelay: delay,
      constraints: Constraints(networkType: NetworkType.connected),
    );

  }

  /// Cancel all background sync tasks
  static Future<void> cancelAll() async {
    if (kIsWeb || Platform.isMacOS || Platform.isWindows || Platform.isLinux) {
      return;
    }

    // Cancel tasks for mobile platforms (Android and iOS)
    await Workmanager().cancelAll();
  }

  /// Cancel periodic sync only
  static Future<void> cancelPeriodicSync() async {
    if (kIsWeb || Platform.isMacOS || Platform.isWindows || Platform.isLinux) {
      return;
    }

    // Cancel periodic sync for mobile platforms (Android and iOS)
    await Workmanager().cancelByUniqueName(syncTaskName);
  }
}

/// Background task callback
/// This runs in a separate isolate
@pragma('vm:entry-point')
void callbackDispatcher() {
  // Only execute on mobile platforms (Android and iOS) - workmanager is not supported on desktop/web
  if (!kIsWeb && !Platform.isMacOS && !Platform.isWindows && !Platform.isLinux) {
    Workmanager().executeTask((task, inputData) async {

      try {
        // Initialize PowerSync database
        final db = await openDatabase();

        // Check if already connected (foreground app may still be running)
        var status = db.currentStatus;

        // Skip background sync if never synced before (initial sync should be done in foreground)
        if (status.lastSyncedAt == null) {
          return Future.value(true);
        }

        // Skip if a recent sync occurred (foreground is likely handling it)
        final timeSinceLastSync = DateTime.now().difference(status.lastSyncedAt!);
        if (timeSinceLastSync.inMinutes < 5) {
          return Future.value(true);
        }

        // If already connected, the foreground is still running — don't interfere
        if (status.connected) {
          return Future.value(true);
        }

        // Not connected and no recent sync — app is likely backgrounded, do a sync

        // Guard: only sync when the user has an active Supabase session.
        // Without this, SupabaseConnector.fetchCredentials() returns null
        // (session == null) and PowerSync reports "Not logged in".
        if (!isLoggedIn()) {
          return Future.value(true);
        }

        final connector = SupabaseConnector();
        await db.connect(connector: connector);


        // Wait for sync to complete (with timeout)
        final syncCompleted = await _waitForSync(db, timeout: const Duration(seconds: 45));

        if (syncCompleted) {
        } else {
        }

        // Disconnect after sync
        await db.disconnect();

        status = db.currentStatus;

        return Future.value(true);
      } catch (e, stackTrace) {
        return Future.value(false);
      }
    });
  }
}

/// Wait for PowerSync to complete sync
/// Returns true if sync completed, false if timeout
Future<bool> _waitForSync(dynamic db, {required Duration timeout}) async {
  final startTime = DateTime.now();
  var lastStatus = db.currentStatus;


  while (DateTime.now().difference(startTime) < timeout) {
    final status = db.currentStatus;

    // Check if we're syncing
    if (status.downloading || status.uploading) {
      lastStatus = status;
    }
    // Check if sync just completed
    else if ((lastStatus.downloading || lastStatus.uploading) &&
        !status.downloading &&
        !status.uploading) {
      // Wait a bit more to ensure all operations finish
      await Future.delayed(const Duration(seconds: 2));
      return true;
    }
    // Check if we've synced at least once
    else if (status.hasSynced && status.lastSyncedAt != null) {
      final timeSinceLastSync = DateTime.now().difference(status.lastSyncedAt!);
      if (timeSinceLastSync.inSeconds < 60) {
        return true;
      }
    }

    await Future.delayed(const Duration(seconds: 2));
  }

  return false;
}
