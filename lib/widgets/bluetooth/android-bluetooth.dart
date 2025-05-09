import 'package:flutter/foundation.dart' show kIsWeb;
// Conditionally import dart:io (not available on web)
import 'dart:io' if (dart.library.html) 'package:terrestrial_forest_monitor/widgets/bluetooth/web_stub.dart';

import 'package:flutter/material.dart';
import 'package:terrestrial_forest_monitor/widgets/bluetooth/android-bluetooth-ble.dart';
import 'package:terrestrial_forest_monitor/widgets/bluetooth/android-bluetooth-classic.dart';
import 'package:terrestrial_forest_monitor/widgets/bluetooth/windows-bluetooth-ble.dart';

class BluetoothSetup extends StatefulWidget {
  const BluetoothSetup({super.key});

  @override
  State<BluetoothSetup> createState() => _BluetoothSetupState();
}

class _BluetoothSetupState extends State<BluetoothSetup> {
  @override
  Widget build(BuildContext context) {
    // Handle web platform specifically
    if (kIsWeb) {
      return SizedBox(height: 200, child: Center(child: Text('Bluetooth is not supported on web')));
    }

    // For non-web platforms, use Platform checks
    return Column(children: [if (Platform.isWindows) WindowsBluetoothBle(), Divider(), if (!Platform.isWindows) AndroidBluetoothBle(), Divider(), if (!Platform.isWindows) AndroidBluetoothClassic()]);
  }
}
