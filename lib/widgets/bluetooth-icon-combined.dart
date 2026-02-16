import 'package:flutter/material.dart';
import 'package:flutter_blue_plus/flutter_blue_plus.dart' as ble;
import 'package:flutter_bluetooth_serial/flutter_bluetooth_serial.dart' as classic;
import 'package:provider/provider.dart';
import 'package:terrestrial_forest_monitor/providers/gps-position.dart';
import 'dart:async';
import 'dart:io' show Platform;

// Combined device class to hold both BLE and Classic devices
class CombinedBluetoothDevice {
  final String id;
  final String name;
  final int? rssi;
  final bool isBLE;
  final ble.BluetoothDevice? bleDevice;
  final classic.BluetoothDevice? classicDevice;

  CombinedBluetoothDevice({
    required this.id,
    required this.name,
    this.rssi,
    required this.isBLE,
    this.bleDevice,
    this.classicDevice,
  });
}

class BluetoothIconCombined extends StatefulWidget {
  const BluetoothIconCombined({super.key});

  @override
  State<BluetoothIconCombined> createState() => _BluetoothIconCombinedState();
}

class _BluetoothIconCombinedState extends State<BluetoothIconCombined> {
  classic.BluetoothDevice? _connectedClassicDevice;
  List<CombinedBluetoothDevice> _combinedDevices = [];
  bool _isScanning = false;

  // BLE subscriptions
  StreamSubscription<List<ble.ScanResult>>? _bleScanSubscription;

  // Classic Bluetooth (only on Android)
  classic.FlutterBluetoothSerial? _flutterBluetoothSerial;
  StreamSubscription<classic.BluetoothDiscoveryResult>? _classicScanSubscription;

  // Modal state callback to update modal UI
  void Function(void Function())? _modalSetState;

  @override
  void initState() {
    super.initState();
    _checkConnectedDevices();

    // Initialize Classic Bluetooth only on Android
    if (Platform.isAndroid) {
      _flutterBluetoothSerial = classic.FlutterBluetoothSerial.instance;
    }
  }

  Future<void> _checkConnectedDevices() async {
    // GPS devices are managed by GpsPositionProvider, no need to check here
  }

  Future<void> _stopAllScans() async {
    try {
      // Stop BLE scan
      if (await ble.FlutterBluePlus.isScanning.first) {
        await ble.FlutterBluePlus.stopScan();
        debugPrint('Stopped BLE scan before connection');
      }

      // Stop Classic scan
      _classicScanSubscription?.cancel();
      _classicScanSubscription = null;

      if (mounted) {
        setState(() {
          _isScanning = false;
        });
      }
    } catch (e) {
      debugPrint('Error stopping scans: $e');
    }
  }

  Future<void> _startScan() async {
    // Don't scan if already connecting or connected to prevent interference
    final gpsProvider = context.read<GpsPositionProvider>();
    final hasActiveGPS =
        gpsProvider.connectedDevice != null ||
        gpsProvider.connectedClassicDevice != null ||
        gpsProvider.listeningPosition;

    if (gpsProvider.isConnecting || hasActiveGPS) {
      debugPrint('Not starting scan - GPS device active or connection in progress');
      return;
    }

    // Stop any existing scans first
    await _stopAllScans();

    setState(() {
      _combinedDevices = [];
      _isScanning = true;
    });

    try {
      // Start BLE scan
      await _startBLEScan();

      // Start Classic Bluetooth scan (Android only)
      if (Platform.isAndroid && _flutterBluetoothSerial != null) {
        await _startClassicScan();
      }
    } catch (e) {
      debugPrint('Error starting scan: $e');
      _showErrorDialog('Failed to start scan: $e');
      if (mounted) {
        setState(() => _isScanning = false);
      }
    }
  }

  Future<bool> _checkBluetoothAvailable() async {
    try {
      // Check if Bluetooth is available
      if (await ble.FlutterBluePlus.isSupported == false) {
        return false;
      }

      // Check if Bluetooth is on
      final adapterState = await ble.FlutterBluePlus.adapterState.first;
      if (adapterState != ble.BluetoothAdapterState.on) {
        return false;
      }

      return true;
    } catch (e) {
      debugPrint('Error checking Bluetooth availability: $e');
      return false;
    }
  }

