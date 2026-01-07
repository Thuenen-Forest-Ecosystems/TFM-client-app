import 'dart:async';
import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:flutter_map_location_marker/flutter_map_location_marker.dart';
import 'package:geolocator/geolocator.dart';
import 'package:latlong2/latlong.dart';
import 'package:flutter_blue_plus/flutter_blue_plus.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:terrestrial_forest_monitor/services/utils.dart';

class CurrentNMEA {
  String? mode;
  int? fixType; // Fix type (0 = no fix, 1 = GPS fix, 2 = DGPS fix, etc.)
  double? pdop; // Position Dilution of Precision
  double? hdop; // Horizontal Dilution of Precision
  double? vdop; // Vertical Dilution of Precision
  int? satellites; // Number of satellites used
  double? altitude; // Altitude above mean sea level
  String? fixQuality; // GPS Fix Quality (e.g., '1' for GPS fix, '2' for DGPS)
  DateTime? timestamp; // Timestamp of the NMEA sentence
  double? longitude; // Longitude in degrees
  double? latitude; // Latitude in degrees
  double? heading;
  double? speedKnots;

  CurrentNMEA({
    this.pdop,
    this.hdop,
    this.vdop,
    this.satellites,
    this.altitude,
    this.fixQuality,
    this.timestamp,
    this.longitude,
    this.latitude,
    this.mode,
    this.fixType,
    this.heading,
    this.speedKnots,
  });

  @override
  String toString() {
    return 'NMEA(PDOP: $pdop, HDOP: $hdop, VDOP: $vdop, Satellites: $satellites, Altitude: $altitude, Fix: $fixQuality, Time: $timestamp, Longitude: $longitude, Latitude: $latitude, Mode: $mode, FixType: $fixType, Heading: $heading, SpeedKnots: $speedKnots)';
  }
}

class GpsPositionProvider with ChangeNotifier, DiagnosticableTreeMixin {
  Position? _lastPosition;
  bool _listeningPosition = false;
  bool _isConnecting = false;
  StreamSubscription<Position>? _positionStream;
  Map? _navigationTarget;
  LocationPermission? _permission;

  StreamSubscription? blueConnectionSubscription;
  BluetoothDevice? connectedDevice;

  CurrentNMEA? _currentNMEA = CurrentNMEA();

  late final StreamController<LocationMarkerPosition> _positionStreamController;
  late final StreamController<LocationMarkerHeading> _headingStreamController;

  GpsPositionProvider() {
    _positionStreamController = StreamController<LocationMarkerPosition>.broadcast();
    _headingStreamController = StreamController<LocationMarkerHeading>.broadcast();
  }

  Position? get lastPosition => _lastPosition;
  bool get listeningPosition => _listeningPosition;
  Map? get navigationTarget => _navigationTarget;
  bool get isConnecting => _isConnecting;
  StreamSubscription? get positionStream => _positionStream;
  Stream<LocationMarkerPosition> get positionStreamController => _positionStreamController.stream;
  Stream<LocationMarkerHeading> get headingStreamController => _headingStreamController.stream;
  LocationPermission? get permission => _permission;
  CurrentNMEA? get currentNMEA => _currentNMEA;

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

  // BLUETOOTH
  Future<void> initialize() async {
    List<BluetoothDevice> connected = FlutterBluePlus.connectedDevices;
    if (connected.isEmpty) {
      await getSettings('GNSSDevice').then((value) {
        if (value != null) {
          dynamic devices = jsonDecode(value['value']);
          if (devices is Map && devices.isNotEmpty) {
            // autoConnect First
            for (var deviceId in devices.keys) {
              var device = BluetoothDevice.fromId(deviceId);
              connectDevice(device);
              break; // Connect to the first found device
            }
          } else {
            // No saved bluetooth device, use internal GPS
            debugPrint('No bluetooth device configured, starting internal GPS');
            startInternalGps();
          }
        } else {
          // No settings found, use internal GPS
          debugPrint('No GPS settings found, starting internal GPS');
          startInternalGps();
        }
      });
    }
  }

