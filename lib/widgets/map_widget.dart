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
import 'package:terrestrial_forest_monitor/widgets/cluster/order-cluster-by.dart';
import 'package:terrestrial_forest_monitor/widgets/map/map-settings.dart';
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
  List<Map<String, dynamic>> _treePositions = [];
  Map<String, List<LatLng>> _clusterPolygons = {};
  List<CircleMarker>? _cachedTreeCircles;
  Map<String, Map<String, List<LatLng>>> _historicalPositionPolygons = {};
  double _treeDiameterMultiplier = 1.0;

  List<Color> aggregatedMarkerColors = [
    Color.fromARGB(255, 0, 170, 170), // #0aa
    Color.fromARGB(255, 0, 170, 130), // #00aa82
    Color.fromARGB(255, 0, 159, 224), // #009fe0
    Color.fromARGB(255, 120, 189, 30), // #78bd1e
    Color.fromARGB(255, 201, 219, 156), // #c9db9c
    Color.fromARGB(255, 213, 123, 22), // #d57b16
    Color.fromARGB(255, 235, 192, 139), // #ebc08b
  ];

  @override
  void initState() {
    super.initState();

    // Initialize FMTC stores
    _initializeTileStores();

    // Load saved basemap preference
    _loadMapSettings();

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

  Future<void> _checkForFocusedRecord() async {
    try {
      final mapControllerProvider = context.read<MapControllerProvider>();
      final focusedRecord = mapControllerProvider.focusedRecord;

      if (focusedRecord != _focusedRecord) {
        final treePositions = focusedRecord != null
            ? await _calculateTreePositions(focusedRecord)
            : <Map<String, dynamic>>[];

        if (!_isDisposed && mounted) {
          setState(() {
            _focusedRecord = focusedRecord;
            _treePositions = treePositions;
            // Update cached tree circles when positions change
            _cachedTreeCircles = treePositions.isNotEmpty ? _treeCircles(treePositions) : null;
          });
        }
      }
    } catch (e) {
      debugPrint('Error checking focused record: $e');
    }
  }

  Future<List<Map<String, dynamic>>> _calculateTreePositions(Record record) async {
    // Offload tree position calculations to isolate
    return compute(_computeTreePositions, {
      'recordCoords': record.getCoordinates(),
      'properties': record.properties,
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
        if (record.previousPositionData != null) {
          // Iterate through all measurements (bwi2012, bwi2022, etc.)
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
                // Group by measurement period
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
        final dbh = tree['dbh'];

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
            'data': tree,
          });
        }
      }
    } catch (e) {
      debugPrint('Error calculating tree positions: $e');
    }

    return positions;
  }

  Future<void> _initializeTileStores() async {
    try {
      // Initialize OpenCycleMap store
      final openCycleStore = FMTCStore('opencyclemap');
      if (!(await openCycleStore.manage.ready)) {
        await openCycleStore.manage.create();
        debugPrint('Created opencyclemap tile store');
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
    } catch (e) {
      debugPrint('Error loading map settings: $e');
    }
  }

  Future<void> _saveMapSettings() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setStringList('map_basemaps', _selectedBasemaps.toList());
      await prefs.setDouble('tree_diameter_multiplier', _treeDiameterMultiplier);
    } catch (e) {
      debugPrint('Error saving map settings: $e');
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
            height: 20,
            alignment: Alignment.bottomCenter,

            child: GestureDetector(
              onTap: () {
                _onMarkerTapped(record);
              },
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 2, vertical: 2),
                decoration: BoxDecoration(
                  color: Colors.white.withOpacity(0.9),
                  borderRadius: BorderRadius.circular(4),
                  border: Border.all(color: Colors.black54, width: 1),
                ),
                child: Text(
                  label,
                  style: const TextStyle(
                    color: Colors.black,
                    fontSize: 10,
                    fontWeight: FontWeight.bold,
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

  Widget _buildClusterMarker(BuildContext context, List<Marker> markers) {
    final pointCount = markers.length;

    // Show count instead of empty text
    String displayText = pointCount.toString();

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

  List<CircleMarker> _treeCircles(List<Map<String, dynamic>> treePositions) {
    debugPrint(
      'Building ${treePositions.length} tree circle markers with multiplier $_treeDiameterMultiplier',
    );
    return treePositions.map((tree) {
      final lat = tree['lat'] as double;
      final lng = tree['lng'] as double;
      final dbh = tree['dbh']; // DBH in millimeters

      // Calculate radius: DBH is in mm, convert to meters and divide by 2
      // Apply the diameter multiplier
      // If dbh is null, use a default small radius of 0.05m (5cm)
      final radiusMeters = dbh != null
          ? ((dbh as num).toDouble() / 1000.0 / 2.0) * _treeDiameterMultiplier
          : 0.1;

      final isNull = dbh == null;

      return CircleMarker(
        point: LatLng(lat, lng),
        radius: radiusMeters,
        useRadiusInMeter: true,
        color: isNull ? Color.fromARGB(255, 0, 0, 0) : Color.fromARGB(255, 255, 255, 0), // yellow
      );
    }).toList();
  }

  List<CircleMarker> _getDefaultCircles(Record record) {
    final coords = record.getCoordinates();
    if (coords == null) return [];

    final centerLat = coords['latitude']!;
    final centerLng = coords['longitude']!;

    return [
      // 25m radius circle
      CircleMarker(
        point: LatLng(
          _focusedRecord!.getCoordinates()!['latitude']!,
          _focusedRecord!.getCoordinates()!['longitude']!,
        ),
        radius: 25.0,
        useRadiusInMeter: true,
        color: const Color.fromARGB(25, 0, 159, 224),
      ),
      // 10m radius circle
      CircleMarker(
        point: LatLng(
          _focusedRecord!.getCoordinates()!['latitude']!,
          _focusedRecord!.getCoordinates()!['longitude']!,
        ),
        radius: 10.0,
        useRadiusInMeter: true,
        color: const Color.fromARGB(25, 0, 170, 130),
      ),
      // 5m radius circle
      CircleMarker(
        point: LatLng(
          _focusedRecord!.getCoordinates()!['latitude']!,
          _focusedRecord!.getCoordinates()!['longitude']!,
        ),
        radius: 5.0,
        useRadiusInMeter: true,
        color: const Color.fromARGB(25, 0, 170, 170),
      ),
    ];
  }

  void _openMapSettings() {
    MapSettingsModal.show(
      context,
      selectedBasemaps: _selectedBasemaps,
      treeDiameterMultiplier: _treeDiameterMultiplier,
      onBasemapsChanged: (newBasemaps) {
        setState(() {
          _selectedBasemaps = newBasemaps;
        });
        _saveMapSettings();
      },
      onTreeDiameterMultiplierChanged: (newMultiplier) {
        setState(() {
          _treeDiameterMultiplier = newMultiplier;
          // Rebuild tree circles with new multiplier
          if (_treePositions.isNotEmpty) {
            _cachedTreeCircles = _treeCircles(_treePositions);
          }
        });
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

    // Watch for distance line updates from provider
    final mapControllerProvider = context.watch<MapControllerProvider>();
    final distanceLineFrom = mapControllerProvider.distanceLineFrom;
    final distanceLineTo = mapControllerProvider.distanceLineTo;

    return FlutterMap(
      mapController: _mapController,
      options: MapOptions(
        initialCenter: initialCenter,
        initialZoom: initialZoom,
        minZoom: 4.0,
        maxZoom: 22.0,
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
          _openMapSettings();
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
        // Tile Layers - rendered in order: OpenCycleMap → DOP (top)

        // Layer 1: OpenCycleMap (offline, covers zoom 4-18)
        if (_selectedBasemaps.contains('opencycle') && _storesInitialized)
          TileLayer(
            // https://b.tile-cyclosm.openstreetmap.fr/cyclosm/{z}/{x}/{y}.png
            urlTemplate: 'https://{s}.tile-cyclosm.openstreetmap.fr/cyclosm/{z}/{x}/{y}.png ',
            userAgentPackageName: 'com.thuenen.terrestrial_forest_monitor',
            subdomains: const ['a', 'b', 'c'],
            //maxZoom: _selectedBasemaps.contains('dop')
            //    ? 14
            //    : 19, // Limit to zoom 14 if DOP is enabled
            //maxNativeZoom: 18,
            tileProvider: FMTCStore('opencyclemap').getTileProvider(
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
              debugPrint('Error loading DOP tile ${tile.coordinates}: $error');
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
        if (_clusterPolygons.isNotEmpty && _currentZoom > 14)
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
        if (_historicalPositionPolygons.isNotEmpty && _currentZoom > 14 && _focusedRecord != null)
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

        // Distance line (from navigation element)
        if (distanceLineFrom != null && distanceLineTo != null)
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

        // Line from center to trees
        //if (_focusedRecord != null && _treePositions.isNotEmpty)
        //  PolylineLayer(polylines: _buildTreeLines(_focusedRecord!, _treePositions)),
        if (_focusedRecord != null) CircleLayer(circles: _getDefaultCircles(_focusedRecord!)),

        // Tree positions for focused record (cached)
        if (_focusedRecord != null && _cachedTreeCircles != null)
          CircleLayer(circles: _cachedTreeCircles!),

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

        // Scale bar - positioned based on sheet position
        // Account for both sheet height and map vertical offset
        Positioned(
          left: 8,
          bottom: widget.sheetPosition != null
              ? MediaQuery.of(context).size.height * (widget.sheetPosition! * 0.5 + 0.15 * 0.5) + 8
              : MediaQuery.of(context).size.height * 0.075 + 8,
          child: Container(
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
        ),
      ],
    );
  }
}
