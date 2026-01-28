import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:terrestrial_forest_monitor/widgets/cluster/order-cluster-by.dart';
import 'package:geolocator/geolocator.dart';
import 'package:terrestrial_forest_monitor/services/organization_selection_service.dart';

class RecordsListProvider extends ChangeNotifier {
  // Cache for records list
  final Map<String, List<Map<String, dynamic>>> _recordsCache = {};
  final Map<String, int> _currentPageCache = {};
  final Map<String, bool> _hasMoreDataCache = {};

  Position? _currentPosition;
  String? _currentPermissionId;

  RecordsListProvider() {
    _initializePermissionListener();
  }

  void _initializePermissionListener() {
    // Register listener for permission changes
    OrganizationSelectionService().addPermissionChangeListener(_onPermissionChanged);

    // Load current permission ID
    OrganizationSelectionService().getSelectedPermissionId().then((permissionId) {
      _currentPermissionId = permissionId;
      debugPrint('RecordsListProvider: Permission ID loaded: $permissionId');
    });
  }

  void _onPermissionChanged(String newPermissionId) {
    print('RecordsListProvider: Permission changed to $newPermissionId, clearing cache');

    // Only clear if permission actually changed
    if (_currentPermissionId != newPermissionId) {
      _currentPermissionId = newPermissionId;
      clearAllCache();
      print('RecordsListProvider: Cache cleared due to permission change');
    }
  }

  @override
  void dispose() {
    OrganizationSelectionService().removePermissionChangeListener(_onPermissionChanged);
    super.dispose();
  }

  // Get cached data for an interval and order
  List<Map<String, dynamic>>? getCachedRecords(String intervalName, ClusterOrderBy orderBy) {
    final key = _getCacheKey(intervalName, orderBy);
    debugPrint(
      'RecordsListProvider: getCachedRecords with key: $key (found: ${_recordsCache[key]?.length ?? 0} items)',
    );
    return _recordsCache[key];
  }

  int getCachedPage(String intervalName, ClusterOrderBy orderBy) {
    final key = _getCacheKey(intervalName, orderBy);
    return _currentPageCache[key] ?? 0;
  }

  bool getHasMoreData(String intervalName, ClusterOrderBy orderBy) {
    final key = _getCacheKey(intervalName, orderBy);
    return _hasMoreDataCache[key] ?? true;
  }

  Position? get currentPosition => _currentPosition;

  bool get isPermissionIdLoaded => _currentPermissionId != null;

  void setCurrentPosition(Position? position) {
    _currentPosition = position;
    notifyListeners();
  }

  // Cache records for an interval and order
  void cacheRecords(
    String intervalName,
    ClusterOrderBy orderBy,
    List<Map<String, dynamic>> records,
    int page,
    bool hasMore,
  ) {
    final key = _getCacheKey(intervalName, orderBy);
    debugPrint(
      'RecordsListProvider: cacheRecords with key: $key (storing ${records.length} items)',
    );

    // Only notify listeners if the data actually changed
    final existing = _recordsCache[key];
    final hasChanged =
        existing == null ||
        existing.length != records.length ||
        _currentPageCache[key] != page ||
        _hasMoreDataCache[key] != hasMore;

    _recordsCache[key] = records;
    _currentPageCache[key] = page;
    _hasMoreDataCache[key] = hasMore;

    if (hasChanged) {
      notifyListeners();
    }
  }

  // Append more records to cache
  void appendRecords(
    String intervalName,
    ClusterOrderBy orderBy,
    List<Map<String, dynamic>> newRecords,
    int page,
    bool hasMore,
  ) {
    final key = _getCacheKey(intervalName, orderBy);
    final existing = _recordsCache[key] ?? [];
    _recordsCache[key] = [...existing, ...newRecords];
    _currentPageCache[key] = page;
    _hasMoreDataCache[key] = hasMore;
    notifyListeners();
  }

  // Clear cache for a specific interval/order combination
  void clearCache(String intervalName, ClusterOrderBy orderBy) {
    final key = _getCacheKey(intervalName, orderBy);
    _recordsCache.remove(key);
    _currentPageCache.remove(key);
    _hasMoreDataCache.remove(key);
    notifyListeners();
  }

  // Clear all cache
  void clearAllCache() {
    _recordsCache.clear();
    _currentPageCache.clear();
    _hasMoreDataCache.clear();
    notifyListeners();
  }

  String _getCacheKey(String intervalName, ClusterOrderBy orderBy) {
    // Include permission ID in cache key to isolate cache per permission
    final permissionPart = _currentPermissionId ?? 'no-permission';
    return '$permissionPart-$intervalName-${orderBy.name}';
  }

  // Check if we should invalidate cache (e.g., after sync)
  bool shouldInvalidateCache(String intervalName, ClusterOrderBy orderBy) {
    // Can add logic here to check if data has changed
    // For now, cache is valid unless manually cleared
    return false;
  }
}
