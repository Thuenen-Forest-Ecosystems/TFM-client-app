import 'package:flutter/material.dart';
import 'package:terrestrial_forest_monitor/providers/gps-position.dart';
import 'package:provider/provider.dart';

class GpsButton extends StatefulWidget {
  const GpsButton({super.key});
  @override
  State<GpsButton> createState() => _GpsButtonState();
}

class _GpsButtonState extends State<GpsButton> {
  @override
  Widget build(BuildContext context) {
    return IconButton(
      icon: Consumer<GpsPositionProvider>(builder: (context, GpsPositionProvider gps, child) {
        return Icon(
          gps.listeningPosition ? Icons.gps_fixed : Icons.gps_not_fixed,
        );
      }),
      color: Color.fromARGB(255, 27, 27, 27),
      onPressed: context.read<GpsPositionProvider>().toggleGps,
    );
  }
}