  // Add this new method to discover and interact with services
  Future<void> _discoverServices(BluetoothDevice device) async {
    _isConnecting = true;
    try {
      print('Discovering services...');
      List<BluetoothService> services = await device.discoverServices();
      print('Found ${services.length} services');

      for (var service in services) {
        print('Service: ${service.uuid}');

        // Get characteristics for this service
        for (var characteristic in service.characteristics) {
          // Check if characteristic is readable
          if (characteristic.properties.read) {
            // Read value
            List<int> value = await characteristic.read();

            // You can process the data here
            String stringValue = String.fromCharCodes(value);

            print('Device Name: $device');
          }

          // Check if characteristic supports notifications
          if (characteristic.properties.notify) {
            // Subscribe to notifications
            await characteristic.setNotifyValue(true);
            characteristic.onValueReceived.listen((value) {
              _currentNMEA = parseData(value, _currentNMEA);
              // merge with current NMEA only not null and has valid coordinates
              if (_currentNMEA != null &&
                  _currentNMEA!.latitude != null &&
                  _currentNMEA!.longitude != null) {
                // Calculate accuracy from HDOP (horizontal dilution of precision)
                // HDOP * 5 gives approximate accuracy in meters (rough estimation)
                double calculatedAccuracy = (_currentNMEA!.hdop ?? 1.0) * 5.0;

                // set last position
                _lastPosition = Position(
                  latitude: _currentNMEA!.latitude!,
                  longitude: _currentNMEA!.longitude!,
                  accuracy: calculatedAccuracy,
                  altitude: _currentNMEA!.altitude ?? 0,
                  altitudeAccuracy: 0,
                  heading: _currentNMEA!.heading ?? 0,
                  headingAccuracy: 0,
                  speed: _currentNMEA!.speedKnots ?? 0,
                  speedAccuracy: 0,
                  timestamp: DateTime.now(),
                );

                if (_currentNMEA?.heading != null) {
                  // Estimate heading accuracy based on HDOP and Speed
                  double estimatedHeadingAccuracy = 10.0; // Default to higher uncertainty

                  if (_currentNMEA?.hdop != null) {
                    if (_currentNMEA!.hdop! < 1.5) {
                      estimatedHeadingAccuracy = 3.0; // Good HDOP
                    } else if (_currentNMEA!.hdop! < 3.0) {
                      estimatedHeadingAccuracy = 7.0; // Moderate HDOP
                    } else {
                      estimatedHeadingAccuracy = 15.0; // Poor HDOP
                    }
                  }

                  // Increase uncertainty significantly if speed is very low
                  if (_currentNMEA?.speedKnots != null && _currentNMEA!.speedKnots! < 0.5) {
                    estimatedHeadingAccuracy = 30.0; // Very uncertain when slow/stationary
                  }

                  _headingStreamController.add(
                    LocationMarkerHeading(
                      heading: _currentNMEA!.heading!,
                      accuracy: estimatedHeadingAccuracy, // Use the estimated value
                    ),
                  );
                } else {
                  _headingStreamController.add(
                    LocationMarkerHeading(
                      heading: 0,
                      accuracy: 0, // Use the estimated value
                    ),
                  );
                }

                // Add position to stream for map widget
                _positionStreamController.add(
                  LocationMarkerPosition(
                    latitude: _lastPosition!.latitude,
                    longitude: _lastPosition!.longitude,
                    accuracy: _lastPosition!.accuracy,
                  ),
                );

                _isConnecting = false;
                notifyListeners();
              }
            });
          }
        }
      }
    } catch (e) {
      print('Error discovering services: $e');
      _isConnecting = false;
    }
  }

  void toggleDeviceFromId(String deviceId) async {
    stopAll();

    BluetoothDevice device = BluetoothDevice.fromId(deviceId);
    if (connectedDevice != null && connectedDevice!.remoteId == device.remoteId) {
    } else {
      connectDevice(device);
    }
  }

