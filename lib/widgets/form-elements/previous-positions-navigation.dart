import 'dart:async';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:latlong2/latlong.dart';
import 'dart:math' as math;
import 'package:terrestrial_forest_monitor/repositories/records_repository.dart' as repo;
import 'package:terrestrial_forest_monitor/providers/map_controller_provider.dart';
import 'package:terrestrial_forest_monitor/providers/gps-position.dart';
import 'package:terrestrial_forest_monitor/services/powersync.dart';
import 'package:terrestrial_forest_monitor/widgets/form-elements/position-selector.dart';
import 'package:terrestrial_forest_monitor/widgets/form-elements/manual-navigation-steps.dart';

/// Widget for navigating to previous position measurements
/// Displays a list of previous positions from previousProperties.plot_coordinates and
/// previousPositionData, allowing selection to show a distance line from current GPS position
class PreviousPositionsNavigation extends StatefulWidget {
  final repo.Record? rawRecord;
  final Map<String, dynamic>? jsonSchema;
  final bool isVisible; // Whether this tab is currently visible

  const PreviousPositionsNavigation({
    super.key,
    this.rawRecord,
    this.jsonSchema,
    this.isVisible = true,
  });

  @override
  State<PreviousPositionsNavigation> createState() => _PreviousPositionsNavigationState();
}

class _PreviousPositionsNavigationState extends State<PreviousPositionsNavigation> {
  String? _selectedPositionKey;
  String? _startPositionKey;
  List<String> _positionKeys = [];
  Map<String, LatLng> _positionCoordinates = {};
  Map<String, Map<String, dynamic>> _positionMetadata = {}; // Quality/accuracy metadata
  List<String> _supportPointKeys = [];
  Map<String, LatLng> _supportPointCoordinates = {};
  Map<String, String> _supportPointNotes = {};
  Map<int, String> _supportPointTypeLabels = {}; // Cache for point type labels

  /// Handle setting/clearing a position as the center for relative calculations
  void _setCenterPosition(String? key) {
    try {
      final mapControllerProvider = context.read<MapControllerProvider>();

      if (key == null) {
        // Clear center position - will use default SOLL position
        mapControllerProvider.clearCenterPosition();
      } else {
        // Get coordinates for the selected key
        final coords = _getCoordinatesForKey(key);
        if (coords != null) {
          mapControllerProvider.setCenterPosition(key, coords);
        }
      }
    } catch (e) {
      debugPrint('Error setting center position: $e');
    }
  }

  StreamSubscription? _gpsSubscription;
  Map<String, double>? _calculatedNavigation;
  List<LatLng>? _stepPositions;
  LatLng? _startMapTappedPosition; // Position selected from map for start
  LatLng? _targetMapTappedPosition; // Position selected from map for target
  StreamSubscription? _mapTapSubscription; // Subscription to map tap events

