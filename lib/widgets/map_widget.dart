import 'dart:math';
import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart'; // Add for compute
import 'package:flutter_map/flutter_map.dart';
import 'package:flutter_map_marker_cluster/flutter_map_marker_cluster.dart';
import 'package:flutter_map_tile_caching/flutter_map_tile_caching.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:latlong2/latlong.dart';
import 'package:provider/provider.dart';
import 'package:terrestrial_forest_monitor/repositories/records_repository.dart';
import 'package:terrestrial_forest_monitor/providers/records_list_provider.dart';
import 'package:terrestrial_forest_monitor/providers/gps-position.dart';
import 'package:terrestrial_forest_monitor/providers/map_controller_provider.dart';
import 'package:terrestrial_forest_monitor/services/powersync.dart';
import 'package:terrestrial_forest_monitor/widgets/cluster/order-cluster-by.dart';
import 'package:terrestrial_forest_monitor/widgets/map/map-settings.dart';
import 'package:terrestrial_forest_monitor/widgets/map/edge_layers.dart';
import 'package:terrestrial_forest_monitor/widgets/map/tree_layers.dart';
import 'package:terrestrial_forest_monitor/widgets/map/tree_crown_layers.dart';
import 'package:terrestrial_forest_monitor/widgets/map/subplot_layers.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'dart:async';

import 'package:turf/turf.dart' as turf;

class MapWidget extends StatefulWidget {
  final LatLng? initialCenter;
  final double? initialZoom;
  final double? sheetPosition;

  const MapWidget({super.key, this.initialCenter, this.initialZoom, this.sheetPosition});

  @override
  State<MapWidget> createState() => _MapWidgetState();
}

class _MapWidgetState extends State<MapWidget> {
  final MapController _mapController = MapController();
  List<Record> _records = [];
  List<Record> _visibleRecords = [];
  bool _markersLoaded = false;
  bool _isDisposed = false;
  bool _isMapReady = false;
  StreamSubscription? _gpsSubscription;
  Timer? _debounceTimer;
  DateTime? _lastFocusTimestamp;
  DateTime? _lastManualFocusTime;
  LatLng? _currentPosition;
  double? _currentAccuracy;
  Set<String> _selectedBasemaps = {
    'topo_offline',
  }; // Can select multiple: 'osm', 'topo_offline', 'dop'
  double _currentZoom = 5.5;
  LatLngBounds? _lastBounds;
  bool _storesInitialized = false;
  Record? _focusedRecord;
  String? _lastCenterPositionKey; // Track center position changes
  List<Map<String, dynamic>> _treePositions = [];
  List<Map<String, dynamic>> _previousTreePositions = [];
  Map<String, List<LatLng>> _clusterPolygons = {};
  List<CircleMarker>? _cachedTreeCircles;
  List<CircleMarker>? _cachedPreviousTreeCircles;
  List<Map<String, dynamic>> _edges = [];
  List<Map<String, dynamic>> _previousEdges = [];
  List<Map<String, dynamic>> _subplotPositions = [];
  List<Map<String, dynamic>> _previousSubplotPositions = [];
  Map<String, Map<String, List<LatLng>>> _historicalPositionPolygons = {};
  double _treeDiameterMultiplier = 1.0;
  bool _showTreeLabels = true;
  Set<String> _treeLabelFields = {'tree_number', 'dbh'};
  bool _showEdges = true;
  bool _showCrownCircles = true;
  bool _showClusterPolygons = true;
  bool _showProbekreise = true;
  Map<int, String> _treeSpeciesLookup = {}; // Maps species code to species name

  List<Color> aggregatedMarkerColors = [
    Color.fromARGB(255, 0, 170, 170), // #0aa
    Color.fromARGB(255, 0, 170, 130), // #00aa82
    Color.fromARGB(255, 0, 159, 224), // #009fe0
    Color.fromARGB(255, 120, 189, 30), // #78bd1e
    Color.fromARGB(255, 201, 219, 156), // #c9db9c
    Color.fromARGB(255, 213, 123, 22), // #d57b16
    Color.fromARGB(255, 235, 192, 139), // #ebc08b
  ];

  Map<String, Color> intervalColorCache = {
    'previousColor': Color.fromARGB(255, 0, 202, 224),
    'currentColor': Color.fromARGB(255, 217, 25, 231),
  };

