import 'package:flutter/material.dart';

import 'package:flutter_map/flutter_map.dart';
import 'package:flutter_map_location_marker/flutter_map_location_marker.dart';
import 'package:flutter_map_cancellable_tile_provider/flutter_map_cancellable_tile_provider.dart';
import 'package:get_storage/get_storage.dart';
import 'package:latlong2/latlong.dart';
import 'package:terrestrial_forest_monitor/providers/gps-position.dart';
import 'package:provider/provider.dart';
import 'package:geolocator/geolocator.dart';
import 'package:terrestrial_forest_monitor/providers/map-state.dart';
import 'package:terrestrial_forest_monitor/services/api.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';

// https://docs.fleaflet.dev/layers/tile-layer#url-template
// offline Map: https://docs.fleaflet.dev/tile-servers/offline-mapping
class TFMMap extends StatefulWidget {
  const TFMMap({super.key});

  @override
  _TFMMapState createState() => _TFMMapState();
}

class _TFMMapState extends State<TFMMap> {
  Function? disposeListen;
  bool _isDisposed = false;

  List? clusters;
  List _plot_locations = [];
  int _zoomState = 0;
  int _focusAllCluster = 0;
  LatLng _currentCenter = LatLng(52.825277, 13.809495);
  double _currentZoom = 10.0;

  final MapController _mapController = MapController();

  late MapOptions options;

  @override
  void initState() {
    super.initState();

    options = MapOptions(
      onMapEvent: _handleMapEvent,
      onPositionChanged: _handlePositionChanged,
      initialCenter: _currentCenter,
      initialZoom: _currentZoom,
      interactionOptions: const InteractionOptions(flags: InteractiveFlag.all & ~InteractiveFlag.rotate),
      minZoom: 5.0,
      maxZoom: 21.0,
    );

    GetStorage users = GetStorage('Users');

    ApiService().getLoggedInUser().then((value) {
      if (value == null && !_isDisposed) return;
      disposeListen = users.listenKey(value['email'], (value) async {
        _getClusters();
      });
      Future.delayed(Duration(milliseconds: 100), () async {
        _getClusters();
      });
    });
  }

  @override
  void dispose() {
    _isDisposed = true;
    if (disposeListen != null) {
      disposeListen!();
    }
    super.dispose();
  }

  void _handlePositionChanged(position, bool hasGesture) {
    _currentCenter = position.center;
    _currentZoom = position.zoom;
  }

  void _handleMapEvent(MapEvent event) {}

  void _getClusters() async {
    if (_isDisposed) return;
    clusters = await ApiService().getAllClusters();
    setState(() {});
    _flatPlots();
  }

  void _zoomIn() {
    _mapController.move(_currentCenter, _currentZoom + 1);
  }

  void _zoomOut() {
    _mapController.move(_currentCenter, _currentZoom - 1);
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
  }

  Widget _plotLayer() {
    List<CircleMarker> plots = _plot_locations.map(
      (plotLocation) {
        if (plotLocation['geometry'] == null) return CircleMarker(point: LatLng(0, 0), radius: 0);
        return CircleMarker(
          point: LatLng(plotLocation['geometry']['coordinates'][1], plotLocation['geometry']['coordinates'][0]),
          radius: plotLocation['radius'].toDouble(),
          useRadiusInMeter: true,
          color: Colors.blue.withOpacity(0.7),
        );
      },
    ).toList();

    return CircleLayer(circles: plots);
  }

  _osmLayer() {
    return TileLayer(
      urlTemplate: 'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
      userAgentPackageName: 'dev.fleaflet.flutter_map.example',
      tileProvider: CancellableNetworkTileProvider(),
      // Plenty of other options available!
    );
  }

  _dopLayer() {
    return TileLayer(
      wmsOptions: WMSTileLayerOptions(
        baseUrl: 'https://{s}.s2maps-tiles.eu/wms/?',
        layers: const ['s2cloudless-2021_3857'],
      ),
      subdomains: const ['a', 'b', 'c', 'd', 'e', 'f', 'g', 'h'],
      userAgentPackageName: 'dev.fleaflet.flutter_map.example',
      tileProvider: CancellableNetworkTileProvider(),
    );
  }

  _gdzLayer() {
    return TileLayer(
      wmsOptions: WMSTileLayerOptions(
        baseUrl: 'https://sg.geodatenzentrum.de/wms_dop__${dotenv.env['DMZ_KEY']}?',
        layers: const ['rgb'],
        format: 'image/jpeg',
      ),
      /*urlTemplate: 'https://sg.geodatenzentrum.de/wms_dop__KEY?'
          'SERVICE=WMS&'
          'REQUEST=GetMap&'
          'VERSION=1.3.0&'
          'layers=rgb&'
          'styles=&'
          'CRS=CRS:84&'
          'format=image/jpeg&'
          'transparent=true&'
          'height=277&'
          'width=578&'
          'srs=EPSG:3857&'
          'dpi=72&'
          'map_resolution=72&'
          'FORMAT_OPTIONS=dpi:72&'
          'BBOX=9.924460420605907274%2C50.80435950151600366%2C9.96722508776188576%2C50.8514836735762259',*/
      userAgentPackageName: 'dev.fleaflet.flutter_map.example',
      tileProvider: CancellableNetworkTileProvider(),
      additionalOptions: {
        'userAgent': 'dev.fleaflet.flutter_map.example',
        'layers': 'your-layer-name',
        'format': 'image/png',
        'transparent': 'true',
      },
    );
  }

  focusAllCluster() {
    if (clusters == null) return;
    List<LatLng> clusterPoints = [];
    for (var cluster in clusters!) {
      if (cluster['plot'] == null) continue;
      for (var plot in cluster['plot']) {
        if (plot['plot_location'] == null) continue;
        for (var plot_location in plot['plot_location']) {
          if (plot_location['geometry'] == null) continue;
          clusterPoints.add(LatLng(plot_location['geometry']['coordinates'][1], plot_location['geometry']['coordinates'][0]));
        }
      }
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

    _mapController.fitCamera(
      CameraFit.bounds(
        bounds: LatLngBounds(LatLng(minLat, minLng), LatLng(maxLat, maxLng)),
        padding: const EdgeInsets.all(20),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    Position? lastPosition = context.watch<GpsPositionProvider>().lastPosition;

    final zoom = context.watch<MapState>().zoom;
    if (zoom != _zoomState) {
      zoom > _zoomState ? _zoomIn() : _zoomOut();
      _zoomState = zoom;
    }
    final newFocus = context.watch<MapState>().focusAll;
    if (_focusAllCluster != newFocus) {
      focusAllCluster();
      _focusAllCluster = newFocus;
    }

    return Stack(
      children: [
        Container(
          child: FlutterMap(
            mapController: _mapController,
            options: options,
            children: [
              if (context.read<MapState>().isDop && dotenv.env.containsKey('DMZ_KEY')) _gdzLayer() else _osmLayer(),
              _plotLayer(),
              if (context.read<MapState>().gps) CurrentLocationLayer(),
            ],
          ),
        ),
      ],
    );
  }
}
