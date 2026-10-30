import 'dart:async';
import 'dart:convert';
import 'dart:math' as math;

import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:flutter_map_tile_caching/flutter_map_tile_caching.dart';
import 'package:intl/intl.dart';
import 'package:latlong2/latlong.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Offline basemaps offered for bulk download.
///
/// Read lazily because the WMS URLs embed the DMZ key from `.env`, which the
/// foreground-service isolate loads itself.
Map<String, Map<String, dynamic>> offlineBasemaps() => {
  'DTK25': {
    'wmsBaseUrl': 'https://sg.geodatenzentrum.de/wms_dtk25__${dotenv.env['DMZ_KEY']}?',
    'wmsLayers': ['dtk25'],
    'wmsFormat': 'image/png',
    'storeName': 'wms_dtk25__',
    'title': 'DTK25 (offline)',
    // Zoom bands of the map view (map_widget.dart). Overview levels for the
    // whole area (~500m buffer); level 14 tiles are ~90 KB, so only ~1 km
    // around each record instead of gigabytes for the full bbox.
    'areas': [
      {
        'zooms': [4, 7, 10],
        'perRecord': false,
        'padding': 0.005,
      },
      {
        'zooms': [14],
        'perRecord': true,
        'padding': 0.01,
      },
    ],
  },
  'DOP': {
    'wmsBaseUrl': 'https://sg.geodatenzentrum.de/wms_dop__${dotenv.env['DMZ_KEY']}?',
    'wmsLayers': ['rgb'],
    'wmsFormat': 'image/jpeg',
    'storeName': 'wms_dop__',
    'title': 'Luftbilder (offline)',
    // Aerial imagery is too heavy for a full bbox: ~100m around each record
    'areas': [
      {
        'zooms': [15, 19],
        'perRecord': true,
        'padding': 0.001,
      },
    ],
  },
};

/// Download steps for [basemapName], derived from record coordinates
/// (`{'latitude': .., 'longitude': ..}`): one `[south, west, north, east, zoom]`
/// entry per region and zoom level, serialisable for the foreground service.
List<List<double>> regionsForBasemap(
  String basemapName,
  Iterable<Map<String, double?>> coordinates,
) {
  final config = offlineBasemaps()[basemapName]!;
  final points = coordinates
      .where((c) => c['latitude'] != null && c['longitude'] != null)
      .map((c) => LatLng(c['latitude']!, c['longitude']!))
      .toList();
  if (points.isEmpty) return [];

  final steps = <List<double>>[];
  for (final area in (config['areas'] as List).cast<Map<String, dynamic>>()) {
    final padding = area['padding'] as double;
    final zooms = (area['zooms'] as List).cast<int>();
    final boxes = area['perRecord'] == true
        ? points.map((p) => LatLngBounds(p, p))
        : [LatLngBounds.fromPoints(points)];
    for (final box in boxes) {
      for (final zoom in zooms) {
        steps.add([
          box.south - padding,
          box.west - padding,
          box.north + padding,
          box.east + padding,
          zoom.toDouble(),
        ]);
      }
    }
  }
  return steps;
}

/// Number of tiles FMTC will download for one region at one zoom level. Same
/// arithmetic as FMTC's own rectangle counter, so the stored count reaches the
/// total exactly when everything is downloaded.
int countRegionTiles(List<double> region, int zoom) {
  const crs = Epsg3857();
  const tileSize = 256;
  final nw = crs.latLngToPoint(LatLng(region[2], region[1]), zoom.toDouble()) / tileSize;
  final se = crs.latLngToPoint(LatLng(region[0], region[3]), zoom.toDouble()) / tileSize;
  final nwX = nw.x.floor(), nwY = nw.y.floor();
  final seX = se.x.ceil() - 1, seY = se.y.ceil() - 1;
  return (seX - nwX + 1) * (seY - nwY + 1);
}

/// Total tiles over all download steps (see [regionsForBasemap]).
int countBasemapTiles(List<List<double>> regions) {
  var total = 0;
  for (final step in regions) {
    total += countRegionTiles(step, step[4].toInt());
  }
  return total;
}

