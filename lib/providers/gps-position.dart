import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:flutter/foundation.dart';
import 'package:flutter_map_location_marker/flutter_map_location_marker.dart';
import 'package:geolocator/geolocator.dart';
import 'package:latlong2/latlong.dart';
import 'package:flutter_blue_plus/flutter_blue_plus.dart' as ble;
import 'package:flutter_bluetooth_serial/flutter_bluetooth_serial.dart' as classic;
import 'package:permission_handler/permission_handler.dart';
import 'package:terrestrial_forest_monitor/services/utils.dart';
import 'package:terrestrial_forest_monitor/services/gnss_service.dart';

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
  ble.BluetoothDevice? connectedDevice;

  // Classic Bluetooth support
  classic.BluetoothConnection? classicConnection;
  classic.BluetoothDevice? connectedClassicDevice;
  StreamSubscription<Uint8List>? classicDataSubscription;
  Timer? _classicReconnectTimer;
  Timer? _classicDataTimeoutTimer;
  bool _isClassicReconnecting = false;
  int _classicReconnectAttempts = 0;
  static const int _maxReconnectAttempts = 3;

  CurrentNMEA? _currentNMEA = CurrentNMEA();

  // Android GNSS service for satellite data
  GnssService? _gnssService;
  StreamSubscription<GnssStatus>? _gnssStatusSubscription;
  GnssStatus? _lastGnssStatus;

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
    foregroundNotificationConfig: const ForegroundNotificationConfig(
      notificationText: "App keeps location active in background",
      notificationTitle: "TFM Location Service",
      enableWakeLock: true,
    ),
  );

  // BLUETOOTH
  Future<void> initialize() async {
    List<ble.BluetoothDevice> connected = ble.FlutterBluePlus.connectedDevices;
    if (connected.isEmpty) {
      await getSettings('GNSSDevice').then((value) {
        if (value != null) {
          dynamic devices = jsonDecode(value['value']);
          if (devices is Map && devices.isNotEmpty) {
            // autoConnect First
            for (var deviceId in devices.keys) {
              var device = ble.BluetoothDevice.fromId(deviceId);
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
  Future<void> _discoverServices(ble.BluetoothDevice device) async {
    // _isConnecting = true; // Managed by caller
    try {
      print('Discovering services...');
      List<ble.BluetoothService> services = await device.discoverServices();
      print('Found ${services.length} services');

      for (var service in services) {
        print('Service: ${service.uuid}');

        // Get characteristics for this service
        for (var characteristic in service.characteristics) {
          // Check if characteristic is readable
          if (characteristic.properties.read) {
            // Read value if needed for device identification
            await characteristic.read();

            print('Device Name: $device');
          }

          // Check if characteristic supports notifications
          if (characteristic.properties.notify) {
            // Subscribe to notifications
            await characteristic.setNotifyValue(true);
            characteristic.onValueReceived.listen((value) {
              _currentNMEA = parseData(value, _currentNMEA);
              // Update position if we have valid coordinates
              if (_currentNMEA != null &&
                  _currentNMEA!.latitude != null &&
                  _currentNMEA!.longitude != null) {
                _updatePositionFromNMEA();
              }
            });
          }
        }
      }
    } catch (e) {
      print('Error discovering services: $e');
      // _isConnecting = false; // Managed by caller
    }
  }

  void toggleDeviceFromId(String deviceId) async {
    stopAll();

    ble.BluetoothDevice device = ble.BluetoothDevice.fromId(deviceId);
    if (connectedDevice != null && connectedDevice!.remoteId == device.remoteId) {
    } else {
      connectDevice(device);
    }
  }

  void connectDeviceFromId(String deviceId) async {
    ble.BluetoothDevice device = ble.BluetoothDevice.fromId(deviceId);
    connectDevice(device);
  }

  void _saveConnectedDevice(ble.BluetoothDevice device) async {
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

  void connectDevice(ble.BluetoothDevice device) async {
    // Ensure permissions on Android
    if (Platform.isAndroid) {
      await [Permission.bluetoothScan, Permission.bluetoothConnect].request();
    }

    List<ble.BluetoothDevice> connected = ble.FlutterBluePlus.connectedDevices;

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

    // Add connection timeout
    Timer connectionTimeout = Timer(const Duration(seconds: 15), () {
      if (_isConnecting && connectedDevice == null) {
        debugPrint('Connection timeout - stopping connection attempt');
        debugPrint('Bluetooth device not reachable, falling back to internal GPS');
        _isConnecting = false;
        blueConnectionSubscription?.cancel();
        device.disconnect();
        // Automatically start internal GPS as fallback
        startInternalGps();
      }
    });

    blueConnectionSubscription = device.connectionState.listen((
      ble.BluetoothConnectionState state,
    ) async {
      if (state == ble.BluetoothConnectionState.disconnected) {
        debugPrint('Device disconnected');
        connectedDevice = null;
        _isConnecting = false;
        notifyListeners();
        // Don't auto-reconnect to prevent connection loops
        // User must manually reconnect from UI
      } else if (state == ble.BluetoothConnectionState.connected) {
        connectionTimeout.cancel();
        _saveConnectedDevice(device);
        connectedDevice = device;
        await _discoverServices(device);
        _isConnecting = false;
        notifyListeners();
      }
    });
    //device.cancelWhenDisconnected(blueConnectionSubscription!, delayed: true, next: true);
    try {
      // Use autoConnect: false for more stable connections
      // Request high connection priority for better performance
      await device.connect(
        autoConnect: false,
        mtu: null, // Let system negotiate MTU automatically
      );

      // Request high connection priority after successful connection
      // This helps maintain stable GPS data streaming
      try {
        await device.requestConnectionPriority(
          connectionPriorityRequest: ble.ConnectionPriority.high,
        );
        debugPrint('Requested high connection priority');
      } catch (e) {
        debugPrint('Could not request connection priority: $e');
      }
    } catch (error) {
      print('Error connecting to device: $error');
      debugPrint('Failed to connect to Bluetooth device, falling back to internal GPS');
      connectionTimeout.cancel();
      _isConnecting = false;
      // Automatically start internal GPS as fallback
      startInternalGps();
    }
  }

  // Connect to Classic Bluetooth GPS device
  Future<void> connectClassicDevice(classic.BluetoothDevice device) async {
    // Ensure permissions on Android
    if (Platform.isAndroid) {
      await [Permission.bluetoothScan, Permission.bluetoothConnect].request();
    }

    // Check if device is bonded (paired)
    if (!device.isBonded) {
      debugPrint(
        'Device ${device.name} is not paired. Please pair the device first in system Bluetooth settings.',
      );
      _isConnecting = false;
      notifyListeners();
      return;
    }

    // Prevent multiple simultaneous connection attempts
    if (_isClassicReconnecting) {
      debugPrint('Classic reconnection already in progress, skipping');
      return;
    }

    // Cancel existing connection and timers
    _classicReconnectTimer?.cancel();
    _classicDataTimeoutTimer?.cancel();
    classicDataSubscription?.cancel();
    if (classicConnection != null && classicConnection!.isConnected) {
      try {
        await classicConnection!.finish();
      } catch (e) {
        debugPrint('Error closing previous connection: $e');
      }
    }

    _isConnecting = true;
    _isClassicReconnecting = true;
    connectedClassicDevice = device;
    notifyListeners();

    try {
      debugPrint('Connecting to Classic Bluetooth device: ${device.name}');

      // Connect to the device with proper error handling
      try {
        classicConnection = await classic.BluetoothConnection.toAddress(device.address);
      } catch (e) {
        // If connection fails, reset the reconnecting flag and schedule retry
        debugPrint('Initial connection attempt failed: $e');
        _isConnecting = false;
        _isClassicReconnecting = false;

        if (connectedClassicDevice?.address == device.address) {
          _scheduleClassicReconnection(device);
        }
        notifyListeners();
        return;
      }

      if (classicConnection == null || !classicConnection!.isConnected) {
        throw Exception('Connection failed - not connected');
      }

      debugPrint('Connected to ${device.name}');

      // Buffer to accumulate NMEA sentences
      String buffer = '';

      // Reset data timeout timer
      _resetDataTimeout(device);

      // Listen to incoming data with robust error handling
      classicDataSubscription = classicConnection!.input!.listen(
        (Uint8List data) {
          // Reset timeout timer on each data received
          _resetDataTimeout(device);

          // Convert bytes to string and add to buffer
          String incoming = String.fromCharCodes(data);
          buffer += incoming;

          // Process complete NMEA sentences (ended with \r\n)
          while (buffer.contains('\n')) {
            final int index = buffer.indexOf('\n');
            final String sentence = buffer.substring(0, index).trim();
            buffer = buffer.substring(index + 1);

            if (sentence.isNotEmpty) {
              // Parse NMEA sentence
              try {
                List<int> bytes = sentence.codeUnits;
                _currentNMEA = parseData(bytes, _currentNMEA);

                // Update position if we have valid coordinates
                if (_currentNMEA != null &&
                    _currentNMEA!.latitude != null &&
                    _currentNMEA!.longitude != null) {
                  _updatePositionFromNMEA();
                }
              } catch (e) {
                debugPrint('Error parsing NMEA from Classic BT: $e');
              }
            }
          }

          // Prevent buffer from growing too large
          if (buffer.length > 1000) {
            buffer = buffer.substring(buffer.length - 500);
          }
        },
        onDone: () {
          debugPrint('Classic Bluetooth connection closed');
          _handleClassicDisconnection(device);
        },
        onError: (error) {
          debugPrint('Error with Classic Bluetooth data stream: $error');
          _handleClassicDisconnection(device);
        },
        cancelOnError: false, // Keep listening even after errors
      );

      _isConnecting = false;
      _isClassicReconnecting = false;
      _classicReconnectAttempts = 0; // Reset on successful connection
      notifyListeners();
    } catch (e) {
      debugPrint('Error connecting to Classic Bluetooth device: $e');
      _isConnecting = false;
      _isClassicReconnecting = false;

      // Schedule reconnection attempt
      _scheduleClassicReconnection(device);
      notifyListeners();
    }
  }

  // Reset the data timeout timer
  void _resetDataTimeout(classic.BluetoothDevice device) {
    _classicDataTimeoutTimer?.cancel();
    _classicDataTimeoutTimer = Timer(const Duration(seconds: 10), () {
      debugPrint('Classic Bluetooth data timeout - no data received for 10 seconds');
      _handleClassicDisconnection(device);
    });
  }

  // Handle disconnection and attempt reconnection
  void _handleClassicDisconnection(classic.BluetoothDevice device) {
    _classicDataTimeoutTimer?.cancel();
    classicDataSubscription?.cancel();
    classicDataSubscription = null;

    if (classicConnection != null && classicConnection!.isConnected) {
      try {
        classicConnection!.finish();
      } catch (e) {
        debugPrint('Error closing connection during cleanup: $e');
      }
    }
    classicConnection = null;

    notifyListeners();

    // Schedule reconnection if we still want to be connected to this device
    if (connectedClassicDevice?.address == device.address) {
      _scheduleClassicReconnection(device);
    }
  }

  // Schedule automatic reconnection
  void _scheduleClassicReconnection(classic.BluetoothDevice device) {
    _classicReconnectTimer?.cancel();

    // Check if we've exceeded max reconnection attempts
    if (_classicReconnectAttempts >= _maxReconnectAttempts) {
      debugPrint('Max reconnection attempts ($_maxReconnectAttempts) reached for ${device.name}');
      debugPrint('Classic Bluetooth device not reachable, falling back to internal GPS');
      connectedClassicDevice = null;
      _classicReconnectAttempts = 0;
      startInternalGps();
      return;
    }

    _classicReconnectAttempts++;
    _classicReconnectTimer = Timer(const Duration(seconds: 3), () {
      if (connectedClassicDevice?.address == device.address) {
        debugPrint(
          'Reconnection attempt $_classicReconnectAttempts/$_maxReconnectAttempts to ${device.name}',
        );
        connectClassicDevice(device);
      }
    });
  }

  // Helper method to update position from NMEA data (shared by BLE and Classic)
  void _updatePositionFromNMEA() {
    if (_currentNMEA == null || _currentNMEA!.latitude == null || _currentNMEA!.longitude == null) {
      return;
    }

    // Calculate accuracy from HDOP (horizontal dilution of precision)
    double calculatedAccuracy = (_currentNMEA!.hdop ?? 1.0) * 5.0;

    // Set last position
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

    // Update heading if available
    if (_currentNMEA?.heading != null) {
      double estimatedHeadingAccuracy = 10.0;

      if (_currentNMEA?.hdop != null) {
        if (_currentNMEA!.hdop! < 1.5) {
          estimatedHeadingAccuracy = 3.0;
        } else if (_currentNMEA!.hdop! < 3.0) {
          estimatedHeadingAccuracy = 7.0;
        } else {
          estimatedHeadingAccuracy = 15.0;
        }
      }

      if (_currentNMEA?.speedKnots != null && _currentNMEA!.speedKnots! < 0.5) {
        estimatedHeadingAccuracy = 30.0;
      }

      _headingStreamController.add(
        LocationMarkerHeading(heading: _currentNMEA!.heading!, accuracy: estimatedHeadingAccuracy),
      );
    } else {
      _headingStreamController.add(LocationMarkerHeading(heading: 0, accuracy: 0));
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

  @override
  void dispose() {
    stopAll();
    _gnssStatusSubscription?.cancel();
    _gnssService?.stopGnssListener();
    _gnssService?.dispose();

    super.dispose();
  }

  void stopAll() {
    // Reset connecting flag
    _isConnecting = false;

    if (blueConnectionSubscription != null) {
      blueConnectionSubscription?.cancel();
      blueConnectionSubscription = null;
    }
    if (connectedDevice != null) {
      connectedDevice!.disconnect();
      connectedDevice = null;
    }

    // Stop Classic Bluetooth connection
    _classicReconnectTimer?.cancel();
    _classicReconnectTimer = null;
    _classicDataTimeoutTimer?.cancel();
    _classicDataTimeoutTimer = null;
    _isClassicReconnecting = false;
    _classicReconnectAttempts = 0; // Reset reconnection attempts
    classicDataSubscription?.cancel();
    classicDataSubscription = null;
    if (classicConnection != null && classicConnection!.isConnected) {
      try {
        classicConnection!.finish();
      } catch (e) {
        debugPrint('Error closing Classic connection: $e');
      }
    }
    classicConnection = null;
    connectedClassicDevice = null;

    _positionStream?.cancel();
    _listeningPosition = false;

    // Stop Android GNSS listener
    _gnssStatusSubscription?.cancel();
    _gnssStatusSubscription = null;
    _lastGnssStatus = null;
    if (Platform.isAndroid && _gnssService != null) {
      _gnssService?.stopGnssListener();
    }

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

    // Initialize Android GNSS service for satellite data
    if (Platform.isAndroid) {
      _gnssService ??= GnssService();
      try {
        final isAvailable = await _gnssService!.isGnssAvailable();
        if (isAvailable) {
          await _gnssService!.startGnssListener();
          _gnssStatusSubscription = _gnssService!.getGnssStatusStream().listen((status) {
            _lastGnssStatus = status;
            // Update NMEA with satellite data if we have a valid position
            if (_currentNMEA != null &&
                _currentNMEA!.latitude != null &&
                _currentNMEA!.longitude != null) {
              _currentNMEA = CurrentNMEA(
                latitude: _currentNMEA!.latitude,
                longitude: _currentNMEA!.longitude,
                altitude: _currentNMEA!.altitude,
                heading: _currentNMEA!.heading,
                speedKnots: _currentNMEA!.speedKnots,
                timestamp: _currentNMEA!.timestamp,
                // Use actual satellite data from GNSS
                satellites: status.usedInFix,
                hdop: status.estimateHdop(),
                pdop: status.estimatePdop(),
                vdop: null, // Not directly available
                fixQuality: status.usedInFix >= 4 ? '1' : '0',
                mode: null,
                fixType: status.usedInFix >= 4 ? 3 : 0,
              );
              notifyListeners();
            }
          });
          debugPrint('Android GNSS listener started successfully');
        }
      } catch (e) {
        debugPrint('Failed to initialize Android GNSS service: $e');
      }
    }

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

          // Create NMEA object from internal GPS Position data
          // On Android, enhance with real satellite data from GNSS service
          if (Platform.isAndroid && _lastGnssStatus != null) {
            // Use actual satellite data from Android GNSS
            _currentNMEA = CurrentNMEA(
              latitude: position.latitude,
              longitude: position.longitude,
              altitude: position.altitude,
              heading: position.heading,
              speedKnots: position.speed * 1.94384, // Convert m/s to knots
              timestamp: position.timestamp,
              // Real satellite data from GNSS
              satellites: _lastGnssStatus!.usedInFix,
              hdop: _lastGnssStatus!.estimateHdop(),
              pdop: _lastGnssStatus!.estimatePdop(),
              vdop: null, // Not available from Android API
              fixQuality: _lastGnssStatus!.usedInFix >= 4 ? '1' : '0',
              mode: null,
              fixType: _lastGnssStatus!.usedInFix >= 4 ? 3 : 0,
            );
          } else {
            // Fallback: estimate from accuracy (Windows, iOS, or Android without GNSS data)
            _currentNMEA = CurrentNMEA(
              latitude: position.latitude,
              longitude: position.longitude,
              altitude: position.altitude,
              heading: position.heading,
              speedKnots: position.speed * 1.94384, // Convert m/s to knots
              timestamp: position.timestamp,
              // Estimate HDOP from accuracy (rough approximation: accuracy ≈ HDOP * 5)
              hdop: position.accuracy / 5.0,
              // These are not available without external GPS or Android GNSS:
              satellites: null,
              pdop: null,
              vdop: null,
              fixQuality: null,
              mode: null,
              fixType: null,
            );
          }

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
    if (_currentNMEA != null && _currentNMEA!.latitude != null && _currentNMEA!.longitude != null) {
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
        _headingStreamController.add(LocationMarkerHeading(heading: 0, accuracy: 0));
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