  void connectDeviceFromId(String deviceId) async {
    BluetoothDevice device = BluetoothDevice.fromId(deviceId);
    connectDevice(device);
  }

  void _saveConnectedDevice(BluetoothDevice device) async {
    String deviceId = device.remoteId.toString();
    Map deviceMap = {'remoteId': deviceId, 'platformName': device.platformName};

    await getSettings('GNSSDevice').then((value) {
      if (value != null) {
        dynamic devices = jsonDecode(value['value']);
        if (devices is Map) {
          devices[deviceId] = deviceMap;
          setSettings('GNSSDevice', jsonEncode(devices));
        } else {
          setSettings('GNSSDevice', jsonEncode({deviceId: deviceMap}));
        }
      } else {
        setSettings('GNSSDevice', jsonEncode({deviceId: deviceMap}));
      }
    });
  }

  void connectDevice(BluetoothDevice device) async {
    List<BluetoothDevice> connected = FlutterBluePlus.connectedDevices;

    if (connected.isNotEmpty) {
      for (var connectedDevice in connected) {
        if (connectedDevice.remoteId == device.remoteId) {
          print('Already connected to device: ${device.platformName}');
          return;
        }
      }
    }

    stopAll();

    if (blueConnectionSubscription != null) {
      blueConnectionSubscription?.cancel();
    }
    _isConnecting = true;
    notifyListeners();
    blueConnectionSubscription = device.connectionState.listen((
      BluetoothConnectionState state,
    ) async {
      if (state == BluetoothConnectionState.disconnected) {
        // try to reconnect after 2 seconds
        await Future.delayed(const Duration(seconds: 2));
        connectDevice(device);
      } else if (state == BluetoothConnectionState.connected) {
        //
        _saveConnectedDevice(device);
        connectedDevice = device;
        _discoverServices(device);
        _isConnecting = false;
        notifyListeners();
      }
    });
    //device.cancelWhenDisconnected(blueConnectionSubscription!, delayed: true, next: true);
    await device.connect(autoConnect: true, mtu: null).catchError((error) {
      print('Error connecting to device: $error');
      _isConnecting = false;
      notifyListeners();
    });
  }

  @override
  void dispose() {
    stopAll();

    super.dispose();
  }

  void stopAll() {
    if (blueConnectionSubscription != null) {
      blueConnectionSubscription?.cancel();
    }
    if (connectedDevice != null) {
      connectedDevice!.disconnect();
      connectedDevice = null;
    }
    _positionStream?.cancel();
    _listeningPosition = false;

    _currentNMEA = null;
    _navigationTarget = null;
    _lastPosition = null;
    _positionStream = null;
    notifyListeners();
  }

  void startInternalGps() {
    bool isListening = _listeningPosition;
    stopAll();
    if (!isListening) {
      startTrackingLocation();
    }
  }

  void startExternalGps() {
    stopAll();
    if (connectedDevice != null) {
      connectDevice(connectedDevice!);
    }
  }

  void navigateToTarget(LatLng position, Map target) {
    _navigationTarget = {'position': position, 'target': target};
    startTrackingLocation();
  }

  void setCurrentLocation() async {
    /// if not web
    if (!kIsWeb) {
      _lastPosition = await Geolocator.getLastKnownPosition();
    }
    if (_lastPosition != null) {
      _positionStreamController.add(
        LocationMarkerPosition(
          latitude: _lastPosition!.latitude,
          longitude: _lastPosition!.longitude,
          accuracy: _lastPosition!.accuracy,
        ),
      );
      notifyListeners();
    }
  }

