import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart'; // Add for compute
import 'dart:math' show Point;
import 'package:maplibre_gl/maplibre_gl.dart';
import 'package:provider/provider.dart';
import 'package:terrestrial_forest_monitor/repositories/records_repository.dart';
import 'package:terrestrial_forest_monitor/providers/records_list_provider.dart';
import 'package:terrestrial_forest_monitor/providers/gps-position.dart';
import 'package:terrestrial_forest_monitor/providers/map_controller_provider.dart';
import 'package:terrestrial_forest_monitor/widgets/cluster/order-cluster-by.dart';
import 'dart:convert';
import 'dart:async';

// Top-level function for compute isolation
Map<String, dynamic> _createGeoJsonInIsolate(List<Map<String, dynamic>> recordsData) {
  final features =
      recordsData.map((data) {
        return {
          'type': 'Feature',
          'geometry': {
            'type': 'Point',
            'coordinates': [data['longitude'], data['latitude']],
          },
          'properties': {'id': data['id'], 'cluster_name': data['cluster_name'], 'plot_name': data['plot_name']},
        };
      }).toList();

  return {'type': 'FeatureCollection', 'features': features};
}

class MapWidgetMapLibre extends StatefulWidget {
  final LatLng? initialCenter;
  final double? initialZoom;
  final double? sheetPosition;

  const MapWidgetMapLibre({super.key, this.initialCenter, this.initialZoom, this.sheetPosition});

  @override
  State<MapWidgetMapLibre> createState() => _MapWidgetMapLibreState();
}