  @override
  void initState() {
    super.initState();
    _loadPositionData();
    // Set GPS live tracking as default start position
    _startPositionKey = PositionSelector.gpsLiveKey;
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
        // Update navigation path if positions are selected and GPS is being used
        if ((_startPositionKey == PositionSelector.gpsLiveKey ||
                _selectedPositionKey == PositionSelector.gpsLiveKey) &&
            mounted) {
          _updateNavigationPath();
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

            // Store quality/accuracy metadata
            _positionMetadata[key] = {
              'quality': value['quality'],
              'hdop_mean': value['hdop_mean'],
              'pdop_mean': value['pdop_mean'],
              'rtcm_age': value['rtcm_age'],
              'satellites_count_mean': value['satellites_count_mean'],
              'measurement_count': value['measurement_count'],
            };
          } else {
            // Fallback to center_location or direct lat/lng
            final coords = _extractCoordinates(value);
            if (coords != null && !_positionKeys.contains(key)) {
              _positionKeys.add(key);
              _positionCoordinates[key] = coords;

              // Store metadata even for fallback coordinates
              _positionMetadata[key] = {
                'quality': value['quality'],
                'hdop_mean': value['hdop_mean'],
                'pdop_mean': value['pdop_mean'],
                'rtcm_age': value['rtcm_age'],
                'satellites_count_mean': value['satellites_count_mean'],
                'measurement_count': value['measurement_count'],
              };
            }
          }
        }
      });
    }

    // Load support points
    _loadSupportPoints();

    // Set SOLL Position as default center for relative calculations
    if (_positionKeys.contains('SOLL Position')) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) {
          _setCenterPosition('SOLL Position');
        }
      });
    }

    // Set current position as default selection if available
    if (_positionKeys.contains('SOLL Position') && _selectedPositionKey == null) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) {
          setState(() {
            _selectedPositionKey = 'SOLL Position';
          });
          _updateNavigationPath();
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

  String _formatDistance(double meters) {
    if (meters < 1000) {
      return '${meters.toStringAsFixed(1)} m';
    } else {
      return '${(meters / 1000).toStringAsFixed(2)} km';
    }
  }

  void _selectTargetPosition(String? positionKey) {
    setState(() {
      _selectedPositionKey = positionKey;

      // Automatically set center only for measured positions
      if (positionKey == null) {
        // No target selected - default to SOLL Position as center
        _setCenterPosition('SOLL Position');
      } else if (_positionCoordinates.containsKey(positionKey)) {
        // Selected position is a measured position ("Messungen Ecken") - use as center
        _setCenterPosition(positionKey);
      }
      // If Hilfspunkt or GPS Position is selected, center stays unchanged

      if (positionKey == null) {
        // Clear navigation target and line string
        final mapProvider = context.read<MapControllerProvider>();
        mapProvider.clearDistanceLine();
        mapProvider.clearNavigationTarget();
        mapProvider.clearNavigationLineStrings();
      } else if (positionKey == PositionSelector.gpsLiveKey) {
        // GPS live tracking - don't set a fixed target, let it track
        final mapProvider = context.read<MapControllerProvider>();
        mapProvider.clearNavigationTarget();
        _updateNavigationPath();
      } else if (positionKey == PositionSelector.gpsLockedKey) {
        // Lock current GPS position as target
        final gpsProvider = context.read<GpsPositionProvider>();
        if (gpsProvider.lastPosition != null) {
          final lockedPosition = LatLng(
            gpsProvider.lastPosition!.latitude,
            gpsProvider.lastPosition!.longitude,
          );
          final mapProvider = context.read<MapControllerProvider>();
          mapProvider.setNavigationTarget(lockedPosition, label: 'GPS Position (Gesperrt)');
          _updateNavigationPath();
        }
      } else {
        // Set navigation target - check both position types
        final targetCoords =
            _positionCoordinates[positionKey] ?? _supportPointCoordinates[positionKey];
        if (targetCoords != null) {
          final mapProvider = context.read<MapControllerProvider>();
          mapProvider.setNavigationTarget(targetCoords, label: positionKey);
        }
        _updateNavigationPath();
      }
    });
  }

  void _selectStartPosition(String? positionKey) {
    setState(() {
      _startPositionKey = positionKey;

      final mapProvider = context.read<MapControllerProvider>();

      if (positionKey == null) {
        // Clear navigation start
        mapProvider.clearNavigationStart();
        mapProvider.clearNavigationLineStrings();
      } else if (positionKey == PositionSelector.gpsLiveKey) {
        // GPS live tracking - don't set a fixed position, let it track
        mapProvider.clearNavigationStart();
      } else if (positionKey == PositionSelector.gpsLockedKey) {
        // Lock current GPS position
        final gpsProvider = context.read<GpsPositionProvider>();
        if (gpsProvider.lastPosition != null) {
          final lockedPosition = LatLng(
            gpsProvider.lastPosition!.latitude,
            gpsProvider.lastPosition!.longitude,
          );
          mapProvider.setNavigationStart(lockedPosition, label: 'GPS Position (Gesperrt)');
        }
      } else {
        // Set navigation start - check both position types
        final startCoords =
            _positionCoordinates[positionKey] ?? _supportPointCoordinates[positionKey];
        if (startCoords != null) {
          mapProvider.setNavigationStart(startCoords, label: positionKey);
        }
      }

      // Update navigation path if target is selected
      if (_selectedPositionKey != null) {
        _updateNavigationPath();
      }
    });
  }

  void _focusMapOnPosition(LatLng position) {
    final mapProvider = context.read<MapControllerProvider>();
    mapProvider.moveToLocation(position, zoom: 18.0);
  }

  void _updateNavigationPath() {
    // Only update navigation if tab is currently visible
    if (!widget.isVisible) return;

    final startCoords = _getCoordinatesForKey(_startPositionKey);
    final targetCoords = _getCoordinatesForKey(_selectedPositionKey);
    final mapProvider = context.read<MapControllerProvider>();

    // Clear old distance line system
    mapProvider.clearDistanceLine();

    // Update start marker
    if (startCoords != null) {
      mapProvider.setNavigationStart(startCoords, label: _startPositionKey);
    } else {
      mapProvider.clearNavigationStart();
    }

    // Update target marker
    if (targetCoords != null) {
      mapProvider.setNavigationTarget(targetCoords, label: _selectedPositionKey);
    } else {
      mapProvider.clearNavigationTarget();
    }

    // Update linestrings
    if (startCoords == null || targetCoords == null) {
      mapProvider.clearNavigationLineStrings();
      return;
    }

    // Line 1: Start → Steps (if steps exist)
    if (_stepPositions != null && _stepPositions!.isNotEmpty) {
      mapProvider.setNavigationStepsLineString(_stepPositions);

      // Line 2: Last step → Target
      final lastStep = _stepPositions!.last;
      mapProvider.setNavigationTargetLineString([lastStep, targetCoords]);
    } else {
      // No steps: clear steps line, and draw direct line from start to target
      mapProvider.setNavigationStepsLineString(null);
      mapProvider.setNavigationTargetLineString([startCoords, targetCoords]);
    }
  }

  LatLng? _getCoordinatesForKey(String? key) {
    if (key == null) return null;

    final gpsProvider = context.read<GpsPositionProvider>();

    if (key == PositionSelector.gpsLiveKey || key == PositionSelector.gpsLockedKey) {
      if (gpsProvider.lastPosition != null) {
        return LatLng(gpsProvider.lastPosition!.latitude, gpsProvider.lastPosition!.longitude);
      }
    } else if (key == PositionSelector.mapTappedKey) {
      // Return the appropriate map-tapped position based on context
      // This is a simplified approach - you might need to track which selector is being used
      return _startMapTappedPosition ?? _targetMapTappedPosition;
    } else {
      return _positionCoordinates[key] ?? _supportPointCoordinates[key];
    }
    return null;
  }

  void _enableMapTapModeForStart() {
    final mapProvider = context.read<MapControllerProvider>();
    // Enable map tap mode and listen for tap events
    _mapTapSubscription?.cancel();
    _mapTapSubscription = mapProvider.mapTapStream.listen((position) {
      if (mounted) {
        setState(() {
          _startMapTappedPosition = position;
          _startPositionKey = PositionSelector.mapTappedKey;
        });
        _updateNavigationPath();
      }
    });
    // Enable map tap mode
    mapProvider.enableMapTapMode();
  }

  void _enableMapTapModeForTarget() {
    final mapProvider = context.read<MapControllerProvider>();
    // Enable map tap mode and listen for tap events
    _mapTapSubscription?.cancel();
    _mapTapSubscription = mapProvider.mapTapStream.listen((position) {
      if (mounted) {
        setState(() {
          _targetMapTappedPosition = position;
          _selectedPositionKey = PositionSelector.mapTappedKey;
        });
        _updateNavigationPath();
      }
    });
    // Enable map tap mode
    mapProvider.enableMapTapMode();
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
    final mapControllerProvider = context.watch<MapControllerProvider>();
    double? distance;
    double? bearing;

    if (_selectedPositionKey != null) {
      final targetCoords = _getCoordinatesForKey(_selectedPositionKey);
      final fromCoords =
          _getCoordinatesForKey(_startPositionKey) ??
          (gpsProvider.lastPosition != null
              ? LatLng(gpsProvider.lastPosition!.latitude, gpsProvider.lastPosition!.longitude)
              : null);

      if (targetCoords != null && fromCoords != null) {
        distance = _calculateDistance(
          fromCoords.latitude,
          fromCoords.longitude,
          targetCoords.latitude,
          targetCoords.longitude,
        );
        bearing = _calculateBearing(
          fromCoords.latitude,
          fromCoords.longitude,
          targetCoords.latitude,
          targetCoords.longitude,
        );
      }
    }

    return Padding(
      padding: const EdgeInsets.all(10),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Navigation:', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
          const SizedBox(height: 8.0),
          Card(
            child: PositionSelector(
              measuredPositionKeys: availablePositions,
              measuredPositionCoordinates: _positionCoordinates,
              measuredPositionMetadata: _positionMetadata,
              supportPointKeys: _supportPointKeys,
              supportPointCoordinates: _supportPointCoordinates,
              supportPointNotes: _supportPointNotes,
              selectedPositionKey: _startPositionKey,
              onPositionSelected: _selectStartPosition,
              onFocusPosition: _focusMapOnPosition,
              label: 'Start',
              icon: Icons.location_on,
              hasGpsPosition: gpsProvider.lastPosition != null,
              currentGpsPosition: gpsProvider.lastPosition != null
                  ? LatLng(gpsProvider.lastPosition!.latitude, gpsProvider.lastPosition!.longitude)
                  : null,
              onSelectFromMap: _enableMapTapModeForStart,
              mapTappedPosition: _startMapTappedPosition,
              centerPositionKey: mapControllerProvider.centerPositionKey,
              subtitle: _startPositionKey != null
                  ? () {
                      final coords = _getCoordinatesForKey(_startPositionKey);
                      if (coords != null) {
                        return 'Lat: ${coords.latitude.toStringAsFixed(6)}, Lon: ${coords.longitude.toStringAsFixed(6)}';
                      }
                      return null;
                    }()
                  : null,
            ),
          ),

          // Manual navigation steps
          ManualNavigationSteps(
            startPosition: _getCoordinatesForKey(_startPositionKey),
            targetPosition: _getCoordinatesForKey(_selectedPositionKey),
            onNavigationCalculated: (calculated) {
              setState(() {
                _calculatedNavigation = calculated;
              });
            },
            onStepPositionsCalculated: (positions) {
              setState(() {
                _stepPositions = positions;
                _updateNavigationPath();
              });
            },
          ),

          Card(
            child: PositionSelector(
              measuredPositionKeys: availablePositions,
              measuredPositionCoordinates: _positionCoordinates,
              measuredPositionMetadata: _positionMetadata,
              supportPointKeys: _supportPointKeys,
              supportPointCoordinates: _supportPointCoordinates,
              supportPointNotes: _supportPointNotes,
              selectedPositionKey: _selectedPositionKey,
              onPositionSelected: _selectTargetPosition,
              onFocusPosition: _focusMapOnPosition,
              label: 'Ziel',
              icon: Icons.where_to_vote,
              hasGpsPosition: gpsProvider.lastPosition != null,
              currentGpsPosition: gpsProvider.lastPosition != null
                  ? LatLng(gpsProvider.lastPosition!.latitude, gpsProvider.lastPosition!.longitude)
                  : null,
              onSelectFromMap: _enableMapTapModeForTarget,
              mapTappedPosition: _targetMapTappedPosition,
              centerPositionKey: mapControllerProvider.centerPositionKey,
              subtitle: _selectedPositionKey != null
                  ? () {
                      // Use calculated navigation from steps if available
                      if (_calculatedNavigation != null) {
                        final calcDistance = _calculatedNavigation!['distance']!;
                        final calcBearing = _calculatedNavigation!['azimuth']!;
                        return 'Distanz: ${_formatDistance(calcDistance)}, Azimut: ${calcBearing.toStringAsFixed(1)} gon';
                      }
                      // Otherwise use direct distance/bearing
                      if (distance != null && bearing != null) {
                        return 'Distanz: ${_formatDistance(distance)}, Azimut: ${bearing.toStringAsFixed(1)} gon';
                      }
                      return null;
                    }()
                  : null,
            ),
          ),
          if (_selectedPositionKey != null && (distance == null || bearing == null)) ...[
            const SizedBox(height: 8.0),
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
      ),
    );
  }

  @override
  void didUpdateWidget(PreviousPositionsNavigation oldWidget) {
    super.didUpdateWidget(oldWidget);

    // Handle visibility changes
    if (widget.isVisible != oldWidget.isVisible) {
      if (widget.isVisible) {
        // Tab became visible - restore navigation
        if (_selectedPositionKey != null || _startPositionKey != null) {
          WidgetsBinding.instance.addPostFrameCallback((_) {
            if (mounted) {
              _updateNavigationPath();
            }
          });
        }
      } else {
        // Tab became hidden - clear navigation
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (mounted) {
            _clearNavigationFromMap();
          }
        });
      }
      return; // Skip other update logic when visibility changes
    }

    final propertiesChanged =
        widget.rawRecord?.previousProperties != oldWidget.rawRecord?.previousProperties;
    final positionDataChanged =
        widget.rawRecord?.previousPositionData != oldWidget.rawRecord?.previousPositionData;

    if (propertiesChanged || positionDataChanged) {
      _positionKeys.clear();
      _positionCoordinates.clear();
      _positionMetadata.clear();
      _supportPointKeys.clear();
      _supportPointCoordinates.clear();
      _supportPointNotes.clear();
      _loadPositionData();
      // Clear selection if data changed
      if (_selectedPositionKey != null || _startPositionKey != null) {
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (mounted) {
            final mapProvider = context.read<MapControllerProvider>();
            mapProvider.clearDistanceLine();
            mapProvider.clearNavigationTarget();
            mapProvider.clearNavigationStart();
          }
        });
        _selectedPositionKey = null;
        _startPositionKey = null;
      }
    }
  }

  void _clearNavigationFromMap() {
    try {
      final mapProvider = context.read<MapControllerProvider>();
      mapProvider.clearDistanceLine();
      mapProvider.clearNavigationTarget();
      mapProvider.clearNavigationStart();
      mapProvider.clearNavigationLineStrings();
      mapProvider.disableMapTapMode();
      _mapTapSubscription?.cancel();
    } catch (e) {
      debugPrint('Error clearing navigation: $e');
    }
  }

  @override
  void dispose() {
    _gpsSubscription?.cancel();
    _mapTapSubscription?.cancel();

    // Disable map tap mode if still enabled
    try {
      context.read<MapControllerProvider>().disableMapTapMode();
    } catch (e) {
      debugPrint('Error disabling map tap mode: $e');
    }

    // Clear all navigation elements when widget is disposed
    _clearNavigationFromMap();
    super.dispose();
  }
}
