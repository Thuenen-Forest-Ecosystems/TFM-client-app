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
import 'package:shared_preferences/shared_preferences.dart';
import 'dart:async';

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
  LatLng? _currentPosition;
  double? _currentAccuracy;
  Set<String> _selectedBasemaps = {
    'topo_offline',
  }; // Can select multiple: 'osm', 'topo_offline', 'dop'
  double _currentZoom = 5.5;
  LatLngBounds? _lastBounds;

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

        // Listen for updates from RecordsSelection
        _checkForProviderUpdates();

        // Set up listener for MapControllerProvider focus bounds
        final mapControllerProvider = context.read<MapControllerProvider>();
        mapControllerProvider.addListener(_onMapControllerProviderChanged);
      }
    });
  }

  void _onMapControllerProviderChanged() {
    if (!_isDisposed && mounted && _isMapReady) {
      _checkForFocusBounds();
    }
  }

  void _checkForProviderUpdates() {
    // Periodically check if provider has new data
    if (!_isDisposed && mounted) {
      final provider = context.read<RecordsListProvider>();
      final cachedData = provider.getCachedRecords('all', ClusterOrderBy.clusterName);

      if (cachedData != null && cachedData.isNotEmpty) {
        final recordCount = cachedData.length;

        // Update if we have different data
        if (recordCount != _records.length) {
          _loadRecordsFromProvider().then((_) {
            // Trigger a rebuild to show new markers
            if (mounted && !_isDisposed && _isMapReady) {
              setState(() {});
            }
          });
        }
      }

      // Check again after a delay (only if not disposed)
      Future.delayed(const Duration(seconds: 2), () {
        if (!_isDisposed && mounted) {
          _checkForProviderUpdates();
        }
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
          _selectedBasemaps = {'osm', 'topo_offline', 'dop'};
        });
        // Save the default selection
        await prefs.setStringList('map_basemaps', _selectedBasemaps.toList());
        debugPrint('First installation: enabled all basemaps by default');
      }
    } catch (e) {
      debugPrint('Error loading map settings: $e');
    }
  }

  Future<void> _saveMapSettings() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setStringList('map_basemaps', _selectedBasemaps.toList());
      debugPrint('Saved basemap preferences: $_selectedBasemaps');
    } catch (e) {
      debugPrint('Error saving map settings: $e');
    }
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();

    // Load records from provider cache (shared with RecordsSelection)
    if (!_markersLoaded && !_isDisposed) {
      _loadRecordsFromProvider();
    }

    // Subscribe to GPS updates
    if (_gpsSubscription == null && !_isDisposed) {
      _subscribeToGPS();
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

  Future<void> _loadRecordsFromProvider() async {
    final provider = context.read<RecordsListProvider>();

    // Try to get cached records (shared with RecordsSelection)
    final cachedData = provider.getCachedRecords('all', ClusterOrderBy.clusterName);

    if (cachedData != null && cachedData.isNotEmpty) {
      // Extract Record objects from cached data
      final records = cachedData.map((item) => item['record'] as Record).toList();

      if (mounted && !_isDisposed) {
        setState(() {
          _records = records;
          _markersLoaded = true;
        });

        debugPrint('MapWidget: Using ${records.length} cached records from provider');

        // Update visible records and fit camera
        if (_isMapReady) {
          _updateVisibleRecords();
        }
        _fitCameraToMarkers();
      }
    } else {
      // No cached data yet - load directly from database
      debugPrint('MapWidget: Cache empty, loading records from database');
      try {
        final records = await RecordsRepository().getAllRecords();

        if (mounted && !_isDisposed) {
          setState(() {
            _records = records;
            _markersLoaded = true;
          });

          debugPrint('MapWidget: Loaded ${records.length} records from database');

          // Update visible records and fit camera
          if (_isMapReady) {
            _updateVisibleRecords();
          }
          _fitCameraToMarkers();
        }
      } catch (e) {
        debugPrint('MapWidget: Error loading records: $e');
      }
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

  void _updateVisibleRecords() {
    if (!_isMapReady) return;

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
    _visibleRecords =
        _records.where((record) {
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

    debugPrint('Updated visible records: ${_visibleRecords.length} out of ${_records.length}');
  }

  void _fitCameraToMarkers() {
    if (_records.isEmpty) return;

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
    // Check if map controller is ready before accessing camera
    if (!_isMapReady) {
      return [];
    }

    // Use cached visible records
    return _visibleRecords.map((record) {
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
    }).toList();
  }

  List<Marker> _buildLabelMarkers(List<Record> records) {
    // Check if map controller is ready before accessing camera
    if (!_isMapReady) {
      return [];
    }

    // Use cached visible records
    return _visibleRecords.map((record) {
      final coords = record.getCoordinates()!;
      final lat = coords['latitude']!;
      final lng = coords['longitude']!;

      final label = '${record.clusterName} | ${record.plotName}';

      return Marker(
        point: LatLng(lat, lng),
        width: 90,
        height: 25,
        alignment: Alignment.topCenter,
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 2),
          decoration: BoxDecoration(
            color: Colors.white.withOpacity(0.9),
            borderRadius: BorderRadius.circular(4),
            border: Border.all(color: Colors.black54, width: 1),
          ),
          child: Text(
            label,
            style: const TextStyle(color: Colors.black, fontSize: 10, fontWeight: FontWeight.bold),
            textAlign: TextAlign.center,
            overflow: TextOverflow.ellipsis,
            maxLines: 2,
          ),
        ),
      );
    }).toList();
  }

  void _onMarkerTapped(Record record) {
    debugPrint('Marker tapped: ${record.clusterName} - ${record.plotName}');
    // Add your custom logic here for when a marker is clicked
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

    // Extract cluster names from all markers in this cluster
    String displayText = '';
    /*if (pointCount <= 4) {
      // For small clusters, try to find the common cluster_name
      final Set<String> clusterNames = {};

      for (final marker in markers) {
        // Find the record that corresponds to this marker
        final record = _records.firstWhere((r) {
          final coords = r.getCoordinates();
          if (coords == null) return false;
          final lat = coords['latitude'];
          final lng = coords['longitude'];
          return lat == marker.point.latitude && lng == marker.point.longitude;
        }, orElse: () => _records.first);

        if (record.clusterName.isNotEmpty) {
          clusterNames.add(record.clusterName);
          displayText = record.clusterName;
          break;
        }
      }
    }*/

    // Determine color based on point count
    Color markerColor;
    if (pointCount <= 4) {
      markerColor = Colors.black;
      //} else if (pointCount < 50) {
      //  markerColor = aggregatedMarkerColors[0];
      //} else if (pointCount < 100) {
      //  markerColor = aggregatedMarkerColors[1];
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
      size = 60; // Larger for cluster names
    } else if (pointCount < 100) {
      size = 40;
    } else if (pointCount < 750) {
      size = 60;
    } else {
      size = 80;
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
        child: Center(
          child: Text(
            displayText,
            style: const TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.bold),
            textAlign: TextAlign.center,
            overflow: TextOverflow.ellipsis,
          ),
        ),
      ),
    );
  }

  void _openMapSettings() {
    showModalBottomSheet(
      context: context,
      builder: (BuildContext context) {
        return StatefulBuilder(
          builder: (BuildContext context, StateSetter setModalState) {
            return Container(
              padding: const EdgeInsets.all(16),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Karteneinstellungen',
                    style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 8),

                  CheckboxListTile(
                    title: const Text('Luftbilder (offline)'),
                    subtitle: const Text('nur höchste Zoomstufen'),
                    value: _selectedBasemaps.contains('dop'),
                    onChanged: (value) {
                      setState(() {
                        if (value == true) {
                          _selectedBasemaps.add('dop');
                        } else {
                          _selectedBasemaps.remove('dop');
                        }
                      });
                      setModalState(() {});
                      _saveMapSettings();
                    },
                  ),
                  CheckboxListTile(
                    title: const Text('Topografische Karte (offline)'),
                    subtitle: const Text('Mittlere Zoomstufen'),
                    value: _selectedBasemaps.contains('topo_offline'),
                    onChanged: (value) {
                      setState(() {
                        if (value == true) {
                          _selectedBasemaps.add('topo_offline');
                        } else {
                          _selectedBasemaps.remove('topo_offline');
                        }
                      });
                      setModalState(() {});
                      _saveMapSettings();
                    },
                  ),
                  CheckboxListTile(
                    title: const Text('Open Street Map (online)'),
                    subtitle: const Text('mobiles Datennetz erforderlich'),
                    value: _selectedBasemaps.contains('osm'),
                    onChanged: (value) {
                      setState(() {
                        if (value == true) {
                          _selectedBasemaps.add('osm');
                        } else {
                          _selectedBasemaps.remove('osm');
                        }
                      });
                      setModalState(() {});
                      _saveMapSettings();
                    },
                  ),
                ],
              ),
            );
          },
        );
      },
    );
  }

  @override
  void dispose() {
    _isDisposed = true;
    _debounceTimer?.cancel();
    _gpsSubscription?.cancel();
    _gpsSubscription = null;

    // Remove listener
    try {
      final mapControllerProvider = context.read<MapControllerProvider>();
      mapControllerProvider.removeListener(_onMapControllerProviderChanged);
    } catch (e) {
      debugPrint('Error removing listener: $e');
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
        maxZoom: 19.0,
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
          _debounceTimer = Timer(const Duration(milliseconds: 150), () {
            if (!_isDisposed && mounted) {
              _updateVisibleRecords();
              setState(() {});
            }
          });
        },
      ),
      children: [
        // Tile Layers - rendered in order: OSM (bottom) → OpenTopoMap → DOP (top)

        // Layer 1: OpenStreetMap (online base layer)
        if (_selectedBasemaps.contains('osm'))
          TileLayer(
            urlTemplate: 'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
            userAgentPackageName: 'com.thuenen.terrestrial_forest_monitor',
          ),

        // Layer 2: OpenTopoMap (offline, covers zoom 4-14)
        if (_selectedBasemaps.contains('topo_offline'))
          TileLayer(
            urlTemplate: 'https://{s}.tile.opentopomap.org/{z}/{x}/{y}.png',
            userAgentPackageName: 'com.thuenen.terrestrial_forest_monitor',
            subdomains: const ['a', 'b', 'c'],
            tileBounds: LatLngBounds(LatLng(-90, -180), LatLng(90, 180)),
            maxZoom:
                _selectedBasemaps.contains('dop') ? 14 : 19, // Limit to zoom 14 if DOP is enabled
            maxNativeZoom: 14,
            tileProvider: FMTCStore('opentopomap').getTileProvider(
              settings: FMTCTileProviderSettings(behavior: CacheBehavior.cacheOnly),
            ),
          ),

        // Layer 3: DOP (offline aerial imagery, zoom 15-19)
        if (_selectedBasemaps.contains('dop'))
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
              settings: FMTCTileProviderSettings(behavior: CacheBehavior.cacheOnly),
            ),
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
        if (_currentZoom >= 14 && _records.isNotEmpty)
          MarkerLayer(markers: _buildLabelMarkers(_records)),

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
      ],
    );
  }
}
