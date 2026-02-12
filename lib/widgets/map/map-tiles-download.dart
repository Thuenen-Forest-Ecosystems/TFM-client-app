import 'package:flutter/material.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:flutter_map_tile_caching/flutter_map_tile_caching.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import 'package:terrestrial_forest_monitor/repositories/records_repository.dart';

class MapTilesDownload extends StatefulWidget {
  const MapTilesDownload({super.key});

  @override
  State<MapTilesDownload> createState() => _MapTilesDownloadState();
}

class _MapTilesDownloadState extends State<MapTilesDownload> {
  Map<String, Map<String, dynamic>> basemapsToSelectFrom = {
    /*'DTK25': {
      'urlTemplate': 'https://sg.geodatenzentrum.de/wms_dtk25__${dotenv.env['DMZ_KEY']}?',
      'minZoom': 1,
      'maxZoom': 20,
      'storeName': 'wms_dtk25__'
    },*/

    /*'OpenStreetMap': {
      'urlTemplate': 'https://{s}.tile.openstreetmap.org/{z}/{x}/{y}.png',
      'minZoom': 1,
      'maxZoom': 19,
      'storeName': 'openstreetmap'
    },*/
    'OpenCycleMap': {
      'urlTemplate': 'https://{s}.tile-cyclosm.openstreetmap.fr/cyclosm/{z}/{x}/{y}.png',
      'zoomLayers': [4, 10, 14],
      'storeName': 'OpenCycleMap',
    },
    /*'ESRI Satellite': {
      'urlTemplate':
          'https://server.arcgisonline.com/ArcGIS/rest/services/World_Imagery/MapServer/tile/{z}/{y}/{x}',
      'zoomLayers': [15, 19],
      'storeName': 'esri_satellite',
    },*/
    'DOP': {
      'urlTemplate': 'https://sg.geodatenzentrum.de/wms_dop__${dotenv.env['DMZ_KEY']}?',
      'zoomLayers': [15, 19],
      'storeName': 'wms_dop__',
    },
    /*'OpenTopoMap': {
      'urlTemplate': 'https://{s}.tile.opentopomap.org/{z}/{x}/{y}.png',
      'zoomLayers': [4, 10, 14],
      'storeName': 'opentopomap',
    },*/
  };
  String? _downloadingBasemap; // Track which basemap is currently downloading
  final Map<String, bool> _downloadedBasemaps = {}; // Track completed downloads
  final Map<String, double> _basemapProgress = {}; // Progress 0.0-1.0 per basemap
  final Map<String, String> _basemapStatus = {}; // Status text per basemap
  bool _isCheckingTiles = true;
  int _missingTilesCount = 0;
  bool _cancelRequested = false;

  @override
  void initState() {
    super.initState();
    _checkMissingTiles();
    // Initialize download status for all basemaps
    for (final basemap in basemapsToSelectFrom.keys) {
      _downloadedBasemaps[basemap] = false;
      _basemapProgress[basemap] = 0.0;
      _basemapStatus[basemap] = '';
    }
  }

