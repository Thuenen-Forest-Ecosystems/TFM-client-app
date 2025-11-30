import 'package:flutter/foundation.dart';
import 'package:powersync/powersync.dart';
//import 'package:sqflite/sqlite_api.dart';
import 'package:terrestrial_forest_monitor/services/powersync.dart';
import 'dart:async';

class DatabaseProvider extends ChangeNotifier {
  StreamSubscription? _statusSubscription;
  SyncStatus? _syncStatus;

  SyncStatus? get syncStatus => _syncStatus;
  bool get isConnected => _syncStatus?.connected ?? false;

  DatabaseProvider() {
    _initializeStatusListener();
  }

  void _initializeStatusListener() {
    // db.currentStatus is a SyncStatus snapshot (not a Stream), so assign it directly.
    _syncStatus = db.currentStatus;
    notifyListeners();
    _statusSubscription = null;
  }

  // Query methods that return streams for reactive UI updates
  Stream<List<Map<String, dynamic>>> watchQuery(String sql, [List<Object?>? parameters]) {
    return db.watch(sql, parameters: parameters ?? []);
  }

  // One-time query
  Future<List<Map<String, dynamic>>> getAll(String sql, [List<Object?>? parameters]) {
    return db.getAll(sql, parameters ?? []);
  }

  // Insert/Update/Delete
  Future<void> execute(String sql, [List<Object?>? parameters]) async {
    await db.execute(sql);
    notifyListeners();
  }

  // Batch operations
  /*Future<void> writeTransaction(Future<void> Function(Transaction tx) callback) async {
    await db.writeTransaction(callback);
    notifyListeners();
  }*/

  @override
  void dispose() {
    _statusSubscription?.cancel();
    super.dispose();
  }
}
