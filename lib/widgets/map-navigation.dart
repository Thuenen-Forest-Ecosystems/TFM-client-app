import 'package:flutter/material.dart';
import 'package:geolocator/geolocator.dart';
import 'package:latlong2/latlong.dart';
import 'package:terrestrial_forest_monitor/providers/gps-position.dart';
import 'package:terrestrial_forest_monitor/providers/map-state.dart';
import 'package:provider/provider.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:terrestrial_forest_monitor/services/powersync.dart';

class MapNavigation extends StatefulWidget {
  final bool isDrawer;
  MapNavigation({super.key, this.isDrawer = false});

  @override
  State<MapNavigation> createState() => _MapNavigationState();
}

class _MapNavigationState extends State<MapNavigation> {
  int recordsCount = 0;

  Future<void> _countRecords() async {
    final result = await db.get('SELECT count(*) as count FROM records');
    recordsCount = result[0]['count'] ?? 0;
  }

  @override
  void initState() {
    super.initState();
    // Initialize the map state
    context.read<MapState>().getDop();
  }

  @override
  Widget build(BuildContext context) {
    bool isDop = context.watch<MapState>().isDop;

    _countRecords();

    return Column(
      mainAxisAlignment: MainAxisAlignment.end,
      mainAxisSize: MainAxisSize.min,
      children: [
        if (dotenv.env.containsKey('DMZ_KEY'))
          RotatedBox(
            quarterTurns: 1,
            child: Switch(
              value: isDop,
              onChanged: (bool value) {
                context.read<MapState>().setDop(value);
              },
            ),
          ),
        Divider(color: Color.fromARGB(150, 27, 27, 27)),

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
        Divider(color: Color.fromARGB(100, 27, 27, 27)),
        if (recordsCount > 0)
          IconButton(
            icon: const Icon(Icons.apps),
            color: Color.fromARGB(255, 27, 27, 27),
            onPressed: () {
              context.read<MapState>().setFocus();
            },
          ),
        IconButton(
          icon: const Icon(Icons.my_location),
          color: Color.fromARGB(255, 27, 27, 27),
          onPressed: () {
            Position? lastPosition = context.read<GpsPositionProvider>().lastPosition;
            if (lastPosition != null) {
              LatLng lastLatLng = LatLng(lastPosition.latitude, lastPosition.longitude);
              context.read<MapState>().moveToPoint(lastLatLng, null);
            }
          },
        ),
        //GpsButton(),
        Divider(color: Color.fromARGB(100, 27, 27, 27)),
        IconButton(
          icon: const Icon(Icons.close),
          color: Color.fromARGB(255, 27, 27, 27),
          onPressed: () {
            context.read<MapState>().closeMap();
          },
        ),
      ],
    );
  }
}
