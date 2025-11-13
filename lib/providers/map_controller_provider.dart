import 'package:flutter/foundation.dart';
import 'package:maplibre_gl/maplibre_gl.dart';

class MapControllerProvider with ChangeNotifier {
  MapLibreMapController? _controller;
  Line? _distanceLine;

  MapLibreMapController? get controller => _controller;
  Line? get distanceLine => _distanceLine;

  void setController(MapLibreMapController? controller) {
    _controller = controller;
    notifyListeners();
  }

  Future<void> showDistanceLine(LatLng from, LatLng to) async {
    if (_controller == null) {
      debugPrint('Map controller not available, cannot show distance line');
      return;
    }

    try {
      // Remove existing line if any
      await clearDistanceLine();

      // Add new line
      _distanceLine = await _controller!.addLine(LineOptions(geometry: [from, to], lineColor: '#FF5722', lineWidth: 3.0, lineOpacity: 0.8));

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