  Future<void> _startBLEScan() async {
    try {
      // Start BLE scanning
      await ble.FlutterBluePlus.startScan(timeout: const Duration(seconds: 10));

      // Wait for scan to complete
      await Future.delayed(const Duration(seconds: 10));
      await ble.FlutterBluePlus.stopScan();

      if (mounted) {
        setState(() {
          _isScanning = false;
        });
      }
    } catch (e) {
      debugPrint('Error with BLE scan: $e');
      rethrow;
    }
  }

  Future<void> _startClassicScan() async {
    try {
      if (_flutterBluetoothSerial == null) return;

      debugPrint('Starting Classic Bluetooth scan');

      // Listen to classic scan results
      _classicScanSubscription?.cancel();
      _classicScanSubscription = _flutterBluetoothSerial!.startDiscovery().listen(
        (result) {
          debugPrint(
            'Classic device found: ${result.device.name ?? "Unknown"} - ${result.device.address}',
          );

          // Add to combined list if not already present
          final exists = _combinedDevices.any((d) => d.id == result.device.address);
          if (!exists) {
            _combinedDevices.add(
              CombinedBluetoothDevice(
                id: result.device.address,
                name: result.device.name ?? 'Unknown Classic Device',
                rssi: result.rssi,
                isBLE: false,
                classicDevice: result.device,
              ),
            );
          }

          // Update both parent and modal state
          if (mounted) {
            setState(() {}); // Update parent widget
            _modalSetState?.call(() {}); // Update modal UI if open
          }
        },
        onError: (error) {
          debugPrint('Error listening to classic scan results: $error');
        },
      );

      // Stop after 10 seconds
      Future.delayed(const Duration(seconds: 10), () {
        _classicScanSubscription?.cancel();
      });
    } catch (e) {
      debugPrint('Error with Classic Bluetooth scan: $e');
    }
  }

