import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';

class SubplotLayers {
  /// Build CircleLayer for subplots
  static CircleLayer buildCircleLayer(
    List<Map<String, dynamic>> subplotPositions, {
    bool withOpacity = false,
  }) {
    return CircleLayer(
      circles: subplotPositions.map((subplot) {
        final lat = subplot['lat'] as double;
        final lng = subplot['lng'] as double;
        final radius = subplot['radius'] as num;

        return CircleMarker(
          point: LatLng(lat, lng),
          radius: radius.toDouble(),
          useRadiusInMeter: true,
          color: withOpacity
              ? const Color.fromARGB(40, 255, 152, 0) // Orange with opacity for previous
              : const Color.fromARGB(80, 255, 152, 0), // Orange for current
          borderColor: withOpacity
              ? const Color.fromARGB(100, 255, 152, 0)
              : const Color.fromARGB(200, 255, 152, 0),
          borderStrokeWidth: 2.0,
        );
      }).toList(),
    );
  }

  /// Build MarkerLayer for subplot labels
  static MarkerLayer buildMarkerLayer(
    List<Map<String, dynamic>> subplotPositions, {
    bool withOpacity = false,
  }) {
    return MarkerLayer(
      markers: subplotPositions.map((subplot) {
        final lat = subplot['lat'] as double;
        final lng = subplot['lng'] as double;
        final parentTable = subplot['parent_table'] as String?;
        final radius = subplot['radius'] as num;

        final label = parentTable != null ? parentTable : 'subplot';

        return Marker(
          point: LatLng(lat, lng),
          width: 80,
          height: 24,
          alignment: Alignment.center,
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 2),
            decoration: BoxDecoration(
              color: withOpacity ? Colors.white.withOpacity(0.6) : Colors.white.withOpacity(0.85),
              borderRadius: BorderRadius.circular(4),
              border: Border.all(color: const Color.fromARGB(150, 255, 152, 0), width: 1),
            ),
            child: Text(
              '$label (${radius}m)',
              style: TextStyle(
                color: withOpacity ? Colors.black54 : Colors.black,
                fontSize: 10,
                fontWeight: FontWeight.bold,
              ),
              textAlign: TextAlign.center,
              overflow: TextOverflow.ellipsis,
              maxLines: 1,
            ),
          ),
        );
      }).toList(),
    );
  }
}
