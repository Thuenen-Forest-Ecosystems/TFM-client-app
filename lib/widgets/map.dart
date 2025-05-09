import 'dart:async';
import 'dart:convert';
import 'package:flutter_map_cancellable_tile_provider/flutter_map_cancellable_tile_provider.dart';
import 'package:provider/provider.dart';

import 'package:beamer/beamer.dart';
import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:flutter_map_location_marker/flutter_map_location_marker.dart';
import 'package:flutter_map_marker_cluster/flutter_map_marker_cluster.dart';
import 'package:flutter_map_tile_caching/flutter_map_tile_caching.dart';
import 'package:latlong2/latlong.dart';
import 'package:powersync/sqlite3_common.dart' as sqlite;
import 'package:terrestrial_forest_monitor/providers/gps-position.dart';
//import 'package:geolocator/geolocator.dart';
//import 'package:geolocator_apple/geolocator_apple.dart';

import 'package:terrestrial_forest_monitor/providers/map-state.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:terrestrial_forest_monitor/services/powersync.dart';
import 'package:terrestrial_forest_monitor/services/utils.dart';
import 'package:turf/destination.dart';
import 'package:turf/helpers.dart';

// https://docs.fleaflet.dev/layers/tile-layer#url-template
// offline Map: https://docs.fleaflet.dev/tile-servers/offline-mapping
class TFMMap extends StatefulWidget {
  const TFMMap({super.key});

  @override
  _TFMMapState createState() => _TFMMapState();
}

class _TFMMapState extends State<TFMMap> {
  List _plotList = [];
  Future<sqlite.ResultSet>? _plots;
  Function? disposeListen;
  sqlite.ResultSet? clusters;
  List? plots = [];
  LatLng _currentCenter = LatLng(51.16, 10.45); // Center of Germany (approx)
  double _currentZoom = 10.0; // Initial zoom suitable for Germany

  // Define approximate bounds for Germany
  final LatLngBounds germanyBounds = LatLngBounds(
    LatLng(47.27, 5.87), // South-West corner
    LatLng(55.06, 15.04), // North-East corner
  );

  Map? _nearestPlot;

  Timer? _debounceTimer; // Timer for debouncing position changes

  StreamSubscription? plotSubscription;

  late final MapController _mapController;
  bool _isControllerInitialized = false;

  late MapOptions options;

  final LayerHitNotifier _plotHitNotifier = ValueNotifier(null);

  Future<void> _watchRecords() async {
    await db.watch('SELECT * FROM records').listen((sqlite.ResultSet resultSet) {
      _plotList = [];
      if (resultSet.isEmpty) return;

      // Get all records from the database
      for (var record in resultSet) {
        Map previousProperties = jsonDecode(record['previous_properties']);
        previousProperties['schemaId'] = record['schema_id'];
        previousProperties['recordId'] = record['id'];

        if (previousProperties['plot_coordinates'] == null) continue;
        _plotList.add(previousProperties);
      }
      if (mounted) {
        setState(() {});
      }
    }).asFuture();
  }

  Future<void> _moveToSavedBounds() async {
    try {
      final setting = await getDeviceSettings('cameraState');
      if (setting != null && setting['value'] != null) {
        final String cameraStateString = setting['value'];
        if (cameraStateString.isNotEmpty) {
          final Map<String, dynamic> cameraState = jsonDecode(cameraStateString);

          if (cameraState.containsKey('center') && cameraState.containsKey('zoom')) {
            final List<dynamic> centerList = cameraState['center'];
            final double zoom = cameraState['zoom'];

            if (centerList.length == 2) {
              // Update the state variables that will be used in MapOptions
              _currentCenter = LatLng(centerList[0], centerList[1]);
              _currentZoom = zoom;
              print('Restored camera state: Center=$_currentCenter, Zoom=$_currentZoom');
            }
          }
        }
      }
    } catch (e) {
      print('Error restoring camera state: $e');
      // Keep default values if restoring fails
    }
  }

