import 'package:flutter/material.dart';
import 'package:flutter_blue_plus/flutter_blue_plus.dart' as ble;
import 'package:flutter_blue_classic/flutter_blue_classic.dart' as classic;
import 'package:provider/provider.dart';
import 'package:flutter/services.dart';
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
  classic.FlutterBlueClassic? _flutterBlueClassic;
  StreamSubscription<classic.BluetoothDevice>? _classicScanSubscription;

  @override
  void initState() {
    super.initState();
    _checkConnectedDevices();

    // Initialize Classic Bluetooth only on Android
    if (Platform.isAndroid) {
      _flutterBlueClassic = classic.FlutterBlueClassic();
    }
  }

  Future<void> _checkConnectedDevices() async {
    // GPS devices are managed by GpsPositionProvider, no need to check here
  }

  Future<void> _startScan() async {
    setState(() {
      _combinedDevices = [];
      _isScanning = true;
    });

    try {
      // Start BLE scan
      await _startBLEScan();

      // Start Classic Bluetooth scan (Android only)
      if (Platform.isAndroid && _flutterBlueClassic != null) {
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
      // Check if Bluetooth is available on this platform
      final isSupported = await ble.FlutterBluePlus.isSupported;
      debugPrint('Bluetooth isSupported: $isSupported (Platform: ${Platform.operatingSystem})');
      
      if (isSupported == false) {
        return false;
      }

      // Check if Bluetooth is on
      final adapterState = await ble.FlutterBluePlus.adapterState.first;
      debugPrint('Bluetooth adapter state: $adapterState');
      
      // On Windows, adapter state may be unknown but still functional
      // Accept 'on' or 'unknown' states, reject 'off' or 'unavailable'
      if (adapterState == ble.BluetoothAdapterState.off || 
          adapterState == ble.BluetoothAdapterState.unavailable ||
          adapterState == ble.BluetoothAdapterState.unauthorized) {
        return false;
      }

      return true;
    } on MissingPluginException catch (e) {
      debugPrint('Bluetooth plugin missing on this platform: $e');
      return false;
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
      if (_flutterBlueClassic == null) return;

      // Listen to classic scan results
      _classicScanSubscription?.cancel();
      _classicScanSubscription = _flutterBlueClassic!.scanResults.listen(
        (device) {
          debugPrint('Classic device found: ${device.name ?? "Unknown"} - ${device.address}');

          if (mounted) {
            setState(() {
              // Add to combined list if not already present
              final exists = _combinedDevices.any((d) => d.id == device.address);
              if (!exists) {
                _combinedDevices.add(
                  CombinedBluetoothDevice(
                    id: device.address,
                    name: device.name ?? 'Unknown Classic Device',
                    rssi: device.rssi,
                    isBLE: false,
                    classicDevice: device,
                  ),
                );
              }
            });
          }
        },
        onError: (error) {
          debugPrint('Error listening to classic scan results: $error');
        },
      );

      // Start the scan
      _flutterBlueClassic!.startScan();

      // Stop after 10 seconds
      Future.delayed(const Duration(seconds: 10), () {
        _flutterBlueClassic?.stopScan();
      });
    } catch (e) {
      debugPrint('Error with Classic Bluetooth scan: $e');
    }
  }

  Future<void> _connectToBLEDevice(ble.BluetoothDevice device, BuildContext context) async {
    // Always connect as GPS sensor - no dialog needed
    try {
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

  Future<void> _connectToClassicDevice(classic.BluetoothDevice device) async {
    // Note: flutter_blue_classic doesn't support programmatic connection
    // Users typically need to pair through system settings
    _showErrorDialog(
      'Please pair with "${device.name ?? "this device"}" through your device\'s Bluetooth settings',
    );
  }

  void _showDeviceMenu() async {
    // Check if Bluetooth is available before showing modal (cached to avoid repeated checks)
    final isBluetoothAvailable = await _checkBluetoothAvailable();

    if (!mounted) return;

    // Auto-start scan when opening modal if bluetooth is available and not already scanning
    final gpsProvider = context.read<GpsPositionProvider>();
    if (isBluetoothAvailable &&
        !_isScanning &&
        gpsProvider.connectedDevice == null &&
        _connectedClassicDevice == null) {
      _startScan();
    }

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      builder: (context) => StatefulBuilder(
        builder: (context, setModalState) {
          // Update the modal when BLE scan results change
          _bleScanSubscription?.cancel();
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

            // Only update state if still mounted
            if (mounted) {
              setState(() {
                _combinedDevices = newDevices;
              });
              // Only update modal state if it's still mounted
              try {
                setModalState(() {}); // Update modal UI
              } catch (e) {
                // Modal might be disposed, ignore
                debugPrint('Modal state update failed: $e');
              }
            }
          });

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
                      const SizedBox(
                        width: 20,
                        height: 20,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      ),
                    if (!_isScanning)
                      // Use cached bluetooth availability to avoid repeated platform checks
                      isBluetoothAvailable
                          ? IconButton(
                              icon: const Icon(Icons.refresh),
                              onPressed: () {
                                _startScan();
                              },
                            )
                          : const Padding(
                              padding: EdgeInsets.symmetric(horizontal: 8.0),
                              child: Text(
                                'Bluetooth Off',
                                style: TextStyle(color: Colors.orange, fontSize: 12),
                              ),
                            ),
                  ],
                ),
                const SizedBox(height: 16),

                // Show connected GPS device or internal GPS
                Consumer<GpsPositionProvider>(
                  builder: (context, gpsProvider, child) {
                    // Show bluetooth GPS if connected
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
                                gpsProvider.startInternalGps();
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
                                    'Accuracy: ${lastPos.accuracy.toStringAsFixed(1)}m',
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
                            /*trailing: IconButton(
                                  icon: const Icon(Icons.refresh),
                                  onPressed: () {
                                    _startScan();
                                  },
                                ),*/
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
                  child: _combinedDevices.isEmpty
                      ? const Center(child: Text('No devices found'))
                      : ListView.builder(
                          shrinkWrap: true,
                          itemCount: _combinedDevices.length,
                          itemBuilder: (context, index) {
                            final device = _combinedDevices[index];

                            return ListTile(
                              leading: Icon(
                                device.isBLE ? Icons.bluetooth : Icons.bluetooth_audio,
                                color: device.isBLE ? Colors.blue[700] : Colors.orange[700],
                              ),
                              title: Text(device.name),
                              subtitle: Text('${device.isBLE ? "BLE" : "Classic"} - ${device.id}'),
                              trailing: device.rssi != null ? Text('${device.rssi} dBm') : null,
                              onTap: () {
                                if (device.isBLE && device.bleDevice != null) {
                                  Navigator.pop(context); // Close modal first
                                  _connectToBLEDevice(device.bleDevice!, context);
                                } else if (device.classicDevice != null) {
                                  _connectToClassicDevice(device.classicDevice!);
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
    _flutterBlueClassic?.stopScan();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    // Check if GPS device is connected via GpsPositionProvider
    final gpsProvider = context.watch<GpsPositionProvider>();
    final hasGPSConnection = gpsProvider.connectedDevice != null;
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
                ? 'Internal GPS: ${lastPos!.accuracy.toStringAsFixed(1)}m'
                : 'GPS: ${gpsProvider.connectedDevice?.platformName} (${nmea!.satellites ?? 0} sats)')
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
