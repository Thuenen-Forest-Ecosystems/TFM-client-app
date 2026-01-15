import 'package:flutter/foundation.dart';
import 'package:flutter_map/flutter_map.dart' show LatLngBounds, MapController;
import 'package:latlong2/latlong.dart';
import 'package:terrestrial_forest_monitor/repositories/records_repository.dart';

class MapControllerProvider with ChangeNotifier {
  // Flutter map controller
  MapController? _flutterMapController;

  // Distance line data for flutter_map
  LatLng? _distanceLineFrom;
  LatLng? _distanceLineTo;

  // Focused record for detailed view
  Record? _focusedRecord;

  // Focus bounds for flutter_map
  LatLngBounds? _focusBounds;
  DateTime? _focusTimestamp;
  DateTime? _lastManualMoveTimestamp;

  // Navigation request
  String? _navigationPath;
  DateTime? _navigationTimestamp;

  // Visible previous positions per record (recordId -> Set of position keys)
  final Map<String, Set<String>> _visiblePreviousPositions = {};

  // Selected navigation target position
  LatLng? _navigationTarget;
  String? _navigationTargetLabel;

  MapController? get flutterMapController => _flutterMapController;
  LatLng? get distanceLineFrom => _distanceLineFrom;
  LatLng? get distanceLineTo => _distanceLineTo;
  Record? get focusedRecord => _focusedRecord;
  LatLngBounds? get focusBounds => _focusBounds;
  DateTime? get focusTimestamp => _focusTimestamp;
  DateTime? get lastManualMoveTimestamp => _lastManualMoveTimestamp;
  String? get navigationPath => _navigationPath;
  DateTime? get navigationTimestamp => _navigationTimestamp;
  LatLng? get navigationTarget => _navigationTarget;
  String? get navigationTargetLabel => _navigationTargetLabel;

  void setFlutterMapController(MapController? controller) {
    _flutterMapController = controller;
    debugPrint('Flutter map controller registered');
    notifyListeners();
  }

  void setFocusBounds(LatLngBounds bounds) {
    _focusBounds = bounds;
    _focusTimestamp = DateTime.now();
    debugPrint(
      'Focus bounds set: SW(${bounds.south}, ${bounds.west}) NE(${bounds.north}, ${bounds.east})',
    );
    notifyListeners();
  }

  void clearFocusBounds() {
    _focusBounds = null;
    _focusTimestamp = null;
    notifyListeners();
  }

  void moveToLocation(LatLng location, {double zoom = 15.0, bool animate = true}) {
    if (_flutterMapController != null) {
      _lastManualMoveTimestamp = DateTime.now();

      if (animate) {
        // Smooth animated movement
        _flutterMapController!.moveAndRotate(location, zoom, 0.0);
      } else {
        // Instant jump
        _flutterMapController!.move(location, zoom);
      }

      debugPrint(
        'Map moved to: ${location.latitude}, ${location.longitude} at zoom $zoom (animated: $animate)',
      );
      notifyListeners();
    } else {
      debugPrint('Cannot move map: controller not initialized');
    }
  }

  void markManualInteraction() {
    _lastManualMoveTimestamp = DateTime.now();
    notifyListeners();
  }

  void showDistanceLine(LatLng from, LatLng to) {
    _distanceLineFrom = from;
    _distanceLineTo = to;
    notifyListeners();
  }

  void clearDistanceLine() {
    if (_distanceLineFrom != null || _distanceLineTo != null) {
      _distanceLineFrom = null;
      _distanceLineTo = null;
      debugPrint('Distance line cleared');
      notifyListeners();
    }
  }

  void setFocusedRecord(Record? record) {
    _focusedRecord = record;
    notifyListeners();
    debugPrint('Focused record set: ${record?.plotName ?? "none"}');
  }

  void clearFocusedRecord() {
    if (_focusedRecord != null) {
      _focusedRecord = null;
      debugPrint('Focused record cleared');
      notifyListeners();
    }
  }

  void requestNavigation(String path) {
    _navigationPath = path;
    _navigationTimestamp = DateTime.now();
    debugPrint('Navigation requested: $path');
    notifyListeners();
  }

  void clearNavigationRequest() {
    _navigationPath = null;
    _navigationTimestamp = null;
  }

  /// Set which previous positions should be visible for a record
  void setVisiblePreviousPositions(String recordId, Set<String> visibleKeys) {
    _visiblePreviousPositions[recordId] = Set.from(visibleKeys);
    debugPrint('Visible previous positions for $recordId: $visibleKeys');
    notifyListeners();
  }

  /// Get visible previous positions for a record (returns all if not set)
  Set<String>? getVisiblePreviousPositions(String recordId) {
    return _visiblePreviousPositions[recordId];
  }

  /// Check if a specific previous position is visible for a record
  bool isPreviousPositionVisible(String recordId, String positionKey) {
    final visible = _visiblePreviousPositions[recordId];
    // If not set, all are visible by default
    return visible == null || visible.contains(positionKey);
  }

  /// Set the navigation target position
  void setNavigationTarget(LatLng target, {String? label}) {
    _navigationTarget = target;
    _navigationTargetLabel = label;
    debugPrint(
      'Navigation target set: ${label ?? "unnamed"} at (${target.latitude}, ${target.longitude})',
    );
    notifyListeners();
  }

  /// Clear the navigation target
  void clearNavigationTarget() {
    if (_navigationTarget != null) {
      _navigationTarget = null;
      _navigationTargetLabel = null;
      debugPrint('Navigation target cleared');
      notifyListeners();
    }
  }

  @override
  void dispose() {
    clearDistanceLine();
    _flutterMapController = null;
    _visiblePreviousPositions.clear();
    super.dispose();
  }
}
