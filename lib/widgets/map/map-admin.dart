/// Show downloaded map tiles cached on device by list of

import 'package:flutter/material.dart';
import 'package:flutter_map_tile_caching/flutter_map_tile_caching.dart';

class MapAdmin extends StatefulWidget {
  const MapAdmin({super.key});

  @override
  State<MapAdmin> createState() => _MapAdminState();
}

class _MapAdminState extends State<MapAdmin> {
  List<String> _storeList = [
    //'wms_dtk25__',
    'wms_dop__',
    //'openstreetmap',
    'opentopomap',
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
        print('Error loading stats for $storeName: $e');
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
    final confirmed = await showDialog<bool>(
      context: context,
      builder:
          (context) => AlertDialog(
            title: const Text('Cache löschen'),
            content: Text('Möchten Sie alle Kacheln für "$storeName" löschen?'),
            actions: [
              TextButton(
                onPressed: () => Navigator.of(context).pop(false),
                child: const Text('Abbrechen'),
              ),
              ElevatedButton(
                onPressed: () => Navigator.of(context).pop(true),
                style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
                child: const Text('Löschen'),
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
          ).showSnackBar(SnackBar(content: Text('Cache für "$storeName" gelöscht')));
          _loadStoreStats();
        }
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(
            context,
          ).showSnackBar(SnackBar(content: Text('Fehler beim Löschen: $e')));
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
        return 'Luftbilder (DOP)';
      case 'wms_dtk25__':
        return 'DTK25';
      case 'opentopomap':
        return 'OpenTopoMap';
      case 'openstreetmap':
        return 'OpenStreetMap';
      default:
        return storeName;
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return const Padding(
        padding: EdgeInsets.all(16.0),
        child: Center(child: CircularProgressIndicator()),
      );
    }

    return Column(
      mainAxisSize: MainAxisSize.min,
      children:
          _storeList.map((storeName) {
            final tileCount = _storeTileCounts[storeName] ?? 0;
            final displayName = _getStoreDisplayName(storeName);
            final storageSize = _getStorageSize(tileCount);

            return ListTile(
              title: Text(displayName),
              subtitle: Text(
                tileCount > 0 ? '$tileCount Kacheln (~$storageSize)' : 'Kein Cache vorhanden',
              ),
              trailing:
                  tileCount > 0
                      ? IconButton(
                        icon: const Icon(Icons.delete),
                        onPressed: () => _deleteStore(storeName),
                        tooltip: 'Cache löschen',
                      )
                      : null,
            );
          }).toList(),
    );
  }
}
