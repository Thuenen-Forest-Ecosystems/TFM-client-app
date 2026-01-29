import 'dart:io';
import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:flutter_map_tile_caching/flutter_map_tile_caching.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import 'package:terrestrial_forest_monitor/repositories/records_repository.dart';

class MapTilesDownloadWindows extends StatefulWidget {
  const MapTilesDownloadWindows({super.key});

  @override
  State<MapTilesDownloadWindows> createState() => _MapTilesDownloadWindowsState();
}

class _MapTilesDownloadWindowsState extends State<MapTilesDownloadWindows> {
  Map<String, Map<String, dynamic>> basemapsToSelectFrom = {
    'DOP': {
      'urlTemplate': 'https://sg.geodatenzentrum.de/wms_dop__${dotenv.env['DMZ_KEY']}?',
      'zoomLayers': [15, 19],
      'storeName': 'wms_dop__',
      'isWMS': true,
    },
    'OpenCycleMap': {
      'urlTemplate': 'https://{s}.tile-cyclosm.openstreetmap.fr/cyclosm/{z}/{x}/{y}.png',
      'zoomLayers': [4, 10, 14],
      'storeName': 'OpenCycleMap',
      'isWMS': false,
    },
  };

  bool _isDownloading = false;
  bool _isCheckingTiles = true;
  int _missingTilesCount = 0;
  int _downloadedTiles = 0;
  int _totalTiles = 0;

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
      print('[Windows Check] Error checking records: $e');
      if (!mounted) return;

