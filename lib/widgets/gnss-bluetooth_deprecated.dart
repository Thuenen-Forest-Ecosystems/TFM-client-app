import 'dart:io';
import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_blue_plus/flutter_blue_plus.dart';
import 'package:permission_handler/permission_handler.dart';

class GNSSBluetooth extends StatefulWidget {
  const GNSSBluetooth({Key? key}) : super(key: key);

  @override
  State<GNSSBluetooth> createState() => _GNSSBluetoothState();
}

class _GNSSBluetoothState extends State<GNSSBluetooth> {
  List<int> baudeRates = [9600, 19200, 38400, 57600, 115200];
  int? baudeRate;
  List<String> availablePorts = [];
  String selectedPort = '';
  bool scanning = false;
  bool tested = false;
  bool testing = false;
  var serialPort;
  bool _bluetoothEnabled = false;
  StreamSubscription? _scanSubscription;

  @override
  void initState() {
    super.initState();
    _init();
  }

  Future<void> _init() async {
    // Check Bluetooth support
    if (!await FlutterBluePlus.isSupported) {
      print("Bluetooth not supported by this device");
      return;
    }

    // Request Bluetooth permissions
    if (Platform.isAndroid) {
      // Request Bluetooth permissions on Android
      Map<Permission, PermissionStatus> statuses = await [Permission.bluetoothConnect, Permission.bluetoothScan, Permission.location].request();

      if (statuses[Permission.bluetoothConnect] == PermissionStatus.granted && statuses[Permission.bluetoothScan] == PermissionStatus.granted && statuses[Permission.location] == PermissionStatus.granted) {
        print("Bluetooth permissions granted");
        _bluetoothEnabled = true;
      } else {
        print("Bluetooth permissions denied");
        _bluetoothEnabled = false;
      }
    } else if (Platform.isIOS) {
      // On iOS, we only need to check Bluetooth status
      _bluetoothEnabled = true; // Assume enabled, handle errors later
    }

    // Listen to Bluetooth adapter state changes
    FlutterBluePlus.adapterState.listen((BluetoothAdapterState state) {
      print('BluetoothAdapterState: $state');
      if (state == BluetoothAdapterState.on) {
        _bluetoothEnabled = true;
        _getAvailablePorts();
        print('start Scanning');
      } else {
        _bluetoothEnabled = false;
        print('Bluetooth is off');
      }
      setState(() {}); // Update UI based on Bluetooth state
    });

    // Turn on Bluetooth if possible (Android only)
    if (Platform.isAndroid) {
      try {
        await FlutterBluePlus.turnOn();
      } catch (e) {
        print("Error turning on Bluetooth: $e");
      }
    }
  }

  _getAvailablePorts() async {
    if (!_bluetoothEnabled) {
      print("Bluetooth is not enabled. Cannot scan for devices.");
      return;
    }

    scanning = true;
    setState(() {}); // Update UI to show scanning indicator

    try {
      // Listen to scan results
      _scanSubscription = FlutterBluePlus.scanResults.listen((results) {
        // Process scan results here
        setState(() {
          // Create a unique list of device names/IDs
          availablePorts =
              results
                  .map((result) => result.device.name.isNotEmpty ? result.device.name : result.device.id.id)
                  .toSet() // Convert to Set to remove duplicates
                  .toList(); // Convert back to List

          // Reset selectedPort if it's no longer in the list
          if (selectedPort.isNotEmpty && !availablePorts.contains(selectedPort)) {
            selectedPort = '';
          }
        });
      });

      await FlutterBluePlus.startScan(timeout: Duration(seconds: 4), androidUsesFineLocation: true);
    } catch (e) {
      print("Error during Bluetooth scan: $e");
    } finally {
      scanning = false;
      setState(() {}); // Update UI to hide scanning indicator
    }
  }

  @override
  void dispose() {
    if (_scanSubscription != null) {
      FlutterBluePlus.cancelWhenScanComplete(_scanSubscription!);
    }
    super.dispose();
  }

  _testConnection() {}
  _cancelTesting() {}
  _startConnection() {
    // establish connection to the selected port

    print(selectedPort);
    selectedPort.connect();

    // Simulate a connection test
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        ListTile(
          title: Text('Serial Ports:'),
          subtitle: Text('Get Information from Device...'),
          trailing: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              DropdownButton<String>(
                value: selectedPort.isNotEmpty ? selectedPort : null,
                hint: Text("Select Port"),
                onChanged: (String? value) {
                  if (value == null) return;
                  setState(() {
                    selectedPort = value;
                  });
                },
                items:
                    availablePorts.map<DropdownMenuItem<String>>((String value) {
                      return DropdownMenuItem<String>(value: value, child: Text(value));
                    }).toList(),
              ),
              IconButton(icon: Icon(Icons.refresh), onPressed: _refreshAvailable),
            ],
          ),
        ),
        ListTile(
          title: Text('Baud Rate: '),
          subtitle: Text('Get Information from Device...'),
          trailing: DropdownButton<int>(
            value: baudeRate,
            hint: Text("Select Baud Rate"),
            onChanged: (int? value) {
              setState(() {
                baudeRate = value;
              });
            },
            items:
                baudeRates.map<DropdownMenuItem<int>>((int value) {
                  return DropdownMenuItem<int>(value: value, child: Text(value.toString()));
                }).toList(),
          ),
        ),
        Row(
          mainAxisAlignment: MainAxisAlignment.end,
          children: [if (testing) ElevatedButton(onPressed: _cancelTesting, child: Text('Cancel testing')) else ElevatedButton(onPressed: baudeRate != null ? _startConnection : null, child: Text('TEST connection'))],
        ),
      ],
    );
  }

  _refreshAvailable() async {
    if (!_bluetoothEnabled) {
      print("Bluetooth is not enabled. Cannot refresh devices.");
      return;
    }

    // Clear the list and update the selection
    setState(() {
      availablePorts.clear();
      selectedPort = ''; // Reset selection when refreshing
    });

    scanning = true;
    setState(() {}); // Show scanning indicator

    try {
      // Make sure to clean up any previous subscription
      if (_scanSubscription != null) {
        _scanSubscription!.cancel();
      }

      // Create new subscription
      _scanSubscription = FlutterBluePlus.scanResults.listen((results) {
        setState(() {
          availablePorts = results.map((result) => result.device.platformName.isNotEmpty ? result.device.platformName : result.device.remoteId.str).toSet().toList();
        });
      });

      await FlutterBluePlus.startScan(timeout: Duration(seconds: 10), androidUsesFineLocation: true);
    } catch (e) {
      print("Error during Bluetooth scan: $e");
    } finally {
      scanning = false;
      setState(() {}); // Hide scanning indicator
    }
  }
}
