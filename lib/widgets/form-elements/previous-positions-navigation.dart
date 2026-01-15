import 'dart:async';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:latlong2/latlong.dart';
import 'dart:math' as math;
import 'package:terrestrial_forest_monitor/repositories/records_repository.dart' as repo;
import 'package:terrestrial_forest_monitor/providers/map_controller_provider.dart';
import 'package:terrestrial_forest_monitor/providers/gps-position.dart';
import 'package:terrestrial_forest_monitor/services/powersync.dart';

/// Widget for navigating to previous position measurements
/// Displays a list of previous positions from previousProperties.plot_coordinates and
/// previousPositionData, allowing selection to show a distance line from current GPS position
class PreviousPositionsNavigation extends StatefulWidget {
  final repo.Record? rawRecord;
  final Map<String, dynamic>? jsonSchema;

  const PreviousPositionsNavigation({super.key, this.rawRecord, this.jsonSchema});

  @override
  State<PreviousPositionsNavigation> createState() => _PreviousPositionsNavigationState();
}

class _PreviousPositionsNavigationState extends State<PreviousPositionsNavigation> {
  String? _selectedPositionKey;
  List<String> _positionKeys = [];
  Map<String, LatLng> _positionCoordinates = {};
  List<String> _supportPointKeys = [];
  Map<String, LatLng> _supportPointCoordinates = {};
  Map<String, String> _supportPointNotes = {};
  Map<int, String> _supportPointTypeLabels = {}; // Cache for point type labels
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
        _positionKeys.add('SOLL Position');
        _positionCoordinates['SOLL Position'] = LatLng(lat, lng);
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

    // Load support points
    _loadSupportPoints();

