// instead of import 'package:flutter_blue_plus/flutter_blue_plus.dart';
import 'package:flutter/material.dart';
import 'package:flutter_blue_plus_windows/flutter_blue_plus_windows.dart';

// Alternatively, you can hide FlutterBluePlus when importing the FBP statement
import 'package:flutter_blue_plus/flutter_blue_plus.dart' hide FlutterBluePlus;
import 'package:flutter_blue_plus_windows/flutter_blue_plus_windows.dart';


class WindowsBluetoothBle extends StatefulWidget {
  const WindowsBluetoothBle({super.key});

  @override
  State<WindowsBluetoothBle> createState() => _AndroidBluetoothBleState();
}

class _AndroidBluetoothBleState extends State<WindowsBluetoothBle> {
  List<ScanResult> devices = [];

  void _startScan() async {
    const timeout = Duration(seconds: 30);
    FlutterBluePlus.startScan(timeout: timeout);

    final sub = FlutterBluePlus.scanResults.listen((results) {
      setState(() {
        devices = results;
      });
    }, onError: (e) => print(e));

    await Future.delayed(timeout);
    sub.cancel();
  }

  @override
  void initState() {
    super.initState();
  }

  @override
  Widget build(BuildContext context) {
    return ListView(
      physics: const NeverScrollableScrollPhysics(),
      shrinkWrap: true,
      children: [
        ListTile(
          title: const Text('BLE Bluetooth Devices'),
          subtitle: Text('Found ${devices.length} devices'),
          trailing: IconButton(
            icon: const Icon(Icons.search),
            onPressed: () {
              _startScan();
            },
          ),
        ),
        ListView.builder(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          itemCount: devices.length,
          itemBuilder: (context, index) {
            ScanResult device = devices[index];
            return ListTile(
              title: Text(device.device.platformName.isEmpty ? 'Unknown' : device.device.platformName),
              subtitle: Text(device.device.remoteId.toString()),
              trailing: IconButton(
                icon: const Icon(Icons.bluetooth),
                onPressed: () {
                  // Handle Bluetooth connection
                },
              ),
            );
          },
        ),
      ],
    );
  }
}
