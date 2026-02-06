import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:flutter_map/flutter_map.dart' show LatLngBounds, MapController;
import 'package:latlong2/latlong.dart';
import 'package:terrestrial_forest_monitor/repositories/records_repository.dart';

class MapControllerProvider with ChangeNotifier {
  // Flutter map controller
  MapController? _flutterMapController;

  // Map tap stream for position selection
  final _mapTapController = StreamController<LatLng>.broadcast();
  Stream<LatLng> get mapTapStream => _mapTapController.stream;
  bool _isMapTapEnabled = false;

  // Distance line data for flutter_map
  LatLng? _distanceLineFrom;
  LatLng? _distanceLineTo;

  // Focused record for detailed view
  Record? _focusedRecord;

  // Focus bounds for flutter_map
  LatLngBounds? _focusBounds;
  DateTime? _focusTimestamp;
  DateTime? _lastManualMoveTimestamp;

  // Current map bounds (visible area)
  LatLngBounds? _currentMapBounds;
  DateTime? _mapBoundsTimestamp;

  // Sheet height for scroll coordination
  double _sheetHeight = 0.25;
  double get sheetHeight => _sheetHeight;
  bool _isSheetFullyExpanded = false;
  bool get isSheetFullyExpanded => _isSheetFullyExpanded;

  // Callback to manually drag the sheet from deep within the widget tree
  Function(double deltaPixels)? _onSheetDrag;

  void setSheetDragHandler(Function(double deltaPixels) handler) {
    _onSheetDrag = handler;
  }

  void dragSheet(double deltaPixels) {
    _onSheetDrag?.call(deltaPixels);
  }

  void setSheetHeight(double height) {
    if ((_sheetHeight - height).abs() > 0.01) {
      _sheetHeight = height;
      notifyListeners();
    }
  }

  void setSheetFullyExpanded(bool expanded) {
    if (_isSheetFullyExpanded != expanded) {
      _isSheetFullyExpanded = expanded;
      notifyListeners();
    }
  }

  // Navigation request
  String? _navigationPath;
  DateTime? _navigationTimestamp;

  // Visible previous positions per record (recordId -> Set of position keys)
  final Map<String, Set<String>> _visiblePreviousPositions = {};

  // Selected navigation target position
  LatLng? _navigationTarget;
  String? _navigationTargetLabel;

  // Selected navigation start position
  LatLng? _navigationStart;
  String? _navigationStartLabel;

  // Navigation line string for steps (points from start through all steps)
  List<LatLng>? _navigationStepsLineString;

  // Navigation line string for target (line from last step or start to target)
  List<LatLng>? _navigationTargetLineString;

  // Grid row selection request (arrayName -> identifier value)
  String? _selectedArrayName;
  dynamic _selectedRowIdentifier;
  DateTime? _selectionTimestamp;

  MapController? get flutterMapController => _flutterMapController;
  LatLng? get distanceLineFrom => _distanceLineFrom;
  LatLng? get distanceLineTo => _distanceLineTo;
  Record? get focusedRecord => _focusedRecord;
  LatLngBounds? get focusBounds => _focusBounds;
  DateTime? get focusTimestamp => _focusTimestamp;
  DateTime? get lastManualMoveTimestamp => _lastManualMoveTimestamp;
  String? get navigationPath => _navigationPath;
  DateTime? get navigationTimestamp => _navigationTimestamp;
  LatLngBounds? get currentMapBounds => _currentMapBounds;
  DateTime? get mapBoundsTimestamp => _mapBoundsTimestamp;
  LatLng? get navigationTarget => _navigationTarget;
  String? get navigationTargetLabel => _navigationTargetLabel;
  LatLng? get navigationStart => _navigationStart;
  String? get navigationStartLabel => _navigationStartLabel;
  List<LatLng>? get navigationStepsLineString => _navigationStepsLineString;
  List<LatLng>? get navigationTargetLineString => _navigationTargetLineString;
  String? get selectedArrayName => _selectedArrayName;
  dynamic get selectedRowIdentifier => _selectedRowIdentifier;
  DateTime? get selectionTimestamp => _selectionTimestamp;

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

  void setCurrentMapBounds(LatLngBounds bounds) {
    _currentMapBounds = bounds;
    _mapBoundsTimestamp = DateTime.now();
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
    notifyListeners();
  }

  /// Clear the navigation target
  void clearNavigationTarget() {
    if (_navigationTarget != null) {
      _navigationTarget = null;
      _navigationTargetLabel = null;
      notifyListeners();
    }
  }

  /// Set the navigation start position
  void setNavigationStart(LatLng start, {String? label}) {
    _navigationStart = start;
    _navigationStartLabel = label;
    notifyListeners();
  }

  /// Clear the navigation start position
  void clearNavigationStart() {
    if (_navigationStart != null) {
      _navigationStart = null;
      _navigationStartLabel = null;
      debugPrint('Navigation start cleared');
      notifyListeners();
    }
  }

  /// Set the navigation steps line string (points from start through all steps)
  void setNavigationStepsLineString(List<LatLng>? lineString) {
    _navigationStepsLineString = lineString != null ? List<LatLng>.from(lineString) : null;
    notifyListeners();
  }

  /// Set the navigation target line string (line from last step or start to target)
  void setNavigationTargetLineString(List<LatLng>? lineString) {
    _navigationTargetLineString = lineString != null ? List<LatLng>.from(lineString) : null;
    notifyListeners();
  }

  /// Clear both navigation line strings
  void clearNavigationLineStrings() {
    bool changed = false;
    if (_navigationStepsLineString != null) {
      _navigationStepsLineString = null;
      changed = true;
    }
    if (_navigationTargetLineString != null) {
      _navigationTargetLineString = null;
      changed = true;
    }
    if (changed) {
      debugPrint('Navigation line strings cleared');
      notifyListeners();
    }
  }

  @override
  void dispose() {
    clearDistanceLine();
    _flutterMapController = null;
    _visiblePreviousPositions.clear();
    _mapTapController.close();
    super.dispose();
  }

  /// Enable map tap mode for position selection
  void enableMapTapMode() {
    _isMapTapEnabled = true;
    debugPrint('Map tap mode enabled');
    notifyListeners();
  }

  /// Disable map tap mode
  void disableMapTapMode() {
    _isMapTapEnabled = false;
    debugPrint('Map tap mode disabled');
    notifyListeners();
  }

  /// Check if map tap mode is enabled
  bool get isMapTapEnabled => _isMapTapEnabled;

  /// Handle a map tap event (called from map widget)
  void onMapTapped(LatLng position) {
    if (_isMapTapEnabled) {
      debugPrint('Map tapped at: ${position.latitude}, ${position.longitude}');
      _mapTapController.add(position);
      // Automatically disable after one tap
      disableMapTapMode();
    }
  }

  /// Request to scroll and select a row in a grid
  void selectGridRow(String arrayName, dynamic identifier) {
    _selectedArrayName = arrayName;
    _selectedRowIdentifier = identifier;
    _selectionTimestamp = DateTime.now();
    debugPrint('Grid row selection requested: $arrayName[$identifier]');
    notifyListeners();
  }

  /// Clear grid row selection request
  void clearGridRowSelection() {
    if (_selectedArrayName != null || _selectedRowIdentifier != null) {
      _selectedArrayName = null;
      _selectedRowIdentifier = null;
      _selectionTimestamp = null;
      debugPrint('Grid row selection cleared');
    }
  }
}
