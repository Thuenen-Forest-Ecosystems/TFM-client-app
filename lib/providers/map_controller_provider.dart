import 'package:flutter/foundation.dart';
import 'package:flutter_map/flutter_map.dart' show LatLngBounds, MapController;
import 'package:latlong2/latlong.dart';

class MapControllerProvider with ChangeNotifier {
  // Flutter map controller
  MapController? _flutterMapController;

  // Distance line data for flutter_map
  LatLng? _distanceLineFrom;
  LatLng? _distanceLineTo;

  // Focus bounds for flutter_map
  LatLngBounds? _focusBounds;
  DateTime? _focusTimestamp;

  MapController? get flutterMapController => _flutterMapController;
  LatLng? get distanceLineFrom => _distanceLineFrom;
  LatLng? get distanceLineTo => _distanceLineTo;
  LatLngBounds? get focusBounds => _focusBounds;
  DateTime? get focusTimestamp => _focusTimestamp;

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

  void showDistanceLine(LatLng from, LatLng to) {
    _distanceLineFrom = from;
    _distanceLineTo = to;
    debugPrint('Distance line set from $from to $to');
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

  @override
  void dispose() {
    clearDistanceLine();
    _flutterMapController = null;
    super.dispose();
  }
}
