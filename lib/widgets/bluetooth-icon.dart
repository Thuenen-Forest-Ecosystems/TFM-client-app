import 'package:flutter/material.dart';
import 'package:flutter_blue_plus/flutter_blue_plus.dart' as ble;
import 'package:flutter_blue_classic/flutter_blue_classic.dart' as classic;
import 'dart:async';

// Combined device class to hold both BLE and Classic devices
class CombinedBluetoothDevice {
  final String id;
  final String name;
  final int? rssi;
  final bool isBLE;
  final ble.BluetoothDevice? bleDevice;
  final classic.BluetoothDevice? classicDevice;

  CombinedBluetoothDevice({required this.id, required this.name, this.rssi, required this.isBLE, this.bleDevice, this.classicDevice});
}

class BluetoothIcon extends StatefulWidget {
  const BluetoothIcon({super.key});

  @override
  State<BluetoothIcon> createState() => _BluetoothIconState();
}

class _BluetoothIconState extends State<BluetoothIcon> {
  ble.BluetoothDevice? _connectedBLEDevice;
  classic.BluetoothDevice? _connectedClassicDevice;
  List<CombinedBluetoothDevice> _combinedDevices = [];
  bool _isScanning = false;

  // BLE subscriptions
  StreamSubscription<List<ble.ScanResult>>? _bleScanSubscription;
  StreamSubscription<ble.BluetoothConnectionState>? _bleConnectionSubscription;

  // Classic Bluetooth
  final classic.FlutterBlueClassic _flutterBlueClassic = classic.FlutterBlueClassic();
  StreamSubscription<classic.BluetoothDevice>? _classicScanSubscription;

  @override
  void initState() {
    super.initState();
    _checkConnectedDevices();
  }

  Future<void> _checkConnectedDevices() async {
    try {
      final connectedDevices = await FlutterBluePlus.connectedDevices;
      if (connectedDevices.isNotEmpty && mounted) {
        setState(() {
          _connectedDevice = connectedDevices.first;
        });
      }
    } catch (e) {
      debugPrint('Error checking connected devices: $e');
    }
  }

  Future<void> _startScan() async {
    setState(() {
      _scanResults = [];
      _isScanning = true;
    });

    try {
      // Check if Bluetooth is available
      if (await FlutterBluePlus.isSupported == false) {
        _showErrorDialog('Bluetooth is not supported on this device');
        setState(() => _isScanning = false);
        return;
      }

      // Check if Bluetooth is on
      final adapterState = await FlutterBluePlus.adapterState.first;
      if (adapterState != BluetoothAdapterState.on) {
        _showErrorDialog('Please turn on Bluetooth');
        setState(() => _isScanning = false);
        return;
      }

      // Start scanning
      await FlutterBluePlus.startScan(timeout: const Duration(seconds: 10));

      // Wait for scan to complete
      await Future.delayed(const Duration(seconds: 10));
      await FlutterBluePlus.stopScan();

      if (mounted) {
        setState(() {
          _isScanning = false;
        });
      }
    } catch (e) {
      debugPrint('Error scanning: $e');
      _showErrorDialog('Failed to scan: $e');
      if (mounted) {
        setState(() => _isScanning = false);
      }
    }
  }

  Future<void> _connectToDevice(BluetoothDevice device) async {
    try {
      // Cancel scanning if still active
      if (_isScanning) {
        await FlutterBluePlus.stopScan();
        setState(() => _isScanning = false);
      }

      // Show connecting dialog
      if (mounted) {
        showDialog(context: context, barrierDismissible: false, builder: (context) => const AlertDialog(content: Row(children: [CircularProgressIndicator(), SizedBox(width: 16), Text('Connecting...')])));
      }

      // Connect to device
      await device.connect(timeout: const Duration(seconds: 15));

      // Listen to connection state
      _connectionSubscription?.cancel();
      _connectionSubscription = device.connectionState.listen((state) {
        if (state == BluetoothConnectionState.disconnected && mounted) {
          setState(() {
            _connectedDevice = null;
          });
          ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Disconnected from ${device.platformName}')));
        }
      });

      if (mounted) {
        Navigator.of(context).pop(); // Close connecting dialog
        setState(() {
          _connectedDevice = device;
        });
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Connected to ${device.platformName}')));
      }
    } catch (e) {
      debugPrint('Error connecting: $e');
      if (mounted) {
        Navigator.of(context).pop(); // Close connecting dialog
        _showErrorDialog('Failed to connect: $e');
      }
    }
  }

  Future<void> _disconnectDevice() async {
    if (_connectedDevice != null) {
      try {
        await _connectedDevice!.disconnect();
        setState(() {
          _connectedDevice = null;
        });
      } catch (e) {
        debugPrint('Error disconnecting: $e');
      }
    }
  }

  void _showDeviceMenu() {
    showModalBottomSheet(
      context: context,
      builder:
          (context) => StatefulBuilder(
            builder: (context, setModalState) {
              // Update the modal when scan results change
              _scanSubscription?.cancel();
              _scanSubscription = FlutterBluePlus.scanResults.listen((results) {
                if (mounted) {
                  setState(() {
                    _scanResults = results;
                  });
                  setModalState(() {}); // Update modal UI
                }
              });

              return Container(
                padding: const EdgeInsets.all(16),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        const Text('Bluetooth Devices', style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
                        if (_isScanning) const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2)),
                        if (!_isScanning)
                          IconButton(
                            icon: const Icon(Icons.refresh),
                            onPressed: () {
                              _startScan();
                            },
                          ),
                      ],
                    ),
                    const SizedBox(height: 16),
                    if (_connectedDevice != null)
                      ListTile(
                        leading: const Icon(Icons.bluetooth_connected, color: Colors.green),
                        title: Text(_connectedDevice!.platformName.isEmpty ? 'Unknown Device' : _connectedDevice!.platformName),
                        subtitle: Text(_connectedDevice!.remoteId.toString()),
                        trailing: IconButton(
                          icon: const Icon(Icons.close),
                          onPressed: () {
                            _disconnectDevice();
                            Navigator.pop(context);
                          },
                        ),
                      ),
                    const Divider(),
                    Expanded(
                      child:
                          _scanResults.isEmpty
                              ? const Center(child: Text('No devices found'))
                              : ListView.builder(
                                itemCount: _scanResults.length,
                                itemBuilder: (context, index) {
                                  final result = _scanResults[index];
                                  final device = result.device;
                                  final deviceName = device.platformName.isEmpty ? 'Unknown Device' : device.platformName;

                                  return ListTile(
                                    leading: Icon(Icons.bluetooth, color: Colors.blue[700]),
                                    title: Text(deviceName),
                                    subtitle: Text(device.remoteId.toString()),
                                    trailing: Text('${result.rssi} dBm'),
                                    onTap: () {
                                      _connectToDevice(device);
                                      Navigator.pop(context);
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
    );
  }

  void _showErrorDialog(String message) {
    if (mounted) {
      showDialog(context: context, builder: (context) => AlertDialog(title: const Text('Error'), content: Text(message), actions: [TextButton(onPressed: () => Navigator.of(context).pop(), child: const Text('OK'))]));
    }
  }

  @override
  void dispose() {
    _scanSubscription?.cancel();
    _connectionSubscription?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return IconButton(
      icon: Icon(_connectedDevice != null ? Icons.bluetooth_connected : Icons.bluetooth, color: _connectedDevice != null ? Colors.green : null),
      tooltip: _connectedDevice != null ? 'Connected to ${_connectedDevice!.platformName}' : 'Bluetooth',
      onPressed: _showDeviceMenu,
    );
  }
}