  @override
  void initState() {
    super.initState();
    print('TFMMap initState');

    // get MapController from MapState
    _mapController = context.read<MapState>().mapController;

    _watchRecords();

    WidgetsBinding.instance.addPostFrameCallback((_) async {
      if (!mounted) return;

      // Restore saved state (might override _currentCenter/_currentZoom defaults)
      await _moveToSavedBounds();

      options = MapOptions(
        onMapEvent: _handleMapEvent,
        onPositionChanged: _handlePositionChanged,
        initialCenter: _currentCenter,
        initialZoom: _currentZoom,
        cameraConstraint: CameraConstraint.containCenter(bounds: germanyBounds),
        interactionOptions: const InteractionOptions(flags: InteractiveFlag.all & ~InteractiveFlag.rotate),
        minZoom: 5.0,
        maxZoom: 22.0,
      );

      if (mounted) {
        setState(() {
          _isControllerInitialized = true;
        });
      }
    });

    /*_plotHitNotifier.addListener(() {
      
      // https://docs.fleaflet.dev/layers/layer-interactivity
      final LayerHitResult<Object>? hitResult = _plotHitNotifier.value;

      if (hitResult == null) return;

      for (final hitValue in hitResult.hitValues) {
        Map hitMap = hitValue as Map;

        // is Plot
        if (hitMap['plot_name'] != null) {
          //Beamer.of(context).beamToNamed('/plot/private_ci2027_001/${hitMap['cluster_id']}/${hitMap['id']}');
          _navigateToPlot('private_ci2027_001', hitMap['cluster_id'], hitMap['id']);
          break;
        }
      }
    });*/
  }

  void _navigateToPlot(String schemaId, String clusterId, String plotId) {
    // /plot/edit/${records[0]['schema_id']}/$clusterId/${records[0]['id']}
    context.beamToNamed('/plot/$schemaId/$clusterId/$plotId');
  }

  @override
  void dispose() {
    plotSubscription?.cancel();

    if (disposeListen != null) {
      disposeListen!();
    }
    super.dispose();
  }

  void _handlePositionChanged(position, bool hasGesture) {
    // Timout to avoid too many calls and setSettings('cameraBounds', bounds.toString());
    // Cancel any existing timer
    _debounceTimer?.cancel();

    // Start a new timer
    _debounceTimer = Timer(const Duration(seconds: 2), () {
      // This code runs after 2 seconds of no position changes
      if (mounted) {
        final LatLng center = _mapController.camera.center;
        final double zoom = _mapController.camera.zoom;

        // Create a map to hold the state
        final cameraState = {
          'center': [center.latitude, center.longitude],
          'zoom': zoom,
        };

        // Convert map to JSON string
        final String cameraStateString = jsonEncode(cameraState);

        // Save the JSON string
        setDeviceSettings('cameraState', cameraStateString);
        print('Saved camera state: $cameraStateString');
      }
    });
  }

  void _handleMapEvent(MapEvent event) {}

  /*void _zoomIn() {
    context.read<MapState>().zoomIn();
  }

  void _zoomOut() {
    context.read<MapState>().zoomOut();
  }

  void _flatPlots() {
    _plot_locations.clear();
    if (clusters == null) return;

    for (var cluster in clusters!) {
      if (cluster['plot'] == null) continue;
      for (var plot in cluster['plot']) {
        if (plot['plot_location'] == null) continue;
        for (var plot_location in plot['plot_location']) {
          _plot_locations.add(plot_location);
        }
      }
    }
    setState(() {});
  }*/

  Widget _plotLayer() {
    return GestureDetector(
      onTapUp: (details) {
        final LayerHitResult? hitResult = _plotHitNotifier.value;
        if (hitResult == null) return;

        for (final hitValue in hitResult.hitValues) {
          Map plot = hitValue as Map;
          print(plot);
          Beamer.of(context).beamToNamed('/record/${plot['recordId']}');
          //_navigateToPlot('private_ci2027_001', plot['cluster_id'], plot['id']);
        }
      },
      child: CircleLayer(
        hitNotifier: _plotHitNotifier,
        circles:
            _plotList.map<CircleMarker<Object>>((plot) {
              Map plotLocation = plot['plot_coordinates'][0]['center_location'];

              return CircleMarker<Object>(
                point: LatLng(plotLocation['coordinates'][1], plotLocation['coordinates'][0]),
                radius: 5000,
                useRadiusInMeter: true,
                color: Colors.red, // Color(0xFF008CD2).withAlpha(150),
                hitValue: plot,
              );
            }).toList(),
      ),
    );
  }

