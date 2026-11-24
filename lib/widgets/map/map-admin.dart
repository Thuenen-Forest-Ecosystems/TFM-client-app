/// Show downloaded map tiles cached on device by list of
library;

import 'package:flutter/material.dart';
import 'package:flutter_map_tile_caching/flutter_map_tile_caching.dart';
import 'package:terrestrial_forest_monitor/l10n/app_localizations.dart';

class MapAdmin extends StatefulWidget {
  const MapAdmin({super.key});

  @override
  State<MapAdmin> createState() => _MapAdminState();
}

class _MapAdminState extends State<MapAdmin> {
  List<String> _storeList = [
    //'wms_dtk25__',
    'wms_dop__',
    'OpenCycleMap',
  ];

  Map<String, int> _storeTileCounts = {};
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadStoreStats();
  }

  Future<void> _loadStoreStats() async {
    setState(() {
      _isLoading = true;
    });

    final Map<String, int> tileCounts = {};

    for (final storeName in _storeList) {
      try {
        final store = FMTCStore(storeName);
        final stats = await store.stats.length;
        tileCounts[storeName] = stats;
      } catch (e) {
        tileCounts[storeName] = 0;
      }
    }

    if (mounted) {
      setState(() {
        _storeTileCounts = tileCounts;
        _isLoading = false;
      });
    }
  }

  Future<void> _deleteStore(String storeName) async {
    final l10n = AppLocalizations.of(context)!;
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(l10n.mapAdminDeleteCache),
        content: Text(l10n.mapAdminDeleteConfirm(storeName)),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: Text(l10n.mapAdminCancel),
          ),
          ElevatedButton(
            onPressed: () => Navigator.of(context).pop(true),
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
            child: Text(l10n.mapAdminDelete),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      try {
        final store = FMTCStore(storeName);
        await store.manage.delete();

        if (mounted) {
          ScaffoldMessenger.of(
            context,
          ).showSnackBar(SnackBar(content: Text(l10n.mapAdminCacheDeleted(storeName))));
          _loadStoreStats();
        }
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(
            context,
          ).showSnackBar(SnackBar(content: Text(l10n.mapAdminDeleteError(e.toString()))));
        }
      }
    }
  }

  String _getStorageSize(int tileCount) {
    // Rough estimate: average tile is ~20KB
    final sizeInMB = (tileCount * 20) / 1024;
    if (sizeInMB < 1) {
      return '${(sizeInMB * 1024).toStringAsFixed(0)} KB';
    } else if (sizeInMB < 1024) {
      return '${sizeInMB.toStringAsFixed(1)} MB';
    } else {
      return '${(sizeInMB / 1024).toStringAsFixed(2)} GB';
    }
  }

  String _getStoreDisplayName(String storeName) {
    switch (storeName) {
      case 'wms_dop__':
        return AppLocalizations.of(context)!.mapAdminStoreAerial;
      case 'wms_dtk25__':
        return 'DTK25';
      case 'opentopomap':
        return 'OpenTopoMap';
      case 'openstreetmap':
        return 'OpenStreetMap';
      case 'OpenCycleMap':
        return 'Open Cycle Map';
      case 'esri_satellite':
        return 'ESRI Satellite';
      default:
        return storeName;
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    if (_isLoading) {
      return const Padding(
        padding: EdgeInsets.all(16.0),
        child: Center(child: CircularProgressIndicator()),
      );
    }

    return Column(
      mainAxisSize: MainAxisSize.min,
      children: _storeList.map((storeName) {
        final tileCount = _storeTileCounts[storeName] ?? 0;
        final displayName = _getStoreDisplayName(storeName);
        final storageSize = _getStorageSize(tileCount);

        return ListTile(
          title: Text(displayName),
          subtitle: Text(
            tileCount > 0 ? l10n.mapAdminTileCount(tileCount, storageSize) : l10n.mapAdminNoCache,
          ),
          trailing: tileCount > 0
              ? IconButton(
                  icon: const Icon(Icons.delete),
                  onPressed: () => _deleteStore(storeName),
                  tooltip: l10n.mapAdminDeleteCache,
                )
              : null,
        );
      }).toList(),
    );
  }
}
