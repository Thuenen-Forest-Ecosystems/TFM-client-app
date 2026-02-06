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
  /// Shows old DBH in previousColor by default
  /// Shows new DBH in currentColor when it has been updated
  static MarkerLayer buildMarkerLayer(
    List<Map<String, dynamic>> treePositions,
    Set<String> treeLabelFields, {
    bool withOpacity = false,
    List<Map<String, dynamic>>? previousTreePositions,
    Map<String, Color>? intervalColorCache,
    Map<int, String>? treeSpeciesLookup,
  }) {
    // Create a lookup map for previous tree data by tree_number
    final Map<int, Map<String, dynamic>> previousTreeMap = {};
    if (previousTreePositions != null) {
      for (var prevTree in previousTreePositions) {
        final treeNumber = prevTree['tree_number'];
        if (treeNumber != null) {
          previousTreeMap[treeNumber as int] = prevTree;
        }
      }
    }

    final previousColor = intervalColorCache?['previousColor'] ?? Color.fromARGB(255, 0, 159, 224);
    final currentColor = intervalColorCache?['currentColor'] ?? Color.fromARGB(255, 213, 123, 22);

    return MarkerLayer(
      markers: treePositions
          .map((tree) {
            final lat = tree['lat'] as double;
            final lng = tree['lng'] as double;
            final treeNumber = tree['tree_number'];

            // Build label text from selected fields
            final labelParts = <String>[];
            Color dbhColor = Colors.white; // Default color

            // Add tree number (if selected)
            if (treeLabelFields.contains('tree_number') && treeNumber != null) {
              labelParts.add('#${treeNumber}');
            }

            // Add DBH with color logic (if selected)
            if (treeLabelFields.contains('dbh')) {
              final currentDbh = tree['dbh'];
              final previousTree = treeNumber != null ? previousTreeMap[treeNumber as int] : null;
              final previousDbh = previousTree?['dbh'];

              if (currentDbh != null) {
                // Current tree has DBH - check if it's different from previous
                if (previousDbh != null && currentDbh != previousDbh) {
                  // DBH has changed - show new DBH in current color
                  labelParts.add('${(currentDbh as num).toInt()}mm');
                  dbhColor = currentColor;
                } else if (previousDbh != null) {
                  // DBH unchanged - show in previous color
                  labelParts.add('${(currentDbh as num).toInt()}mm');
                  dbhColor = previousColor;
                } else {
                  // No previous DBH - this is new, show in current color
                  labelParts.add('${(currentDbh as num).toInt()}mm');
                  dbhColor = currentColor;
                }
              } else if (previousDbh != null) {
                // No current DBH but has previous - show previous DBH in previous color
                labelParts.add('${(previousDbh as num).toInt()}mm');
                dbhColor = previousColor;
              }
            }

            // Add tree species code (if selected)
            if (treeLabelFields.contains('tree_species_code') && tree['tree_species'] != null) {
              final speciesCode = tree['tree_species'];
              labelParts.add('$speciesCode');
            }

            // Add tree species name (if selected)
            if (treeLabelFields.contains('tree_species_name') && tree['tree_species'] != null) {
              final speciesCode = tree['tree_species'];
              if (treeSpeciesLookup != null && speciesCode is int) {
                // Use species name from lookup if available
                final speciesName = treeSpeciesLookup[speciesCode];
                if (speciesName != null) {
                  labelParts.add(speciesName);
                }
                // If name not found, don't add anything (user selected name, not code)
              }
            }

            final labelText = labelParts.join(' | ');
            if (labelText.isEmpty) {
              return null;
            }

            return Marker(
              point: LatLng(lat, lng),
              width: 150,
              height: 16,
              alignment: Alignment.bottomCenter,
              child: Align(
                alignment: Alignment.bottomCenter,
                child: IntrinsicWidth(
                  child: Container(
                    padding: const EdgeInsets.only(left: 4, right: 4, top: 2, bottom: 2),
                    decoration: BoxDecoration(
                      color: Colors.black45.withOpacity(0.9),
                      borderRadius: BorderRadius.circular(4),
                      border: Border.all(color: dbhColor, width: 1),
                    ),
                    child: Text(
                      labelText,
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.bold,
                        color: dbhColor,
                        decoration: TextDecoration.none,
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