String formatTileCount(int count) => NumberFormat.decimalPattern('de').format(count);

/// Downloaded/total tiles of the last run per basemap, kept across app starts
/// so the UI can show how far a download got and offer to continue it.
typedef TileCount = ({int done, int total});

String _tileCountKey(String basemapName) => 'map_tiles_count_$basemapName';

Future<TileCount?> loadTileCount(String basemapName) async {
  final raw = await SharedPreferencesAsync().getString(_tileCountKey(basemapName));
  if (raw == null) return null;
  final json = jsonDecode(raw) as Map<String, dynamic>;
  return (done: json['done'] as int, total: json['total'] as int);
}

Future<void> saveTileCount(String basemapName, TileCount count) => SharedPreferencesAsync()
    .setString(_tileCountKey(basemapName), jsonEncode({'done': count.done, 'total': count.total}));

/// No tile downloaded successfully for this long: the server is treated as
/// unreachable. Covers both a hung request (FMTC's bulk download uses an
/// `http.Client` without timeout, it would block forever) and a lost
/// connection (requests fail fast, FMTC would mark every tile failed).
const tileStallTimeout = Duration(seconds: 60);

/// A stalled zoom level is restarted (stored tiles are skipped) this many
/// times, after a pause, before the download gives up. Tile servers like
/// CyclOSM hang for a few minutes now and then.
const tileStallRetries = 5;
const tileStallRetryDelay = Duration(seconds: 30);

class MapTilesDownloadStalled implements Exception {
  @override
  String toString() => 'Kartenserver nicht erreichbar. Später fortsetzen.';
}

/// Detects if an error is proxy-related and returns user-friendly message
String? detectProxyError(Object error) {
  final errorString = error.toString().toLowerCase();

  // Connection/timeout errors
  if (errorString.contains('timeout') || errorString.contains('connection timed out')) {
    return '⚠️ Verbindungs-Timeout: Möglicherweise blockiert ein Proxy die Verbindung.\n'
        'Lösung: Proxy-Einstellungen prüfen oder VPN verwenden.';
  }

  // Certificate errors
  if (errorString.contains('certificate') ||
      errorString.contains('handshake') ||
      errorString.contains('ssl') ||
      errorString.contains('tls')) {
    return '⚠️ SSL/Zertifikat-Fehler: Der Proxy unterbricht verschlüsselte Verbindungen.\n'
        'Lösung: Proxy-Zertifikat installieren oder Proxy umgehen.';
  }

  // Proxy authentication errors
  if (errorString.contains('407') || errorString.contains('proxy authentication')) {
    return '⚠️ Proxy-Authentifizierung erforderlich.\n'
        'Lösung: Proxy-Anmeldedaten konfigurieren.';
  }

  // Connection refused/failed
  if (errorString.contains('connection refused') ||
      errorString.contains('connection failed') ||
      errorString.contains('failed host lookup') ||
      errorString.contains('network unreachable')) {
    return '⚠️ Netzwerkfehler: Server nicht erreichbar.\n'
        'Lösung: Internetverbindung oder Proxy-Einstellungen prüfen.';
  }

  // HTTP errors that might be proxy-related
  if (errorString.contains('502') || errorString.contains('bad gateway')) {
    return '⚠️ Bad Gateway (502): Proxy-Konfigurationsproblem.\n'
        'Lösung: Proxy-Einstellungen prüfen oder Administrator kontaktieren.';
  }

  if (errorString.contains('503') || errorString.contains('service unavailable')) {
    return '⚠️ Service nicht verfügbar (503): Server oder Proxy überlastet.\n'
        'Lösung: Später erneut versuchen.';
  }

  return null; // Not a detected proxy error
}

/// Runs one basemap bulk download without any UI dependency, so the same code
/// serves the Android foreground service and the in-process path (Windows).
///
/// Tiles already in the store are skipped, so re-running an interrupted job
/// effectively resumes it.
class MapTilesDownloadRunner {
  MapTilesDownloadRunner({
    required this.basemapName,
    required this.regions,
    required this.onProgress,
    this.onWarning,
    this.onLog,
    this.onStatus,
  });