  // Tree Layer
  Widget _treeLayer() {
    Map? targetPlot = context.read<GpsPositionProvider>().navigationTarget;

    if (targetPlot == null) return Container();

    return FutureBuilder(
      future: db.getAll('SELECT * FROM tree WHERE plot_id=?', [targetPlot['target']['id']]),
      builder: (context, snapshot) {
        if (snapshot.hasData) {
          Map<String, dynamic> jsonCoordinates = jsonDecode(targetPlot['target']['center_location_json']);

          return CircleLayer(
            circles:
                snapshot.data!.map<CircleMarker<Object>>((tree) {
                  double dbh = 1000;
                  Color color = Colors.black;
                  double distance = double.parse(tree['distance']);
                  double azimuth = double.parse(tree['azimuth']);
                  if (tree['dbh'] != null) {
                    dbh = double.parse(tree['dbh']);
                    color = Colors.red;
                  }

                  Point dest = destination(Point.fromJson(jsonCoordinates), distance, azimuth, Unit.centimeters);

                  return CircleMarker<Object>(
                    point: LatLng(dest.coordinates.lat.toDouble(), dest.coordinates.lng.toDouble()),
                    radius: dbh / 1000 / 2,
                    useRadiusInMeter: true,
                    color: color,
                    //hitValue: plot,
                  );
                }).toList(),
          );
        }
        return Container();
      },
    );
  }

  Widget _plotClusterLayer(data) {
    // https://github.com/lpongetti/flutter_map_marker_cluster/tree/master
    List<Marker> markers = [];
    for (var plot in data) {
      if (plot['center_location_json'] == null) continue;
      Map plotLocation = jsonDecode(plot['center_location_json']);
      markers.add(
        Marker(
          key: ValueKey(plot['plot_name'] + '_' + plot['cluster_id']),
          width: 20.0,
          height: 20.0,
          point: LatLng(plotLocation['coordinates'][1], plotLocation['coordinates'][0]),
          child: GestureDetector(
            onTapUp: (_) {
              _navigateToPlot('private_ci2027_001', plot['cluster_id'], plot['id']);
            },
            child: Container(
              width: 20.0,
              height: 20.0,
              decoration: BoxDecoration(color: Color(0xFF333333), borderRadius: BorderRadius.circular(10)),
              child: Center(child: Text(plot['plot_name'].toString(), style: const TextStyle(color: Colors.white))),
            ),
          ),
        ),
      );
    }
    return MarkerClusterLayerWidget(
      options: MarkerClusterLayerOptions(
        maxClusterRadius: 1,
        size: const Size(15, 15),
        alignment: Alignment.center,
        padding: const EdgeInsets.all(50),
        maxZoom: 15,
        markers: markers,
        builder: (context, markers) {
          // Get first Marker key as String
          String clusterName = (markers[0].key as ValueKey).value.toString().split('_')[1];

          return Container(
            decoration: BoxDecoration(borderRadius: BorderRadius.circular(20), color: Color(0xFF008CD2)),
            /*child: Center(
              child: Text(
                clusterName, //markers.length.toString(),
                style: const TextStyle(color: Colors.white),
              ),
            ),*/
          );
        },
      ),
    );
  }

  Future<Map> getNearestPlot(LatLng from) async {
    sqlite.ResultSet? allplots = await _plots;

    if (allplots == null) return {};

    List<Map> orderedPlots = orderPlotByDistance(allplots, 'center_location_json', from);

    return orderedPlots[0];
  }

