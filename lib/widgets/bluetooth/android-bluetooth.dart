import 'dart:async';
import 'dart:io'; // Import dart:io for platform checks


import 'package:flutter/material.dart';
import 'package:terrestrial_forest_monitor/widgets/bluetooth/android-bluetooth-ble.dart';
import 'package:terrestrial_forest_monitor/widgets/bluetooth/android-bluetooth-classic.dart';
import 'package:terrestrial_forest_monitor/widgets/bluetooth/windows-bluetooth-ble.dart';

// instead of import 'package:flutter_blue_plus/flutter_blue_plus.dart'; https://pub.dev/packages/flutter_blue_plus_windows
//import 'package:flutter_blue_plus_windows/flutter_blue_plus_windows.dart';

// Alternatively, you can hide FlutterBluePlus when importing the FBP statement
//import 'package:flutter_blue_plus/flutter_blue_plus.dart' hide FlutterBluePlus;
//import 'package:flutter_blue_plus_windows/flutter_blue_plus_windows.dart';

class AndroidBluetooth extends StatefulWidget {
  const AndroidBluetooth({super.key});

  @override
  State<AndroidBluetooth> createState() => _AndroidBluetoothState();
}

class _AndroidBluetoothState extends State<AndroidBluetooth> {
  @override
  Widget build(BuildContext context) {
    return Column(children: [
      if(Platform.isWindows) WindowsBluetoothBle(),
      if(!Platform.isWindows) AndroidBluetoothBle(),
    if (!Platform.isWindows) AndroidBluetoothClassic(),
    ]); // ,AndroidBluetoothBle(),AndroidBluetoothClassic()
  }
}