  @override
  void initState() {
    super.initState();

    // Initialize FMTC stores
    _initializeTileStores();

    // Load saved basemap preference
    _loadMapSettings();

    // Load tree species lookup
    _loadTreeSpeciesLookup();

    // Register map controller with provider
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!_isDisposed && mounted) {
        try {
          final mapControllerProvider = context.read<MapControllerProvider>();
          mapControllerProvider.setFlutterMapController(_mapController);
          debugPrint('Flutter map controller registered with provider');
        } catch (e) {
          debugPrint('MapControllerProvider not found: $e');
        }

        // Set up listener for MapControllerProvider focus bounds
        final mapControllerProvider = context.read<MapControllerProvider>();
        mapControllerProvider.addListener(_onMapControllerProviderChanged);
      }
    });
  }

  void _onMapControllerProviderChanged() {
    if (!_isDisposed && mounted && _isMapReady) {
      _checkForFocusBounds();
      _checkForManualMove();
      _checkForFocusedRecord();
      _checkForCenterPositionChange();
    }
  }

  void _checkForManualMove() {
    try {
      final mapControllerProvider = context.read<MapControllerProvider>();
      final manualMoveTimestamp = mapControllerProvider.lastManualMoveTimestamp;

      if (manualMoveTimestamp != null && manualMoveTimestamp != _lastManualFocusTime) {
        _lastManualFocusTime = manualMoveTimestamp;
        debugPrint('Manual move detected at ${manualMoveTimestamp}');
      }
    } catch (e) {
      debugPrint('Error checking manual move: $e');
    }
  }

  /// Check if center position changed and recalculate positions
  Future<void> _checkForCenterPositionChange() async {
    try {
      final mapControllerProvider = context.read<MapControllerProvider>();
      final currentCenterKey = mapControllerProvider.centerPositionKey;

      // Check if center position changed
      if (currentCenterKey != _lastCenterPositionKey) {
        _lastCenterPositionKey = currentCenterKey;
        debugPrint('Center position changed to: $currentCenterKey');

        // Recalculate positions for current focused record if any
        if (_focusedRecord != null) {
          final treePositions = await _calculateTreePositions(_focusedRecord!);
          final previousTreePositions = await _calculateTreePositions(
            _focusedRecord!,
            usePrevious: true,
          );
          final edges = await _calculateEdges(_focusedRecord!);
          final previousEdges = await _calculateEdges(_focusedRecord!, usePrevious: true);
          final subplotPositions = await _calculateSubplotPositions(_focusedRecord!);
          final previousSubplotPositions = await _calculateSubplotPositions(
            _focusedRecord!,
            usePrevious: true,
          );

          if (!_isDisposed && mounted) {
            setState(() {
              _treePositions = treePositions;
              _previousTreePositions = previousTreePositions;
              _edges = edges;
              _previousEdges = previousEdges;
              _subplotPositions = subplotPositions;
              _previousSubplotPositions = previousSubplotPositions;
            });
            debugPrint('Recalculated positions with new center: $currentCenterKey');
          }
        }
      }
    } catch (e) {
      debugPrint('Error checking center position change: $e');
    }
  }

  Future<void> _checkForFocusedRecord() async {
    try {
      final mapControllerProvider = context.read<MapControllerProvider>();
      final focusedRecord = mapControllerProvider.focusedRecord;

      if (focusedRecord != _focusedRecord) {
        // Update focused record IMMEDIATELY to prevent re-entry during async operations
        final previousFocusedRecord = _focusedRecord;
        _focusedRecord = focusedRecord;

        // Clear center position when switching plots so calculations use the new plot's default SOLL position
        mapControllerProvider.clearCenterPosition();
        // Update tracking to prevent infinite loop from change listener
        _lastCenterPositionKey = null;

        final treePositions = focusedRecord != null
            ? await _calculateTreePositions(focusedRecord, usePrevious: false)
            : <Map<String, dynamic>>[];

        final previousTreePositions = focusedRecord != null
            ? await _calculateTreePositions(focusedRecord, usePrevious: true)
            : <Map<String, dynamic>>[];

        final edges = focusedRecord != null
            ? await _calculateEdges(focusedRecord, usePrevious: false)
            : <Map<String, dynamic>>[];

        final previousEdges = focusedRecord != null
            ? await _calculateEdges(focusedRecord, usePrevious: true)
            : <Map<String, dynamic>>[];

        final subplotPositions = focusedRecord != null
            ? await _calculateSubplotPositions(focusedRecord, usePrevious: false)
            : <Map<String, dynamic>>[];

        final previousSubplotPositions = focusedRecord != null
            ? await _calculateSubplotPositions(focusedRecord, usePrevious: true)
            : <Map<String, dynamic>>[];

        if (!_isDisposed && mounted) {
          setState(() {
            // _focusedRecord already updated above
            _treePositions = treePositions;
            _previousTreePositions = previousTreePositions;
            _edges = edges;
            _previousEdges = previousEdges;
            _subplotPositions = subplotPositions;
            _previousSubplotPositions = previousSubplotPositions;
          });
        }
      }
    } catch (e) {
      debugPrint('Error checking focused record: $e');
    }
  }

  Future<List<Map<String, dynamic>>> _calculateTreePositions(
    Record record, {
    bool usePrevious = false,
  }) async {
    // Offload tree position calculations to isolate
    final properties = usePrevious ? record.previousProperties : record.properties;

    // If properties is null, return empty list
    if (properties == null) {
      debugPrint(
        'No ${usePrevious ? 'previous' : 'current'} properties available for tree positions',
      );
      return [];
    }

    // Get center position: use selected center if available, otherwise use record coordinates
    Map<String, dynamic>? centerCoords;
    try {
      final mapControllerProvider = context.read<MapControllerProvider>();
      final centerPosition = mapControllerProvider.centerPosition;

      if (centerPosition != null) {
        centerCoords = {'latitude': centerPosition.latitude, 'longitude': centerPosition.longitude};
        debugPrint('Using selected center position: ${mapControllerProvider.centerPositionKey}');
      } else {
        centerCoords = record.getCoordinates();
        debugPrint('Using default center position (SOLL)');
      }
    } catch (e) {
      centerCoords = record.getCoordinates();
      debugPrint('Error getting center position, using default: $e');
    }

    return compute(_computeTreePositions, {'recordCoords': centerCoords, 'properties': properties});
  }

  Future<List<Map<String, dynamic>>> _calculateEdges(
    Record record, {
    bool usePrevious = false,
  }) async {
    // Get center position: use selected center if available, otherwise use record coordinates
    Map<String, dynamic>? centerCoords;
    try {
      final mapControllerProvider = context.read<MapControllerProvider>();
      final centerPosition = mapControllerProvider.centerPosition;

      if (centerPosition != null) {
        centerCoords = {'latitude': centerPosition.latitude, 'longitude': centerPosition.longitude};
      } else {
        centerCoords = record.getCoordinates();
      }
    } catch (e) {
      centerCoords = record.getCoordinates();
    }

    // Offload edge position calculations to isolate
    final rawEdges = await compute(_computeEdges, {
      'recordCoords': centerCoords,
      'properties': usePrevious ? record.previousProperties : record.properties,
    });

    return rawEdges.map((edge) {
      final points = (edge['points'] as List)
          .cast<Map<String, dynamic>>()
          .map((point) => LatLng(point['lat'] as double, point['lng'] as double))
          .toList();

      return {'points': points, 'edge_number': edge['edge_number']};
    }).toList();
  }

  Future<List<Map<String, dynamic>>> _calculateSubplotPositions(
    Record record, {
    bool usePrevious = false,
  }) async {
    // Offload subplot position calculations to isolate
    final properties = usePrevious ? record.previousProperties : record.properties;

    // If properties is null, return empty list
    if (properties == null) {
      debugPrint(
        'No ${usePrevious ? 'previous' : 'current'} properties available for subplot positions',
      );
      return [];
    }

    // Get center position: use selected center if available, otherwise use record coordinates
    Map<String, dynamic>? centerCoords;
    try {
      final mapControllerProvider = context.read<MapControllerProvider>();
      final centerPosition = mapControllerProvider.centerPosition;

      if (centerPosition != null) {
        centerCoords = {'latitude': centerPosition.latitude, 'longitude': centerPosition.longitude};
      } else {
        centerCoords = record.getCoordinates();
      }
    } catch (e) {
      centerCoords = record.getCoordinates();
    }

    return compute(_computeSubplotPositions, {
      'recordCoords': centerCoords,
      'properties': properties,
    });
  }

  Map<String, List<LatLng>> _buildClusterPolygons(List<Record> records) {
    final Map<String, List<LatLng>> polygons = {};

    // Group records by cluster_name
    for (final record in records) {
      final clusterName = record.clusterName;
      final coords = record.getCoordinates();

      if (coords != null) {
        final lat = coords['latitude'] as double;
        final lng = coords['longitude'] as double;

        if (!polygons.containsKey(clusterName)) {
          polygons[clusterName] = [];
        }
        polygons[clusterName]!.add(LatLng(lat, lng));
      }
    }

    // Sort points by angle from centroid to create proper polygon
    polygons.forEach((clusterName, points) {
      if (points.length >= 3) {
        // Calculate centroid
        double centerLat = 0, centerLng = 0;
        for (final point in points) {
          centerLat += point.latitude;
          centerLng += point.longitude;
        }
        centerLat /= points.length;
        centerLng /= points.length;

        // Sort points by angle from centroid
        points.sort((a, b) {
          final angleA = atan2(a.latitude - centerLat, a.longitude - centerLng);
          final angleB = atan2(b.latitude - centerLat, b.longitude - centerLng);
          return angleA.compareTo(angleB);
        });
      }
    });

    return polygons;
  }

  Map<String, Map<String, List<LatLng>>> _buildHistoricalPositionPolygons(List<Record> records) {
    final Map<String, Map<String, List<LatLng>>> polygons = {};

    // Group records by cluster_id
    final Map<String, List<Record>> clusterGroups = {};
    for (final record in records) {
      final clusterId = record.clusterId;
      if (!clusterGroups.containsKey(clusterId)) {
        clusterGroups[clusterId] = [];
      }
      clusterGroups[clusterId]!.add(record);
    }

    // For each cluster, extract positions grouped by measurement period
    clusterGroups.forEach((clusterId, clusterRecords) {
      final Map<String, List<LatLng>> measurementPolygons = {};

      for (final record in clusterRecords) {
        // First try previousProperties.plot_coordinates
        if (record.previousProperties != null) {
          final plotCoordinates = record.previousProperties!['plot_coordinates'];
          if (plotCoordinates is Map<String, dynamic>) {
            plotCoordinates.forEach((measurementKey, measurementData) {
              if (measurementData is Map<String, dynamic>) {
                // Try to extract from center_location
                final centerLocation = measurementData['center_location'];
                if (centerLocation is Map<String, dynamic>) {
                  final lat = _extractDouble(centerLocation['latitude']);
                  final lng = _extractDouble(centerLocation['longitude']);

                  if (lat != null && lng != null) {
                    if (!measurementPolygons.containsKey(measurementKey)) {
                      measurementPolygons[measurementKey] = [];
                    }
                    measurementPolygons[measurementKey]!.add(LatLng(lat, lng));
                  }
                } else {
                  // Try direct latitude/longitude
                  final lat = _extractDouble(measurementData['latitude']);
                  final lng = _extractDouble(measurementData['longitude']);

                  if (lat != null && lng != null) {
                    if (!measurementPolygons.containsKey(measurementKey)) {
                      measurementPolygons[measurementKey] = [];
                    }
                    measurementPolygons[measurementKey]!.add(LatLng(lat, lng));
                  }
                }
              }
            });
          }
        }

        // Also check previousPositionData as fallback (bwi2012, bwi2022, etc.)
        if (record.previousPositionData != null) {
          record.previousPositionData!.forEach((measurementKey, measurementData) {
            if (measurementData is Map) {
              // Try to extract coordinates - prefer median over mean
              final latMedian = _extractDouble(measurementData['latitude_median']);
              final lngMedian = _extractDouble(measurementData['longitude_median']);
              final latMean = _extractDouble(measurementData['latitude_mean']);
              final lngMean = _extractDouble(measurementData['longitude_mean']);

              final lat = latMedian ?? latMean;
              final lng = lngMedian ?? lngMean;

              if (lat != null && lng != null) {
                // Group by measurement period (only add if not already added from plot_coordinates)
                if (!measurementPolygons.containsKey(measurementKey)) {
                  measurementPolygons[measurementKey] = [];
                }
                measurementPolygons[measurementKey]!.add(LatLng(lat, lng));
              }
            }
          });
        }
      }

      // For each measurement period, create a polygon if there are at least 3 points
      measurementPolygons.forEach((measurementKey, points) {
        if (points.length >= 3) {
          // Calculate centroid
          double centerLat = 0, centerLng = 0;
          for (final point in points) {
            centerLat += point.latitude;
            centerLng += point.longitude;
          }
          centerLat /= points.length;
          centerLng /= points.length;

          // Sort points by angle from centroid to create proper polygon
          points.sort((a, b) {
            final angleA = atan2(a.latitude - centerLat, a.longitude - centerLng);
            final angleB = atan2(b.latitude - centerLat, b.longitude - centerLng);
            return angleA.compareTo(angleB);
          });

          // Store this measurement period's polygon
          if (!polygons.containsKey(clusterId)) {
            polygons[clusterId] = {};
          }
          polygons[clusterId]![measurementKey] = points;
        }
      });
    });

    return polygons;
  }

  /// Get color for a specific measurement period
  Color _getColorForMeasurementPeriod(String measurementKey) {
    // Define colors for different measurement periods
    final Map<String, Color> periodColors = {
      'bwi2012': Colors.purple.withOpacity(0.6),
      'bwi2022': Colors.orange.withOpacity(0.6),
      'bwi2002': Colors.green.withOpacity(0.6),
      'bwi1987': Colors.brown.withOpacity(0.6),
    };

    // Return predefined color or generate from hash for unknown periods
    return periodColors[measurementKey] ??
        Color.fromARGB(
          150,
          (measurementKey.hashCode % 200) + 55,
          ((measurementKey.hashCode ~/ 200) % 200) + 55,
          ((measurementKey.hashCode ~/ 40000) % 200) + 55,
        );
  }

  /// Helper method to safely extract a double value
  double? _extractDouble(dynamic value) {
    if (value == null) return null;
    if (value is double) return value;
    if (value is int) return value.toDouble();
    if (value is String) return double.tryParse(value);
    return null;
  }

  static List<Map<String, dynamic>> _computeTreePositions(Map<String, dynamic> params) {
    final List<Map<String, dynamic>> positions = [];
    final recordCoords = params['recordCoords'] as Map<String, dynamic>?;
    final properties = params['properties'] as Map<String, dynamic>;

    debugPrint('Calculating tree positions for record at: $recordCoords');

    if (recordCoords == null) return positions;

    final centerLat = recordCoords['latitude'] as double;
    final centerLng = recordCoords['longitude'] as double;

    try {
      // Check if tree data exists in properties (note: field is 'tree', not 'trees')
      final trees = properties['tree'];
      if (trees == null || trees is! List) {
        debugPrint('No tree data found in properties. Available keys: ${properties.keys.toList()}');
        return positions;
      }
      debugPrint('Found ${trees.length} trees in tree array');

      // Calculate position for each tree based on azimuth and distance
      final centerPoint = turf.Point(coordinates: turf.Position(centerLng, centerLat));

      for (var tree in trees) {
        if (tree is! Map) continue;

        final azimuth = tree['azimuth'];
        final distance = tree['distance'];
        final treeNumber = tree['tree_number'];
        // BHD aktuell [mm]" * (1,0 + (0,0011 * ("Messhöhe des BHD [cm]" - 130[cm])))
        final dbh = tree['dbh'];
        /*
        tree['dbh'] *
            (1.0 +
                (0.0011 *
                    ((tree['dbh_height'] is num
                            ? (tree['dbh_measurement_height_cm'] as num).toDouble()
                            : 130.0) -
                        130.0)));*/

        if (azimuth != null && distance != null) {
          // Convert azimuth from gon to degrees (400 gon = 360 degrees)
          final azimuthDegrees = (azimuth as num).toDouble() * 0.9;

          // Convert distance from cm to meters then to kilometers
          final distanceKm = (distance as num).toDouble() / 100.0 / 1000.0;

          debugPrint(
            'Tree ${treeNumber}: azimuth=${azimuthDegrees}°, distance=${distanceKm}km, dbh=${dbh}mm',
          );

          // Use Turf's destination to calculate the new position
          final destinationPoint = turf.destination(
            centerPoint,
            distanceKm,
            azimuthDegrees,
            turf.Unit.kilometers,
          );

          final coords = destinationPoint.coordinates;

          positions.add({
            'lat': coords.lat,
            'lng': coords.lng,
            'tree_number': treeNumber,
            'azimuth': azimuth,
            'distance': distance,
            'dbh': dbh,
            'tree_species': tree['tree_species'],
            'tree_status': tree['tree_status'],
            'data': tree,
          });
        }
      }
    } catch (e) {
      debugPrint('Error calculating tree positions: $e');
    }

    return positions;
  }

  static List<Map<String, dynamic>> _computeEdges(Map<String, dynamic> params) {
    final List<Map<String, dynamic>> results = [];
    final recordCoords = params['recordCoords'] as Map<String, dynamic>?;
    final properties = params['properties'] as Map<String, dynamic>?;

    if (recordCoords == null || properties == null) return results;

    final centerLat = recordCoords['latitude'] as double;
    final centerLng = recordCoords['longitude'] as double;

    try {
      final edges = properties['edges'];
      if (edges == null || edges is! List) return results;

      final centerPoint = turf.Point(coordinates: turf.Position(centerLng, centerLat));

      for (var edgeGroup in edges) {
        if (edgeGroup is! Map) continue;

        // "edges" inside the edge record contains the points
        final edgepoints = edgeGroup['edges'];
        if (edgepoints is! List) continue;

        // Sort points? The example does not imply sorting, usually they are in order.
        // Assuming they are vertices of a polygon/polyline in order.

        final List<Map<String, double>> currentPolyline = [];

        for (var point in edgepoints) {
          if (point is! Map) continue;

          final azimuth = point['azimuth'];
          final distance = point['distance'];

          if (azimuth != null && distance != null) {
            // Convert azimuth from gon to degrees (400 gon = 360 degrees)
            final azimuthDegrees = (azimuth as num).toDouble() * 0.9;

            // Convert distance from cm to meters then to kilometers
            // Assuming cm based on tree example
            final distanceKm = (distance as num).toDouble() / 100.0 / 1000.0;

            // Use Turf's destination to calculate the new position
            final destinationPoint = turf.destination(
              centerPoint,
              distanceKm,
              azimuthDegrees,
              turf.Unit.kilometers,
            );

            final coords = destinationPoint.coordinates;
            currentPolyline.add({'lat': coords.lat.toDouble(), 'lng': coords.lng.toDouble()});
          }
        }

        if (currentPolyline.isNotEmpty) {
          results.add({'points': currentPolyline, 'edge_number': edgeGroup['edge_number']});
        }
      }
    } catch (e) {
      debugPrint('Error calculating edges: $e');
    }

    return results;
  }

  static List<Map<String, dynamic>> _computeSubplotPositions(Map<String, dynamic> params) {
    final List<Map<String, dynamic>> positions = [];
    final recordCoords = params['recordCoords'] as Map<String, dynamic>?;
    final properties = params['properties'] as Map<String, dynamic>;

    debugPrint('Calculating subplot positions for record at: $recordCoords');

    if (recordCoords == null) return positions;

    final centerLat = recordCoords['latitude'] as double;
    final centerLng = recordCoords['longitude'] as double;

    try {
      // Check if subplot data exists in properties
      final subplots = properties['subplots_relative_position'];
      if (subplots == null || subplots is! List) {
        debugPrint(
          'No subplot data found in properties. Available keys: ${properties.keys.toList()}',
        );
        return positions;
      }
      debugPrint('Found ${subplots.length} subplots in subplots_relative_position array');

      // Calculate position for each subplot based on azimuth and distance
      final centerPoint = turf.Point(coordinates: turf.Position(centerLng, centerLat));

      for (var subplot in subplots) {
        if (subplot is! Map) continue;

        final azimuth = subplot['azimuth'];
        final distance = subplot['distance'];
        final radius = subplot['radius'];
        final parentTable = subplot['parent_table'];

        if (azimuth != null && distance != null && radius != null) {
          // Convert azimuth from gon to degrees (400 gon = 360 degrees)
          final azimuthDegrees = (azimuth as num).toDouble() * 0.9;

          // Convert distance from cm to meters then to kilometers
          final distanceKm = (distance as num).toDouble() / 100.0 / 1000.0;

          debugPrint(
            'Subplot: azimuth=${azimuthDegrees}°, distance=${distanceKm}km, radius=${radius}m, parent_table=${parentTable}',
          );

          // Use Turf's destination to calculate the center position of the subplot
          final destinationPoint = turf.destination(
            centerPoint,
            distanceKm,
            azimuthDegrees,
            turf.Unit.kilometers,
          );

          final coords = destinationPoint.coordinates;

          positions.add({
            'lat': coords.lat,
            'lng': coords.lng,
            'radius': radius,
            'azimuth': azimuth,
            'distance': distance,
            'parent_table': parentTable,
            'data': subplot,
          });
        }
      }
    } catch (e) {
      debugPrint('Error calculating subplot positions: $e');
    }

    return positions;
  }

  Future<void> _initializeTileStores() async {
    try {
      // Initialize OpenCycleMap store
      final openCycleStore = FMTCStore('OpenCycleMap');
      if (!(await openCycleStore.manage.ready)) {
        await openCycleStore.manage.create();
        debugPrint('Created opencyclemap tile store');
      }

      // Initialize ESRI Satellite store
      final esriStore = FMTCStore('esri_satellite');
      if (!(await esriStore.manage.ready)) {
        await esriStore.manage.create();
        debugPrint('Created ESRI satellite tile store');
      }

      // Initialize DOP store
      final dopStore = FMTCStore('wms_dop__');
      if (!(await dopStore.manage.ready)) {
        await dopStore.manage.create();
        debugPrint('Created wms_dop__ tile store');
      }

      setState(() {
        _storesInitialized = true;
      });
      debugPrint('Tile stores initialized successfully');
    } catch (e) {
      debugPrint('Error initializing tile stores: $e');
      // Set flag anyway to allow app to continue
      setState(() {
        _storesInitialized = true;
      });
    }
  }

  Future<void> _loadMapSettings() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final savedBasemaps = prefs.getStringList('map_basemaps');
      if (savedBasemaps != null && savedBasemaps.isNotEmpty) {
        setState(() {
          _selectedBasemaps = savedBasemaps.toSet();
        });
        debugPrint('Loaded saved basemaps: $savedBasemaps');
      } else {
        // First installation: select all basemaps by default
        setState(() {
          _selectedBasemaps = {'opencycle', 'dop'};
        });
        // Save the default selection
        await prefs.setStringList('map_basemaps', _selectedBasemaps.toList());
        debugPrint('First installation: enabled all basemaps by default');
      }

      // Load tree diameter multiplier
      final savedMultiplier = prefs.getDouble('tree_diameter_multiplier');
      if (savedMultiplier != null) {
        setState(() {
          _treeDiameterMultiplier = savedMultiplier;
        });
        debugPrint('Loaded tree diameter multiplier: $savedMultiplier');
      }

      // Load tree label settings
      final savedShowLabels = prefs.getBool('show_tree_labels');
      if (savedShowLabels != null) {
        setState(() {
          _showTreeLabels = savedShowLabels;
        });
        debugPrint('Loaded show tree labels: $savedShowLabels');
      }

      final savedLabelFields = prefs.getStringList('tree_label_fields');
      if (savedLabelFields != null && savedLabelFields.isNotEmpty) {
        setState(() {
          _treeLabelFields = savedLabelFields.toSet();
        });
        debugPrint('Loaded tree label fields: $savedLabelFields');
      }

      // Load layer visibility settings
      final savedShowEdges = prefs.getBool('show_edges');
      if (savedShowEdges != null) setState(() => _showEdges = savedShowEdges);

      final savedShowCrownCircles = prefs.getBool('show_crown_circles');
      if (savedShowCrownCircles != null) setState(() => _showCrownCircles = savedShowCrownCircles);

      final savedShowClusterPolygons = prefs.getBool('show_cluster_polygons');
      if (savedShowClusterPolygons != null)
        setState(() => _showClusterPolygons = savedShowClusterPolygons);

      final savedShowProbekreise = prefs.getBool('show_probekreise');
      if (savedShowProbekreise != null) setState(() => _showProbekreise = savedShowProbekreise);
    } catch (e) {
      debugPrint('Error loading map settings: $e');
    }
  }

  Future<void> _saveMapSettings() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setStringList('map_basemaps', _selectedBasemaps.toList());
      await prefs.setDouble('tree_diameter_multiplier', _treeDiameterMultiplier);
      await prefs.setBool('show_tree_labels', _showTreeLabels);
      await prefs.setStringList('tree_label_fields', _treeLabelFields.toList());
      await prefs.setBool('show_edges', _showEdges);
      await prefs.setBool('show_crown_circles', _showCrownCircles);
      await prefs.setBool('show_cluster_polygons', _showClusterPolygons);
      await prefs.setBool('show_probekreise', _showProbekreise);
    } catch (e) {
      debugPrint('Error saving map settings: $e');
    }
  }

  Future<void> _loadTreeSpeciesLookup() async {
    debugPrint('_loadTreeSpeciesLookup');
    try {
      final results = await db.getAll('SELECT code, name_de FROM lookup_tree_species');
      final lookup = <int, String>{};
      for (var row in results) {
        // Handle code as either int or String
        final codeValue = row['code'];
        final name = row['name_de'] as String?;

        int? code;
        if (codeValue is int) {
          code = codeValue;
        } else if (codeValue is String) {
          code = int.tryParse(codeValue);
        }

        if (code != null && name != null) {
          lookup[code] = name;
        }
      }
      if (!_isDisposed && mounted) {
        setState(() {
          _treeSpeciesLookup = lookup;
        });
        debugPrint('Loaded ${lookup.length} tree species names');
      }
    } catch (e) {
      debugPrint('Error loading tree species lookup: $e');
    }
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();

    // Subscribe to GPS updates
    if (_gpsSubscription == null && !_isDisposed) {
      _subscribeToGPS();
    }

    // Listen to provider changes for real-time updates (populated by start.dart)
    final provider = context.read<RecordsListProvider>();

    // Load initial data from cache
    if (_records.isEmpty) {
      _loadRecordsFromProvider();
    }

    // Listen for future updates
    provider.addListener(_onProviderChanged);
  }

  void _onProviderChanged() {
    if (!_isDisposed && mounted) {
      _loadRecordsFromProvider();
    }
  }

  void _loadRecordsFromProvider() {
    try {
      final provider = context.read<RecordsListProvider>();
      final cachedData = provider.getCachedRecords('all', ClusterOrderBy.clusterName);

      if (cachedData != null) {
        final records = cachedData.map((item) => item['record'] as Record).toList();

        // Filter to only records with coordinates
        final recordsWithCoords = records
            .where((record) => record.getCoordinates() != null)
            .toList();

        debugPrint('MapWidget: Loaded ${recordsWithCoords.length} records from provider cache');

        if (!_isDisposed && mounted) {
          setState(() {
            _records = recordsWithCoords;

            // Build cluster polygons
            _clusterPolygons = _buildClusterPolygons(recordsWithCoords);

            // Build historical position polygons from previous_position_data
            _historicalPositionPolygons = _buildHistoricalPositionPolygons(recordsWithCoords);

            // Always update visible records immediately (filtered or all)
            if (!_isMapReady) {
              // If map not ready, show all records
              _visibleRecords = recordsWithCoords;
              debugPrint(
                'MapWidget: Map not ready, showing all ${recordsWithCoords.length} records',
              );
            } else {
              // If map is ready, filter immediately (synchronously for removed records)
              final bounds = _mapController.camera.visibleBounds;
              _visibleRecords = recordsWithCoords.where((record) {
                final coords = record.getCoordinates();
                if (coords == null) return false;

                final lat = coords['latitude'];
                final lng = coords['longitude'];
                if (lat == null || lng == null) return false;

                return lat >= bounds.south &&
                    lat <= bounds.north &&
                    lng >= bounds.west &&
                    lng <= bounds.east;
              }).toList();
              debugPrint(
                'MapWidget: Updated visible records: ${_visibleRecords.length} out of ${recordsWithCoords.length}',
              );
            }

            if (!_markersLoaded && recordsWithCoords.isNotEmpty) {
              _markersLoaded = true;
              _fitCameraToMarkers();
            }
          });
        }
      } else {
        // No cached data means records were cleared - clear visible records too
        if (!_isDisposed && mounted) {
          setState(() {
            _records = [];
            _visibleRecords = [];
            _clusterPolygons = {};
            _historicalPositionPolygons = {};
          });
          debugPrint('MapWidget: Cache cleared, removed all markers');
        }
      }
    } catch (e) {
      debugPrint('MapWidget: Error loading records from provider: $e');
    }
  }

  void _checkForFocusBounds() {
    if (!_isMapReady || _isDisposed) return;

    try {
      final mapControllerProvider = context.read<MapControllerProvider>();
      final focusBounds = mapControllerProvider.focusBounds;
      final timestamp = mapControllerProvider.focusTimestamp;

      // Only focus if this is a new request (timestamp changed)
      if (focusBounds != null && timestamp != null && timestamp != _lastFocusTimestamp) {
        _lastFocusTimestamp = timestamp;
        _lastManualFocusTime = DateTime.now(); // Track manual focus

        debugPrint(
          'Focusing map on bounds: SW(${focusBounds.south}, ${focusBounds.west}) NE(${focusBounds.north}, ${focusBounds.east})',
        );

        // Fit camera to the requested bounds
        _mapController.fitCamera(
          CameraFit.bounds(bounds: focusBounds, padding: const EdgeInsets.all(50)),
        );

        // Clear the focus bounds after applying
        Future.delayed(const Duration(milliseconds: 500), () {
          if (!_isDisposed && mounted) {
            mapControllerProvider.clearFocusBounds();
          }
        });
      }
    } catch (e) {
      debugPrint('Error checking focus bounds: $e');
    }
  }

  void _subscribeToGPS() {
    try {
      final gpsProvider = context.read<GpsPositionProvider>();

      _gpsSubscription = gpsProvider.positionStreamController.listen(
        (position) {
          if (_isDisposed) {
            debugPrint('Cannot update location: disposed=$_isDisposed');
            return;
          }

          setState(() {
            _currentPosition = LatLng(position.latitude, position.longitude);
            _currentAccuracy = position.accuracy;
          });
        },
        onError: (error) {
          debugPrint('❌ GPS stream error: $error');
        },
        onDone: () {
          debugPrint('GPS stream closed');
        },
      );
    } catch (e) {
      debugPrint('❌ Error subscribing to GPS: $e');
    }
  }

  Future<void> _updateVisibleRecords() async {
    if (!_isMapReady) {
      // If map not ready yet, show all records (markers won't render until map is ready anyway)
      if (!_isDisposed && mounted) {
        setState(() {
          _visibleRecords = _records;
        });
        debugPrint('MapWidget: Map not ready, showing all ${_records.length} records');
      }
      return;
    }

    final bounds = _mapController.camera.visibleBounds;

    // Update current bounds in provider
    try {
      final mapControllerProvider = context.read<MapControllerProvider>();
      mapControllerProvider.setCurrentMapBounds(bounds);
    } catch (e) {
      debugPrint('Error updating map bounds in provider: $e');
    }

    // Only update if bounds changed significantly (avoid micro-updates during pan)
    if (_lastBounds != null) {
      final latDiff = (_lastBounds!.north - bounds.north).abs();
      final lngDiff = (_lastBounds!.east - bounds.east).abs();
      if (latDiff < 0.0001 && lngDiff < 0.0001) {
        return; // Bounds haven't changed significantly
      }
    }

    _lastBounds = bounds;

    // Offload filtering to isolate for large datasets
    final visibleRecords = await compute(_filterVisibleRecords, {
      'records': _records,
      'south': bounds.south,
      'north': bounds.north,
      'west': bounds.west,
      'east': bounds.east,
    });

    if (!_isDisposed && mounted) {
      setState(() {
        _visibleRecords = visibleRecords;
      });
      debugPrint('Updated visible records: ${_visibleRecords.length} out of ${_records.length}');
    }
  }

  static List<Record> _filterVisibleRecords(Map<String, dynamic> params) {
    final records = params['records'] as List<Record>;
    final south = params['south'] as double;
    final north = params['north'] as double;
    final west = params['west'] as double;
    final east = params['east'] as double;

    return records.where((record) {
      final coords = record.getCoordinates();
      if (coords == null) return false;

      final lat = coords['latitude'];
      final lng = coords['longitude'];
      if (lat == null || lng == null) return false;

      return lat >= south && lat <= north && lng >= west && lng <= east;
    }).toList();
  }

  void _fitCameraToMarkers() {
    if (_records.isEmpty) return;

    // Skip auto-fit if there was a recent manual focus (within 5 seconds)
    if (_lastManualFocusTime != null) {
      final timeSinceManualFocus = DateTime.now().difference(_lastManualFocusTime!);
      if (timeSinceManualFocus.inSeconds < 5) {
        debugPrint(
          'Skipping auto-fit due to recent manual focus (${timeSinceManualFocus.inSeconds}s ago)',
        );
        return;
      }
    }

    final recordsWithCoords = _records.where((record) => record.getCoordinates() != null).toList();
    if (recordsWithCoords.isEmpty) return;

    double minLat = double.infinity;
    double maxLat = -double.infinity;
    double minLng = double.infinity;
    double maxLng = -double.infinity;

    for (final record in recordsWithCoords) {
      final coords = record.getCoordinates()!;
      final lat = coords['latitude'];
      final lng = coords['longitude'];

      if (lat != null && lng != null) {
        if (lat < minLat) minLat = lat;
        if (lat > maxLat) maxLat = lat;
        if (lng < minLng) minLng = lng;
        if (lng > maxLng) maxLng = lng;
      }
    }

    if (minLat != double.infinity && maxLat != -double.infinity) {
      // Add some padding (10% of the range)
      final latPadding = (maxLat - minLat) * 0.1;
      final lngPadding = (maxLng - minLng) * 0.1;

      debugPrint('Bounding box: SW($minLng, $minLat) NE($maxLng, $maxLat)');

      final bounds = LatLngBounds(
        LatLng(minLat - latPadding, minLng - lngPadding),
        LatLng(maxLat + latPadding, maxLng + lngPadding),
      );

      // Fit camera to bounds
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!_isDisposed && mounted) {
          _mapController.fitCamera(
            CameraFit.bounds(bounds: bounds, padding: const EdgeInsets.all(50)),
          );
          debugPrint('Camera moved to fit all markers');
        }
      });
    }
  }

  List<Marker> _buildMarkers(List<Record> records) {
    // Use cached visible records, excluding the focused record
    return _visibleRecords
        .where(
          (record) =>
              _focusedRecord == null ||
              record.clusterName != _focusedRecord!.clusterName ||
              record.plotName != _focusedRecord!.plotName,
        )
        .map((record) {
          final coords = record.getCoordinates()!;
          final lat = coords['latitude']!;
          final lng = coords['longitude']!;

          return Marker(
            point: LatLng(lat, lng),
            width: 16,
            height: 16,
            child: GestureDetector(
              onTap: () {
                _onMarkerTapped(record);
              },
              child: Container(
                width: 16,
                height: 16,
                decoration: BoxDecoration(
                  color: Colors.red,
                  shape: BoxShape.circle,
                  border: Border.all(color: Colors.white, width: 2),
                ),
              ),
            ),
          );
        })
        .toList();
  }

  List<Marker> _buildLabelMarkers(List<Record> records) {
    // Use cached visible records, excluding the focused record
    return _visibleRecords
        .where(
          (record) =>
              _focusedRecord == null ||
              record.clusterName != _focusedRecord!.clusterName ||
              record.plotName != _focusedRecord!.plotName,
        )
        .map((record) {
          final coords = record.getCoordinates()!;
          final lat = coords['latitude']!;
          final lng = coords['longitude']!;

          final label = '${record.clusterName} | ${record.plotName}';

          return Marker(
            point: LatLng(lat, lng),
            width: 85,
            height: 16,
            alignment: Alignment.bottomCenter,
            child: GestureDetector(
              onTap: () {
                _onMarkerTapped(record);
              },
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 2, vertical: 2),
                decoration: BoxDecoration(
                  color: Colors.black87.withOpacity(0.9),
                  borderRadius: BorderRadius.circular(4),
                  border: Border.all(color: Colors.black54, width: 1),
                ),
                child: Text(
                  label,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 12,
                    fontWeight: FontWeight.bold,
                    decoration: TextDecoration.none,
                  ),
                  textAlign: TextAlign.center,
                  overflow: TextOverflow.ellipsis,
                  maxLines: 2,
                ),
              ),
            ),
          );
        })
        .toList();
  }

  void _onMarkerTapped(Record record) {
    debugPrint('Marker tapped: ${record.clusterName} - ${record.plotName}');

    // Mark as manual interaction to prevent auto-fit
    _lastManualFocusTime = DateTime.now();

    // Also mark in provider to prevent other map instances from auto-fitting
    try {
      final mapControllerProvider = context.read<MapControllerProvider>();
      mapControllerProvider.markManualInteraction();

      // Set the focused record immediately (before navigation)
      // This ensures the circles remain visible during and after navigation
      mapControllerProvider.setFocusedRecord(record);

      // Request navigation through provider (same as from records-selection card tap)
      // This will be handled by start.dart's nested BeamerDelegate
      final navPath =
          '/properties-edit/${Uri.encodeComponent(record.clusterName)}/${Uri.encodeComponent(record.plotName)}';
      mapControllerProvider.requestNavigation(navPath);
    } catch (e) {
      debugPrint('Error marking manual interaction or requesting navigation: $e');
    }
  }

  void _onClusterTapped(List<Marker> markers) {
    debugPrint('Cluster tapped with ${markers.length} markers');
    // Zoom in on cluster
    if (markers.isNotEmpty) {
      final center = markers.first.point;
      _mapController.move(center, _mapController.camera.zoom + 2);
    }
  }

  void _onTreeCircleTapped(int treeNumber) {
    debugPrint('Tree circle tapped: tree_number=$treeNumber');
    try {
      final mapControllerProvider = context.read<MapControllerProvider>();
      mapControllerProvider.selectGridRow('tree', treeNumber);
    } catch (e) {
      debugPrint('Error handling tree circle tap: $e');
    }
  }

  void _onEdgeCircleTapped(int edgeNumber) {
    debugPrint('Edge circle tapped: edge_number=$edgeNumber');
    try {
      final mapControllerProvider = context.read<MapControllerProvider>();
      mapControllerProvider.selectGridRow('edges', edgeNumber);
    } catch (e) {
      debugPrint('Error handling edge circle tap: $e');
    }
  }

  Widget _buildClusterMarker(BuildContext context, List<Marker> markers) {
    final pointCount = markers.length;

    // Determine color based on point count
    Color markerColor;
    if (pointCount <= 4) {
      markerColor = Colors.red;
    } else if (pointCount < 250) {
      markerColor = aggregatedMarkerColors[2];
    } else if (pointCount < 500) {
      markerColor = aggregatedMarkerColors[3];
    } else if (pointCount < 1000) {
      markerColor = aggregatedMarkerColors[4];
    } else if (pointCount < 2500) {
      markerColor = aggregatedMarkerColors[5];
    } else {
      markerColor = aggregatedMarkerColors[6];
    }

    // Determine size based on point count
    double size;
    if (pointCount <= 4) {
      size = 40;
    } else if (pointCount < 100) {
      size = 50;
    } else if (pointCount < 750) {
      size = 60;
    } else {
      size = 70;
    }

    return GestureDetector(
      onTap: () => _onClusterTapped(markers),
      child: Container(
        width: size,
        height: size,
        decoration: BoxDecoration(
          color: markerColor,
          shape: BoxShape.circle,
          border: Border.all(color: Colors.white, width: 2),
        ),
        //child: Center(
        //  child: Text(
        //    displayText,
        //    style: const TextStyle(color: Colors.white, fontSize: 14, fontWeight: FontWeight.bold),
        //    textAlign: TextAlign.center,
        //  ),
        //),
      ),
    );
  }

  List<CircleMarker> _getDefaultCircles(Record record) {
    final coords = record.getCoordinates();
    if (coords == null) return [];

    return [
      // 25m radius circle
      CircleMarker(
        point: LatLng(
          _focusedRecord!.getCoordinates()!['latitude']!,
          _focusedRecord!.getCoordinates()!['longitude']!,
        ),
        radius: 25.0,
        useRadiusInMeter: true,
        color: Color.fromARGB(15, 120, 189, 30),
        borderColor: Color.fromARGB(155, 120, 189, 30),
        borderStrokeWidth: 1.0,
      ),
      // 10m radius circle
      CircleMarker(
        point: LatLng(
          _focusedRecord!.getCoordinates()!['latitude']!,
          _focusedRecord!.getCoordinates()!['longitude']!,
        ),
        radius: 10.0,
        useRadiusInMeter: true,
        color: Color.fromARGB(15, 120, 189, 30),
        borderColor: Color.fromARGB(155, 120, 189, 30),
        borderStrokeWidth: 1.0,
      ),
      // 5m radius circle
      CircleMarker(
        point: LatLng(
          _focusedRecord!.getCoordinates()!['latitude']!,
          _focusedRecord!.getCoordinates()!['longitude']!,
        ),
        radius: 5.0,
        useRadiusInMeter: true,
        color: Color.fromARGB(15, 120, 189, 30),
        borderColor: Color.fromARGB(155, 120, 189, 30),
        borderStrokeWidth: 1.0,
      ),
    ];
  }

  void _openMapSettings() {
    MapSettingsModal.show(
      context,
      selectedBasemaps: _selectedBasemaps,
      treeDiameterMultiplier: _treeDiameterMultiplier,
      showTreeLabels: _showTreeLabels,
      treeLabelFields: _treeLabelFields,
      showEdges: _showEdges,
      showCrownCircles: _showCrownCircles,
      showClusterPolygons: _showClusterPolygons,
      showProbekreise: _showProbekreise,
      onBasemapsChanged: (newBasemaps) {
        setState(() {
          _selectedBasemaps = newBasemaps;
        });
        _saveMapSettings();
      },
      onTreeDiameterMultiplierChanged: (newMultiplier) {
        setState(() {
          _treeDiameterMultiplier = newMultiplier;
        });
        _saveMapSettings();
      },
      onShowTreeLabelsChanged: (value) {
        setState(() {
          _showTreeLabels = value;
        });
        _saveMapSettings();
      },
      onTreeLabelFieldsChanged: (fields) {
        setState(() {
          _treeLabelFields = fields;
        });
        _saveMapSettings();
      },
      onShowEdgesChanged: (value) {
        setState(() => _showEdges = value);
        _saveMapSettings();
      },
      onShowCrownCirclesChanged: (value) {
        setState(() => _showCrownCircles = value);
        _saveMapSettings();
      },
      onShowClusterPolygonsChanged: (value) {
        setState(() => _showClusterPolygons = value);
        _saveMapSettings();
      },
      onShowProbekreiseChanged: (value) {
        setState(() => _showProbekreise = value);
        _saveMapSettings();
      },
    );
  }

  @override
  void dispose() {
    _isDisposed = true;
    _debounceTimer?.cancel();
    _gpsSubscription?.cancel();
    _gpsSubscription = null;

    // Remove listeners
    try {
      final mapControllerProvider = context.read<MapControllerProvider>();
      mapControllerProvider.removeListener(_onMapControllerProviderChanged);

      final recordsProvider = context.read<RecordsListProvider>();
      recordsProvider.removeListener(_onProviderChanged);
    } catch (e) {
      debugPrint('Error removing listeners: $e');
    }

    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final initialCenter = widget.initialCenter ?? const LatLng(51.1657, 10.4515);
    final initialZoom = widget.initialZoom ?? 5.5;
    final markers = _buildMarkers(_records);

    // Watch for distance line and navigation updates from provider
    final mapControllerProvider = context.watch<MapControllerProvider>();
    final distanceLineFrom = mapControllerProvider.distanceLineFrom;
    final distanceLineTo = mapControllerProvider.distanceLineTo;
    final navigationStart = mapControllerProvider.navigationStart;
    final navigationTarget = mapControllerProvider.navigationTarget;
    final navigationStepsLineString = mapControllerProvider.navigationStepsLineString;
    final navigationTargetLineString = mapControllerProvider.navigationTargetLineString;

    return FlutterMap(
      mapController: _mapController,
      options: MapOptions(
        initialCenter: initialCenter,
        initialZoom: initialZoom,
        minZoom: 4.0,
        maxZoom: 24.0,
        interactionOptions: const InteractionOptions(
          flags: InteractiveFlag.all & ~InteractiveFlag.rotate,
        ),
        onMapReady: () {
          setState(() {
            _isMapReady = true;
          });
          _updateVisibleRecords();
        },
        onTap: (tapPosition, point) {
          final mapProvider = context.read<MapControllerProvider>();
          if (mapProvider.isMapTapEnabled) {
            // Position selection mode - emit tap event
            mapProvider.onMapTapped(point);
          } else {
            // Normal mode - open map settings
            _openMapSettings();
          }
        },
        onPositionChanged: (position, hasGesture) {
          final newZoom = position.zoom;

          // Immediate update if crossing zoom 13 threshold (for label visibility)
          final shouldShowLabels = newZoom >= 13;
          final wasShowingLabels = _currentZoom >= 13;

          if (shouldShowLabels != wasShowingLabels) {
            setState(() {
              _currentZoom = newZoom;
            });
          } else {
            _currentZoom = newZoom;
          }

          // Debounce viewport updates to avoid rebuilding on every frame
          _debounceTimer?.cancel();
          _debounceTimer = Timer(const Duration(milliseconds: 200), () {
            if (!_isDisposed && mounted) {
              _updateVisibleRecords();
              setState(() {});
            }
          });
        },
      ),
      children: [
        // Tile Layers - rendered in order: OpenCycleMap → ESRI Satellite → DOP (top)

        // Layer 1: OpenCycleMap (offline, covers zoom 4-18)
        if (_selectedBasemaps.contains('opencycle') && _storesInitialized)
          TileLayer(
            // https://b.tile-cyclosm.openstreetmap.fr/cyclosm/{z}/{x}/{y}.png
            urlTemplate: 'https://{s}.tile-cyclosm.openstreetmap.fr/cyclosm/{z}/{x}/{y}.png',
            userAgentPackageName: 'com.thuenen.terrestrial_forest_monitor',
            subdomains: const ['a', 'b', 'c'],
            maxNativeZoom: 24, // Tiles only available up to zoom 18, upscale for higher zooms
            tileProvider: FMTCStore('OpenCycleMap').getTileProvider(
              settings: FMTCTileProviderSettings(behavior: CacheBehavior.cacheFirst),
            ),
          ),

        // Layer 2: ESRI Satellite (free worldwide satellite imagery)
        if (_selectedBasemaps.contains('esri_satellite') && _storesInitialized)
          TileLayer(
            urlTemplate:
                'https://server.arcgisonline.com/ArcGIS/rest/services/World_Imagery/MapServer/tile/{z}/{y}/{x}',
            userAgentPackageName: 'com.thuenen.terrestrial_forest_monitor',
            maxNativeZoom: 19,
            tileProvider: FMTCStore('esri_satellite').getTileProvider(
              settings: FMTCTileProviderSettings(behavior: CacheBehavior.cacheFirst),
            ),
          ),

        // Layer 3: DOP (offline aerial imagery, zoom 15-19)
        if (_selectedBasemaps.contains('dop') &&
            _storesInitialized &&
            dotenv.env['DMZ_KEY'] != null &&
            dotenv.env['DMZ_KEY']!.isNotEmpty)
          TileLayer(
            wmsOptions: WMSTileLayerOptions(
              baseUrl: 'https://sg.geodatenzentrum.de/wms_dop__${dotenv.env['DMZ_KEY']}?',
              layers: const ['rgb'],
              format: 'image/jpeg',
              crs: const Epsg3857(),
            ),
            userAgentPackageName: 'com.thuenen.terrestrial_forest_monitor',
            tileBounds: LatLngBounds(LatLng(-90, -180), LatLng(90, 180)),
            minZoom: 15, // Only show from zoom 15 onwards
            maxNativeZoom: 19,
            tileProvider: FMTCStore('wms_dop__').getTileProvider(
              settings: FMTCTileProviderSettings(
                behavior: CacheBehavior.cacheFirst,
                cachedValidDuration: const Duration(days: 30),
              ),
            ),
            errorTileCallback: (tile, error, stackTrace) {
              // Enhanced error logging to detect proxy issues
              final errorMsg = error.toString().toLowerCase();
              if (errorMsg.contains('timeout') ||
                  errorMsg.contains('certificate') ||
                  errorMsg.contains('proxy') ||
                  errorMsg.contains('connection')) {
                debugPrint('🔴 PROXY/NETWORK ERROR loading DOP tile ${tile.coordinates}:');
                debugPrint('   Error: $error');
                debugPrint('   Possible cause: Proxy blocking geodatenzentrum.de');
              } else {
                debugPrint('🔴 Error loading DOP tile ${tile.coordinates}: $error');
              }
              if (stackTrace != null) {
                debugPrint('   Stack: $stackTrace');
              }
            },
          ),

        // Clustered Markers from records
        if (markers.isNotEmpty)
          MarkerClusterLayerWidget(
            options: MarkerClusterLayerOptions(
              maxClusterRadius: 50,
              size: const Size(40, 40),
              markers: markers,
              builder: _buildClusterMarker,
            ),
          ),

        // Cluster polygons (shown at zoom 16+)
        if (_showClusterPolygons && _clusterPolygons.isNotEmpty && _currentZoom > 14)
          PolygonLayer(
            polygons: _clusterPolygons.entries
                .map((entry) {
                  final points = entry.value;

                  // Only draw polygon if there are at least 3 points
                  if (points.length < 3) return null;

                  return Polygon(
                    points: points,
                    color: aggregatedMarkerColors[0].withAlpha(
                      25,
                    ), // Color.fromARGB(15, 0, 0, 255),
                    borderColor: aggregatedMarkerColors[0].withAlpha(100),
                    borderStrokeWidth: 1.0,
                  );
                })
                .whereType<Polygon>()
                .toList(),
          ),

        // Historical position polygons from previous_position_data (shown at zoom 16+)
        // Only show for the focused record's cluster
        // Filter based on visibility settings from MapControllerProvider
        if (_showClusterPolygons &&
            _historicalPositionPolygons.isNotEmpty &&
            _currentZoom > 14 &&
            _focusedRecord != null)
          PolygonLayer(
            polygons: _historicalPositionPolygons.entries
                .where((clusterEntry) => clusterEntry.key == _focusedRecord!.clusterId)
                .expand((clusterEntry) {
                  // For each cluster, create polygons for all measurement periods
                  return clusterEntry.value.entries
                      .where((measurementEntry) {
                        // Filter based on visibility from MapControllerProvider
                        final measurementKey = measurementEntry.key;
                        final recordId = _focusedRecord?.id;
                        // If no record ID, show all by default
                        if (recordId == null) return true;
                        return mapControllerProvider.isPreviousPositionVisible(
                          recordId,
                          measurementKey,
                        );
                      })
                      .map((measurementEntry) {
                        final points = measurementEntry.value;
                        final measurementKey = measurementEntry.key;

                        // Only draw polygon if there are at least 3 points
                        if (points.length < 3) return null;

                        return Polygon(
                          points: points,
                          color: _getColorForMeasurementPeriod(measurementKey).withOpacity(0.15),
                          borderColor: _getColorForMeasurementPeriod(measurementKey),
                          borderStrokeWidth: 2.0,
                        );
                      });
                })
                .whereType<Polygon>()
                .toList(),
          ),

        // Display PREVIOUS edges (with opacity)
        if (_showEdges && _previousEdges.isNotEmpty)
          EdgeLayers.buildPolylineLayer(
            _previousEdges,
            withOpacity: true,
            color: intervalColorCache['previousColor']!,
          ),
        if (_showEdges && _previousEdges.isNotEmpty)
          EdgeLayers.buildCircleLayer(
            _previousEdges,
            withOpacity: true,
            color: intervalColorCache['previousColor']!,
          ),
        if (_showEdges && _previousEdges.isNotEmpty)
          EdgeLayers.buildMarkerLayer(
            _previousEdges,
            withOpacity: true,
            color: intervalColorCache['previousColor']!,
          ),

        // Display CURRENT edges (without opacity)
        if (_showEdges && _edges.isNotEmpty)
          EdgeLayers.buildPolylineLayer(
            _edges,
            withOpacity: false,
            color: intervalColorCache['currentColor']!,
          ),
        if (_showEdges && _edges.isNotEmpty)
          EdgeLayers.buildCircleLayer(
            _edges,
            withOpacity: false,
            color: intervalColorCache['currentColor']!,
          ),
        if (_showEdges && _edges.isNotEmpty)
          EdgeLayers.buildMarkerLayer(
            _edges,
            withOpacity: false,
            color: intervalColorCache['currentColor']!,
          ),

        // Clickable layer for CURRENT edges (on top for click handling)
        if (_showEdges && _edges.isNotEmpty)
          EdgeLayers.buildClickableLayer(_edges, _onEdgeCircleTapped),

        // Display PREVIOUS subplots (with opacity)
        /*if (_previousSubplotPositions.isNotEmpty)
          SubplotLayers.buildCircleLayer(_previousSubplotPositions, withOpacity: true),*/
        //if (_previousSubplotPositions.isNotEmpty)
        //  SubplotLayers.buildMarkerLayer(_previousSubplotPositions, withOpacity: true),

        // Display CURRENT subplots (without opacity)
        if (_subplotPositions.isNotEmpty)
          SubplotLayers.buildCircleLayer(_subplotPositions, withOpacity: true),
        //if (_subplotPositions.isNotEmpty)
        //  SubplotLayers.buildMarkerLayer(_subplotPositions, withOpacity: false),

        // Distance line - DO NOT SHOW when navigation is active
        if (distanceLineFrom != null &&
            distanceLineTo != null &&
            navigationStart == null &&
            navigationTarget == null)
          PolylineLayer(
            polylines: [
              Polyline(
                points: [distanceLineFrom, distanceLineTo],
                color: Colors.orange,
                strokeWidth: 3.0,
              ),
            ],
          ),

        // Record Labels (shown at zoom 14+)
        if (_currentZoom > 14 && _records.isNotEmpty)
          MarkerLayer(markers: _buildLabelMarkers(_records)),

        // Default circles / Probekreise (5m, 10m, 25m radius)
        if (_showProbekreise && _focusedRecord != null)
          CircleLayer(circles: _getDefaultCircles(_focusedRecord!)),

        // Tree crown circles / Grenzkreise for CURRENT trees (based on DBH)
        if (_showCrownCircles && _focusedRecord != null && _treePositions.isNotEmpty)
          TreeCrownLayers.buildCrownCircleLayer(
            _treePositions,
            withOpacity: false,
            crownColor: intervalColorCache['currentColor']!.withOpacity(0.1),
            borderColor: intervalColorCache['currentColor'],
            borderStrokeWidth: 1.0,
          ),

        // Display PREVIOUS trees (with opacity for differentiation)
        if (_focusedRecord != null && _previousTreePositions.isNotEmpty)
          TreeLayers.buildCircleLayer(
            _previousTreePositions,
            _treeDiameterMultiplier,
            //withOpacity: true,
            showNull: true,
            treeColor: intervalColorCache['previousColor']!,
            nullTreeColor: Colors.black.withAlpha(50),
            borderStrokeWidth: 0.0,
            borderColor: Colors.transparent,
          ),
        // Display CURRENT trees (without opacity, on top)
        if (_focusedRecord != null && _treePositions.isNotEmpty)
          TreeLayers.buildCircleLayer(
            _treePositions,
            _treeDiameterMultiplier,
            //withOpacity: false,
            showNull: true,
            treeColor: intervalColorCache['currentColor']!,
            nullTreeColor: Colors.red,
            borderStrokeWidth: 0.0,
            borderColor: Colors.transparent,
          ),
        // Display PREVIOUS trees (with opacity for differentiation)
        if (_focusedRecord != null && _previousTreePositions.isNotEmpty)
          TreeLayers.buildCircleLayer(
            _previousTreePositions,
            _treeDiameterMultiplier,
            //withOpacity: true,
            showNull: false,
            treeColor: Colors.transparent,
            nullTreeColor: Colors.black.withAlpha(50),
            borderStrokeWidth: 1.0,
            borderColor: intervalColorCache['previousColor']!,
          ),
        //if (_focusedRecord != null && _previousTreePositions.isNotEmpty && _showTreeLabels)
        //  TreeLayers.buildMarkerLayer(_previousTreePositions, _treeLabelFields, withOpacity: false),
        if (_focusedRecord != null && _treePositions.isNotEmpty && _showTreeLabels)
          TreeLayers.buildMarkerLayer(
            _treePositions,
            _treeLabelFields,
            withOpacity: false,
            previousTreePositions: _previousTreePositions,
            intervalColorCache: intervalColorCache,
            treeSpeciesLookup: _treeSpeciesLookup,
          ),

        // Clickable layer for CURRENT trees (on top for click handling)
        //if (_focusedRecord != null && _treePositions.isNotEmpty)
        //  TreeLayers.buildClickableLayer(_treePositions, _onTreeCircleTapped),

        // GPS Location Marker (accuracy circle)
        if (_currentPosition != null && _currentAccuracy != null)
          CircleLayer(
            circles: [
              CircleMarker(
                point: _currentPosition!,
                radius: _currentAccuracy! < 5 ? 5.0 : _currentAccuracy!,
                useRadiusInMeter: true,
                color: Colors.blue.withOpacity(0.2),
                borderColor: Colors.blue.withOpacity(0.5),
                borderStrokeWidth: 1,
              ),
            ],
          ),

        // GPS Location Marker (center dot)
        if (_currentPosition != null)
          MarkerLayer(
            markers: [
              Marker(
                point: _currentPosition!,
                width: 12,
                height: 12,
                child: Container(
                  decoration: BoxDecoration(
                    color: Colors.blue,
                    shape: BoxShape.circle,
                    border: Border.all(color: Colors.white, width: 2),
                  ),
                ),
              ),
            ],
          ),

        // NAVIGATION LAYERS - Rendered on top
        // Navigation line 1: Start → Steps (solid blue line)
        if (navigationStepsLineString != null && navigationStepsLineString.length >= 2)
          PolylineLayer(
            polylines: [
              Polyline(
                points: navigationStepsLineString,
                color: Colors.blue.withOpacity(0.7),
                strokeWidth: 3.0,
              ),
            ],
          ),

        // Navigation line 2: Last step/Start → Target (dashed blue line)
        if (navigationTargetLineString != null && navigationTargetLineString.length >= 2)
          PolylineLayer(
            polylines: [
              Polyline(
                points: navigationTargetLineString,
                color: Colors.blue.withOpacity(0.7),
                strokeWidth: 3.0,
                pattern: StrokePattern.dashed(segments: [10, 5]),
              ),
            ],
          ),

        // Navigation step markers (intermediate points from steps line)
        if (navigationStepsLineString != null && navigationStepsLineString.length > 1)
          CircleLayer(
            circles: navigationStepsLineString
                .sublist(1, navigationStepsLineString.length) // Exclude start point
                .map(
                  (point) => CircleMarker(
                    point: point,
                    radius: 4.0,
                    color: Colors.blue.withOpacity(0.9),
                    borderColor: Colors.white,
                    borderStrokeWidth: 2,
                  ),
                )
                .toList(),
          ),

        // Navigation start marker (green pin)
        if (navigationStart != null)
          MarkerLayer(
            markers: [
              Marker(
                point: navigationStart,
                width: 40,
                height: 40,
                alignment: Alignment.topCenter,
                child: Icon(
                  Icons.location_on,
                  color: Colors.blue,
                  size: 40,
                  shadows: [Shadow(color: Colors.black.withOpacity(0.5), blurRadius: 4)],
                ),
              ),
            ],
          ),

        // Navigation target marker (green pin)
        if (navigationTarget != null)
          MarkerLayer(
            markers: [
              Marker(
                point: navigationTarget,
                width: 40,
                height: 40,
                alignment: Alignment.topCenter,
                child: Icon(
                  Icons.where_to_vote,
                  color: Colors.blue,
                  size: 40,
                  shadows: [Shadow(color: Colors.black.withOpacity(0.5), blurRadius: 4)],
                ),
              ),
            ],
          ),

        // Scale bar - positioned based on sheet position
        // Account for both sheet height and map vertical offset
        Positioned(
          left: 60,
          bottom: widget.sheetPosition != null
              ? MediaQuery.of(context).size.height * (widget.sheetPosition! * 0.5 + 0.11)
              : MediaQuery.of(context).padding.bottom + 8,
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: Color.fromARGB(100, 200, 200, 200),
                  borderRadius: BorderRadius.circular(4),
                  border: Border.all(color: Colors.black26, width: 1),
                ),
                child: Scalebar(
                  textStyle: const TextStyle(
                    color: Colors.black,
                    fontSize: 12,
                    fontWeight: FontWeight.bold,
                  ),
                  lineColor: Colors.black,
                  strokeWidth: 2,
                  padding: EdgeInsets.zero,
                ),
              ),
            ],
          ),
        ),
        // Zoom buttons - only show on tablets and larger screens
        //if (MediaQuery.of(context).size.width >= 600)
        Positioned(
          right: 70,
          bottom: widget.sheetPosition != null
              ? MediaQuery.of(context).size.height * (widget.sheetPosition! * 0.5 + 0.11)
              : MediaQuery.of(context).padding.bottom + 8,
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              // Zoom buttons
              Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  // Zoom out button
                  Container(
                    decoration: BoxDecoration(
                      color: Theme.of(context).colorScheme.surface,
                      borderRadius: BorderRadius.circular(40),
                    ),
                    child: IconButton(
                      icon: Icon(
                        Icons.remove,
                        size: 20,
                        color: Theme.of(context).colorScheme.onSurface,
                      ),
                      constraints: const BoxConstraints(minWidth: 32, minHeight: 32),
                      onPressed: () {
                        final currentZoom = _mapController.camera.zoom;
                        final currentCenter = _mapController.camera.center;
                        _mapController.move(currentCenter, currentZoom - 1);
                      },
                    ),
                  ),

                  // Divider
                  const SizedBox(width: 8),
                  // Zoom in button
                  Container(
                    decoration: BoxDecoration(
                      color: Theme.of(context).colorScheme.surface,
                      borderRadius: BorderRadius.circular(40),
                    ),
                    child: IconButton(
                      icon: Icon(
                        Icons.add,
                        size: 20,
                        color: Theme.of(context).colorScheme.onSurface,
                      ),
                      constraints: const BoxConstraints(minWidth: 32, minHeight: 32),
                      onPressed: () {
                        final currentZoom = _mapController.camera.zoom;
                        final currentCenter = _mapController.camera.center;
                        _mapController.move(currentCenter, currentZoom + 1);
                      },
                    ),
                  ),
                  // Divider
                  const SizedBox(width: 8),
                  // Zoom to current location button
                  Container(
                    decoration: BoxDecoration(
                      color: Theme.of(context).colorScheme.surface,
                      borderRadius: BorderRadius.circular(40),
                    ),
                    child: IconButton(
                      icon: Icon(
                        Icons.my_location,
                        size: 20,
                        color: _currentPosition != null
                            ? Theme.of(context).colorScheme.primary
                            : Theme.of(context).colorScheme.onSurface.withOpacity(0.4),
                      ),
                      constraints: const BoxConstraints(minWidth: 32, minHeight: 32),
                      onPressed: _currentPosition != null
                          ? () {
                              _mapController.move(_currentPosition!, 17.0);
                            }
                          : null,
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ],
    );
  }
}
