import 'dart:async';

import 'package:flutter/material.dart';
import 'package:terrestrial_forest_monitor/repositories/records_repository.dart';
import 'package:terrestrial_forest_monitor/services/map_tiles_download_runner.dart';
import 'package:terrestrial_forest_monitor/services/map_tiles_download_service.dart';

class MapTilesDownload extends StatefulWidget {
  const MapTilesDownload({super.key});

  @override
  State<MapTilesDownload> createState() => _MapTilesDownloadState();
}

class _MapTilesDownloadState extends State<MapTilesDownload> {
  final MapTilesDownloadController _controller = MapTilesDownloadController.instance;
  final Map<String, Map<String, dynamic>> basemapsToSelectFrom = offlineBasemaps();
  StreamSubscription<MapTilesDownloadMessage>? _messagesSubscription;
  bool _isCheckingTiles = true;
  int _missingTilesCount = 0;
  String? _checkError;

  @override
  void initState() {
    super.initState();
    _controller.addListener(_onControllerChanged);
    _messagesSubscription = _controller.messages.listen(
      (m) => _showMessage(m.text, important: m.important),
    );
    // Picks up a download still running in the background service
    _controller.attach();
    _checkMissingTiles();
  }

  @override
  void dispose() {
    _controller.removeListener(_onControllerChanged);
    _messagesSubscription?.cancel();
    super.dispose();
  }

  void _onControllerChanged() {
    if (mounted) setState(() {});
  }