class _MapWidgetMapLibreState extends State<MapWidgetMapLibre> {
  MapLibreMapController? _mapController;
  List<Record> _records = [];
  bool _markersLoaded = false;
  bool _isDisposed = false;
  StreamSubscription? _gpsSubscription;
  Circle? _locationCircle;
  Circle? _accuracyCircle;
  bool _isUpdatingLocation = false;

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
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (!_markersLoaded && !_isDisposed) {
      _loadRecords();
    }
    // Subscribe to GPS updates
    if (_gpsSubscription == null && !_isDisposed) {
      _subscribeToGPS();
    }
  }

  Future<void> _loadRecords() async {
    try {
      // Try to get cached records from provider first
      final provider = context.read<RecordsListProvider>();
      final cachedRecords = provider.getCachedRecords('all', ClusterOrderBy.clusterName);

      List<Record> records;
      if (cachedRecords != null && cachedRecords.isNotEmpty) {
        // Use cached records (extract Record objects from Map)
        records = cachedRecords.map((item) => item['record'] as Record).toList();
        debugPrint('Using ${records.length} cached records for map');
      } else {
        // Load from database with reasonable limit (clustering will handle aggregation)
        records = await RecordsRepository().getRecordsGroupedByCluster(limit: 100000);
        debugPrint('Loaded ${records.length} records from database for map');
      }

      if (!mounted || _isDisposed) return;

      setState(() {
        _records = records;
        _markersLoaded = true;
      });

      // Add markers to map if controller is ready
      if (_mapController != null && !_isDisposed) {
        await _addMarkers();
      }
    } catch (e) {
      debugPrint('Error loading records for map: $e');
    }
  }

  void _onMapCreated(MapLibreMapController controller) {
    _mapController = controller;

    // Register controller with provider
    try {
      final mapProvider = context.read<MapControllerProvider>();
      mapProvider.setController(controller);
      debugPrint('Map controller registered with provider');
    } catch (e) {
      debugPrint('MapControllerProvider not found: $e');
    }

    debugPrint('Map controller created');
  }

  void _subscribeToGPS() {
    try {
      final gpsProvider = context.read<GpsPositionProvider>();

      _gpsSubscription = gpsProvider.positionStreamController.listen(
        (position) {
          if (_isDisposed || _mapController == null) {
            debugPrint('Cannot update location: disposed=$_isDisposed, controller=${_mapController != null}');
            return;
          }

          _updateLocationMarker(LatLng(position.latitude, position.longitude), position.accuracy);
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

  Future<void> _updateLocationMarker(LatLng position, double accuracy) async {
    if (_mapController == null || _isDisposed || _isUpdatingLocation) {
      debugPrint('Skipping location update: controller=${_mapController != null}, disposed=$_isDisposed, updating=$_isUpdatingLocation');
      return;
    }

    _isUpdatingLocation = true;

    try {
      // Use a minimum radius of 5 meters for visibility
      final radiusMeters = accuracy < 5 ? 5.0 : accuracy;

      // Update or create accuracy circle
      if (_accuracyCircle != null) {
        await _mapController!.updateCircle(_accuracyCircle!, CircleOptions(geometry: position, circleRadius: radiusMeters, circleColor: '#2196F3', circleOpacity: 0.2, circleStrokeWidth: 1, circleStrokeColor: '#2196F3', circleStrokeOpacity: 0.5));
      } else {
        _accuracyCircle = await _mapController!.addCircle(CircleOptions(geometry: position, circleRadius: radiusMeters, circleColor: '#2196F3', circleOpacity: 0.2, circleStrokeWidth: 1, circleStrokeColor: '#2196F3', circleStrokeOpacity: 0.5));
      }

      // Update or create location dot
      if (_locationCircle != null) {
        debugPrint('Updating existing location dot');
        await _mapController!.updateCircle(_locationCircle!, CircleOptions(geometry: position, circleRadius: 6, circleColor: '#2196F3', circleOpacity: 1.0, circleStrokeWidth: 2, circleStrokeColor: '#FFFFFF', circleStrokeOpacity: 1.0));
      } else {
        debugPrint('Creating new location dot');
        _locationCircle = await _mapController!.addCircle(CircleOptions(geometry: position, circleRadius: 6, circleColor: '#2196F3', circleOpacity: 1.0, circleStrokeWidth: 2, circleStrokeColor: '#FFFFFF', circleStrokeOpacity: 1.0));
      }

      debugPrint('Location marker updated successfully');
    } catch (e) {
      if (!_isDisposed) {
        debugPrint('Error updating location marker: $e');
      }
    } finally {
      _isUpdatingLocation = false;
    }
  }

  Future<void> _onMapClick(Point<double> point, LatLng coordinates) async {
    if (_isDisposed || _mapController == null) {
      return;
    }

    debugPrint('Map clicked at point: $point, coordinates: $coordinates');

    if (_mapController == null) {
      debugPrint('Map controller is null');
      return;
    }

    try {
      // Query rendered features at the clicked point for clusters
      debugPrint('Querying clusters at point: $point');
      final clusterFeatures = await _mapController!.queryRenderedFeatures(point, ['clusters'], null);

      debugPrint('Found ${clusterFeatures.length} cluster features');

      if (clusterFeatures.isNotEmpty) {
        final cluster = clusterFeatures.first;
        debugPrint('Cluster data: $cluster');
        final pointCount = cluster['properties']['point_count'];

        debugPrint('Cluster clicked with $pointCount points');

        // Get current zoom from camera position
        final currentZoom = _mapController!.cameraPosition?.zoom ?? 5.0;
        final newZoom = currentZoom + 2.0;

        debugPrint('Zooming to level: $newZoom at coordinates: $coordinates');

        // Animate to the cluster location with increased zoom
        await _mapController!.animateCamera(CameraUpdate.newLatLngZoom(coordinates, newZoom), duration: const Duration(milliseconds: 500));
        return;
      }

      // Query for unclustered points
      debugPrint('Querying unclustered points at point: $point');
      final pointFeatures = await _mapController!.queryRenderedFeatures(point, ['unclustered-point'], null);

      debugPrint('Found ${pointFeatures.length} point features');

      if (pointFeatures.isNotEmpty) {
        final feature = pointFeatures.first;
        final clusterName = feature['properties']['cluster_name'];
        final plotName = feature['properties']['plot_name'];

        debugPrint('Individual point clicked: $clusterName - $plotName');
        // You can add navigation or show details here if needed
      } else {
        debugPrint('No features found at clicked location');
      }
    } catch (e, stackTrace) {
      debugPrint('Error handling map click: $e');
      debugPrint('Stack trace: $stackTrace');
    }
  }

  void _onStyleLoaded() {
    if (_isDisposed) return;

    debugPrint('Map style loaded');
    // Add markers if they're already loaded
    if (_markersLoaded && _records.isNotEmpty && mounted && !_isDisposed) {
      _addMarkers();
    }
  }

  Future<void> _addMarkers() async {
    if (_mapController == null || !mounted || _isDisposed) {
      debugPrint('MapController is null or widget disposed, cannot add markers');
      return;
    }

    debugPrint('Map style loaded! Adding ${_records.length} markers with clustering...');

    try {
      // Prepare data for background processing
      final recordsData =
          _records.where((record) => record.getCoordinates() != null).map((record) {
            final coords = record.getCoordinates()!;
            return {'id': record.id, 'cluster_name': record.clusterName, 'plot_name': record.plotName, 'longitude': coords['longitude'], 'latitude': coords['latitude']};
          }).toList();

      debugPrint('Prepared ${recordsData.length} records for GeoJSON conversion');

      // Calculate bounding box for all markers
      if (recordsData.isNotEmpty) {
        double minLat = recordsData.first['latitude'] as double;
        double maxLat = recordsData.first['latitude'] as double;
        double minLng = recordsData.first['longitude'] as double;
        double maxLng = recordsData.first['longitude'] as double;

        for (final record in recordsData) {
          final lat = record['latitude'] as double;
          final lng = record['longitude'] as double;

          if (lat < minLat) minLat = lat;
          if (lat > maxLat) maxLat = lat;
          if (lng < minLng) minLng = lng;
          if (lng > maxLng) maxLng = lng;
        }

        // Add some padding (10% of the range)
        final latPadding = (maxLat - minLat) * 0.1;
        final lngPadding = (maxLng - minLng) * 0.1;

        debugPrint('Bounding box: SW($minLng, $minLat) NE($maxLng, $maxLat)');

        // Move camera to fit all markers
        if (!mounted || _mapController == null || _isDisposed) return;

        await _mapController!.animateCamera(
          CameraUpdate.newLatLngBounds(LatLngBounds(southwest: LatLng(minLat - latPadding, minLng - lngPadding), northeast: LatLng(maxLat + latPadding, maxLng + lngPadding)), left: 50, top: 50, right: 50, bottom: 50),
        );

        debugPrint('Camera moved to fit all markers');
      }

      // Check before starting expensive operation
      if (!mounted || _mapController == null || _isDisposed) return;

      // Process GeoJSON creation in background thread
      final geojsonData = await compute(_createGeoJsonInIsolate, recordsData);

      debugPrint('GeoJSON created in background thread');

      // Check if still mounted after async operation
      if (!mounted || _mapController == null || _isDisposed) return;

      await _mapController!.addSource('records', GeojsonSourceProperties(data: geojsonData, cluster: true, clusterMaxZoom: 14, clusterRadius: 50));

      debugPrint('Added GeoJSON source with clustering');

      // Check if still mounted after async operation
      if (!mounted || _mapController == null || _isDisposed) return;

      // Add clustered circles layer
      await _mapController!.addCircleLayer(
        'records',
        'clusters',
        CircleLayerProperties(
          circleColor: [
            'step',
            ['get', 'point_count'],
            '#${aggregatedMarkerColors[0].value.toRadixString(16).substring(2)}',
            50,
            '#${aggregatedMarkerColors[1].value.toRadixString(16).substring(2)}',
            100,
            '#${aggregatedMarkerColors[2].value.toRadixString(16).substring(2)}',
            250,
            '#${aggregatedMarkerColors[3].value.toRadixString(16).substring(2)}',
            500,
            '#${aggregatedMarkerColors[4].value.toRadixString(16).substring(2)}',
            1000,
            '#${aggregatedMarkerColors[5].value.toRadixString(16).substring(2)}',
            2500,
            '#${aggregatedMarkerColors[6].value.toRadixString(16).substring(2)}',
          ],
          circleRadius: [
            'step',
            ['get', 'point_count'],
            20,
            100,
            30,
            750,
            40,
          ],
        ),
        filter: ['has', 'point_count'],
      );

      debugPrint('Added cluster circles layer');

      // Check if still mounted after async operation
      if (!mounted || _mapController == null || _isDisposed) return;

      // Add unclustered points as circles
      await _mapController!.addCircleLayer(
        'records',
        'unclustered-point',
        const CircleLayerProperties(circleColor: '#ff0000', circleRadius: 8, circleStrokeWidth: 2, circleStrokeColor: '#ffffff'),
        filter: [
          '!',
          ['has', 'point_count'],
        ],
      );

      debugPrint('Added unclustered points layer');
      debugPrint('Finished adding all marker layers!');
    } catch (e, stackTrace) {
      if (!_isDisposed) {
        debugPrint('Error adding markers: $e');
        debugPrint('Stack trace: $stackTrace');
      }
    }
  }

  @override
  void dispose() {
    _isDisposed = true;
    _gpsSubscription?.cancel();
    _gpsSubscription = null;

    // Unregister controller from provider
    try {
      final mapProvider = context.read<MapControllerProvider>();
      mapProvider.setController(null);
      debugPrint('Map controller unregistered from provider');
    } catch (e) {
      debugPrint('Error unregistering map controller: $e');
    }

    // Don't manually dispose the controller - MapLibre handles this internally
    _mapController = null;
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final initialCenter = widget.initialCenter ?? const LatLng(51.1657, 10.4515);
    final initialZoom = widget.initialZoom ?? 5.5;

    // Create OSM style
    final styleJson = {
      "version": 8,
      "sources": {
        "osm": {
          "type": "raster",
          "tiles": ["https://tile.openstreetmap.org/{z}/{x}/{y}.png"],
          "tileSize": 256,
          "attribution": "© OpenStreetMap contributors",
        },
      },
      "layers": [
        {"id": "osm", "type": "raster", "source": "osm", "minzoom": 0, "maxzoom": 22},
      ],
    };

    return MapLibreMap(
      styleString: jsonEncode(styleJson),
      initialCameraPosition: CameraPosition(target: initialCenter, zoom: initialZoom),
      onMapCreated: _onMapCreated,
      onStyleLoadedCallback: _onStyleLoaded,
      onMapClick: _onMapClick,
      myLocationEnabled: false,
      trackCameraPosition: true,
    );
  }
}