  final String basemapName;
  final List<List<double>> regions;
  final void Function(int done, int total) onProgress;
  final void Function(String message)? onWarning;

  /// Diagnostics that are not worth interrupting the user for (retries).
  final void Function(String message)? onLog;

  /// Explains phases in which the count stands still (checking stored tiles,
  /// waiting for a retry); null once tiles are counting up again.
  final void Function(String? status)? onStatus;

  String? _status;

  void _setStatus(String? status) {
    if (status == _status) return;
    _status = status;
    onStatus?.call(status);
  }

  bool _cancelRequested = false;
  DateTime _lastSave = DateTime.fromMillisecondsSinceEpoch(0);
  FMTCStore? _store;
  int? _activeInstanceId;
  Completer<void>? _zoomDone;

  bool get isCancelled => _cancelRequested;

  /// Stops the download without waiting for FMTC: its cancel only returns once
  /// the in-flight tile request finishes, which may never happen on a hung
  /// connection. Breaking out of the progress stream alone would leave the
  /// FMTC isolate downloading, so it is told to cancel as well.
  Future<void> cancel() async {
    _cancelRequested = true;
    _abandonActiveDownload();
  }

  void _abandonActiveDownload([Object? error]) {
    final instanceId = _activeInstanceId;
    if (instanceId != null) {
      unawaited(_store?.download.cancel(instanceId: instanceId));
    }
    final done = _zoomDone;
    if (done != null && !done.isCompleted) {
      error == null ? done.complete() : done.completeError(error);
    }
  }

  /// Waits [duration], returning early on cancel.
  Future<void> _pause(Duration duration) async {
    final end = DateTime.now().add(duration);
    while (!_cancelRequested && DateTime.now().isBefore(end)) {
      await Future<void>.delayed(const Duration(seconds: 1));
    }
  }

  /// Downloads one region at one zoom level, reporting FMTC's successful
  /// (downloaded + skipped) tile count. Throws [MapTilesDownloadStalled] when
  /// no tile succeeds for [tileStallTimeout].
  Future<void> _downloadStep(
    FMTCStore store,
    DownloadableRegion downloadableRegion,
    int zoom,
    void Function(int successful) onSuccessful,
  ) async {
    final instanceId = '${basemapName}_${zoom}_${DateTime.now().microsecondsSinceEpoch}'.hashCode;
    _activeInstanceId = instanceId;
    try {
      final download = store.download.startForeground(
        region: downloadableRegion,
        instanceId: instanceId,
        parallelThreads: 1,
        maxBufferLength: 100,
        skipExistingTiles: true,
      );

      final zoomDone = _zoomDone = Completer<void>();
      var lastSuccessful = -1;
      var lastChange = DateTime.now();
      final watchdog = Timer.periodic(const Duration(seconds: 5), (_) {
        if (DateTime.now().difference(lastChange) > tileStallTimeout) {
          _abandonActiveDownload(MapTilesDownloadStalled());
        }
      });
      final subscription = download.listen(
        (progress) {
          if (progress.successfulTiles != lastSuccessful) {
            lastSuccessful = progress.successfulTiles;
            lastChange = DateTime.now();
          }
          onSuccessful(progress.successfulTiles);
        },
        onDone: () {
          if (!zoomDone.isCompleted) zoomDone.complete();
        },
        onError: (Object e) {
          if (!zoomDone.isCompleted) zoomDone.completeError(e);
        },
      );
      try {
        await zoomDone.future;
      } finally {
        watchdog.cancel();
        _zoomDone = null;
        unawaited(subscription.cancel());
      }
    } finally {
      _activeInstanceId = null;
    }
  }

