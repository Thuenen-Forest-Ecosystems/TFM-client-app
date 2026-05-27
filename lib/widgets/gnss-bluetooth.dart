import 'package:flutter/material.dart';
import 'package:flutter_blue_plus/flutter_blue_plus.dart';

class GnssBluetooth extends StatefulWidget {
  const GnssBluetooth({super.key});

  @override
  State<GnssBluetooth> createState() => _GnssBluetoothState();
}

class _GnssBluetoothState extends State<GnssBluetooth> {
  List<BluetoothDevice> devices = [];
  String remoteID = 'F8256438-D5D2-457B-28E4-0A23DD0F6DEA-NONE';
  bool _connected = false;

  BluetoothDevice? _dearchForDeviceByID() {
    for (var device in devices) {
      if (device.remoteId.toString() == remoteID) {
        return device;
      }
    }
    return null;
  }

  Future<void> _searchDevices() async {
    // Use FlutterBluePlus directly without instance
    await FlutterBluePlus.startScan(timeout: const Duration(seconds: 20));
    FlutterBluePlus.scanResults.listen((results) {
      setState(() {
        devices = results.map((r) => r.device).toList();
      });
      BluetoothDevice? device = _dearchForDeviceByID();
      if (device != null && !_connected) {
        _connected = true;
        // Connect to the device
        device
            .connect()
            .then((_) {
              // Perform any additional actions after connecting
            })
            .catchError((error) {
            });
      } else {
      }
    });
  }

  @override
  void initState() {
    // TODO: implement initState
    super.initState();
    _searchDevices();
  }

  @override
  Widget build(BuildContext context) {
    return Container();
  }
}
