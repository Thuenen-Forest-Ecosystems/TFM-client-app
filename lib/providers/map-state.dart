import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

import 'package:flutter_map/flutter_map.dart';
import 'package:geolocator/geolocator.dart';
import 'package:latlong2/latlong.dart';
import 'package:terrestrial_forest_monitor/services/powersync.dart';
import 'package:terrestrial_forest_monitor/services/utils.dart';

class MapState with ChangeNotifier, DiagnosticableTreeMixin {
  double _zoom = 0;
  bool _isDop = false;
  bool _mapOpen = false;
  bool _gps = false;
  int _focusAll = 0;

  final MapController _mapController = MapController();

  bool get mapOpen => _mapOpen;
  double get zoom => _zoom;
  bool get isDop => _isDop;
  int get focusAll => _focusAll;
  bool get gps => _gps;
  MapController get mapController => _mapController;

  void toggleMap() {
    _mapOpen = !_mapOpen;
    notifyListeners();
  }

  void openMap() {
    _mapOpen = true;
    notifyListeners();
  }

  void closeMap() {
    _mapOpen = false;
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
    LatLng centerLatLng = _mapController.camera.center;
    _zoom = _mapController.camera.zoom + 1;

    _mapController.move(centerLatLng, _zoom);
  }

  void fitCameraBounds(LatLngBounds bounds, double padding) {
    _mapController.fitCamera(
      CameraFit.bounds(
        bounds: bounds,
        padding: EdgeInsets.all(padding),
      ),
    );
  }

  void moveToPoint(LatLng point, double? zoom) {
    double newZoom = zoom ?? _mapController.camera.zoom;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _mapController.move(point, newZoom);
    });
  }

  void zoomOut() {
    LatLng centerLatLng = _mapController.camera.center;
    _zoom = _mapController.camera.zoom - 1;

    _mapController.move(centerLatLng, _zoom);
  }

  void setFocus() {
    // LatLngBounds bounds = getBounds(plots, 'center_location_json');
    db.getAll('SELECT * FROM plot WHERE center_location_json IS NOT NULL').then((plots) {
      LatLngBounds bounds = getBounds(plots, 'center_location_json');
      fitCameraBounds(bounds, 50);
    });
    //_focusAll++;
    //notifyListeners();
  }

  /// Makes `Counter` readable inside the devtools by listing all of its properties
  @override
  void debugFillProperties(DiagnosticPropertiesBuilder properties) {
    super.debugFillProperties(properties);
    properties.add(FlagProperty('mapOpen', value: mapOpen, ifTrue: 'mapOpen'));
  }
}