  Future<void> _connectToBLEDevice(ble.BluetoothDevice device, BuildContext context) async {
    // Always connect as GPS sensor - no dialog needed
    try {
      // Stop all scans immediately to prevent interference
      await _stopAllScans();

      final gpsProvider = context.read<GpsPositionProvider>();

      // Stop any existing connections
      gpsProvider.stopAll();

      // Connect using the GPS provider which handles NMEA parsing
      gpsProvider.connectDevice(ble.BluetoothDevice.fromId(device.remoteId.toString()));

      if (mounted && context.mounted) {
        // Try to show snackbar, but don't fail if no scaffold
        try {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(
                'Connecting to ${device.platformName.isEmpty ? "GPS device" : device.platformName}...',
              ),
            ),
          );
        } catch (e) {
          debugPrint('Could not show snackbar: $e');
        }
      }
    } catch (e) {
      debugPrint('Error connecting GPS device: $e');
      if (mounted && context.mounted) {
        _showErrorDialog('Failed to connect GPS device: $e');
      }
    }
  }

  Future<void> _connectToClassicDevice(classic.BluetoothDevice device, BuildContext context) async {
    try {
      // Check if device is bonded (paired)
      if (!device.isBonded) {
        if (mounted && context.mounted) {
          _showErrorDialog(
            'Device "${device.name ?? device.address}" is not paired.\n\n'
            'Please pair the device in your system Bluetooth settings first, then try again.',
          );
        }
        return;
      }

      // Stop all scans immediately to prevent interference
      await _stopAllScans();

      final gpsProvider = context.read<GpsPositionProvider>();

      // Stop any existing connections
      gpsProvider.stopAll();

      // Connect using the GPS provider
      await gpsProvider.connectClassicDevice(device);

      if (mounted && context.mounted) {
        try {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Connecting to ${device.name ?? "GPS device"}...')),
          );
        } catch (e) {
          debugPrint('Could not show snackbar: $e');
        }
      }
    } catch (e) {
      debugPrint('Error connecting Classic GPS device: $e');
      if (mounted && context.mounted) {
        _showErrorDialog('Failed to connect: $e');
      }
    }
  }

  void _showDeviceMenu() async {
    // Check if Bluetooth is available before showing modal
    // We store this future to use it in the builder without re-triggering checks
    final bluetoothCheckFuture = _checkBluetoothAvailable();
    await bluetoothCheckFuture;

    if (!mounted) return;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      builder: (context) => StatefulBuilder(
        builder: (context, setModalState) {
          // Store modal setState callback for use in scan listeners
          _modalSetState = setModalState;

          // Update the modal when BLE scan results change
          // Only create subscription once, not on every rebuild
          if (_bleScanSubscription == null) {
            _bleScanSubscription = ble.FlutterBluePlus.scanResults.listen((results) {
              // Update combined list with BLE results
              final newDevices = <CombinedBluetoothDevice>[];

              // Add BLE devices
              for (final result in results) {
                newDevices.add(
                  CombinedBluetoothDevice(
                    id: result.device.remoteId.toString(),
                    name: result.device.platformName.isEmpty
                        ? 'Unknown BLE Device'
                        : result.device.platformName,
                    rssi: result.rssi,
                    isBLE: true,
                    bleDevice: result.device,
                  ),
                );
              }

              // Add existing Classic devices (maintain them during BLE updates)
              final classicDevices = _combinedDevices.where((d) => !d.isBLE);
              newDevices.addAll(classicDevices);

              // Update both parent state and modal state
              _combinedDevices = newDevices;

              if (mounted) {
                setState(() {}); // Update parent widget
                setModalState(() {}); // Update modal UI
              }
            });
          }

          return Container(
            constraints: BoxConstraints(maxHeight: MediaQuery.of(context).size.height * 0.75),
            padding: const EdgeInsets.all(16),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Text(
                      'erreichbare GNSS Geräte',
                      style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
                    ),
                    if (_isScanning)
                      IconButton(
                        icon: const Icon(Icons.stop),
                        onPressed: () {
                          _stopAllScans();
                        },
                      ),
                    if (!_isScanning)
                      Consumer<GpsPositionProvider>(
                        builder: (context, gpsProvider, child) {
                          final hasActiveGPS =
                              gpsProvider.connectedDevice != null ||
                              gpsProvider.connectedClassicDevice != null ||
                              gpsProvider.listeningPosition;

                          return FutureBuilder<bool>(
                            future: bluetoothCheckFuture,
                            builder: (context, snapshot) {
                              final isAvailable = snapshot.data ?? false;
                              if (!isAvailable) {
                                return const Padding(
                                  padding: EdgeInsets.symmetric(horizontal: 8.0),
                                  child: Text(
                                    'Bluetooth Off',
                                    style: TextStyle(color: Colors.orange, fontSize: 12),
                                  ),
                                );
                              }
                              return IconButton(
                                icon: Icon(Icons.refresh, color: hasActiveGPS ? Colors.grey : null),
                                onPressed: hasActiveGPS
                                    ? null
                                    : () {
                                        _startScan();
                                      },
                              );
                            },
                          );
                        },
                      ),
                  ],
                ),
                const SizedBox(height: 16),

                // Show connected GPS device or internal GPS
                Consumer<GpsPositionProvider>(
                  builder: (context, gpsProvider, child) {
                    // Show bluetooth GPS if connected (BLE)
                    if (gpsProvider.connectedDevice != null) {
                      final device = gpsProvider.connectedDevice!;
                      final nmea = gpsProvider.currentNMEA;

                      final hasValidPosition =
                          nmea != null && nmea.latitude != null && nmea.longitude != null;

                      return Column(
                        children: [
                          ListTile(
                            leading: Icon(
                              Icons.gps_fixed,
                              color: hasValidPosition ? Colors.green : Colors.orange,
                            ),
                            title: Text(
                              device.platformName.isEmpty ? 'GPS Device' : device.platformName,
                            ),
                            subtitle: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text('${device.remoteId}'),
                                if (hasValidPosition) ...[
                                  Text(
                                    'Sats: ${nmea.satellites ?? "N/A"} | HDOP: ${nmea.hdop?.toStringAsFixed(1) ?? "N/A"} | PDOP: ${nmea.pdop?.toStringAsFixed(1) ?? "N/A"}',
                                    style: const TextStyle(fontSize: 11, color: Colors.grey),
                                  ),
                                  Text(
                                    'Lat: ${nmea.latitude!.toStringAsFixed(6)}, Lon: ${nmea.longitude!.toStringAsFixed(6)}',
                                    style: const TextStyle(fontSize: 11, color: Colors.grey),
                                  ),
                                ] else ...[
                                  const Text(
                                    'Waiting for GPS position...',
                                    style: TextStyle(fontSize: 11, color: Colors.orange),
                                  ),
                                ],
                              ],
                            ),
                            trailing: IconButton(
                              icon: const Icon(Icons.close),
                              onPressed: () {
                                gpsProvider.stopAll();
                                _startScan();
                              },
                            ),
                          ),
                          const Divider(),
                        ],
                      );
                    }
                    // Show Classic Bluetooth GPS if connected
                    else if (gpsProvider.connectedClassicDevice != null) {
                      final device = gpsProvider.connectedClassicDevice!;
                      final nmea = gpsProvider.currentNMEA;

                      final hasValidPosition =
                          nmea != null && nmea.latitude != null && nmea.longitude != null;

                      return Column(
                        children: [
                          ListTile(
                            leading: Icon(
                              Icons.gps_fixed,
                              color: hasValidPosition ? Colors.green : Colors.orange,
                            ),
                            title: Text(device.name ?? 'Classic GPS Device'),
                            subtitle: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text('${device.address}'),
                                if (hasValidPosition) ...[
                                  Text(
                                    'Sats: ${nmea.satellites ?? "N/A"} | HDOP: ${nmea.hdop?.toStringAsFixed(1) ?? "N/A"} | PDOP: ${nmea.pdop?.toStringAsFixed(1) ?? "N/A"}',
                                    style: const TextStyle(fontSize: 11, color: Colors.grey),
                                  ),
                                  Text(
                                    'Lat: ${nmea.latitude!.toStringAsFixed(6)}, Lon: ${nmea.longitude!.toStringAsFixed(6)}',
                                    style: const TextStyle(fontSize: 11, color: Colors.grey),
                                  ),
                                ] else ...[
                                  const Text(
                                    'Waiting for GPS position...',
                                    style: TextStyle(fontSize: 11, color: Colors.orange),
                                  ),
                                ],
                              ],
                            ),
                            trailing: IconButton(
                              icon: const Icon(Icons.close),
                              onPressed: () {
                                gpsProvider.stopAll();
                                _startScan();
                              },
                            ),
                          ),
                          const Divider(),
                        ],
                      );
                    }
                    // Show internal GPS if it's active
                    else if (gpsProvider.listeningPosition) {
                      final lastPos = gpsProvider.lastPosition;
                      final nmea = gpsProvider.currentNMEA;
                      final hasValidPosition = lastPos != null;

                      return Column(
                        children: [
                          ListTile(
                            leading: Icon(
                              Icons.smartphone,
                              color: hasValidPosition ? Colors.green : Colors.orange,
                            ),
                            title: const Text('Internal GPS'),
                            subtitle: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                const Text('Device internal GPS sensor'),
                                if (hasValidPosition) ...[
                                  Text(
                                    'Accuracy: ${lastPos.accuracy.toStringAsFixed(1)}m | HDOP: ${nmea?.hdop?.toStringAsFixed(1) ?? "N/A"}',
                                    style: const TextStyle(fontSize: 11, color: Colors.grey),
                                  ),
                                  Text(
                                    'Lat: ${lastPos.latitude.toStringAsFixed(6)}, Lon: ${lastPos.longitude.toStringAsFixed(6)}',
                                    style: const TextStyle(fontSize: 11, color: Colors.grey),
                                  ),
                                ] else ...[
                                  const Text(
                                    'Waiting for GPS position...',
                                    style: TextStyle(fontSize: 11, color: Colors.orange),
                                  ),
                                ],
                              ],
                            ),
                            trailing: IconButton(
                              icon: const Icon(Icons.close),
                              onPressed: () {
                                gpsProvider.stopAll();
                                _startScan();
                              },
                            ),
                          ),
                          const Divider(),
                        ],
                      );
                    }
                    return const SizedBox.shrink();
                  },
                ),

                // Show connected BLE device - removed, only GPS sensors supported now

                // Device list
                Expanded(
                  child: ListView.builder(
                    shrinkWrap: true,
                    itemCount: _combinedDevices.length + 1, // +1 for internal GPS
                    itemBuilder: (context, index) {
                      // First item is always internal GPS
                      if (index == 0) {
                        final gpsProvider = context.watch<GpsPositionProvider>();
                        final isInternalGPS =
                            gpsProvider.listeningPosition &&
                            gpsProvider.connectedDevice == null &&
                            gpsProvider.connectedClassicDevice == null;

                        return ListTile(
                          leading: Icon(
                            Icons.smartphone,
                            color: isInternalGPS ? Colors.green : Colors.grey,
                          ),
                          title: const Text('Internal GPS'),
                          subtitle: const Text('Device internal GPS sensor'),
                          trailing: isInternalGPS
                              ? const Icon(Icons.check_circle, color: Colors.green)
                              : null,
                          onTap: () {
                            Navigator.pop(context); // Close modal first
                            gpsProvider.stopAll();
                            gpsProvider.startInternalGps();
                          },
                        );
                      }

                      // Remaining items are Bluetooth devices
                      final deviceIndex = index - 1;
                      if (deviceIndex >= _combinedDevices.length) {
                        return const SizedBox.shrink();
                      }

                      final device = _combinedDevices[deviceIndex];

                      return ListTile(
                        leading: Icon(
                          device.isBLE ? Icons.bluetooth : Icons.bluetooth_audio,
                          color: device.isBLE ? Colors.blue[700] : Colors.orange[700],
                        ),
                        title: Row(
                          children: [
                            Expanded(child: Text(device.name)),
                            if (!device.isBLE &&
                                device.classicDevice != null &&
                                !device.classicDevice!.isBonded)
                              const Padding(
                                padding: EdgeInsets.only(left: 4.0),
                                child: Icon(Icons.lock_open, size: 16, color: Colors.orange),
                              ),
                          ],
                        ),
                        subtitle: Text('${device.isBLE ? "BLE" : "Classic"} - ${device.id}'),
                        trailing: device.rssi != null ? Text('${device.rssi} dBm') : null,
                        onTap: () {
                          if (device.isBLE && device.bleDevice != null) {
                            Navigator.pop(context); // Close modal first
                            _connectToBLEDevice(device.bleDevice!, context);
                          } else if (device.classicDevice != null) {
                            Navigator.pop(context); // Close modal first
                            _connectToClassicDevice(device.classicDevice!, context);
                          }
                        },
                      );
                    },
                  ),
                ),
              ],
            ),
          );
        },
      ),
    ).whenComplete(() {
      _modalSetState = null; // Clear modal setState callback
      // Cancel BLE scan subscription when modal is closed to prevent setState after dispose
      _bleScanSubscription?.cancel();
      _bleScanSubscription = null;
    });
  }

  void _showErrorDialog(String message) {
    if (mounted) {
      showDialog(
        context: context,
        builder: (context) => AlertDialog(
          title: const Text('Error'),
          content: Text(message),
          actions: [
            TextButton(onPressed: () => Navigator.of(context).pop(), child: const Text('OK')),
          ],
        ),
      );
    }
  }

  @override
  void dispose() {
    _bleScanSubscription?.cancel();
    _classicScanSubscription?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    // Check if GPS device is connected via GpsPositionProvider
    final gpsProvider = context.watch<GpsPositionProvider>();
    final hasBLEConnection = gpsProvider.connectedDevice != null;
    final hasClassicConnection = gpsProvider.connectedClassicDevice != null;
    final hasGPSConnection = hasBLEConnection || hasClassicConnection;
    final isGPSConnecting = gpsProvider.isConnecting;
    final nmea = gpsProvider.currentNMEA;
    final isInternalGPS = gpsProvider.listeningPosition && !hasGPSConnection;
    final lastPos = gpsProvider.lastPosition;

    // GPS has valid position if connected AND has valid lat/lon coordinates
    final hasValidPosition =
        (hasGPSConnection && nmea != null && nmea.latitude != null && nmea.longitude != null) ||
        (isInternalGPS && lastPos != null);

    // Choose icon based on GPS source
    //final icon = isInternalGPS ? Icons.smartphone : (hasValidPosition ? Icons.bluetooth_connected : Icons.bluetooth);
    final icon = isInternalGPS ? Icons.smartphone : Icons.satellite_alt;
    //final icon = Icons.satellite_alt;

    return IconButton(
      icon: Icon(
        icon,
        color: hasValidPosition
            ? Colors.green
            : (hasGPSConnection || isGPSConnecting || isInternalGPS ? Colors.orange : null),
      ),
      tooltip: hasValidPosition
          ? (isInternalGPS
                ? 'Internal GPS: ${lastPos!.accuracy.toStringAsFixed(1)}m (HDOP: ${nmea?.hdop?.toStringAsFixed(1) ?? "N/A"})'
                : hasBLEConnection
                ? 'GPS: ${gpsProvider.connectedDevice?.platformName} (${nmea!.satellites ?? 0} sats)'
                : 'GPS: ${gpsProvider.connectedClassicDevice?.name} (${nmea!.satellites ?? 0} sats)')
          : hasGPSConnection
          ? 'GPS connected - waiting for position...'
          : isGPSConnecting
          ? 'Connecting to GPS...'
          : isInternalGPS
          ? 'Internal GPS active'
          : 'Bluetooth GPS',
      onPressed: _showDeviceMenu,
    );
  }
}
