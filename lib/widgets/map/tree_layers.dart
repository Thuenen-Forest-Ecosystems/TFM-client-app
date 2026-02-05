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
    double borderStrokeWidth = 0.0,
    Color borderColor = Colors.black,
  }) {
    return CircleLayer(
      circles: treePositions.map((tree) {
        final lat = tree['lat'] as double;
        final lng = tree['lng'] as double;
        final dbh = tree['dbh']; // DBH in millimeters
        final status = tree['tree_status'];

        if (!showNull && dbh == null) {
          return CircleMarker(
            point: LatLng(lat, lng),
            radius: 0,
            useRadiusInMeter: true,
            color: Colors.transparent,
            borderStrokeWidth: borderStrokeWidth,
            borderColor: borderColor,
          );
        }

        // Calculate radius: DBH is in mm, convert to meters and divide by 2
        // Apply the diameter multiplier
        // If dbh is null, use a default visible radius of 0.5m (for visibility)
        final radius = dbh != null
            ? ((dbh as num).toDouble() / 1000.0 / 2.0) * treeDiameterMultiplier
            : 3.0; // 3 pixels if no DBH

        // Use provided colors or fall back to default colors
        Color baseColor = (treeColor ?? Color.fromARGB(255, 255, 255, 0));
        if (dbh == null) {
          if (![0, 1, 8, 1111].contains(status)) {
            baseColor = Colors.black;
          } else {
            baseColor = nullTreeColor ?? Colors.red;
          }
        }

        return CircleMarker(
          point: LatLng(lat, lng),
          radius: radius,
          useRadiusInMeter: dbh != null,
          color: baseColor,
          // borderStrokeWidth is always in pixels, independent of useRadiusInMeter which only applies to the radius
          borderStrokeWidth: dbh != null ? borderStrokeWidth : 0.0,
          borderColor: borderColor,
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
                      color: Colors.white.withOpacity(0.9),
                      borderRadius: BorderRadius.circular(4),
                    ),
                    child: Text(
                      labelText,
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        fontSize: 10,
                        fontWeight: FontWeight.bold,
                        color: Colors.black,
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

  /// Build invisible clickable marker layer for tree selection
  static MarkerLayer buildClickableLayer(
    List<Map<String, dynamic>> treePositions,
    Function(int treeNumber) onTreeTapped,
  ) {
    return MarkerLayer(
      markers: treePositions
          .map((tree) {
            final lat = tree['lat'] as double;
            final lng = tree['lng'] as double;
            final treeNumber = tree['tree_number'] as int?;

            if (treeNumber == null) return null;

            return Marker(
              point: LatLng(lat, lng),
              width: 40,
              height: 40,
              alignment: Alignment.center,
              child: GestureDetector(
                onTap: () => onTreeTapped(treeNumber),
                child: Container(width: 40, height: 40, color: Colors.transparent),
              ),
            );
          })
          .whereType<Marker>()
          .toList(),
    );
  }
}
