import 'package:flutter/material.dart';
import 'package:terrestrial_forest_monitor/providers/map-state.dart';
import 'package:provider/provider.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';

class MapNavigation extends StatefulWidget {
  const MapNavigation({super.key});

  @override
  State<MapNavigation> createState() => _MapNavigationState();
}

class _MapNavigationState extends State<MapNavigation> {
  @override
  Widget build(BuildContext context) {
    bool isDop = context.watch<MapState>().isDop;
    return Column(
      children: [
        if (dotenv.env.containsKey('DMZ_KEY'))
          RotatedBox(
            quarterTurns: 1,
            child: Switch(
              // This bool value toggles the switch.
              value: isDop,
              onChanged: (bool value) {
                context.read<MapState>().setDop(value);
              },
            ),
          ),
        Divider(
          color: Color.fromARGB(150, 27, 27, 27),
        ),
        IconButton(
          icon: const Icon(Icons.zoom_in),
          color: Color.fromARGB(255, 27, 27, 27),
          onPressed: () {
            context.read<MapState>().zoomIn();
          },
        ),
        IconButton(
          icon: const Icon(Icons.zoom_out),
          color: Color.fromARGB(255, 27, 27, 27),
          onPressed: () {
            context.read<MapState>().zoomOut();
          },
        ),
        Divider(
          color: Color.fromARGB(100, 27, 27, 27),
        ),
        IconButton(
          icon: Icon(context.read<MapState>().gps ? Icons.gps_fixed : Icons.gps_not_fixed),
          color: Color.fromARGB(255, 27, 27, 27),
          onPressed: () {
            context.read<MapState>().toggleGps();
          },
        ),
        Divider(
          color: Color.fromARGB(100, 27, 27, 27),
        ),
      ],
    );
  }
}
