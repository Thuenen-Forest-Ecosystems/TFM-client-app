import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter_map_location_marker/flutter_map_location_marker.dart';
import 'package:geolocator/geolocator.dart';
import 'package:latlong2/latlong.dart';
import 'package:permission_handler/permission_handler.dart';

class GpsPositionProvider with ChangeNotifier, DiagnosticableTreeMixin {
  Position? _lastPosition;
  bool _listeningPosition = false;
  StreamSubscription<Position>? _positionStream;
  Map? _navigationTarget;
  LocationPermission? _permission;

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
  LocationPermission? get permission => _permission;

  final LocationSettings locationSettings = AndroidSettings(
    accuracy: LocationAccuracy.high,
    //distanceFilter: 100,
    //forceLocationManager: true,
    intervalDuration: const Duration(seconds: 1),
    //(Optional) Set foreground notification config to keep the app alive
    //when going to the background
    /*foregroundNotificationConfig: const ForegroundNotificationConfig(
      notificationText: "Example app will continue to receive your location even when you aren't using it",
      notificationTitle: "Running in Background",
      enableWakeLock: true,
    ),*/
  );

  void toggleGps() {
    if (_listeningPosition) {
      stopTrackingLocation();
    } else {
      startTrackingLocation();
    }
  }

  Future<LocationPermission> checkPermission() async {
    // bool serviceEnabled;
    LocationPermission permission;

    // Test if location services are enabled.
    /*
  serviceEnabled = await Geolocator.isLocationServiceEnabled();
  if (!serviceEnabled) {
    // Location services are not enabled don't continue
    // accessing the position and request users of the 
    // App to enable the location services.
    return Future.error('Location services are disabled.');
  }*/

    permission = await Geolocator.checkPermission();
    if (permission == LocationPermission.denied) {
      permission = await Geolocator.requestPermission();
      if (permission == LocationPermission.denied) {
        return permission;
      }
    }

    return permission;
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
    checkPermission();
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
  }

  void setPosition(Position? lastPosition) {
    _lastPosition = lastPosition;
    notifyListeners();
  }
}