  /// Detects if an error is proxy-related and returns user-friendly message
  String? _detectProxyError(dynamic error) {
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

  Future<void> _checkMissingTiles() async {
    if (!mounted) return;

    setState(() {
      _isCheckingTiles = true;
    });

    try {
      final records = await RecordsRepository().getAllRecords();
      if (!mounted) return;

      setState(() {
        _missingTilesCount = records.isNotEmpty ? -1 : 0; // -1 = ready to download
        _isCheckingTiles = false;
      });
    } catch (e) {
      print('[Check] Error checking records: $e');
      if (!mounted) return;

      setState(() {
        _missingTilesCount = 0;
        _isCheckingTiles = false;
      });
    }
  }

  void _cancelDownload() {
    setState(() {
      _cancelRequested = true;
      _downloadingBasemap = null;
    });
    if (mounted) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('Download wird abgebrochen...')));
    }
  }

  Future<void> _downloadMapTilesForBasemap(String basemapName) async {
    print('[Download] Starting download for $basemapName...');
    final records = await RecordsRepository().getAllRecords();
    print('[Download] Found ${records.length} records');

    if (records.isEmpty) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Keine Aufnahmepunkte gefunden. Bitte laden Sie zuerst Daten.'),
          ),
        );
      }
      return;
    }

    setState(() {
      _downloadingBasemap = basemapName;
      _cancelRequested = false;
      _basemapProgress[basemapName] = 0.0;
      _basemapStatus[basemapName] = 'Wird heruntergeladen...';
    });
    print('[Download] Download state initialized for $basemapName');

    try {
      // DOP and ESRI Satellite need per-record download with small radius (100m)
      if (basemapName == 'DOP' || basemapName == 'ESRI Satellite') {
        await _downloadDOPForRecords(records, basemapName);
      } else {
        // Other basemaps: download entire bbox with larger buffer
        final bbox = _calculateBoundingBox(records, basemapName);
        if (bbox != null) {
          await _downloadTiles(bbox, basemapName);
        } else {
          print('[Download] $basemapName bbox is null, skipping');
        }
      }

      if (mounted && !_cancelRequested) {
        setState(() {
          _downloadedBasemaps[basemapName] = true;
          _basemapStatus[basemapName] = 'Download abgeschlossen';
        });
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('$basemapName Download abgeschlossen')));
      }
    } catch (e) {
      if (mounted) {
        print('[Download] Error: $e');
        setState(() {
          _basemapStatus[basemapName] = 'Fehler beim Download';
        });
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Fehler beim Download von $basemapName: $e')));
      }
    } finally {
      if (mounted) {
        setState(() {
          _downloadingBasemap = null;
        });
      }
    }
  }

  Future<void> _downloadDOPForRecords(List<Record> records, String basemapName) async {
    print('[$basemapName] Processing ${records.length} records');

    // Download tiles for each record position with 100m radius
    int recordIndex = 0;
    for (final record in records) {
      if (_cancelRequested) {
        print('[$basemapName] Download cancelled by user');
        break;
      }
      recordIndex++;
      final coords = record.getCoordinates();
      if (coords == null) {
        print('[$basemapName] Record $recordIndex: No coordinates, skipping');
        continue;
      }

      final lat = coords['latitude'];
      final lng = coords['longitude'];
      if (lat == null || lng == null) {
        print('[$basemapName] Record $recordIndex: Missing lat/lng, skipping');
        continue;
      }

      // Create 100m radius bbox around each record
      const radiusPadding = 0.001; // ~100m in degrees
      final recordBbox = LatLngBounds(
        LatLng(lat - radiusPadding, lng - radiusPadding),
        LatLng(lat + radiusPadding, lng + radiusPadding),
      );
      print(
        '[$basemapName] Record $recordIndex/${records.length}: Downloading bbox around ($lat, $lng)',
      );

      // Update progress based on record completion
      if (mounted) {
        setState(() {
          _basemapProgress[basemapName] = recordIndex / records.length;
          _basemapStatus[basemapName] = 'Aufnahme $recordIndex von ${records.length}';
        });
      }

      await _downloadTiles(recordBbox, basemapName);
      print('[$basemapName] Record $recordIndex/${records.length}: Download completed');
    }
    print('[$basemapName] All records processed');
  }

  LatLngBounds? _calculateBoundingBox(List<Record> records, String basemapName) {
    double? minLat, maxLat, minLng, maxLng;

    for (final record in records) {
      final coords = record.getCoordinates();
      if (coords == null) continue;

      final lat = coords['latitude'];
      final lng = coords['longitude'];

      if (lat == null || lng == null) continue;
      minLat = minLat == null ? lat : (lat < minLat ? lat : minLat);
      maxLat = maxLat == null ? lat : (lat > maxLat ? lat : maxLat);
      minLng = minLng == null ? lng : (lng < minLng ? lng : minLng);
      maxLng = maxLng == null ? lng : (lng > maxLng ? lng : maxLng);
    }

    if (minLat == null || maxLat == null || minLng == null || maxLng == null) {
      return null;
    }

    // Add buffer based on basemap type
    // OpenTopoMap: larger buffer (500m) for overview
    // DOP/ESRI Satellite: smaller buffer (100m) for detailed aerial imagery
    final padding = (basemapName == 'DOP' || basemapName == 'ESRI Satellite')
        ? 0.001
        : 0.005; // ~100m or ~500m in degrees
    return LatLngBounds(
      LatLng(minLat - padding, minLng - padding),
      LatLng(maxLat + padding, maxLng + padding),
    );
  }

  Future<void> _downloadTiles(LatLngBounds bbox, String basemapName) async {
    if (basemapName == 'DTK25' || basemapName == 'DOP') {
      await _downloadWmsTiles(bbox, basemapName);
    } else {
      await _downloadStandardTiles(bbox, basemapName);
    }
  }

  Future<void> _downloadStandardTiles(LatLngBounds bbox, String basemapName) async {
    print('[$basemapName] Starting download for bbox: $bbox');
    final storeName =
        basemapsToSelectFrom[basemapName]?['storeName'] ??
        basemapName.toLowerCase().replaceAll(' ', '_');
    final store = FMTCStore(storeName);

    // Create store if it doesn't exist
    await store.manage.create();
    print('[$basemapName] Store created/verified: $storeName');

    // Define download region
    final region = RectangleRegion(bbox);

    // Get zoom layers or fall back to min/max zoom
    final zoomLayers = basemapsToSelectFrom[basemapName]?['zoomLayers'] as List<dynamic>?;
    final zoomLevels =
        zoomLayers?.cast<int>() ??
        [
          basemapsToSelectFrom[basemapName]?['minZoom'] ?? 1,
          basemapsToSelectFrom[basemapName]?['maxZoom'] ?? 19,
        ];
    print('[$basemapName] Zoom levels to download: $zoomLevels');

    // Download each zoom level separately
    int zoomIndex = 0;
    for (final zoom in zoomLevels) {
      if (_cancelRequested) {
        print('[$basemapName] Cancelled at zoom level $zoom');
        break;
      }
      print('[$basemapName] Starting download for zoom level $zoom');
      // Configure TileLayer with urlTemplate (required by FMTC)
      final downloadableRegion = region.toDownloadable(
        minZoom: zoom,
        maxZoom: zoom,
        options: TileLayer(urlTemplate: basemapsToSelectFrom[basemapName]?['urlTemplate']),
      );

      // Start download
      print('[$basemapName] Starting download for zoom $zoom...');
      try {
        final download = store.download.startForeground(
          region: downloadableRegion,
          instanceId: '${basemapName}_${zoom}_${DateTime.now().microsecondsSinceEpoch}'.hashCode,
          parallelThreads: 1,
          maxBufferLength: 100,
          skipExistingTiles: true,
        );
        print('[$basemapName] Download stream created for zoom $zoom');

        // Consume the progress stream
        int progressUpdateCount = 0;
        int lastFailedCount = 0;
        await for (final progress in download) {
          if (_cancelRequested) {
            print('[$basemapName] Breaking progress loop due to cancel');
            break;
          }

          progressUpdateCount++;
          if (progressUpdateCount == 1 || progressUpdateCount % 10 == 0) {
            print(
              '[$basemapName] Zoom $zoom progress: ${progress.successfulTiles}/${progress.maxTiles} '
              '(skipped: ${progress.skippedTiles}, failed: ${progress.failedTiles})',
            );
          }

          // Detect if many tiles are failing - likely a proxy/network issue
          if (progress.failedTiles > lastFailedCount) {
            lastFailedCount = progress.failedTiles;
            // If more than 20% of tiles failed, show warning
            if (progress.maxTiles > 0 && progress.failedTiles > progress.maxTiles * 0.2) {
              print(
                '[$basemapName] ⚠️ High failure rate detected: ${progress.failedTiles}/${progress.maxTiles}',
              );
            }
          }

          if (mounted) {
            setState(() {
              // Update progress: (current zoom index + progress within zoom) / total zooms
              final progressInCurrentZoom = progress.maxTiles > 0
                  ? progress.successfulTiles / progress.maxTiles
                  : 0.0;
              _basemapProgress[basemapName] =
                  (zoomIndex + progressInCurrentZoom) / zoomLevels.length;
              _basemapStatus[basemapName] =
                  'Zoom $zoom: ${progress.successfulTiles}/${progress.maxTiles}';
            });
          }
        }

        print('[$basemapName] Zoom $zoom download completed ($progressUpdateCount updates)');
        zoomIndex++;
      } catch (e, stackTrace) {
        print('[$basemapName] Error during download at zoom $zoom: $e');
        print('[$basemapName] Stack trace: $stackTrace');

        // Check for Windows isolate serialization error
        if (e.toString().contains('Illegal argument in isolate message') &&
            e.toString().contains('_SecurityContext')) {
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(
                content: Text(
                  '⚠️ Bulk-Downloads funktionieren nicht unter Windows.\n'
                  'Lösung: Karten werden automatisch beim Ansehen heruntergeladen, '
                  'oder Download auf Linux/macOS durchführen.',
                ),
                duration: Duration(seconds: 10),
              ),
            );
          }
          print('[$basemapName] Windows isolate limitation - bulk downloads not supported');
          // Skip remaining zoom levels for this basemap
          break;
        }

        // Check for proxy-related errors
        final proxyError = _detectProxyError(e);
        if (proxyError != null && mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(proxyError),
              duration: const Duration(seconds: 8),
              action: SnackBarAction(label: 'OK', onPressed: () {}),
            ),
          );
        }
        // Continue with next zoom level instead of failing completely
        zoomIndex++;
      }

      print('[$basemapName] Zoom $zoom processing complete');
    }
    print('[$basemapName] All zoom levels completed');
  }

  Future<void> _downloadWmsTiles(LatLngBounds bbox, String basemapName) async {
    print('[WMS] Starting download for bbox: $bbox');
    // Use the same WMS configuration as the existing map layer
    // FMTC will handle WMS tile generation and caching
    final storeName = basemapName == 'DTK25' ? 'wms_dtk25__' : 'wms_dop__';
    final store = FMTCStore(storeName);
    await store.manage.create();
    print('[WMS] Store created/verified: $storeName');

    final baseUrl = basemapName == 'DTK25'
        ? 'https://sg.geodatenzentrum.de/wms_dtk25__${dotenv.env['DMZ_KEY']}?'
        : 'https://sg.geodatenzentrum.de/wms_dop__${dotenv.env['DMZ_KEY']}?';
    final layers = basemapName == 'DTK25' ? ['dtk25'] : ['rgb'];

    final region = RectangleRegion(bbox);

    // Get zoom layers or fall back to min/max zoom
    final zoomLayers = basemapsToSelectFrom[basemapName]?['zoomLayers'] as List<dynamic>?;
    final zoomLevels =
        zoomLayers?.cast<int>() ??
        [
          basemapsToSelectFrom[basemapName]?['minZoom'] ?? 1,
          basemapsToSelectFrom[basemapName]?['maxZoom'] ?? 19,
        ];
    print('[WMS] Zoom levels to download: $zoomLevels');

    // Download each zoom level separately
    int zoomIndex = 0;
    for (final zoom in zoomLevels) {
      if (_cancelRequested) {
        print('[WMS] Cancelled at zoom level $zoom');
        break;
      }
      print('[WMS] Starting download for zoom level $zoom');
      // Configure TileLayer with WMS options (required by FMTC)
      final downloadableRegion = region.toDownloadable(
        minZoom: zoom,
        maxZoom: zoom,
        options: TileLayer(
          wmsOptions: WMSTileLayerOptions(
            baseUrl: baseUrl,
            layers: layers,
            format: 'image/jpeg',
            crs: const Epsg3857(),
          ),
        ),
      );

      print('[WMS] Starting download for zoom $zoom...');
      try {
        final download = store.download.startForeground(
          region: downloadableRegion,
          instanceId: '${basemapName}_${zoom}_${DateTime.now().microsecondsSinceEpoch}'.hashCode,
          parallelThreads: 1,
          maxBufferLength: 100,
          skipExistingTiles: true,
        );
        print('[WMS] Download stream created for zoom $zoom');

        // Consume the progress stream
        int progressUpdateCount = 0;
        int lastFailedCount = 0;
        await for (final progress in download) {
          if (_cancelRequested) {
            print('[WMS] Breaking progress loop due to cancel');
            break;
          }

          progressUpdateCount++;

          if (progressUpdateCount == 1 || progressUpdateCount % 10 == 0) {
            print(
              '[WMS] Zoom $zoom progress: ${progress.successfulTiles}/${progress.maxTiles} '
              '(skipped: ${progress.skippedTiles}, failed: ${progress.failedTiles})',
            );
          }

          // Detect if many tiles are failing - likely a proxy/network issue
          if (progress.failedTiles > lastFailedCount) {
            lastFailedCount = progress.failedTiles;
            // If more than 20% of tiles failed, show warning
            if (progress.maxTiles > 0 && progress.failedTiles > progress.maxTiles * 0.2) {
              print(
                '[WMS] ⚠️ High failure rate detected: ${progress.failedTiles}/${progress.maxTiles}',
              );
            }
          }

          if (mounted) {
            setState(() {
              // Update progress: (current zoom index + progress within zoom) / total zooms
              final progressInCurrentZoom = progress.maxTiles > 0
                  ? progress.successfulTiles / progress.maxTiles
                  : 0.0;
              _basemapProgress[basemapName] =
                  (zoomIndex + progressInCurrentZoom) / zoomLevels.length;
              _basemapStatus[basemapName] =
                  'Zoom $zoom: ${progress.successfulTiles}/${progress.maxTiles}';
            });
          }
        }

        print('[WMS] Zoom $zoom download completed ($progressUpdateCount updates)');
        zoomIndex++;
      } catch (e, stackTrace) {
        print('[WMS] Error during download at zoom $zoom: $e');
        print('[WMS] Stack trace: $stackTrace');

        // Check for Windows isolate serialization error
        if (e.toString().contains('Illegal argument in isolate message') &&
            e.toString().contains('_SecurityContext')) {
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(
                content: Text(
                  '⚠️ Bulk-Downloads funktionieren nicht unter Windows.\n'
                  'Lösung: Karten werden automatisch beim Ansehen heruntergeladen, '
                  'oder Download auf Linux/macOS durchführen.',
                ),
                duration: Duration(seconds: 10),
              ),
            );
          }
          print('[WMS] Windows isolate limitation - bulk downloads not supported');
          break;
        }

        // Check for proxy-related errors
        final proxyError = _detectProxyError(e);
        if (proxyError != null && mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(proxyError),
              duration: const Duration(seconds: 8),
              action: SnackBarAction(label: 'OK', onPressed: () {}),
            ),
          );
        }
        // Continue with next zoom level
        zoomIndex++;
      }
    }
    print('[WMS] All zoom levels completed');
  }

  @override
  Widget build(BuildContext context) {
    final isAnyDownloading = _downloadingBasemap != null;

    return Material(
      color: Colors.transparent,
      child: Column(
        children: [
          // Header
          Padding(
            padding: const EdgeInsets.all(16.0),
            child: Row(
              children: [
                const Icon(Icons.map),
                const SizedBox(width: 8),
                Text(
                  'Karten herunterladen',
                  style: Theme.of(
                    context,
                  ).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold),
                ),
              ],
            ),
          ),

          // Basemap tiles
          ...basemapsToSelectFrom.entries.map((entry) {
            final basemapName = entry.key;
            final config = entry.value;
            final urlTemplate = config['urlTemplate'] as String;

            // Determine provider name from URL
            String providerName = '';
            Icon providerIcon = const Icon(Icons.map);
            if (urlTemplate.contains('tile-cyclosm.openstreetmap.fr')) {
              providerName = 'OpenStreetMap CycloSM';
              providerIcon = const Icon(Icons.directions_bike);
            } else if (urlTemplate.contains('geodatenzentrum.de')) {
              providerName = 'BKG GeoDatenZentrum';
              providerIcon = const Icon(Icons.satellite_alt);
            } else if (urlTemplate.contains('arcgisonline.com')) {
              providerName = 'ESRI World Imagery';
              providerIcon = const Icon(Icons.public);
            }

            final isDownloading = _downloadingBasemap == basemapName;
            final isCompleted = _downloadedBasemaps[basemapName] ?? false;
            final progress = _basemapProgress[basemapName] ?? 0.0;
            final status = _basemapStatus[basemapName] ?? '';
            final canDownload = !isAnyDownloading && !_isCheckingTiles && _missingTilesCount == -1;

            return Column(
              children: [
                ListTile(
                  leading: isDownloading
                      ? const SizedBox(
                          width: 24,
                          height: 24,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : providerIcon,
                  title: Text(basemapName),
                  subtitle: isDownloading
                      ? Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(status),
                            const SizedBox(height: 4),
                            LinearProgressIndicator(value: progress),
                          ],
                        )
                      : isCompleted
                      ? const Text('Download abgeschlossen')
                      : Text(providerName),
                  trailing: isDownloading
                      ? IconButton(
                          icon: const Icon(Icons.cancel),
                          onPressed: _cancelDownload,
                          tooltip: 'Abbrechen',
                        )
                      : isCompleted
                      ? const Icon(Icons.check_circle, color: Colors.green)
                      : null,
                  onTap: canDownload ? () => _downloadMapTilesForBasemap(basemapName) : null,
                  enabled: canDownload,
                ),
                const Divider(height: 1),
              ],
            );
          }).toList(),

          // Status message if no records
          if (_isCheckingTiles)
            const Padding(padding: EdgeInsets.all(16.0), child: Text('Prüfe Aufnahmepunkte...'))
          else if (_missingTilesCount == 0)
            const Padding(
              padding: EdgeInsets.all(16.0),
              child: Text('Keine Aufnahmepunkte gefunden. Bitte laden Sie zuerst Daten.'),
            ),
        ],
      ),
    );
  }
}
