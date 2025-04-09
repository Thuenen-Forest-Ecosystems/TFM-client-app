import 'package:flutter/material.dart';
import 'package:flutter_blue_classic/flutter_blue_classic.dart';

// instead of import 'package:flutter_blue_plus/flutter_blue_plus.dart'; https://pub.dev/packages/flutter_blue_plus_windows
//import 'package:flutter_blue_plus_windows/flutter_blue_plus_windows.dart';

// Alternatively, you can hide FlutterBluePlus when importing the FBP statement
//import 'package:flutter_blue_plus/flutter_blue_plus.dart' hide FlutterBluePlus;
//import 'package:flutter_blue_plus_windows/flutter_blue_plus_windows.dart';

class AndroidBluetoothClassic extends StatefulWidget {
  const AndroidBluetoothClassic({super.key});

  @override
  State<AndroidBluetoothClassic> createState() => _AndroidBluetoothClassicState();
}

class _AndroidBluetoothClassicState extends State<AndroidBluetoothClassic> {
  final _flutterBlueClassicPlugin = FlutterBlueClassic();
  bool _isScanning = false;
  Set<BluetoothDevice> _scanResults = {};

  Future<void> _getBluetoothDevices() async {
    // Initialize FlutterBlueClassic
    try {
      // Then listen to results
      _flutterBlueClassicPlugin.scanResults.listen(
        (device) {
          print('FlutterBlueClassic scan results: $device');
          setState(() {
            _scanResults.add(device);
          });
        },
        onError: (error) {
          print('Error listening to scan resultss: $error');
        },
      );
    } catch (e) {
      print('Error with FlutterBlueClassic: $e');
    }
  }

  void _toggleScan() {
    print('Starting scan...');
    try {
      if (_isScanning) {
        _flutterBlueClassicPlugin.stopScan();
      } else {
        _scanResults.clear();
        _flutterBlueClassicPlugin.startScan();
      }
    } catch (e) {
      print('Error starting scan: $e');
    }
  }

  @override
  void initState() {
    super.initState();
    _getBluetoothDevices();
  }

  @override
  void dispose() {
    // Make sure to stop scanning when disposing the widget
    if (_isScanning) {
      _flutterBlueClassicPlugin.stopScan();
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        ListTile(
          title: Text('Classic Bluetooth Devices'),
          subtitle: Text('Found ${_scanResults.length} devices'),
          trailing: IconButton(
            icon: Icon(_isScanning ? Icons.stop : Icons.search),
            onPressed: () {
              _toggleScan();
            },
          ),
        ),
        ListView.builder(
          physics: const NeverScrollableScrollPhysics(),
          shrinkWrap: true,
          itemCount: _scanResults.length,
          itemBuilder: (context, index) {
            final device = _scanResults.elementAt(index);
            return ListTile(
              title: Text(device.name ?? 'Unknown'),
              subtitle: Text(device.rssi.toString()),
              onTap: () {
                // Handle device tap
              },
            );
          },
        ),
      ],
    );
  }
}
