import 'dart:async';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:latlong2/latlong.dart';
import 'dart:math' as math;
import 'package:terrestrial_forest_monitor/repositories/records_repository.dart' as repo;
import 'package:terrestrial_forest_monitor/providers/map_controller_provider.dart';
import 'package:terrestrial_forest_monitor/providers/gps-position.dart';

/// Widget for navigating to previous position measurements
/// Displays a list of previous positions from previousProperties.plot_coordinates and
/// previousPositionData, allowing selection to show a distance line from current GPS position
class PreviousPositionsNavigation extends StatefulWidget {
  final repo.Record? rawRecord;

  const PreviousPositionsNavigation({super.key, this.rawRecord});

  @override
  State<PreviousPositionsNavigation> createState() => _PreviousPositionsNavigationState();
}

class _PreviousPositionsNavigationState extends State<PreviousPositionsNavigation> {
  String? _selectedPositionKey;
  List<String> _positionKeys = [];
  Map<String, LatLng> _positionCoordinates = {};
  StreamSubscription? _gpsSubscription;

  @override
  void initState() {
    super.initState();
    _loadPositionData();
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _subscribeToGPS();
  }

  void _subscribeToGPS() {
    if (_gpsSubscription != null) return;

    try {
      final gpsProvider = context.read<GpsPositionProvider>();
      _gpsSubscription = gpsProvider.positionStreamController.listen((position) {
        // Update distance line if a target is selected
        if (_selectedPositionKey != null) {
          _showDistanceLineToPosition(_selectedPositionKey!);
        }
      });
    } catch (e) {
      debugPrint('Error subscribing to GPS: $e');
    }
  }

