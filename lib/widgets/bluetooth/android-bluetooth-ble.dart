import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_blue_plus/flutter_blue_plus.dart';
import 'package:terrestrial_forest_monitor/widgets/bluetooth/android-bluetooth-classic.dart';

// instead of import 'package:flutter_blue_plus/flutter_blue_plus.dart'; https://pub.dev/packages/flutter_blue_plus_windows
//import 'package:flutter_blue_plus_windows/flutter_blue_plus_windows.dart';

// Alternatively, you can hide FlutterBluePlus when importing the FBP statement
//import 'package:flutter_blue_plus/flutter_blue_plus.dart' hide FlutterBluePlus;
//import 'package:flutter_blue_plus_windows/flutter_blue_plus_windows.dart';

class AndroidBluetoothBle extends StatefulWidget {
  const AndroidBluetoothBle({super.key});

  @override
  State<AndroidBluetoothBle> createState() => _AndroidBluetoothBleState();
}

class _AndroidBluetoothBleState extends State<AndroidBluetoothBle> {
  List<ScanResult> devices = [];
  late StreamSubscription subscription;
  late StreamSubscription subscriptionAdapter;

  void _startScan() async {
    print('Starting scan...');
    subscription = FlutterBluePlus.onScanResults.listen((results) {
      print('Scan results: $results');
      if (results.isNotEmpty) {
        setState(() {
          devices = results;
        });
        ScanResult r = results.last; // the most recently found device
        print('${r.device.remoteId}: "${r.advertisementData.advName}" found!');
      }
    }, onError: (e) => print(e));
    FlutterBluePlus.cancelWhenScanComplete(subscription);

    //await FlutterBluePlus.adapterState.where((val) => val == BluetoothAdapterState.on).first;
    subscriptionAdapter = FlutterBluePlus.adapterState.listen((BluetoothAdapterState state) {
      print('Adapter state: $state');
    });

    await FlutterBluePlus.startScan(timeout: const Duration(seconds: 20), androidUsesFineLocation: true);
    print('STARTED SCAN');
  }

  @override
  void initState() {
    super.initState();
    _startScan();
  }

  @override
  void dispose() {
    // Make sure to stop scanning when disposing the widget
    FlutterBluePlus.stopScan();
    if (subscriptionAdapter != null) {
      subscriptionAdapter.cancel();
    }
    if (subscription != null) {
      subscription.cancel();
    }
    super.dispose();
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
