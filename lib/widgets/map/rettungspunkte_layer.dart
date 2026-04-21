import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';

class RettungspunktePoint {
  final String id;
  final double lat;
  final double lng;

  const RettungspunktePoint({required this.id, required this.lat, required this.lng});
}

class RettungspunkteLayers {
  /// Parse raw CSV string (runs in isolate via compute()).
  /// Expects header: RP_Nr,WGS_Breite,WGS_Laenge
  static List<RettungspunktePoint> parseCsv(String csv) {
    final lines = csv.split('\n');
    final List<RettungspunktePoint> points = [];

    for (int i = 1; i < lines.length; i++) {
      final line = lines[i].trim();
      if (line.isEmpty) continue;

      final parts = line.split(',');
      if (parts.length < 3) continue;

      final id = parts[0].trim();
      final lat = double.tryParse(parts[1].trim());
      final lng = double.tryParse(parts[2].trim());

      if (lat != null && lng != null) {
        points.add(RettungspunktePoint(id: id, lat: lat, lng: lng));
      }
    }

    return points;
  }

  static const Color _orange = Color.fromARGB(255, 255, 140, 0);

  /// Build a CircleLayer with rescue point dots (shown at all zoom levels).
  static CircleLayer buildCircleLayer(List<RettungspunktePoint> points) {
    return CircleLayer(
      circles: points
          .map(
            (p) => CircleMarker(
              point: LatLng(p.lat, p.lng),
              radius: 6,
              color: _orange.withOpacity(0.85),
              borderColor: Colors.white,
              borderStrokeWidth: 1.5,
            ),
          )
          .toList(),
    );
  }

  /// Build a MarkerLayer with RP_Nr labels (shown at zoom >= 13).
  static MarkerLayer buildLabelLayer(List<RettungspunktePoint> points) {
    return MarkerLayer(
      markers: points
          .map(
            (p) => Marker(
              point: LatLng(p.lat, p.lng),
              width: 140,
              height: 44,
              alignment: Alignment.bottomCenter,
              child: Align(
                alignment: Alignment.bottomCenter,
                child: Padding(
                  padding: const EdgeInsets.only(bottom: 30),
                  child: IntrinsicWidth(
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 2),
                      decoration: BoxDecoration(
                        color: Colors.black.withOpacity(0.9),
                        borderRadius: BorderRadius.circular(4),
                        border: Border.all(color: _orange, width: 1),
                      ),
                      child: Text(
                        p.id,
                        style: const TextStyle(
                          fontSize: 10,
                          fontWeight: FontWeight.bold,
                          color: _orange,
                          decoration: TextDecoration.none,
                        ),
                        overflow: TextOverflow.ellipsis,
                        textAlign: TextAlign.center,
                        maxLines: 1,
                      ),
                    ),
                  ),
                ),
              ),
            ),
          )
          .toList(),
    );
  }
}