  void _loadPositionData() {
    // First, add current record position as default target
    final recordCoords = widget.rawRecord?.getCoordinates();
    if (recordCoords != null) {
      final lat = recordCoords['latitude'];
      final lng = recordCoords['longitude'];
      if (lat != null && lng != null) {
        _positionKeys.add('Aktuelle Position');
        _positionCoordinates['Aktuelle Position'] = LatLng(lat, lng);
      }
    }

    // Add SOLL coordinates from previous_properties.position.position_mean.coordinates
    if (widget.rawRecord?.previousProperties != null) {
      final previousProperties = widget.rawRecord!.previousProperties!;

      // Extract SOLL coordinates
      final position = previousProperties['position'];
      if (position is Map<String, dynamic>) {
        final positionMean = position['position_mean'];
        if (positionMean is Map<String, dynamic>) {
          final coordinates = positionMean['coordinates'];
          if (coordinates is Map<String, dynamic>) {
            final lat = _extractDouble(coordinates['latitude']);
            final lng = _extractDouble(coordinates['longitude']);
            if (lat != null && lng != null) {
              _positionKeys.add('SOLL Koordinaten');
              _positionCoordinates['SOLL Koordinaten'] = LatLng(lat, lng);
            }
          }
        }
      }

      // Extract positions from previousProperties.plot_coordinates
      final plotCoordinates = previousProperties['plot_coordinates'];
      if (plotCoordinates is Map<String, dynamic>) {
        // Iterate through all keys in plot_coordinates (measurement periods)
        plotCoordinates.forEach((key, value) {
          if (value is Map<String, dynamic>) {
            final coords = _extractCoordinates(value);
            if (coords != null) {
              _positionKeys.add(key);
              _positionCoordinates[key] = coords;
            }
          }
        });
      }
    }

    // Also extract positions from previousPositionData (e.g., bwi2012, bwi2022)
    if (widget.rawRecord?.previousPositionData != null) {
      final previousPositionData = widget.rawRecord!.previousPositionData!;

      previousPositionData.forEach((key, value) {
        if (value is Map<String, dynamic>) {
          // Try to extract from latitude_mean/longitude_mean first (preferred for position data)
          final latMean = _extractDouble(value['latitude_mean']);
          final lngMean = _extractDouble(value['longitude_mean']);

          if (latMean != null && lngMean != null) {
            // Only add if not already present from plot_coordinates
            if (!_positionKeys.contains(key)) {
              _positionKeys.add(key);
            }
            _positionCoordinates[key] = LatLng(latMean, lngMean);
          } else {
            // Fallback to center_location or direct lat/lng
            final coords = _extractCoordinates(value);
            if (coords != null && !_positionKeys.contains(key)) {
              _positionKeys.add(key);
              _positionCoordinates[key] = coords;
            }
          }
        }
      });
    }

    // Set current position as default selection if available
    if (_positionKeys.contains('Aktuelle Position') && _selectedPositionKey == null) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) {
          setState(() {
            _selectedPositionKey = 'Aktuelle Position';
          });
          _showDistanceLineToPosition('Aktuelle Position');
        }
      });
    }
  }

  /// Extract coordinates from position data
  LatLng? _extractCoordinates(Map<String, dynamic> positionData) {
    try {
      // Try to extract from center_location or similar structure
      final centerLocation = positionData['center_location'];
      if (centerLocation is Map<String, dynamic>) {
        final lat = _extractDouble(centerLocation['latitude']);
        final lng = _extractDouble(centerLocation['longitude']);
        if (lat != null && lng != null) {
          return LatLng(lat, lng);
        }
      }

      // Try direct latitude/longitude
      final lat = _extractDouble(positionData['latitude']);
      final lng = _extractDouble(positionData['longitude']);
      if (lat != null && lng != null) {
        return LatLng(lat, lng);
      }
    } catch (e) {
      debugPrint('Error extracting coordinates: $e');
    }
    return null;
  }

  /// Helper method to safely extract a double value
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
    final a =
        math.sin(dLat / 2) * math.sin(dLat / 2) +
        math.cos(_toRadians(lat1)) *
            math.cos(_toRadians(lat2)) *
            math.sin(dLon / 2) *
            math.sin(dLon / 2);
    final c = 2 * math.atan2(math.sqrt(a), math.sqrt(1 - a));
    return earthRadiusMeters * c;
  }

  /// Calculate bearing in gon (0-400)
  double _calculateBearing(double lat1, double lon1, double lat2, double lon2) {
    final dLon = _toRadians(lon2 - lon1);
    final y = math.sin(dLon) * math.cos(_toRadians(lat2));
    final x =
        math.cos(_toRadians(lat1)) * math.sin(_toRadians(lat2)) -
        math.sin(_toRadians(lat1)) * math.cos(_toRadians(lat2)) * math.cos(dLon);
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

  void _selectPosition(String positionKey) {
    setState(() {
      // Toggle selection - if already selected, clear it
      if (_selectedPositionKey == positionKey) {
        _selectedPositionKey = null;
        // Clear distance line
        final mapProvider = context.read<MapControllerProvider>();
        mapProvider.clearDistanceLine();
      } else {
        _selectedPositionKey = positionKey;
        // Show distance line to selected position
        _showDistanceLineToPosition(positionKey);
      }
    });
  }

  void _showDistanceLineToPosition(String positionKey) {
    final targetCoords = _positionCoordinates[positionKey];
    if (targetCoords == null) {
      debugPrint('No coordinates found for position: $positionKey');
      return;
    }

    // Get current GPS position
    final gpsProvider = context.read<GpsPositionProvider>();
    final currentPosition = gpsProvider.lastPosition;

    if (currentPosition == null) {
      debugPrint('No current GPS position available');
      // Show distance line from record's current position instead
      final recordCoords = widget.rawRecord?.getCoordinates();
      if (recordCoords != null) {
        final fromPosition = LatLng(recordCoords['latitude']!, recordCoords['longitude']!);
        final mapProvider = context.read<MapControllerProvider>();
        mapProvider.showDistanceLine(fromPosition, targetCoords);
      }
      return;
    }

    final fromPosition = LatLng(currentPosition.latitude, currentPosition.longitude);

    // Show distance line on map
    final mapProvider = context.read<MapControllerProvider>();
    mapProvider.showDistanceLine(fromPosition, targetCoords);

    debugPrint('Distance line set: from $fromPosition to $targetCoords');
  }

  Widget _buildNavigationItem({
    required IconData icon,
    required String label,
    required String value,
  }) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(borderRadius: BorderRadius.circular(8)),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            label,
            style: TextStyle(fontSize: 12, color: Colors.grey[600], fontWeight: FontWeight.w500),
          ),
          const SizedBox(height: 4),
          Text(value, style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold)),
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

  @override
  Widget build(BuildContext context) {
    final hasData =
        (widget.rawRecord?.previousProperties != null ||
        widget.rawRecord?.previousPositionData != null);

    if (!hasData || _positionKeys.isEmpty) {
      return Card(
        margin: const EdgeInsets.all(16.0),
        child: Padding(
          padding: const EdgeInsets.all(16.0),
          child: Text(
            'Keine vorherigen Positionsdaten verfügbar',
            style: Theme.of(context).textTheme.bodyMedium,
          ),
        ),
      );
    }

    // Filter to only show positions with valid coordinates
    final availablePositions = _positionKeys
        .where((key) => _positionCoordinates.containsKey(key))
        .toList();

    if (availablePositions.isEmpty) {
      return Card(
        margin: const EdgeInsets.all(16.0),
        child: Padding(
          padding: const EdgeInsets.all(16.0),
          child: Text(
            'Keine Koordinaten in vorherigen Positionsdaten gefunden',
            style: Theme.of(context).textTheme.bodyMedium,
          ),
        ),
      );
    }

    // Calculate distance and bearing if position is selected
    final gpsProvider = context.watch<GpsPositionProvider>();
    final userPosition = gpsProvider.lastPosition;
    double? distance;
    double? bearing;

    if (_selectedPositionKey != null && userPosition != null) {
      final targetCoords = _positionCoordinates[_selectedPositionKey];
      if (targetCoords != null) {
        distance = _calculateDistance(
          userPosition.latitude,
          userPosition.longitude,
          targetCoords.latitude,
          targetCoords.longitude,
        );
        bearing = _calculateBearing(
          userPosition.latitude,
          userPosition.longitude,
          targetCoords.latitude,
          targetCoords.longitude,
        );
      }
    }

    return Card(
      margin: const EdgeInsets.all(16.0),
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Navigation zu', style: Theme.of(context).textTheme.titleMedium),
            const SizedBox(height: 16.0),
            Wrap(
              spacing: 8.0,
              runSpacing: 8.0,
              children: availablePositions.map((key) {
                final isSelected = _selectedPositionKey == key;
                return ChoiceChip(
                  label: Text(key),
                  selected: isSelected,
                  showCheckmark: false,
                  onSelected: (_) => _selectPosition(key),
                );
              }).toList(),
            ),
            if (_selectedPositionKey != null) ...[
              const SizedBox(height: 16.0),
              if (distance != null && bearing != null) ...[
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                  children: [
                    Expanded(
                      child: _buildNavigationItem(
                        icon: Icons.straighten,
                        label: 'Distanz',
                        value: _formatDistance(distance),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: _buildNavigationItem(
                        icon: Icons.explore,
                        label: 'Richtung',
                        value: '${bearing.toStringAsFixed(1)} gon',
                      ),
                    ),
                  ],
                ),
              ] else ...[
                Center(
                  child: Padding(
                    padding: const EdgeInsets.all(10),
                    child: Column(
                      children: [
                        Text(
                          'Keine Navigationsdaten verfügbar, verbinde ein externes GPS oder nutze das interne GPS des Geräts.',
                          style: TextStyle(color: Colors.grey[600], fontSize: 14),
                          textAlign: TextAlign.center,
                        ),
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
                      ],
                    ),
                  ),
                ),
              ],
            ],
          ],
        ),
      ),
    );
  }

  @override
  void didUpdateWidget(PreviousPositionsNavigation oldWidget) {
    super.didUpdateWidget(oldWidget);
    final propertiesChanged =
        widget.rawRecord?.previousProperties != oldWidget.rawRecord?.previousProperties;
    final positionDataChanged =
        widget.rawRecord?.previousPositionData != oldWidget.rawRecord?.previousPositionData;

    if (propertiesChanged || positionDataChanged) {
      _positionKeys.clear();
      _positionCoordinates.clear();
      _loadPositionData();
      // Clear selection if data changed
      if (_selectedPositionKey != null) {
        final mapProvider = context.read<MapControllerProvider>();
        mapProvider.clearDistanceLine();
        _selectedPositionKey = null;
      }
    }
  }

  @override
  void dispose() {
    _gpsSubscription?.cancel();

    // Clear distance line when widget is disposed
    if (_selectedPositionKey != null && mounted) {
      try {
        final mapProvider = context.read<MapControllerProvider>();
        mapProvider.clearDistanceLine();
      } catch (e) {
        debugPrint('Error clearing distance line on dispose: $e');
      }
    }
    super.dispose();
  }
}
