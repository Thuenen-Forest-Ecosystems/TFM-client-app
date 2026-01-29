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
  String selectedBasemap = '';
  bool _isDownloading = false;
  //int _totalTiles = 0;
  int _downloadedTiles = 0;
  int _cumulativeDownloadedTiles = 0;
  int _cumulativeTotalTiles = 0;
  bool _isCheckingTiles = true;
  int _missingTilesCount = 0;
  bool _cancelRequested = false;

  // Per-basemap progress tracking
  final Map<String, Map<String, int>> _basemapProgress = {};
  final List<String> _basemapOrder = [];
  int? _lastDOPSuccessfulTiles = 0; // Track previous count to calculate delta

  @override
  void initState() {
    super.initState();
    _checkMissingTiles();
  }

  /// Detects if an error is proxy-related and returns user-friendly message
  String? _detectProxyError(dynamic error) {
    final errorString = error.toString().toLowerCase();
    
    // Connection/timeout errors
    if (errorString.contains('timeout') || 
        errorString.contains('connection timed out')) {
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
    if (errorString.contains('407') || 
        errorString.contains('proxy authentication')) {
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
      _isDownloading = false;
    });
    if (mounted) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('Download wird abgebrochen...')));
    }
  }

  Future<Map<String, int>> _estimateTileCounts(List<Record> records) async {
    print('[Estimate] Starting tile count estimation...');
    final Map<String, int> estimates = {};

    for (final basemapEntry in basemapsToSelectFrom.entries) {
      final basemapName = basemapEntry.key;
      final config = basemapEntry.value;
      final storeName = config['storeName'] ?? basemapName.toLowerCase().replaceAll(' ', '_');
      final store = FMTCStore(storeName);

      int totalTiles = 0;

      if (basemapName == 'DOP') {
        // For DOP: estimate per record
        for (final record in records) {
          final coords = record.getCoordinates();
          if (coords == null) continue;

          final lat = coords['latitude'];
          final lng = coords['longitude'];
          if (lat == null || lng == null) continue;

          const radiusPadding = 0.001;
          final recordBbox = LatLngBounds(
            LatLng(lat - radiusPadding, lng - radiusPadding),
            LatLng(lat + radiusPadding, lng + radiusPadding),
          );

          totalTiles += await _estimateTilesForBbox(basemapName, recordBbox, store);
        }
      } else {
        // For other basemaps: single bbox for all records
        final bbox = _calculateBoundingBox(records);
        if (bbox != null) {
          totalTiles = await _estimateTilesForBbox(basemapName, bbox, store);
        }
      }

      estimates[basemapName] = totalTiles;
      print('[Estimate] $basemapName: $totalTiles tiles');
    }

    return estimates;
  }

  Future<int> _estimateTilesForBbox(String basemapName, LatLngBounds bbox, FMTCStore store) async {
    final config = basemapsToSelectFrom[basemapName];
    if (config == null) return 0;

    final zoomLayers = config['zoomLayers'] as List<dynamic>?;
    final zoomLevels = zoomLayers?.cast<int>() ?? [config['minZoom'] ?? 1, config['maxZoom'] ?? 19];

    int totalTiles = 0;
    final region = RectangleRegion(bbox);

    for (final zoom in zoomLevels) {
      try {
        // Use minimal TileLayer without urlTemplate to avoid Windows isolate serialization issues
        final downloadableRegion = region.toDownloadable(
          minZoom: zoom,
          maxZoom: zoom,
          options: TileLayer(), // Minimal TileLayer without URL template
        );

        final count = await store.download.check(downloadableRegion);
        totalTiles += count;
      } catch (e) {
        print('[Estimate] Error estimating tiles for $basemapName zoom $zoom: $e');
        // If check fails (e.g., on Windows), use approximate calculation
        // Rough estimate: number of tiles = 4^zoom for a small bbox
        final approxTiles = _calculateApproximateTiles(bbox, zoom);
        print('[Estimate] Using approximate count for $basemapName zoom $zoom: $approxTiles');
        totalTiles += approxTiles;
      }
    }

    return totalTiles;
  }

  int _calculateApproximateTiles(LatLngBounds bbox, int zoom) {
    // Calculate approximate tile count based on bbox size and zoom level
    // Tile grid at zoom level z has 2^z × 2^z tiles covering the world
    final tileSize = 256.0;
    final earthCircumference = 40075017.0; // meters at equator
    final metersPerTile = earthCircumference / (1 << zoom);

    // Calculate bbox dimensions in degrees
    final latDiff = (bbox.north - bbox.south).abs();
    final lngDiff = (bbox.east - bbox.west).abs();

    // Rough conversion: 1 degree ≈ 111km at equator
    final latMeters = latDiff * 111000;
    final lngMeters = lngDiff * 111000;

    // Calculate tiles needed
    final tilesX = (lngMeters / metersPerTile).ceil();
    final tilesY = (latMeters / metersPerTile).ceil();

    return tilesX * tilesY;
  }

  Future<void> _downloadMapTilesFromRecordsBBox() async {
    print('[Download] Starting download process...');
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

    // Estimate tile counts before downloading
    print('[Download] Estimating tile counts...');
    final estimates = await _estimateTileCounts(records);
    final totalEstimatedTiles = estimates.values.fold<int>(0, (sum, count) => sum + count);

    print('[Download] Total estimated tiles: $totalEstimatedTiles');

    // Show confirmation dialog
    if (mounted) {
      final confirmed = await showDialog<bool>(
        context: context,
        builder: (context) => AlertDialog(
          title: const Text('Download-Bestätigung'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('Geschätzte Kacheln zum Download:'),
              const SizedBox(height: 12),
              ...estimates.entries.map(
                (entry) => Padding(
                  padding: const EdgeInsets.only(bottom: 4),
                  child: Text('${entry.key}: ${entry.value} Kacheln'),
                ),
              ),
              const Divider(),
              Text(
                'Gesamt: $totalEstimatedTiles Kacheln',
                style: const TextStyle(fontWeight: FontWeight.bold),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(false),
              child: const Text('Abbrechen'),
            ),
            FilledButton(
              onPressed: () => Navigator.of(context).pop(true),
              child: const Text('Download starten'),
            ),
          ],
        ),
      );

      if (confirmed != true) {
        print('[Download] User cancelled download');
        return;
      }
    }

    setState(() {
      _isDownloading = true;
      _downloadedTiles = 0;
      _cumulativeDownloadedTiles = 0;
      _cancelRequested = false;
      _basemapProgress.clear();
      _basemapOrder.clear();
      // Initialize progress tracking with estimated totals
      for (final basemapName in basemapsToSelectFrom.keys) {
        _basemapProgress[basemapName] = {'downloaded': 0, 'total': estimates[basemapName] ?? 0};
        _basemapOrder.add(basemapName);
      }
      _cumulativeTotalTiles = totalEstimatedTiles;
    });
    print('[Download] Download state initialized');

    try {
      // Iterate through all uncommented basemaps
      for (final basemapEntry in basemapsToSelectFrom.entries) {
        if (_cancelRequested) break;

        selectedBasemap = basemapEntry.key;
        final config = basemapEntry.value;

        print('[Download] Starting $selectedBasemap download...');

        // DOP needs per-record download with small radius
        if (selectedBasemap == 'DOP') {
          await _downloadDOPForRecords(records);
        } else {
          // Other basemaps: download entire bbox with larger buffer
          final bbox = _calculateBoundingBox(records);
          if (bbox != null) {
            await _downloadTiles(bbox);
          } else {
            print('[Download] $selectedBasemap bbox is null, skipping');
          }
        }

        print('[Download] $selectedBasemap download completed');
      }

      if (mounted) {
        final totalProcessed = _cumulativeDownloadedTiles + _downloadedTiles;
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              'Download abgeschlossen: $totalProcessed von $_cumulativeTotalTiles Kacheln verarbeitet',
            ),
          ),
        );
        // Recheck missing tiles after download
        _checkMissingTiles();
      }
    } catch (e) {
      if (mounted) {
        print('[Download] Error: $e');
        print('[Download] Error type: ${e.runtimeType}');
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Fehler beim Download: $e\nTyp: ${e.runtimeType}')));
      }
    } finally {
      if (mounted) {
        setState(() {
          _isDownloading = false;
        });
      }
    }
  }

  Future<void> _downloadDOPForRecords(List<Record> records) async {
    selectedBasemap = 'DOP';
    print('[DOP] Processing ${records.length} records');

    // Download tiles for each record position with 100m radius
    int recordIndex = 0;
    for (final record in records) {
      if (_cancelRequested) {
        print('[DOP] Download cancelled by user');
        break;
      }
      recordIndex++;
      final coords = record.getCoordinates();
      if (coords == null) {
        print('[DOP] Record $recordIndex: No coordinates, skipping');
        continue;
      }

      final lat = coords['latitude'];
      final lng = coords['longitude'];
      if (lat == null || lng == null) {
        print('[DOP] Record $recordIndex: Missing lat/lng, skipping');
        continue;
      }

      // Create 100m radius bbox around each record
      const radiusPadding = 0.001; // ~100m in degrees
      final recordBbox = LatLngBounds(
        LatLng(lat - radiusPadding, lng - radiusPadding),
        LatLng(lat + radiusPadding, lng + radiusPadding),
      );
      print('[DOP] Record $recordIndex/${records.length}: Downloading bbox around ($lat, $lng)');

      await _downloadTiles(recordBbox);
      print('[DOP] Record $recordIndex/${records.length}: Download completed');
    }
    print('[DOP] All records processed');
  }

  LatLngBounds? _calculateBoundingBox(List<Record> records) {
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
    // DOP: smaller buffer (100m) for detailed aerial imagery
    final padding = selectedBasemap == 'DOP' ? 0.001 : 0.005; // ~100m or ~500m in degrees
    return LatLngBounds(
      LatLng(minLat - padding, minLng - padding),
      LatLng(maxLat + padding, maxLng + padding),
    );
  }

  Future<void> _downloadTiles(LatLngBounds bbox) async {
    if (selectedBasemap == 'DTK25' || selectedBasemap == 'DOP') {
      await _downloadWmsTiles(bbox);
    } else {
      await _downloadStandardTiles(bbox);
    }
  }

  Future<void> _downloadStandardTiles(LatLngBounds bbox) async {
    print('[$selectedBasemap] Starting download for bbox: $bbox');
    final storeName =
        basemapsToSelectFrom[selectedBasemap]?['storeName'] ??
        selectedBasemap.toLowerCase().replaceAll(' ', '_');
    final store = FMTCStore(storeName);

    // Create store if it doesn't exist
    await store.manage.create();
    print('[$selectedBasemap] Store created/verified: $storeName');

    // Define download region
    final region = RectangleRegion(bbox);

    // Get zoom layers or fall back to min/max zoom
    final zoomLayers = basemapsToSelectFrom[selectedBasemap]?['zoomLayers'] as List<dynamic>?;
    final zoomLevels =
        zoomLayers?.cast<int>() ??
        [
          basemapsToSelectFrom[selectedBasemap]?['minZoom'] ?? 1,
          basemapsToSelectFrom[selectedBasemap]?['maxZoom'] ?? 19,
        ];
    print('[$selectedBasemap] Zoom levels to download: $zoomLevels');

    // Download each zoom level separately
    for (final zoom in zoomLevels) {
      if (_cancelRequested) {
        print('[$selectedBasemap] Cancelled at zoom level $zoom');
        break;
      }
      print('[$selectedBasemap] Starting download for zoom level $zoom');
      // Configure download with absolute minimal TileLayer to avoid HTTP client serialization
      final downloadableRegion = region.toDownloadable(
        minZoom: zoom,
        maxZoom: zoom,
        options: TileLayer(urlTemplate: basemapsToSelectFrom[selectedBasemap]?['urlTemplate']),
      );

      // Start download
      print('[$selectedBasemap] Starting download for zoom $zoom...');
      try {
        final download = store.download.startForeground(
          region: downloadableRegion,
          instanceId: '${selectedBasemap}_$zoom'.hashCode, // Unique ID per basemap and zoom
          parallelThreads: 1,
          maxBufferLength: 100,
          skipExistingTiles: true,
        );
        print('[$selectedBasemap] Download stream created for zoom $zoom');

        // Consume the progress stream
        int progressUpdateCount = 0;
        int lastFailedCount = 0;
        await for (final progress in download) {
          if (_cancelRequested) {
            print('[$selectedBasemap] Breaking progress loop due to cancel');
            break;
          }

          progressUpdateCount++;
          if (progressUpdateCount == 1 || progressUpdateCount % 10 == 0) {
            print(
              '[$selectedBasemap] Zoom $zoom progress: ${progress.successfulTiles}/${progress.maxTiles} '
              '(skipped: ${progress.skippedTiles}, failed: ${progress.failedTiles})',
            );
          }
          
          // Detect if many tiles are failing - likely a proxy/network issue
          if (progress.failedTiles > lastFailedCount) {
            lastFailedCount = progress.failedTiles;
            // If more than 20% of tiles failed, show warning
            if (progress.maxTiles > 0 && progress.failedTiles > progress.maxTiles * 0.2) {
              print('[$selectedBasemap] ⚠️ High failure rate detected: ${progress.failedTiles}/${progress.maxTiles}');
              if (mounted) {
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Text(
                      '⚠️ Viele Kacheln fehlgeschlagen (${progress.failedTiles}/${progress.maxTiles}).\n'
                      'Mögliche Ursache: Proxy blockiert Verbindung.',
                    ),
                    duration: const Duration(seconds: 5),
                    action: SnackBarAction(
                      label: 'Abbrechen',
                      onPressed: _cancelDownload,
                    ),
                  ),
                );
              }
            }
          }

          if (mounted) {
            setState(() {
              _downloadedTiles = progress.successfulTiles;
              // Update per-basemap downloaded count (current zoom progress only)
              _basemapProgress[selectedBasemap]?['downloaded'] =
                  _cumulativeDownloadedTiles + progress.successfulTiles;
            });
          }
        }

        print('[$selectedBasemap] Zoom $zoom download completed ($progressUpdateCount updates)');

        // Update cumulative counter
        if (mounted) {
          setState(() {
            _cumulativeDownloadedTiles += _downloadedTiles;
          });
        }

        print('[$selectedBasemap] Zoom $zoom cumulative tiles: $_cumulativeDownloadedTiles');
      } catch (e, stackTrace) {
        print('[$selectedBasemap] Error during download at zoom $zoom: $e');
        print('[$selectedBasemap] Stack trace: $stackTrace');
        
        // Check for proxy-related errors
        final proxyError = _detectProxyError(e);
        if (proxyError != null && mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(proxyError),
              duration: const Duration(seconds: 8),
              action: SnackBarAction(
                label: 'OK',
                onPressed: () {},
              ),
            ),
          );
        }
        // Continue with next zoom level instead of failing completely
      }

      print('[$selectedBasemap] Zoom $zoom processing complete');
    }
    print('[$selectedBasemap] All zoom levels completed');
  }

  Future<void> _downloadWmsTiles(LatLngBounds bbox) async {
    print('[WMS] Starting download for bbox: $bbox');
    // Use the same WMS configuration as the existing map layer
    // FMTC will handle WMS tile generation and caching
    final storeName = selectedBasemap == 'DTK25' ? 'wms_dtk25__' : 'wms_dop__';
    final store = FMTCStore(storeName);
    await store.manage.create();
    print('[WMS] Store created/verified: $storeName');

    final baseUrl = selectedBasemap == 'DTK25'
        ? 'https://sg.geodatenzentrum.de/wms_dtk25__${dotenv.env['DMZ_KEY']}?'
        : 'https://sg.geodatenzentrum.de/wms_dop__${dotenv.env['DMZ_KEY']}?';
    final layers = selectedBasemap == 'DTK25' ? ['dtk25'] : ['rgb'];

    final region = RectangleRegion(bbox);

    // Get zoom layers or fall back to min/max zoom
    final zoomLayers = basemapsToSelectFrom[selectedBasemap]?['zoomLayers'] as List<dynamic>?;
    final zoomLevels =
        zoomLayers?.cast<int>() ??
        [
          basemapsToSelectFrom[selectedBasemap]?['minZoom'] ?? 1,
          basemapsToSelectFrom[selectedBasemap]?['maxZoom'] ?? 19,
        ];
    print('[WMS] Zoom levels to download: $zoomLevels');

    // Download each zoom level separately
    for (final zoom in zoomLevels) {
      if (_cancelRequested) {
        print('[WMS] Cancelled at zoom level $zoom');
        break;
      }
      print('[WMS] Starting download for zoom level $zoom');
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
          instanceId: '${selectedBasemap}_$zoom'.hashCode, // Unique ID per basemap and zoom
          parallelThreads: 1,
          maxBufferLength: 100,
          skipExistingTiles: true,
        );
        print('[WMS] Download stream created for zoom $zoom');

        // Track total tiles for this zoom level to avoid counting multiple times
        int zoomTotalTiles = 0;
        _lastDOPSuccessfulTiles = 0; // Reset for this zoom level

        // Consume the progress stream
        int progressUpdateCount = 0;
        int lastFailedCount = 0;
        await for (final progress in download) {
          if (_cancelRequested) {
            print('[WMS] Breaking progress loop due to cancel');
            break;
          }

          progressUpdateCount++;
          // Only set total once (first update of this zoom)
          if (progressUpdateCount == 1) {
            zoomTotalTiles = progress.maxTiles;
          }

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
              print('[WMS] ⚠️ High failure rate detected: ${progress.failedTiles}/${progress.maxTiles}');
              if (mounted) {
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Text(
                      '⚠️ Viele WMS-Kacheln fehlgeschlagen (${progress.failedTiles}/${progress.maxTiles}).\n'
                      'Mögliche Ursache: Proxy blockiert geodatenzentrum.de',
                    ),
                    duration: const Duration(seconds: 5),
                    action: SnackBarAction(
                      label: 'Abbrechen',
                      onPressed: _cancelDownload,
                    ),
                  ),
                );
              }
            }
          }

          if (mounted) {
            setState(() {
              _downloadedTiles = progress.successfulTiles;
              // For DOP: accumulate progress across all records
              // Calculate delta and update immediately
              final delta = progress.successfulTiles - (_lastDOPSuccessfulTiles ?? 0);
              _basemapProgress[selectedBasemap]?['downloaded'] =
                  (_basemapProgress[selectedBasemap]?['downloaded'] ?? 0) + delta;
              _lastDOPSuccessfulTiles = progress.successfulTiles; // Update for next iteration
            });
          }
        }

        // Update total only once per zoom level (after loop completes)
        if (mounted) {
          setState(() {
            _basemapProgress[selectedBasemap]?['total'] =
                (_basemapProgress[selectedBasemap]?['total'] ?? 0) + zoomTotalTiles;
          });
        }

        print('[WMS] Zoom $zoom download completed ($progressUpdateCount updates)');

        // Update cumulative counter
        if (mounted) {
          setState(() {
            _cumulativeDownloadedTiles += _downloadedTiles;
          });
        }

        print('[WMS] Zoom $zoom cumulative tiles: $_cumulativeDownloadedTiles');
      } catch (e, stackTrace) {
        print('[WMS] Error during download at zoom $zoom: $e');
        print('[WMS] Stack trace: $stackTrace');
        
        // Check for proxy-related errors
        final proxyError = _detectProxyError(e);
        if (proxyError != null && mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(proxyError),
              duration: const Duration(seconds: 8),
              action: SnackBarAction(
                label: 'OK',
                onPressed: () {},
              ),
            ),
          );
        }
        // Continue with next zoom level
      }
    }
    print('[WMS] All zoom levels completed');
  }

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: Column(
        children: [
          ListTile(
            leading: _isDownloading
                ? const SizedBox(
                    width: 24,
                    height: 24,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : const Icon(Icons.download),
            title: const Text('Karten herunterladen'),
            subtitle: _isDownloading
                ? Text(
                    'Gesamt: ${_cumulativeDownloadedTiles + _downloadedTiles}/$_cumulativeTotalTiles Kacheln',
                  )
                : _isCheckingTiles
                ? const Text('Prüfe Aufnahmepunkte...')
                : _missingTilesCount == -1
                ? const Text('Bereit zum Herunterladen der Karten.')
                : const Text('Keine Aufnahmepunkte gefunden.'),
            onTap: (_isDownloading || _isCheckingTiles) ? null : _downloadMapTilesFromRecordsBBox,
            enabled: !_isDownloading && !_isCheckingTiles,
            trailing: _isDownloading
                ? TextButton.icon(
                    onPressed: _cancelDownload,
                    label: const Text('Abbrechen'),
                    icon: const Icon(Icons.cancel),
                  )
                : null,
          ),
          if (_isDownloading)
            Padding(
              padding: const EdgeInsets.all(10),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Per-basemap progress bars
                  ..._basemapOrder.map((basemapName) {
                    final progress = _basemapProgress[basemapName] ?? {'downloaded': 0, 'total': 0};
                    final downloaded = progress['downloaded'] as int;
                    final total = progress['total'] as int;
                    final basemapProgress = total > 0 ? downloaded / total : 0.0;

                    return Padding(
                      padding: const EdgeInsets.only(bottom: 12),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Text(
                                basemapName,
                                style: Theme.of(
                                  context,
                                ).textTheme.bodySmall?.copyWith(fontWeight: FontWeight.bold),
                              ),
                              Text(
                                '$downloaded/$total Kacheln',
                                style: Theme.of(context).textTheme.bodySmall,
                              ),
                            ],
                          ),
                          const SizedBox(height: 4),
                          LinearProgressIndicator(value: basemapProgress),
                        ],
                      ),
                    );
                  }).toList(),
                ],
              ),
            ),
        ],
      ),
    );
  }
}
