import 'package:flutter/foundation.dart';
import 'package:maplibre_gl/maplibre_gl.dart' as maplibre;
import 'package:flutter_map/flutter_map.dart' show LatLngBounds;

class MapControllerProvider with ChangeNotifier {
  maplibre.MapLibreMapController? _controller;
  maplibre.Line? _distanceLine;

  // Focus bounds for flutter_map
  LatLngBounds? _focusBounds;
  DateTime? _focusTimestamp;

  maplibre.MapLibreMapController? get controller => _controller;
  maplibre.Line? get distanceLine => _distanceLine;
  LatLngBounds? get focusBounds => _focusBounds;
  DateTime? get focusTimestamp => _focusTimestamp;

  void setController(maplibre.MapLibreMapController? controller) {
    _controller = controller;
    notifyListeners();
  }

  void setFocusBounds(LatLngBounds bounds) {
    _focusBounds = bounds;
    _focusTimestamp = DateTime.now();
    debugPrint('Focus bounds set: SW(${bounds.south}, ${bounds.west}) NE(${bounds.north}, ${bounds.east})');
    notifyListeners();
  }

  void clearFocusBounds() {
    _focusBounds = null;
    _focusTimestamp = null;
    notifyListeners();
  }

  Future<void> showDistanceLine(maplibre.LatLng from, maplibre.LatLng to) async {
    if (_controller == null) {
      debugPrint('Map controller not available, cannot show distance line');
      return;
    }

    try {
      // Remove existing line if any
      await clearDistanceLine();

      // Add new line
      _distanceLine = await _controller!.addLine(maplibre.LineOptions(geometry: [from, to], lineColor: '#FF5722', lineWidth: 3.0, lineOpacity: 0.8));

      debugPrint('Distance line added from $from to $to');
      notifyListeners();
    } catch (e) {
      debugPrint('Error showing distance line: $e');
    }
  }

  Future<void> clearDistanceLine() async {
    if (_distanceLine != null && _controller != null) {
      try {
        await _controller!.removeLine(_distanceLine!);
        debugPrint('Distance line removed');
      } catch (e) {
        debugPrint('Error removing distance line: $e');
      }
      _distanceLine = null;
      notifyListeners();
    }
  }

  @override
  void dispose() {
    clearDistanceLine();
    _controller = null;
    super.dispose();
  }
}
