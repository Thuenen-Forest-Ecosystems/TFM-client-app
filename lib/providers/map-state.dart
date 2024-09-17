import 'package:flutter/foundation.dart';

class MapState with ChangeNotifier, DiagnosticableTreeMixin {
  int _zoom = 0;
  bool _isDop = false;
  bool _mapOpen = false;
  bool _gps = false;
  int _focusAll = 0;

  bool get mapOpen => _mapOpen;
  int get zoom => _zoom;
  bool get isDop => _isDop;
  int get focusAll => _focusAll;
  bool get gps => _gps;

  void toggleMap() {
    _mapOpen = !_mapOpen;
    notifyListeners();
  }

  void toggleGps() {
    _gps = !_gps;
    notifyListeners();
  }

  void setDop(bool value) {
    _isDop = value;
    notifyListeners();
  }

  void zoomIn() {
    _zoom++;
    notifyListeners();
  }

  void zoomOut() {
    _zoom--;
    notifyListeners();
  }

  void setFocus() {
    _focusAll++;
    notifyListeners();
  }

  /// Makes `Counter` readable inside the devtools by listing all of its properties
  @override
  void debugFillProperties(DiagnosticPropertiesBuilder properties) {
    super.debugFillProperties(properties);
    properties.add(FlagProperty('mapOpen', value: mapOpen, ifTrue: 'mapOpen'));
  }
}
