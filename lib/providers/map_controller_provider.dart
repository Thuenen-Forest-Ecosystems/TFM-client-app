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

  MapController? get flutterMapController => _flutterMapController;
  LatLng? get distanceLineFrom => _distanceLineFrom;
  LatLng? get distanceLineTo => _distanceLineTo;
  Record? get focusedRecord => _focusedRecord;
  LatLngBounds? get focusBounds => _focusBounds;
  DateTime? get focusTimestamp => _focusTimestamp;
  DateTime? get lastManualMoveTimestamp => _lastManualMoveTimestamp;

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

  void moveToLocation(LatLng location, {double zoom = 15.0}) {
    if (_flutterMapController != null) {
      _lastManualMoveTimestamp = DateTime.now();
      _flutterMapController!.move(location, zoom);
      debugPrint('Map moved to: ${location.latitude}, ${location.longitude} at zoom $zoom');
      notifyListeners();
    } else {
      debugPrint('Cannot move map: controller not initialized');
    }
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

  @override
  void dispose() {
    clearDistanceLine();
    _flutterMapController = null;
    super.dispose();
  }
}
