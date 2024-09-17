import 'package:flutter/foundation.dart';
import 'package:geolocator/geolocator.dart';

class GpsPositionProvider with ChangeNotifier, DiagnosticableTreeMixin {
  Position? _lastPosition;

  GpsPositionProvider();

  Position? get lastPosition => _lastPosition;

  void setPosition(Position? lastPosition) {
    _lastPosition = lastPosition;
    notifyListeners();
  }
}
