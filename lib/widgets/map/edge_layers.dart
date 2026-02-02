import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';

class EdgeLayers {
  /// Build polyline layer for edges
  static PolylineLayer buildPolylineLayer(
    List<Map<String, dynamic>> edges, {
    bool withOpacity = false,
  }) {
    return PolylineLayer(
      polylines: edges
          .map<Polyline>(
            (edge) => Polyline(
              points: edge['points'] as List<LatLng>,
              color: withOpacity
                  ? const Color(0xFFC3E399).withOpacity(0.3)
                  : const Color(0xFFC3E399),
              strokeWidth: 2,
              pattern: StrokePattern.dashed(segments: [5.0, 5.0]),
              borderColor: withOpacity ? Colors.black.withOpacity(0.3) : Colors.black,
              borderStrokeWidth: 1,
            ),
          )
          .toList(),
    );
  }

  /// Build circle layer for edge vertices
  static CircleLayer buildCircleLayer(
    List<Map<String, dynamic>> edges, {
    bool withOpacity = false,
  }) {
    return CircleLayer(
      circles: edges.expand<CircleMarker>((edge) {
        final points = edge['points'] as List<LatLng>;
        return points.map(
          (p) => CircleMarker(
            point: p,
            radius: 3,
            color: withOpacity ? Colors.white.withOpacity(0.3) : Colors.white,
            borderColor: withOpacity ? Colors.black.withOpacity(0.3) : Colors.black,
            borderStrokeWidth: 1,
          ),
        );
      }).toList(),
    );
  }

  /// Build marker layer for edge labels
  static MarkerLayer buildMarkerLayer(
    List<Map<String, dynamic>> edges, {
    bool withOpacity = false,
  }) {
    return MarkerLayer(
      markers: edges
          .map<Marker?>((edge) {
            final points = edge['points'] as List<LatLng>;
            final id = edge['edge_number'];
            if (points.isEmpty || id == null) return null;

            return Marker(
              point: points.first,
              width: 150,
              height: 15,
              alignment: Alignment.bottomCenter,
              child: Align(
                alignment: Alignment.bottomCenter,
                child: IntrinsicWidth(
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 2),
                    decoration: BoxDecoration(
                      color: withOpacity
                          ? Colors.white.withOpacity(0.3)
                          : Colors.white.withOpacity(0.9),
                      borderRadius: BorderRadius.circular(4),
                    ),
                    child: Text(
                      '$id',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        fontSize: 10,
                        fontWeight: FontWeight.bold,
                        color: withOpacity ? Colors.black.withOpacity(0.3) : Colors.black,
                      ),
                    ),
                  ),
                ),
              ),
            );
          })
          .whereType<Marker>()
          .toList(),
    );
  }
}
