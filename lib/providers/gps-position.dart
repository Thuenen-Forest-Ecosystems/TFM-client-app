import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter_map_location_marker/flutter_map_location_marker.dart';
import 'package:geolocator/geolocator.dart';
import 'package:latlong2/latlong.dart';

class GpsPositionProvider with ChangeNotifier, DiagnosticableTreeMixin {
  Position? _lastPosition;
  bool _listeningPosition = false;
  StreamSubscription<Position>? _positionStream;
  Map? _navigationTarget;

  late final StreamController<LocationMarkerPosition> _positionStreamController;
  late final StreamController<LocationMarkerHeading> _headingStreamController;

  GpsPositionProvider() {
    _positionStreamController = StreamController<LocationMarkerPosition>.broadcast();
    _headingStreamController = StreamController<LocationMarkerHeading>.broadcast();
  }

  Position? get lastPosition => _lastPosition;
  bool get listeningPosition => _listeningPosition;
  Map? get navigationTarget => _navigationTarget;
  StreamSubscription? get positionStream => _positionStream;
  Stream<LocationMarkerPosition> get positionStreamController => _positionStreamController.stream;
  Stream<LocationMarkerHeading> get headingStreamController => _headingStreamController.stream;

  final LocationSettings locationSettings = LocationSettings(
    accuracy: LocationAccuracy.high,
    distanceFilter: 100,
  );

  void toggleGps() {
    if (_listeningPosition) {
      stopTrackingLocation();
    } else {
      startTrackingLocation();
    }
  }

  void navigateToTarget(LatLng position, Map target) {
    _navigationTarget = {
      'position': position,
      'target': target,
    };
    startTrackingLocation();
  }

  void setCurrentLocation() async {
    _lastPosition = await Geolocator.getLastKnownPosition();
    _positionStreamController.add(
      LocationMarkerPosition(
        latitude: _lastPosition!.latitude,
        longitude: _lastPosition!.longitude,
        accuracy: _lastPosition!.accuracy,
      ),
    );
    notifyListeners();
  }

  void startTrackingLocation() {
    if (_positionStream != null) {
      _positionStream?.cancel();
    }

    setCurrentLocation();

    _positionStream = Geolocator.getPositionStream(locationSettings: locationSettings).listen((Position position) {
      _lastPosition = position;

      _positionStreamController.add(
        LocationMarkerPosition(
          latitude: position.latitude,
          longitude: position.longitude,
          accuracy: position.accuracy,
        ),
      );
      _headingStreamController.add(
        LocationMarkerHeading(
          heading: position.heading,
          accuracy: position.headingAccuracy,
        ),
      );

      notifyListeners();
    });
    _listeningPosition = true;
    notifyListeners();
  }

  void stopTrackingLocation() {
    _positionStream?.cancel();
    _listeningPosition = false;
    notifyListeners();
    print('cancel');
  }

  void setPosition(Position? lastPosition) {
    _lastPosition = lastPosition;
    notifyListeners();
  }
}