  /// Important messages (warnings, aborted downloads) stay until dismissed,
  /// the rest disappears after a few seconds.
  void _showMessage(String message, {bool important = false}) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        action: important
            ? SnackBarAction(
                label: 'OK',
                // The fromSwatch color schemes leave the default action color
                // white on the (inverse, white) dark-mode snackbar
                textColor: Theme.of(context).brightness == Brightness.dark
                    ? Colors.green.shade800
                    : Colors.green.shade300,
                onPressed: () {},
              )
            : null,
        persist: important,
      ),
    );
  }

  Future<void> _checkMissingTiles() async {
    if (!mounted) return;

    setState(() {
      _isCheckingTiles = true;
    });

    try {
      final records = await RecordsRepository().getAllRecordsUnfiltered();
      if (!mounted) return;

      // Totals for the current records, paired with the stored progress
      final coordinates = records.map((r) => r.getCoordinates()).whereType<Map<String, double>>();
      await _controller.loadCounts({
        for (final basemap in basemapsToSelectFrom.keys)
          basemap: countBasemapTiles(regionsForBasemap(basemap, coordinates)),
      });
      if (!mounted) return;

      setState(() {
        _missingTilesCount = records.isNotEmpty ? -1 : 0; // -1 = ready to download
        _isCheckingTiles = false;
        _checkError = null;
      });
    } catch (e) {
      if (!mounted) return;

      setState(() {
        _missingTilesCount = 0;
        _isCheckingTiles = false;
        _checkError = e.toString();
      });
    }
  }

  Future<void> _downloadMapTilesForBasemap(String basemapName) async {
    final records = await RecordsRepository().getAllRecordsUnfiltered();
    final regions = regionsForBasemap(
      basemapName,
      records.map((r) => r.getCoordinates()).whereType<Map<String, double>>(),
    );

    if (regions.isEmpty) {
      _showMessage('Keine Aufnahmepunkte gefunden. Bitte laden Sie zuerst Daten.');
      return;
    }

    await _controller.start(basemapName, regions);
  }

  @override
  Widget build(BuildContext context) {
    // Only allow download if nothing is currently downloading, not checking, and records exist
    final canStartDownload =
        _controller.activeBasemap == null && !_isCheckingTiles && _missingTilesCount == -1;
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 9),
      child: Row(
        children: basemapsToSelectFrom.entries.map((entry) {
          final basemapName = entry.key;
          final config = entry.value;
          final title = config['title'] as String? ?? basemapName;

          final isDownloading = _controller.activeBasemap == basemapName;
          final notice = _controller.notices[basemapName];
          final count = _controller.counts[basemapName];
          final hasCount = count != null && count.total > 0;
          final progress = hasCount ? count.done / count.total : 0.0;
          final isCompleted = hasCount && count.done >= count.total;
          final isPartial = hasCount && count.done > 0 && !isCompleted;
          final countText = hasCount
              ? '${formatTileCount(count.done)} / ${formatTileCount(count.total)} Kacheln'
              : null;

          return Card(
            margin: const EdgeInsets.only(right: 16, bottom: 16),
            child: Container(
              width: 200,
              padding: const EdgeInsets.all(16),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    title,
                    style: Theme.of(context).textTheme.titleSmall,
                    textAlign: TextAlign.center,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                  if (countText != null && !_isCheckingTiles) ...[
                    const SizedBox(height: 4),
                    Text(
                      countText,
                      style: Theme.of(context).textTheme.bodySmall,
                      textAlign: TextAlign.center,
                    ),
                  ],
                  if (isDownloading) ...[
                    const SizedBox(height: 8),
                    LinearProgressIndicator(value: progress > 0 ? progress : null),
                    const SizedBox(height: 8),
                    Text(
                      '${(progress * 100).toStringAsFixed(1)} %',
                      style: Theme.of(context).textTheme.bodySmall,
                    ),
                    if (_controller.statusText != null) ...[
                      const SizedBox(height: 4),
                      Text(
                        _controller.statusText!,
                        style: Theme.of(context).textTheme.bodySmall,
                        textAlign: TextAlign.center,
                      ),
                    ],
                    IconButton(
                      icon: const Icon(Icons.cancel),
                      onPressed: _controller.cancel,
                      tooltip: 'Abbrechen',
                    ),
                  ] else if (_isCheckingTiles) ...[
                    const SizedBox(height: 16),
                    const SizedBox(
                      width: 24,
                      height: 24,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    ),
                    const SizedBox(height: 4),
                    Text('Prüfe Daten...', style: Theme.of(context).textTheme.bodySmall),
                  ] else if (_checkError != null) ...[
                    const SizedBox(height: 8),
                    Text(
                      'Fehler beim Laden',
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(color: Colors.red),
                    ),
                    TextButton(
                      onPressed: _checkMissingTiles,
                      child: const Text('Erneut versuchen'),
                    ),
                  ] else if (_missingTilesCount == 0) ...[
                    const SizedBox(height: 8),
                    Text(
                      'Keine Aufnahmepunkte vorhanden.\nBitte zuerst Daten synchronisieren.',
                      style: Theme.of(context).textTheme.bodySmall,
                      textAlign: TextAlign.center,
                    ),
                    TextButton(onPressed: _checkMissingTiles, child: const Text('Erneut prüfen')),
                  ] else if (isCompleted) ...[
                    const SizedBox(height: 16),
                    const Text('Vollständig', style: TextStyle(color: Colors.green)),
                  ] else ...[
                    if (notice != null) ...[
                      const SizedBox(height: 8),
                      Text(
                        notice,
                        style: Theme.of(context).textTheme.bodySmall?.copyWith(
                          color: notice == mapTilesInterruptedNotice
                              ? null
                              : Theme.of(context).colorScheme.error,
                        ),
                        textAlign: TextAlign.center,
                      ),
                    ],
                    const SizedBox(height: 16),
                    ElevatedButton(
                      onPressed: canStartDownload
                          ? () => _downloadMapTilesForBasemap(basemapName)
                          : null,
                      child: Text(
                        isPartial || notice == mapTilesInterruptedNotice
                            ? 'Fortsetzen'
                            : 'Download',
                      ),
                    ),
                  ],
                ],
              ),
            ),
          );
        }).toList(),
      ),
    );
  }
}
