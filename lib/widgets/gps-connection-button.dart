import 'dart:async';

import 'package:flutter/material.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:geolocator/geolocator.dart';
import 'package:terrestrial_forest_monitor/providers/gps-position.dart';
import 'package:provider/provider.dart';

// https://pub.dev/packages/flutter_bluetooth_serial
import 'package:flutter_libserialport/flutter_libserialport.dart';

class GpsConnectionButton extends StatefulWidget {
  const GpsConnectionButton({super.key});

  @override
  State<GpsConnectionButton> createState() => _GpsConnectionButtonState();
}

extension IntToString on int {
  String toHex() => '0x${toRadixString(16)}';
  String toPadded([int width = 3]) => toString().padLeft(width, '0');
  String toTransport() {
    switch (this) {
      case SerialPortTransport.usb:
        return 'USB';
      case SerialPortTransport.bluetooth:
        return 'Bluetooth';
      case SerialPortTransport.native:
        return 'Native';
      default:
        return 'Unknown';
    }
  }
}

class _GpsConnectionButtonState extends State<GpsConnectionButton> {
  Position? currentPosition;
  bool streaming = false;

  List<String> availablePorts = [];

  final LocationSettings locationSettings = LocationSettings(accuracy: LocationAccuracy.high, distanceFilter: 100);
  StreamSubscription<Position>? positionStream;

  @override
  void initState() {
    super.initState();
  }

  void _start_flutter_bluetooth_serial() async {
    print('Start flutter_bluetooth_serial');
    setState(() => availablePorts = SerialPort.availablePorts);
    print('Available ports: $availablePorts');
  }

  void read(ports) {
    SerialPortReader reader = SerialPortReader(ports[2]);
    reader.stream.listen((data) {
      print('Data: $data');
    });
  }

  void _toggleStream() {
    if (streaming) {
      positionStream?.cancel();
      streaming = false;
    } else {
      _requestPermissions();
      positionStream = Geolocator.getPositionStream(locationSettings: locationSettings)
          .handleError((error) {
            print(error);
          })
          .listen((Position? position) {
            context.read<GpsPositionProvider>().setPosition(position);

            if (position != null) {
              setState(() {
                currentPosition = position;
              });
            }
          });
      streaming = true;
    }
    setState(() {});
  }

  Future<bool> _requestPermissions() async {
    var status = await Permission.location.request();
    if (status.isGranted) {
      return true;
    } else if (status.isDenied) {
      // Handle the case when the user denied the permission
      return false;
    } else if (status.isPermanentlyDenied) {
      // Handle the case when the user permanently denied the permission
      openAppSettings();
      return false;
    }
    return false;
  }

  @override
  Widget build(BuildContext context) {
    return IconButton(onPressed: _start_flutter_bluetooth_serial, icon: Icon(streaming ? Icons.gps_fixed : Icons.gps_not_fixed));
  }
}
