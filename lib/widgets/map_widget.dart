import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:flutter_map_marker_cluster/flutter_map_marker_cluster.dart';
import 'package:latlong2/latlong.dart';
import 'package:terrestrial_forest_monitor/repositories/records_repository.dart';

class MapWidget extends StatefulWidget {
  final LatLng? initialCenter;
  final double? initialZoom;

  const MapWidget({super.key, this.initialCenter, this.initialZoom});

  @override
  State<MapWidget> createState() => _MapWidgetState();
}

class _MapWidgetState extends State<MapWidget> {
  List<Record> _records = [];

  @override
  void initState() {
    super.initState();
    _loadRecords();
  }

  Future<void> _loadRecords() async {
    try {
      // Load only grouped records (one per cluster) to reduce memory usage
      final records = await RecordsRepository().getRecordsGroupedByCluster(limit: 10000);

      if (mounted) {
        setState(() {
          _records = records;
        });
      }
    } catch (e) {
      print('Error loading records for map: $e');
    }
  }

  List<Marker> _buildMarkers(List<Record> records) {
    // Filter records to only those with coordinates to reduce processing
    final recordsWithCoords = records.where((record) => record.getCoordinates() != null).toList();

    return recordsWithCoords
        .map((record) {
          final coords = record.getCoordinates()!;
          final lat = coords['latitude'];
          final lng = coords['longitude'];
          if (lat == null || lng == null) {
            return null;
          }
          return Marker(point: LatLng(lat, lng), child: Container(width: 10, height: 10, decoration: const BoxDecoration(color: Colors.red, shape: BoxShape.circle)));
        })
        .where((marker) => marker != null)
        .cast<Marker>()
        .toList();
  }

  @override
  Widget build(BuildContext context) {
    final markers = _buildMarkers(_records);

    return FlutterMap(
      options: MapOptions(
        initialCenter: widget.initialCenter ?? const LatLng(51.1657, 10.4515), // Center on Germany
        initialZoom: widget.initialZoom ?? 5.5,
        interactionOptions: const InteractionOptions(flags: InteractiveFlag.all),
      ),
      children: [
        // OSM Tile Layer
        TileLayer(urlTemplate: 'https://tile.openstreetmap.org/{z}/{x}/{y}.png', userAgentPackageName: 'com.thuenen.terrestrial_forest_monitor'),

        // Clustered Markers from records
        if (markers.isNotEmpty)
          MarkerClusterLayerWidget(
            options: MarkerClusterLayerOptions(
              markers: markers,
              builder: (context, markers) {
                return Container(decoration: BoxDecoration(borderRadius: BorderRadius.circular(20), color: Colors.blue), child: Center(child: Text(markers.length.toString(), style: const TextStyle(color: Colors.white, fontSize: 12))));
              },
            ),
          ),
      ],
    );
  }
}
