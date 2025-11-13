import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:terrestrial_forest_monitor/providers/gps-position.dart';
import 'dart:math' as math;

class NavigationElement extends StatefulWidget {
  final Map<String, dynamic>? jsonSchema;
  final Map<String, dynamic>? data;
  final Map<String, dynamic>? previous_properties;
  final Function(Map<String, dynamic>)? onDataChanged;

  const NavigationElement({super.key, this.jsonSchema, this.data, this.previous_properties, this.onDataChanged});

  @override
  State<NavigationElement> createState() => _NavigationElementState();
}

class _NavigationElementState extends State<NavigationElement> {
  double? _extractDouble(dynamic value) {
    if (value == null) return null;
    if (value is double) return value;
    if (value is int) return value.toDouble();
    if (value is String) return double.tryParse(value);
    return null;
  }

  /// Calculate distance in meters using Haversine formula
  double _calculateDistance(double lat1, double lon1, double lat2, double lon2) {
    const earthRadiusMeters = 6371000.0;
    final dLat = _toRadians(lat2 - lat1);
    final dLon = _toRadians(lon2 - lon1);
    final a = math.sin(dLat / 2) * math.sin(dLat / 2) + math.cos(_toRadians(lat1)) * math.cos(_toRadians(lat2)) * math.sin(dLon / 2) * math.sin(dLon / 2);
    final c = 2 * math.atan2(math.sqrt(a), math.sqrt(1 - a));
    return earthRadiusMeters * c;
  }

  /// Calculate bearing in gon (0-400)
  double _calculateBearing(double lat1, double lon1, double lat2, double lon2) {
    final dLon = _toRadians(lon2 - lon1);
    final y = math.sin(dLon) * math.cos(_toRadians(lat2));
    final x = math.cos(_toRadians(lat1)) * math.sin(_toRadians(lat2)) - math.sin(_toRadians(lat1)) * math.cos(_toRadians(lat2)) * math.cos(dLon);
    final bearingRadians = math.atan2(y, x);
    final bearingDegrees = _toDegrees(bearingRadians);
    // Convert to 0-360 range
    final normalizedDegrees = (bearingDegrees + 360) % 360;
    // Convert degrees to gon (1 degree = 400/360 gon)
    return normalizedDegrees * (400 / 360);
  }

  double _toRadians(double degrees) {
    return degrees * math.pi / 180.0;
  }

  double _toDegrees(double radians) {
    return radians * 180.0 / math.pi;
  }

  @override
  Widget build(BuildContext context) {
    // Watch GPS provider to automatically rebuild when position changes
    final gpsProvider = context.watch<GpsPositionProvider>();
    final userPosition = gpsProvider.lastPosition;

    if (widget.previous_properties?['plot_coordinates'] == null) {
      return Center(child: Padding(padding: const EdgeInsets.all(16.0), child: Text('No plot coordinates available for navigation.', style: TextStyle(color: Colors.grey[600], fontSize: 16))));
    }

    // Calculate navigation in build method
    double? distance;
    double? bearing;

    if (widget.data != null && userPosition != null) {
      try {
        // Extract target coordinates from previous_properties.plot_coordinates.center_location
        final plotCoordinates = widget.previous_properties?['plot_coordinates'];
        if (plotCoordinates != null) {
          final centerLocation = plotCoordinates['center_location'];
          if (centerLocation != null) {
            double? targetLat;
            double? targetLng;

            // Handle GeoJSON Point format
            if (centerLocation is Map && centerLocation['type'] == 'Point' && centerLocation['coordinates'] is List) {
              final coords = centerLocation['coordinates'] as List;
              if (coords.length >= 2) {
                targetLng = _extractDouble(coords[0]);
                targetLat = _extractDouble(coords[1]);
              }
            }

            if (targetLat != null && targetLng != null) {
              distance = _calculateDistance(userPosition.latitude, userPosition.longitude, targetLat, targetLng);
              bearing = _calculateBearing(userPosition.latitude, userPosition.longitude, targetLat, targetLng);
            }
          }
        }
      } catch (e) {
        debugPrint('Error calculating navigation: $e');
      }
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Card(
          elevation: 4,
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(children: [const Text('Navigation')]),
                if (distance != null && bearing != null) ...[
                  _buildNavigationItem(icon: Icons.straighten, label: 'Distanz', value: _formatDistance(distance)),
                  const SizedBox(height: 12),
                  _buildNavigationItem(icon: Icons.explore, label: 'Richtung', value: '${bearing.toStringAsFixed(1)} gon'),
                ] else ...[
                  Center(
                    child: Padding(
                      padding: const EdgeInsets.all(16.0),
                      child: Column(
                        children: [
                          Icon(Icons.location_searching, size: 48, color: Colors.grey[400]),
                          const SizedBox(height: 8),
                          Text('Waiting for GPS position...', style: TextStyle(color: Colors.grey[600], fontSize: 16)),
                          const SizedBox(height: 16),
                          ElevatedButton.icon(
                            onPressed: () {
                              final gpsProvider = context.read<GpsPositionProvider>();
                              gpsProvider.setCurrentLocation();
                              if (!gpsProvider.listeningPosition) {
                                gpsProvider.startTrackingLocation();
                              }
                            },
                            icon: const Icon(Icons.gps_fixed),
                            label: const Text('Start GPS'),
                          ),
                          const SizedBox(height: 8),
                          if (userPosition == null && widget.data != null) Text('GPS position is null', style: TextStyle(color: Colors.red[400], fontSize: 12)),
                          if (userPosition != null && widget.data == null) Text('Data is null', style: TextStyle(color: Colors.red[400], fontSize: 12)),
                        ],
                      ),
                    ),
                  ),
                ],
              ],
            ),
          ),
        ),
        const SizedBox(height: 12),
        Card(
          elevation: 4,
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(children: [const Text('Plot Coordinates')]),
                const SizedBox(height: 12),
                _buildNavigationItem(icon: Icons.map, label: 'Koordinaten', value: widget.previous_properties?['plot_coordinates'] != null ? widget.previous_properties!['plot_coordinates'].toString() : 'N/A'),
              ],
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildNavigationItem({required IconData icon, required String label, required String value}) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(borderRadius: BorderRadius.circular(8)),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [Text(label, style: TextStyle(fontSize: 12, color: Colors.grey[600], fontWeight: FontWeight.w500)), const SizedBox(height: 4), Text(value, style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold))],
            ),
          ),
        ],
      ),
    );
  }

  String _formatDistance(double meters) {
    if (meters < 1000) {
      return '${meters.toStringAsFixed(1)} m';
    } else {
      return '${(meters / 1000).toStringAsFixed(2)} km';
    }
  }
}