    // Set current position as default selection if available
    if (_positionKeys.contains('SOLL Position') && _selectedPositionKey == null) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) {
          setState(() {
            _selectedPositionKey = 'SOLL Position';
          });
          _showDistanceLineToPosition('SOLL Position');
        }
      });
    }
  }

  Future<void> _loadSupportPoints() async {
    if (widget.rawRecord?.previousProperties == null) return;

    final supportPoints =
        widget.rawRecord!.previousProperties!['plot_support_points'] as List<dynamic>? ?? [];

    // Get reference point (SOLL Position) to calculate support point coordinates
    final referenceCoords = _positionCoordinates['SOLL Position'];
    if (referenceCoords == null || supportPoints.isEmpty) return;

    // Keep track of type=3 point for type=4 calculation
    LatLng? type3Coords;

    for (int i = 0; i < supportPoints.length; i++) {
      final point = supportPoints[i] as Map<String, dynamic>;
      final azimuth = point['azimuth'] as num?;
      final distanceCm = point['distance'] as num?;
      final pointType = point['point_type'] as int?;
      final note = point['note'] as String? ?? '';

      if (azimuth != null && distanceCm != null && pointType != null) {
        // Convert distance from cm to meters
        final distanceM = distanceCm / 100;

        // Convert azimuth from degrees to gon
        final azimuthGon = azimuth * (400 / 360);

        final distance = Distance();
        LatLng? supportPointCoords;

        // Calculate position based on point type
        switch (pointType) {
          case 2:
            // Type 2: azimuth/distance FROM SOLL Position
            // Use azimuth directly
            supportPointCoords = distance.offset(referenceCoords, distanceM, azimuthGon);
            break;

          case 1:
          case 3:
          case 5:
            // Types 1, 3, 5: azimuth/distance TO SOLL Position
            // Apply reverse azimuth (add 200 gon)
            final reverseAzimuth = (azimuthGon + 200) % 400;
            supportPointCoords = distance.offset(referenceCoords, distanceM, reverseAzimuth);

            // Save type=3 position for potential type=4 reference
            if (pointType == 3) {
              type3Coords = supportPointCoords;
            }
            break;

          case 4:
            // Type 4: azimuth/distance TO Point type=3
            // Need type=3 coordinates, apply reverse azimuth
            if (type3Coords != null) {
              final reverseAzimuth = (azimuthGon + 200) % 400;
              supportPointCoords = distance.offset(type3Coords, distanceM, reverseAzimuth);
            } else {
              debugPrint('Warning: Point type=4 encountered before type=3');
              // Fallback to SOLL Position with reverse azimuth
              final reverseAzimuth = (azimuthGon + 200) % 400;
              supportPointCoords = distance.offset(referenceCoords, distanceM, reverseAzimuth);
            }
            break;

          default:
            debugPrint('Unknown point type: $pointType');
            // Default fallback: use azimuth directly from SOLL Position
            supportPointCoords = distance.offset(referenceCoords, distanceM, azimuthGon);
        }

        if (supportPointCoords != null) {
          // Create label for support point
          final label = await _getPointTypeLabel(pointType, i + 1);
          _supportPointKeys.add(label);
          _supportPointCoordinates[label] = supportPointCoords;
          _supportPointNotes[label] = note;
        }
      }
    }
  }

  Future<String> _getPointTypeLabel(int? pointType, int index) async {
    if (pointType == null) return 'Punkt $index';

    // Check cache first
    if (_supportPointTypeLabels.containsKey(pointType)) {
      return _supportPointTypeLabels[pointType]!;
    }

    // Try to get label from jsonSchema first
    if (widget.jsonSchema != null) {
      try {
        final properties = widget.jsonSchema!['properties'] as Map<String, dynamic>?;
        if (properties != null) {
          final plotSupportPoints = properties['plot_support_points'] as Map<String, dynamic>?;
          if (plotSupportPoints != null) {
            final items = plotSupportPoints['items'] as Map<String, dynamic>?;
            if (items != null) {
              final itemProperties = items['properties'] as Map<String, dynamic>?;
              if (itemProperties != null) {
                final pointTypeField = itemProperties['point_type'] as Map<String, dynamic>?;
                if (pointTypeField != null) {
                  final tfm = pointTypeField['\$tfm'] as Map<String, dynamic>?;
                  if (tfm != null) {
                    final nameDe = tfm['name_de'] as List<dynamic>?;
                    if (nameDe != null && pointType >= 1 && pointType <= nameDe.length) {
                      // pointType is 1-based, array is 0-based
                      final label = nameDe[pointType - 1] as String;
                      _supportPointTypeLabels[pointType] = label; // Cache the result
                      return label;
                    }
                  }
                }
              }
            }
          }
        }
      } catch (e) {
        debugPrint('Error extracting label from jsonSchema: $e');
      }
    }

    // Fallback to database lookup
    debugPrint('Loading label for support point type from database: $pointType');
    try {
      final result = await db.get('SELECT name_de FROM lookup_support_point_type WHERE code = ?', [
        pointType,
      ]);
      if (result != null && result['name_de'] != null) {
        final label = result['name_de'] as String;
        _supportPointTypeLabels[pointType] = label; // Cache the result
        return label;
      }
    } catch (e) {
      debugPrint('Error loading support point type label from database: $e');
    }

    // Fallback to generic label
    return 'Punkt $index';
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
        // Clear distance line and navigation target
        final mapProvider = context.read<MapControllerProvider>();
        mapProvider.clearDistanceLine();
        mapProvider.clearNavigationTarget();
      } else {
        _selectedPositionKey = positionKey;
        // Set navigation target - check both position types
        final targetCoords =
            _positionCoordinates[positionKey] ?? _supportPointCoordinates[positionKey];
        if (targetCoords != null) {
          final mapProvider = context.read<MapControllerProvider>();
          mapProvider.setNavigationTarget(targetCoords, label: positionKey);
        }
        // Show distance line to selected position
        _showDistanceLineToPosition(positionKey);
      }
    });
  }

  void _showDistanceLineToPosition(String positionKey) {
    final targetCoords = _positionCoordinates[positionKey] ?? _supportPointCoordinates[positionKey];
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
      final targetCoords =
          _positionCoordinates[_selectedPositionKey] ??
          _supportPointCoordinates[_selectedPositionKey];
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
            ListView.builder(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              itemCount:
                  availablePositions.length +
                  _supportPointKeys.length +
                  (_supportPointKeys.isNotEmpty ? 2 : 1), // +headers
              itemBuilder: (context, index) {
                // First group: Gemessene Werte
                if (index == 0) {
                  return Padding(
                    padding: const EdgeInsets.only(left: 16, top: 8, bottom: 8),
                    child: Text(
                      'Gemessene Werte',
                      style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.bold,
                        color: Colors.grey[700],
                      ),
                    ),
                  );
                }

                // Gemessene Werte items
                if (index <= availablePositions.length) {
                  final positionIndex = index - 1;
                  final key = availablePositions[positionIndex];
                  final isSelected = _selectedPositionKey == key;

                  return Column(
                    children: [
                      ListTile(
                        selected: isSelected,
                        leading: Icon(
                          isSelected ? Icons.radio_button_checked : Icons.radio_button_unchecked,
                          color: isSelected ? Theme.of(context).primaryColor : null,
                        ),
                        title: Text(key),
                        onTap: () => _selectPosition(key),
                      ),
                      if (positionIndex < availablePositions.length - 1) const Divider(height: 1),
                    ],
                  );
                }

                // Second group header: Hilfspunkte
                if (index == availablePositions.length + 1 && _supportPointKeys.isNotEmpty) {
                  return Padding(
                    padding: const EdgeInsets.only(left: 16, top: 16, bottom: 8),
                    child: Text(
                      'Hilfspunkte',
                      style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.bold,
                        color: Colors.grey[700],
                      ),
                    ),
                  );
                }

                // Hilfspunkte items
                final supportPointIndex = index - availablePositions.length - 2;
                if (supportPointIndex >= 0 && supportPointIndex < _supportPointKeys.length) {
                  final key = _supportPointKeys[supportPointIndex];
                  final isSelected = _selectedPositionKey == key;
                  final note = _supportPointNotes[key] ?? '';

                  return Column(
                    children: [
                      ListTile(
                        selected: isSelected,
                        leading: Icon(
                          isSelected ? Icons.radio_button_checked : Icons.radio_button_unchecked,
                          color: isSelected ? Theme.of(context).primaryColor : null,
                        ),
                        title: Text(key),
                        subtitle: note.isNotEmpty ? Text(note) : null,
                        onTap: () => _selectPosition(key),
                      ),
                      if (supportPointIndex < _supportPointKeys.length - 1)
                        const Divider(height: 1),
                    ],
                  );
                }

                return const SizedBox.shrink();
              },
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
      _supportPointKeys.clear();
      _supportPointCoordinates.clear();
      _supportPointNotes.clear();
      _loadPositionData();
      // Clear selection if data changed
      if (_selectedPositionKey != null) {
        final mapProvider = context.read<MapControllerProvider>();
        mapProvider.clearDistanceLine();
        mapProvider.clearNavigationTarget();
        _selectedPositionKey = null;
      }
    }
  }

  @override
  void dispose() {
    _gpsSubscription?.cancel();

    // Clear distance line and navigation target when widget is disposed
    if (_selectedPositionKey != null && mounted) {
      try {
        final mapProvider = context.read<MapControllerProvider>();
        mapProvider.clearDistanceLine();
        mapProvider.clearNavigationTarget();
      } catch (e) {
        debugPrint('Error clearing distance line on dispose: $e');
      }
    }
    super.dispose();
  }
}