  /// Returns true if the download ran to the end (not cancelled/aborted).
  Future<bool> run() async {
    final config = offlineBasemaps()[basemapName]!;
    final store = _store = FMTCStore(config['storeName'] as String);
    await store.manage.create();

    final options = config['wmsBaseUrl'] != null
        ? TileLayer(
            wmsOptions: WMSTileLayerOptions(
              baseUrl: config['wmsBaseUrl'] as String,
              layers: (config['wmsLayers'] as List).cast<String>(),
              format: config['wmsFormat'] as String,
              crs: const Epsg3857(),
            ),
          )
        : TileLayer(urlTemplate: config['urlTemplate'] as String);

    final total = countBasemapTiles(regions);
    // On a resumed run FMTC first races through the already stored tiles from
    // zero; don't let the shown/stored count drop below the last known state.
    final saved = await loadTileCount(basemapName);
    final floor = saved != null && saved.total == total ? saved.done : 0;
    var doneBefore = 0;
    var done = floor;

    void report(int current) {
      done = math.max(floor, math.min(current, total));
      onProgress(done, total);
      final now = DateTime.now();
      if (now.difference(_lastSave) < const Duration(seconds: 2)) return;
      _lastSave = now;
      unawaited(saveTileCount(basemapName, (done: done, total: total)));
    }

    report(0);
    // FMTC re-checks stored tiles before downloading new ones
    if (floor > 0) _setStatus('Prüfe vorhandene Kacheln…');
    try {
      for (final b in regions) {
        final region = RectangleRegion(LatLngBounds(LatLng(b[0], b[1]), LatLng(b[2], b[3])));
        final zoom = b[4].toInt();
        if (_cancelRequested) return false;
        final stepTiles = countRegionTiles(b, zoom);
        var stepDone = 0;

        final downloadableRegion = region.toDownloadable(
          minZoom: zoom,
          maxZoom: zoom,
          options: options,
        );

        try {
          // Only consecutive stalls count: a long zoom level on a flaky
          // server may stall many times in total and still get through.
          var stalls = 0;
          while (true) {
            final doneBeforeAttempt = stepDone;
            try {
              await _downloadStep(store, downloadableRegion, zoom, (successful) {
                // A retry counts the stored tiles up from zero again
                stepDone = math.max(stepDone, math.min(successful, stepTiles));
                report(doneBefore + stepDone);
                if (stepDone > doneBeforeAttempt && doneBefore + stepDone > floor) {
                  _setStatus(null);
                }
              });
              break;
            } on MapTilesDownloadStalled {
              if (_cancelRequested) return false;
              stalls = stepDone > doneBeforeAttempt ? 1 : stalls + 1;
              if (stalls > tileStallRetries) rethrow;
              onLog?.call(
                'Kartendownload $basemapName Zoom $zoom: Server nicht erreichbar, '
                'neuer Versuch ($stalls/$tileStallRetries) in '
                '${tileStallRetryDelay.inSeconds} s',
              );
              _setStatus(
                'Server nicht erreichbar – neuer Versuch $stalls/$tileStallRetries '
                'in ${tileStallRetryDelay.inSeconds} s',
              );
              await _pause(tileStallRetryDelay);
              if (_cancelRequested) return false;
              _setStatus('Neuer Versuch $stalls/$tileStallRetries – prüfe vorhandene Kacheln…');
            }
          }
        } on MapTilesDownloadStalled {
          rethrow;
        } catch (e) {
          // Windows isolate serialization error: no bulk download possible at all
          if (e.toString().contains('Illegal argument in isolate message') &&
              e.toString().contains('_SecurityContext')) {
            onWarning?.call(
              '⚠️ Bulk-Downloads funktionieren nicht unter Windows.\n'
              'Lösung: Karten werden automatisch beim Ansehen heruntergeladen, '
              'oder Download auf Linux/macOS durchführen.',
            );
            return false;
          }

          final proxyError = detectProxyError(e);
          if (proxyError != null) onWarning?.call(proxyError);
          // Continue with next zoom level instead of failing completely
        } finally {
          doneBefore += stepDone;
        }
      }
    } finally {
      await saveTileCount(basemapName, (done: done, total: total));
    }

    return !_cancelRequested;
  }
}
