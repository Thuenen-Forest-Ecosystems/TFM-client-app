import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';

/// Helper class for rendering WZP boundary circles (Grenzkreis) on the map
class TreeCrownLayers {
  /// Build a circle layer showing Grenzkreisradius (boundary circle for WZP/angle count sampling)
  ///
  /// Grenzkreisradius formula: ((dbh * (1.0 + (0.0011 * (dbh_height - 130)))) / 10 / 4 * 100) * 1.02
  /// dbh_height is the height at which DBH was measured in cm
  /// dbh is the millimeter diameter at breast height
  /// Where:
  /// - dbh is already corrected for measurement height in tree positions
  /// - Formula result is in cm, converted to meters for map rendering
  static CircleLayer buildCrownCircleLayer(
    List<Map<String, dynamic>> treePositions, {
    bool withOpacity = false,
    Color? crownColor,
    Color? borderColor,
    double borderStrokeWidth = 1.0,
  }) {
    final circles = treePositions
        .where((tree) {
          final dbh = tree['dbh'];
          return dbh != null && dbh > 0;
        })
        .map((tree) {
          final lat = tree['lat'] as double;
          final lng = tree['lng'] as double;
          final dbh = (tree['dbh'] as num).toDouble(); // DBH in mm (already corrected)

          // Calculate Grenzkreisradius (boundary circle radius) for WZP in meters
          // Formula result in cm: ((dbh / 10) / 4 * 100) * 1.02 = (dbh * 2.5) * 1.02 = dbh * 2.55
          // Convert cm to meters: (dbh * 2.55) / 100 = dbh * 0.0255
          final grenzkreisRadiusMeters = dbh * 0.0255;

          return CircleMarker(
            point: LatLng(lat, lng),
            radius: grenzkreisRadiusMeters,
            useRadiusInMeter: true,
            color: withOpacity
                ? (crownColor ?? Colors.green.withOpacity(0.15))
                : (crownColor ?? Colors.green.withOpacity(0.2)),
            borderColor: withOpacity
                ? (borderColor ?? Colors.green.withOpacity(0.3))
                : (borderColor ?? Colors.green.withOpacity(0.5)),
            borderStrokeWidth: borderStrokeWidth,
          );
        })
        .toList();

    return CircleLayer(circles: circles);
  }

  /// Build a circle layer with custom Grenzkreis multiplier
  /// Allows adjusting boundary circle size display
  static CircleLayer buildCrownCircleLayerWithMultiplier(
    List<Map<String, dynamic>> treePositions,
    double multiplier, {
    bool withOpacity = false,
    Color? crownColor,
    Color? borderColor,
    double borderStrokeWidth = 1.0,
  }) {
    final circles = treePositions
        .where((tree) {
          final dbh = tree['dbh'];
          return dbh != null && dbh > 0;
        })
        .map((tree) {
          final lat = tree['lat'] as double;
          final lng = tree['lng'] as double;
          final dbh = (tree['dbh'] as num).toDouble(); // DBH in mm (already corrected)

          // Calculate Grenzkreisradius (boundary circle radius) for WZP in meters with multiplier
          final grenzkreisRadiusMeters = dbh * 0.0255 * multiplier;

          return CircleMarker(
            point: LatLng(lat, lng),
            radius: grenzkreisRadiusMeters,
            useRadiusInMeter: true,
            color: withOpacity
                ? (crownColor ?? Colors.green.withOpacity(0.15))
                : (crownColor ?? Colors.green.withOpacity(0.2)),
            borderColor: withOpacity
                ? (borderColor ?? Colors.green.withOpacity(0.3))
                : (borderColor ?? Colors.green.withOpacity(0.5)),
            borderStrokeWidth: borderStrokeWidth,
          );
        })
        .toList();

    return CircleLayer(circles: circles);
  }
}
