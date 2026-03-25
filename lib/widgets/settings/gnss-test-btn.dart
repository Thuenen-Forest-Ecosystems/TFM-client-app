import 'package:flutter/material.dart';
import 'package:terrestrial_forest_monitor/widgets/bluetooth-icon-combined.dart';

class GnssTestBtn extends StatelessWidget {
  const GnssTestBtn({super.key});

  @override
  Widget build(BuildContext context) {
    return ListTile(
      leading: const Icon(Icons.cable),
      title: const Text('GNSS-Verbindungstest'),
      subtitle: const Text('Verbindung zu einem GNSS-Gerät testen'),
      trailing: const Icon(Icons.arrow_forward_ios, size: 16),
      onTap: () {
        showModalBottomSheet(
          context: context,
          isDismissible: true,
          enableDrag: true,
          isScrollControlled: true,
          builder: (context) => const BluetoothDeviceMenuSheet(popOnConnect: false),
        );
      },
    );
  }
}
