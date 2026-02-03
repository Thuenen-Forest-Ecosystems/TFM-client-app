import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';

class TreeLayers {
  /// Build circle layer for tree positions
  static CircleLayer buildCircleLayer(
    List<Map<String, dynamic>> treePositions,
    double treeDiameterMultiplier, {
    bool withOpacity = false,
    bool showNull = true,
    Color? treeColor,
    Color? nullTreeColor,
  }) {
    return CircleLayer(
      circles: treePositions.map((tree) {
        final lat = tree['lat'] as double;
        final lng = tree['lng'] as double;
        final dbh = tree['dbh']; // DBH in millimeters

        if (!showNull && dbh == null) {
          return CircleMarker(
            point: LatLng(lat, lng),
            radius: 0,
            useRadiusInMeter: true,
            color: Colors.transparent,
            borderStrokeWidth: 0,
          );
        }

        // Calculate radius: DBH is in mm, convert to meters and divide by 2
        // Apply the diameter multiplier
        // If dbh is null, use a default visible radius of 0.5m (for visibility)
        final radiusMeters = dbh != null
            ? ((dbh as num).toDouble() / 1000.0 / 2.0) * treeDiameterMultiplier
            : 0.2;

        // Use provided colors or fall back to default colors
        final baseColor = dbh != null
            ? (treeColor ?? Color.fromARGB(255, 255, 255, 0)) // custom or yellow
            : (nullTreeColor ?? Colors.black); // custom or black for missing DBH

        return CircleMarker(
          point: LatLng(lat, lng),
          radius: radiusMeters,
          useRadiusInMeter: true,
          color: withOpacity ? baseColor.withOpacity(0.5) : baseColor,
          borderStrokeWidth: 0, // no border
        );
      }).toList(),
    );
  }

  /// Build marker layer for tree labels
  static MarkerLayer buildMarkerLayer(
    List<Map<String, dynamic>> treePositions,
    Set<String> treeLabelFields, {
    bool withOpacity = false,
  }) {
    /*if (treeLabelFields.isEmpty) {
      return MarkerLayer(markers: []);
    }*/

    return MarkerLayer(
      markers: treePositions
          .map((tree) {
            final lat = tree['lat'] as double;
            final lng = tree['lng'] as double;

            // Build label text from selected fields
            final labelParts = <String>[];

            //if (treeLabelFields.contains('tree_number')) {
            // Show placeholder '-' for missing tree number
            if (tree['tree_number'] != null) {
              labelParts.add('#${tree['tree_number']}');
            }
            //}
            //if (treeLabelFields.contains('dbh')) {
            // Show placeholder '-' for missing DBH values
            if (tree['dbh'] != null) {
              labelParts.add('${(tree['dbh'] as num).toInt()}mm');
            }
            //}
            //if (treeLabelFields.contains('tree_species')) {
            // Show placeholder '-' for missing species
            if (tree['tree_species'] != null) {
              labelParts.add('${tree['tree_species']}');
            }
            //}

            final labelText = labelParts.join(' | ');
            if (labelText.isEmpty) {
              return null;
            }

            return Marker(
              point: LatLng(lat, lng),
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
                          ? Colors.white.withOpacity(0.5)
                          : Colors.white.withOpacity(0.9),
                      borderRadius: BorderRadius.circular(4),
                    ),
                    child: Text(
                      labelText,
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        fontSize: 10,
                        fontWeight: FontWeight.bold,
                        color: withOpacity ? Colors.black.withOpacity(0.5) : Colors.black,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
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