  void startTrackingLocation() async {
    // Check permissions and service status first
    try {
      Map<Permission, PermissionStatus> statuses = await [
        Permission.location,
        Permission.storage,
      ].request();
      if (statuses[Permission.location] != PermissionStatus.granted) {
        print('Location permission denied. Cannot start tracking.');
        // Optionally show a message to the user
        return;
      }
    } catch (e) {
      print('Error checking permission/service: $e');
      // Handle error (e.g., show message if service disabled)
      return;
    }

    if (_positionStream != null) {
      _positionStream?.cancel();
    }

    setCurrentLocation(); // Attempt to get last known location

    _isConnecting = true;
    notifyListeners();
    _positionStream = Geolocator.getPositionStream(locationSettings: locationSettings)
        .handleError((error) {
          // <-- Add error handling for the stream
          print("Error in location stream: $error");
          // Handle specific errors if needed
          _isConnecting = false;
        })
        .listen((Position position) {
          _lastPosition = position;

          _positionStreamController.add(
            LocationMarkerPosition(
              latitude: position.latitude,
              longitude: position.longitude,
              accuracy: position.accuracy,
            ),
          );
          _headingStreamController.add(
            LocationMarkerHeading(heading: position.heading, accuracy: position.headingAccuracy),
          );
          _listeningPosition = true;
          _isConnecting = false;
          notifyListeners();
        });

    notifyListeners();
  }

  void setPosition(Position? lastPosition) {
    _lastPosition = lastPosition;
    notifyListeners();
  }

  // Method to process serial port NMEA data (for Windows USB GPS devices)
  void processSerialPortData(List<int> data) {
    _currentNMEA = parseData(data, _currentNMEA);
    
    // Update position if we have valid coordinates
    if (_currentNMEA != null &&
        _currentNMEA!.latitude != null &&
        _currentNMEA!.longitude != null) {
      // Calculate accuracy from HDOP (horizontal dilution of precision)
      // HDOP * 5 gives approximate accuracy in meters (rough estimation)
      double calculatedAccuracy = (_currentNMEA!.hdop ?? 1.0) * 5.0;

      // set last position
      _lastPosition = Position(
        latitude: _currentNMEA!.latitude!,
        longitude: _currentNMEA!.longitude!,
        accuracy: calculatedAccuracy,
        altitude: _currentNMEA!.altitude ?? 0,
        altitudeAccuracy: 0,
        heading: _currentNMEA!.heading ?? 0,
        headingAccuracy: 0,
        speed: _currentNMEA!.speedKnots ?? 0,
        speedAccuracy: 0,
        timestamp: DateTime.now(),
      );

      if (_currentNMEA?.heading != null) {
        // Estimate heading accuracy based on HDOP and Speed
        double estimatedHeadingAccuracy = 10.0; // Default to higher uncertainty

        if (_currentNMEA?.hdop != null) {
          if (_currentNMEA!.hdop! < 1.5) {
            estimatedHeadingAccuracy = 3.0; // Good HDOP
          } else if (_currentNMEA!.hdop! < 3.0) {
            estimatedHeadingAccuracy = 7.0; // Moderate HDOP
          } else {
            estimatedHeadingAccuracy = 15.0; // Poor HDOP
          }
        }

        // Increase uncertainty significantly if speed is very low
        if (_currentNMEA?.speedKnots != null && _currentNMEA!.speedKnots! < 0.5) {
          estimatedHeadingAccuracy = 30.0; // Very uncertain when slow/stationary
        }

        _headingStreamController.add(
          LocationMarkerHeading(
            heading: _currentNMEA!.heading!,
            accuracy: estimatedHeadingAccuracy,
          ),
        );
      } else {
        _headingStreamController.add(
          LocationMarkerHeading(
            heading: 0,
            accuracy: 0,
          ),
        );
      }

      // Add position to stream for map widget
      _positionStreamController.add(
        LocationMarkerPosition(
          latitude: _lastPosition!.latitude,
          longitude: _lastPosition!.longitude,
          accuracy: _lastPosition!.accuracy,
        ),
      );

      _isConnecting = false;
      notifyListeners();
    }
  }
}