  Future<Widget> _lineFromUserToNextPlot(gpsPositionProvider) async {
    if (gpsPositionProvider.lastPosition == null) return Container();

    //_nearestPlot = await getNearestPlot(LatLng(gpsPositionProvider.lastPosition.latitude, gpsPositionProvider.lastPosition.longitude));
    Map? targetPlot = context.read<GpsPositionProvider>().navigationTarget;

    if (targetPlot == null) return Container();
    //Map plotLocation = jsonDecode(plot['center_location_json']);
    //LatLng plotCenter = LatLng(plotLocation['coordinates'][1], plotLocation['coordinates'][0]);

    //if (_nearestPlot == null) return Container();

    return PolylineLayer(
      polylines: [
        Polyline(
          points: [
            LatLng(gpsPositionProvider.lastPosition.latitude, gpsPositionProvider.lastPosition.longitude),
            targetPlot['position'], //_nearestPlot!['position'],
          ],
          color: Color(0xFF008CD2),
          strokeWidth: 2.0,
        ),
      ],
    );
  }

  Widget _currentLocationLayer(gpsPositionProvider) {
    return CurrentLocationLayer(
      positionStream: gpsPositionProvider.positionStreamController.asBroadcastStream(),
      alignPositionOnUpdate: AlignOnUpdate.never,
      alignDirectionOnUpdate: AlignOnUpdate.never,
      style: const LocationMarkerStyle(marker: DefaultLocationMarker(color: Color(0xFF008CD2), child: Icon(Icons.navigation, color: Colors.white, size: 10)), markerSize: Size(20, 20), markerDirection: MarkerDirection.heading),
    );
  }

  _osmLayer() {
    return TileLayer(
      urlTemplate: 'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
      userAgentPackageName: 'dev.fleaflet.flutter_map.example',
      tileProvider: FMTCStore('osm').getTileProvider(),
      // Plenty of other options available!
    );
  }

  _dopLayer() {
    return TileLayer(
      wmsOptions: WMSTileLayerOptions(baseUrl: 'https://{s}.s2maps-tiles.eu/wms/?', layers: const ['s2cloudless-2021_3857']),
      subdomains: const ['a', 'b', 'c', 'd', 'e', 'f', 'g', 'h'],
      userAgentPackageName: 'dev.fleaflet.flutter_map.example',
      //tileProvider: CancellableNetworkTileProvider(),
      tileProvider: FMTCStore('dop').getTileProvider(),
    );
  }

  _wmsDtk25Layer() {
    // https://gdz.bkg.bund.de/index.php/default/dienste_in_webanwendungen/
    return TileLayer(
      wmsOptions: WMSTileLayerOptions(baseUrl: 'https://sg.geodatenzentrum.de/wms_dtk25__${dotenv.env['DMZ_KEY']}?', layers: const ['dtk25'], format: 'image/jpeg'),
      userAgentPackageName: 'de.thuenen.tfm',
      //tileProvider: CancellableNetworkTileProvider(),
      tileProvider: kIsWeb ? CancellableNetworkTileProvider() : FMTCStore('wms_dtk25__').getTileProvider(),
      additionalOptions: {'userAgent': 'dev.fleaflet.flutter_map.example', 'layers': 'your-layer-name', 'format': 'image/png', 'transparent': 'true'},
    );
  }

  _gdzLayer() {
    // https://sg.geodatenzentrum.de/wms_dop?request=GetCapabilities&service=WMS
    return TileLayer(
      wmsOptions: WMSTileLayerOptions(baseUrl: 'https://sg.geodatenzentrum.de/wms_dop__${dotenv.env['DMZ_KEY']}?', layers: const ['rgb'], format: 'image/jpeg'), // https://sg.geodatenzentrum.de/wms_dtk25?request=GetCapabilities&service=WMS
      userAgentPackageName: 'de.thuenen.tfm',
      //tileProvider: CancellableNetworkTileProvider(),
      tileProvider: kIsWeb ? CancellableNetworkTileProvider() : FMTCStore('wms_dop__').getTileProvider(),
      additionalOptions: {'userAgent': 'dev.fleaflet.flutter_map.example', 'layers': 'your-layer-name', 'format': 'image/png', 'transparent': 'true'},
    );
  }