      setState(() {
        _missingTilesCount = 0;
        _isCheckingTiles = false;
      });
    }
  }

  Future<void> _downloadMapTilesFromRecordsBBox() async {
    print('[Windows Download] Starting download process...');
    final records = await RecordsRepository().getAllRecords();
    print('[Windows Download] Found ${records.length} records');

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

    // Show confirmation dialog
    if (mounted) {
      final confirmed = await showDialog<bool>(
        context: context,
        builder: (context) => AlertDialog(
          title: const Text('Windows Download'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('Download wird für ${records.length} Aufnahmepunkte vorbereitet.'),
              const SizedBox(height: 12),
              const Text(
                'Hinweis: Download ohne Proxy (Windows-Einschränkung). '
                'Tiles werden im FMTC Cache gespeichert.',
                style: TextStyle(fontSize: 12),
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
        print('[Windows Download] User cancelled download');
        return;
      }
    }

    setState(() {
      _isDownloading = true;
      _downloadedTiles = 0;
      _totalTiles = 0;
    });

    try {
      int processedRecords = 0;

      for (final record in records) {
        final coords = record.getCoordinates();
        if (coords == null) continue;

        final lat = coords['latitude'];
        final lng = coords['longitude'];
        if (lat == null || lng == null) continue;

        // Create small bbox around each record
        const radiusPadding = 0.001; // ~100m
        final recordBbox = LatLngBounds(
          LatLng(lat - radiusPadding, lng - radiusPadding),
          LatLng(lat + radiusPadding, lng + radiusPadding),
        );

        print('[Windows Download] Processing record ${processedRecords + 1}/${records.length}');
        await _downloadTilesForBboxManually(recordBbox);

        processedRecords++;
        if (mounted) {
          setState(() {});
        }
      }

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              'Download abgeschlossen: $processedRecords Aufnahmepunkte, $_downloadedTiles Kacheln',
            ),
          ),
        );
        _checkMissingTiles();
      }
    } catch (e) {
      if (mounted) {
        print('[Windows Download] Error: $e');
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Fehler beim Download: $e')),
        );
      }
    } finally {
      if (mounted) {
        setState(() {
          _isDownloading = false;
        });
      }
    }
  }

  /// Manual tile download that works with proxy and stores in FMTC cache
  /// Uses FMTC's download mechanism but temporarily disables HttpOverrides
  Future<void> _downloadTilesForBboxManually(LatLngBounds bbox) async {
    // Save current HttpOverrides
    final savedOverrides = HttpOverrides.current;

    try {
      // Temporarily remove HttpOverrides to avoid isolate serialization issues
      HttpOverrides.global = null;
      print('[Windows] Temporarily disabled HttpOverrides for FMTC download');

      for (final basemapEntry in basemapsToSelectFrom.entries) {
        final basemapName = basemapEntry.key;
        final config = basemapEntry.value;
        final storeName = config['storeName'] ?? basemapName.toLowerCase().replaceAll(' ', '_');
        final isWMS = config['isWMS'] == true;

        try {
          final store = FMTCStore(storeName);
          await store.manage.create();

          final zoomLayers = config['zoomLayers'] as List<dynamic>?;
          final zoomLevels = zoomLayers?.cast<int>() ?? [1, 19];

          print('[Windows] Downloading $basemapName tiles...');

          final region = RectangleRegion(bbox);

          for (final zoom in zoomLevels) {
            print('[Windows] Processing zoom level $zoom for $basemapName');

            try {
              // Create tile layer configuration
              final TileLayer tileLayer;

              if (isWMS) {
                // WMS tile layer for DOP
                final baseUrl = 'https://sg.geodatenzentrum.de/wms_dop__${dotenv.env['DMZ_KEY']}?';
                tileLayer = TileLayer(
                  wmsOptions: WMSTileLayerOptions(
                    baseUrl: baseUrl,
                    layers: const ['rgb'],
                    format: 'image/jpeg',
                    crs: const Epsg3857(),
                  ),
                );
              } else {
                // Standard tile layer
                tileLayer = TileLayer(
                  urlTemplate: config['urlTemplate'],
                );
              }

              final downloadableRegion = region.toDownloadable(
                minZoom: zoom,
                maxZoom: zoom,
                options: tileLayer,
              );

              // Use FMTC's download mechanism (works without proxy but saves to cache)
              final recoveryId = DateTime.now().millisecondsSinceEpoch + zoom;

              final downloadStream = store.download.startForeground(
                region: downloadableRegion,
                instanceId: recoveryId,
                parallelThreads: 1,
                maxBufferLength: 20,
                skipExistingTiles: true,
              );

              // Consume stream to completion
              int lastSuccessful = 0;
              int lastFailedCount = 0;
              await for (final progress in downloadStream) {
                if (mounted) {
                  setState(() {
                    _downloadedTiles = (_downloadedTiles - lastSuccessful) + progress.successfulTiles;
                    _totalTiles = progress.maxTiles;
                  });
                }
                lastSuccessful = progress.successfulTiles;
                
                // Detect if many tiles are failing - likely a proxy/network issue
                if (progress.failedTiles > lastFailedCount) {
                  lastFailedCount = progress.failedTiles;
                  // If more than 20% of tiles failed, show warning
                  if (progress.maxTiles > 0 && progress.failedTiles > progress.maxTiles * 0.2) {
                    print('[Windows] ⚠️ High failure rate: ${progress.failedTiles}/${progress.maxTiles}');
                    if (mounted) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(
                          content: Text(
                            '⚠️ Viele Kacheln fehlgeschlagen (${progress.failedTiles}/${progress.maxTiles}).\n'
                            'Mögliche Ursache: Proxy blockiert Verbindung zu geodatenzentrum.de',
                          ),
                          duration: const Duration(seconds: 5),
                        ),
                      );
                    }
                  }
                }

                // Log progress periodically
                if (progress.successfulTiles % 10 == 0 ||
                    progress.successfulTiles == progress.maxTiles) {
                  print(
                    '[Windows] $basemapName zoom $zoom: '
                    '${progress.successfulTiles}/${progress.maxTiles} tiles '
                    '(failed: ${progress.failedTiles})',
                  );
                }
              }

              print('[Windows] Completed $basemapName zoom $zoom: $lastSuccessful tiles');
            } catch (e, stackTrace) {
              print('[Windows] Error at zoom $zoom: $e');
              print('[Windows] Stack trace: $stackTrace');
              
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
              
              // Try to cancel the download if it failed
              try {
                await store.download.cancel();
              } catch (_) {}
              // Continue with next zoom level
            }
          }
        } catch (e, stackTrace) {
          print('[Windows] Error downloading $basemapName: $e');
          print('[Windows] Stack trace: $stackTrace');
          
          // Check for proxy-related errors
          final proxyError = _detectProxyError(e);
          if (proxyError != null && mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text('$basemapName: $proxyError'),
                duration: const Duration(seconds: 8),
                action: SnackBarAction(
                  label: 'OK',
                  onPressed: () {},
                ),
              ),
            );
          }
          // Continue with next basemap
        }
      }
    } finally {
      // CRITICAL: Restore HttpOverrides after downloads complete
      if (savedOverrides != null) {
        HttpOverrides.global = savedOverrides;
        print('[Windows] Restored HttpOverrides');
      }
    }
  }

  /// Build WMS URL for a specific tile (kept for reference but not used in current implementation)
  String _buildWMSUrl(String baseUrl, TileCoordinate tile, int zoom) {
    final bbox = _tileToBBox(tile, zoom);

    return '$baseUrl'
        'SERVICE=WMS&'
        'VERSION=1.1.1&'
        'REQUEST=GetMap&'
        'LAYERS=rgb&'
        'STYLES=&'
        'SRS=EPSG:3857&'
        'BBOX=${bbox.join(',')}&'
        'WIDTH=256&'
        'HEIGHT=256&'
        'FORMAT=image/png';
  }

  /// Convert tile coordinates to bounding box for WMS
  List<double> _tileToBBox(TileCoordinate tile, int zoom) {
    final n = math.pow(2, zoom);
    final lonMin = tile.x / n * 360.0 - 180.0;
    final lonMax = (tile.x + 1) / n * 360.0 - 180.0;

    final latMin = _tile2lat(tile.y + 1, zoom);
    final latMax = _tile2lat(tile.y, zoom);

    // Convert to Web Mercator (EPSG:3857)
    final xMin = lonMin * 20037508.34 / 180;
    final xMax = lonMax * 20037508.34 / 180;
    final yMin =
        math.log(math.tan((90 + latMin) * math.pi / 360)) / (math.pi / 180) * 20037508.34 / 180;
    final yMax =
        math.log(math.tan((90 + latMax) * math.pi / 360)) / (math.pi / 180) * 20037508.34 / 180;

    return [xMin, yMin, xMax, yMax];
  }

  double _tile2lat(int y, int zoom) {
    final n = math.pow(2, zoom);
    final latRad = math.atan(_sinh(math.pi * (1 - 2 * y / n)));
    return latRad * 180.0 / math.pi;
  }

  /// Hyperbolic sine function (sinh)
  double _sinh(double x) {
    return (math.exp(x) - math.exp(-x)) / 2;
  }

  /// Get all tile coordinates within a bounding box for a specific zoom level
  List<TileCoordinate> _getTileCoordinates(LatLngBounds bounds, int zoom) {
    final tiles = <TileCoordinate>[];

    final nwTile = _latLngToTile(bounds.northWest, zoom);
    final seTile = _latLngToTile(bounds.southEast, zoom);

    for (int x = nwTile.x; x <= seTile.x; x++) {
      for (int y = nwTile.y; y <= seTile.y; y++) {
        tiles.add(TileCoordinate(x, y));
      }
    }

    return tiles;
  }

  /// Convert lat/lng to tile coordinates
  TileCoordinate _latLngToTile(LatLng latLng, int zoom) {
    final scale = math.pow(2, zoom).toDouble();
    final worldCoordX = (latLng.longitude + 180) / 360;
    final latRad = latLng.latitude * math.pi / 180;
    final worldCoordY = (1 - math.log(math.tan(latRad) + 1 / math.cos(latRad)) / math.pi) / 2;

    return TileCoordinate(
      (worldCoordX * scale).floor(),
      (worldCoordY * scale).floor(),
    );
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
            title: const Text('Karten herunterladen (Windows)'),
            subtitle: _isDownloading
                ? Text('Download läuft... $_downloadedTiles Kacheln')
                : _isCheckingTiles
                ? const Text('Prüfe Aufnahmepunkte...')
                : _missingTilesCount == -1
                ? const Text('Bereit. Kein Proxy, speichert im FMTC Cache.')
                : const Text('Keine Aufnahmepunkte gefunden.'),
            onTap: (_isDownloading || _isCheckingTiles) ? null : _downloadMapTilesFromRecordsBBox,
            enabled: !_isDownloading && !_isCheckingTiles,
          ),
          if (_isDownloading)
            Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                children: [
                  LinearProgressIndicator(
                    value: _totalTiles > 0 ? _downloadedTiles / _totalTiles : null,
                  ),
                  const SizedBox(height: 8),
                  Text(
                    '$_downloadedTiles Kacheln heruntergeladen',
                    style: Theme.of(context).textTheme.bodySmall,
                  ),
                ],
              ),
            ),
        ],
      ),
    );
  }
}

class TileCoordinate {
  final int x, y;
  TileCoordinate(this.x, this.y);

  @override
  String toString() => '($x, $y)';
}
