import 'package:workmanager/workmanager.dart';
import 'package:terrestrial_forest_monitor/services/powersync.dart';
import 'package:flutter/foundation.dart';

class BackgroundSyncService {
  static const String syncTaskName = "powersync-background-sync";
  static const String syncTaskTag = "powersync-sync";

  /// Initialize background sync
  /// Call this in main() before runApp()
  static Future<void> initialize() async {
    await Workmanager().initialize(callbackDispatcher, isInDebugMode: kDebugMode);
  }

  /// Register periodic background sync
  /// Frequency: Every 1 hour
  static Future<void> registerPeriodicSync() async {
    await Workmanager().registerPeriodicTask(
      syncTaskName,
      syncTaskTag,
      frequency: const Duration(hours: 1),
      constraints: Constraints(
        networkType: NetworkType.connected, // Only sync when connected
        requiresBatteryNotLow: true, // Don't drain battery
      ),
    );

    debugPrint('BackgroundSyncService: Registered periodic sync every 1 hour');
  }

  /// Register one-time background sync
  static Future<void> registerOneTimeSync({Duration delay = Duration.zero}) async {
    await Workmanager().registerOneOffTask(
      "$syncTaskName-onetime",
      syncTaskTag,
      initialDelay: delay,
      constraints: Constraints(networkType: NetworkType.connected),
    );

    debugPrint('BackgroundSyncService: Registered one-time sync with ${delay.inSeconds}s delay');
  }

  /// Cancel all background sync tasks
  static Future<void> cancelAll() async {
    await Workmanager().cancelAll();
    debugPrint('BackgroundSyncService: Cancelled all background sync tasks');
  }

  /// Cancel periodic sync only
  static Future<void> cancelPeriodicSync() async {
    await Workmanager().cancelByUniqueName(syncTaskName);
    debugPrint('BackgroundSyncService: Cancelled periodic sync');
  }
}

/// Background task callback
/// This runs in a separate isolate
@pragma('vm:entry-point')
void callbackDispatcher() {
  Workmanager().executeTask((task, inputData) async {
    debugPrint('BackgroundSyncService: Starting background sync task: $task');

    try {
      // Initialize PowerSync database
      final db = await openDatabase();

      // Check if already connected
      var status = db.currentStatus;
      debugPrint(
        'BackgroundSyncService: Initial status - connected: ${status.connected}, hasSynced: ${status.hasSynced}, lastSyncedAt: ${status.lastSyncedAt}',
      );

      // Skip background sync if never synced before (initial sync should be done in foreground)
      if (status.lastSyncedAt == null) {
        debugPrint(
          'BackgroundSyncService: Skipping - no previous sync detected. Initial sync must be completed in foreground.',
        );
        return Future.value(true);
      }

      // If not connected, try to connect PowerSync
      if (!status.connected) {
        debugPrint('BackgroundSyncService: Attempting to connect PowerSync...');

        // Create connector and connect
        final connector = SupabaseConnector();
        await db.connect(connector: connector);

        debugPrint('BackgroundSyncService: Connection initiated, waiting for sync...');

        // Wait for sync to complete (with timeout)
        final syncCompleted = await _waitForSync(db, timeout: const Duration(seconds: 45));

        if (syncCompleted) {
          debugPrint('BackgroundSyncService: Sync completed successfully');
        } else {
          debugPrint('BackgroundSyncService: Sync timeout - may still be in progress');
        }

        // Disconnect after sync
        await db.disconnect();
        debugPrint('BackgroundSyncService: Disconnected PowerSync');
      } else {
        debugPrint('BackgroundSyncService: Already connected, waiting for sync activity...');
        await Future.delayed(const Duration(seconds: 10));
      }

      status = db.currentStatus;
      debugPrint(
        'BackgroundSyncService: Final status - connected: ${status.connected}, hasSynced: ${status.hasSynced}, lastSynced: ${status.lastSyncedAt}',
      );

      return Future.value(true);
    } catch (e, stackTrace) {
      debugPrint('BackgroundSyncService: Error during background sync: $e');
      debugPrint('Stack trace: $stackTrace');
      return Future.value(false);
    }
  });
}

/// Wait for PowerSync to complete sync
/// Returns true if sync completed, false if timeout
Future<bool> _waitForSync(dynamic db, {required Duration timeout}) async {
  final startTime = DateTime.now();
  var lastStatus = db.currentStatus;

  debugPrint('BackgroundSyncService: Waiting for sync (timeout: ${timeout.inSeconds}s)...');

  while (DateTime.now().difference(startTime) < timeout) {
    final status = db.currentStatus;

    // Check if we're syncing
    if (status.downloading || status.uploading) {
      debugPrint(
        'BackgroundSyncService: Syncing... (down: ${status.downloading}, up: ${status.uploading})',
      );
      lastStatus = status;
    }
    // Check if sync just completed
    else if ((lastStatus.downloading || lastStatus.uploading) &&
        !status.downloading &&
        !status.uploading) {
      debugPrint('BackgroundSyncService: Sync activity completed');
      // Wait a bit more to ensure all operations finish
      await Future.delayed(const Duration(seconds: 2));
      return true;
    }
    // Check if we've synced at least once
    else if (status.hasSynced && status.lastSyncedAt != null) {
      final timeSinceLastSync = DateTime.now().difference(status.lastSyncedAt!);
      if (timeSinceLastSync.inSeconds < 60) {
        debugPrint(
          'BackgroundSyncService: Recent sync detected (${timeSinceLastSync.inSeconds}s ago)',
        );
        return true;
      }
    }

    await Future.delayed(const Duration(seconds: 2));
  }

  debugPrint('BackgroundSyncService: Sync wait timeout reached');
  return false;
}