  focusAllCluster() {
    List<LatLng> clusterPoints = [];

    if (plots == null) return;
    for (var plot in plots!) {
      if (plot['center_location_json'] == null) continue;
      Map plotLocation = jsonDecode(plot['center_location_json']);
      clusterPoints.add(LatLng(plotLocation['coordinates'][1], plotLocation['coordinates'][0]));
    }

    if (clusterPoints.isEmpty) return;
    double minLat = clusterPoints[0].latitude;
    double maxLat = clusterPoints[0].latitude;
    double minLng = clusterPoints[0].longitude;
    double maxLng = clusterPoints[0].longitude;
    for (var point in clusterPoints) {
      if (point.latitude < minLat) minLat = point.latitude;
      if (point.latitude > maxLat) maxLat = point.latitude;
      if (point.longitude < minLng) minLng = point.longitude;
      if (point.longitude > maxLng) maxLng = point.longitude;
    }

    _mapController.fitCamera(CameraFit.bounds(bounds: LatLngBounds(LatLng(minLat, minLng), LatLng(maxLat, maxLng)), padding: const EdgeInsets.all(20)));
  }

  @override
  Widget build(BuildContext context) {
    bool isMapOpen = context.watch<MapState>().mapOpen;

    /*final zoom = context.watch<MapState>().zoom;
    if (zoom != _zoomState) {
      zoom > _zoomState ? _zoomIn() : _zoomOut();
      _zoomState = zoom;
    }
    final newFocus = context.watch<MapState>().focusAll;
    if (_focusAllCluster != newFocus) {
      focusAllCluster();
      _focusAllCluster = newFocus;
    }*/
    // Only render the map when controller is initialized
    if (!_isControllerInitialized) {
      return Center(child: CircularProgressIndicator());
    }

    return Stack(
      children: [
        Container(
          child: FlutterMap(
            //mapController: context.watch<MapState>().mapController,
            mapController: _mapController,

            options: options,
            children: [
              Visibility(child: _wmsDtk25Layer(), visible: isMapOpen && dotenv.env.containsKey('DMZ_KEY')),
              Visibility(child: _gdzLayer(), visible: isMapOpen && dotenv.env.containsKey('DMZ_KEY') && context.read<MapState>().isDop),
              if (!dotenv.env.containsKey('DMZ_KEY')) _osmLayer(),
              _plotLayer(),
              FutureBuilder(
                future: _plots,
                builder: (context, snapshot) {
                  if (snapshot.hasData) {
                    return _plotClusterLayer(snapshot.data);
                  }
                  return Container();
                },
              ),
              Consumer<GpsPositionProvider>(
                builder: (context, gpsPositionProvider, child) {
                  // check if lastPosition.timestamp is older than 5 seconds
                  if (gpsPositionProvider.lastPosition == null) return Container();
                  if (gpsPositionProvider.lastPosition!.timestamp.isBefore(DateTime.now().subtract(const Duration(seconds: 10)))) return Container();

                  return Stack(
                    children: [
                      FutureBuilder(
                        future: _lineFromUserToNextPlot(gpsPositionProvider),
                        builder: (context, snapshot) {
                          if (snapshot.hasData) {
                            return snapshot.data!;
                          }
                          return Container();
                        },
                      ),
                      _currentLocationLayer(gpsPositionProvider),
                    ],
                  );
                },
              ),
              _treeLayer(),
              Scalebar(padding: EdgeInsets.all(5), alignment: Alignment.bottomLeft),
            ],
          ),
        ),
        Consumer<GpsPositionProvider>(
          builder: (context, gpsPositionProvider, child) {
            if (!gpsPositionProvider.listeningPosition) return Container();
            if (_nearestPlot == null) return Container();

            return Positioned(
              bottom: 0,
              child: Container(
                margin: const EdgeInsets.all(5),
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                decoration: BoxDecoration(color: Theme.of(context).scaffoldBackgroundColor, borderRadius: const BorderRadius.all(Radius.circular(20))),
                child: Row(children: [Icon(Icons.open_in_full, size: 20), Text(' ${_nearestPlot!['prettyDistance']}'), VerticalDivider(), Icon(Icons.explore, size: 20), Text(' ${_nearestPlot!['bearing'].toStringAsFixed(2)} °')]),
              ),
            );
          },
        ),
      ],
    );
  }
}
