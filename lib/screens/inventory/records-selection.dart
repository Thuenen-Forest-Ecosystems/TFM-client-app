import 'dart:async';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:beamer/beamer.dart';
import 'package:terrestrial_forest_monitor/repositories/records_repository.dart';
import 'package:terrestrial_forest_monitor/widgets/cluster/order-cluster-by.dart';
import 'package:terrestrial_forest_monitor/providers/records_list_provider.dart';
import 'package:terrestrial_forest_monitor/providers/gps-position.dart';
import 'package:terrestrial_forest_monitor/providers/map_controller_provider.dart';
import 'package:terrestrial_forest_monitor/widgets/records/record_card.dart';
import 'package:terrestrial_forest_monitor/widgets/records/filter_dialog.dart';
import 'package:flutter_map/flutter_map.dart' show LatLngBounds;
import 'package:latlong2/latlong.dart';
import 'package:geolocator/geolocator.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'dart:math' as math;

class RecordsSelection extends StatefulWidget {
  final String intervalName;
  const RecordsSelection({super.key, required this.intervalName});

  @override
  State<RecordsSelection> createState() => _RecordsSelectionState();
}

class _RecordsSelectionState extends State<RecordsSelection> {
  ClusterOrderBy _orderBy = ClusterOrderBy.distance;
  Position? _currentPosition;

  // Display variables
  final List<Map<String, dynamic>> _allRecords = []; // All loaded records
  final List<Map<String, dynamic>> _displayedRecords = []; // Records currently displayed
  final int _displayPageSize = 50; // Show 50 records at a time
  bool _isLoading = false;
  ScrollController? _scrollController;
  bool _createdOwnController = false;

  // Search functionality
  bool _isSearching = false;
  final TextEditingController _searchController = TextEditingController();
  String _searchQuery = '';

  // Filter settings
  bool _showCompleted = true;
  bool _filterByMapExtent = false;

  // Pinned records
  final Set<String> _pinnedRecordIds = {};
  List<Record> _pinnedRecords = [];

  @override
  void initState() {
    super.initState();
    _loadPinnedRecords();
    _getCurrentLocation();
    // Load data and start watching for changes
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _loadInitialData();
      // Listen to map controller provider for bounds changes
      _listenToMapBoundsChanges();
    });
  }

  void _listenToMapBoundsChanges() {
    try {
      final mapControllerProvider = context.read<MapControllerProvider>();
      mapControllerProvider.addListener(_onMapBoundsChanged);
    } catch (e) {
      debugPrint('Error adding map bounds listener: $e');
    }
  }

  DateTime? _lastMapBoundsTimestamp;

  void _onMapBoundsChanged() {
    if (!mounted || !_filterByMapExtent) return;

    try {
      final mapControllerProvider = context.read<MapControllerProvider>();
      final timestamp = mapControllerProvider.mapBoundsTimestamp;

      // Only reload if timestamp changed (new bounds update)
      if (timestamp != null && timestamp != _lastMapBoundsTimestamp) {
        _lastMapBoundsTimestamp = timestamp;
        _loadInitialData();
      }
    } catch (e) {
      debugPrint('Error handling map bounds change: $e');
    }
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    // Get the scroll controller from the parent DraggableScrollableSheet
    if (_scrollController == null) {
      try {
        _scrollController = context.read<ScrollController>();
        _scrollController!.addListener(_onScroll);
      } catch (e) {
        // If Provider is not available, create our own controller
        _scrollController = ScrollController();
        _scrollController!.addListener(_onScroll);
        _createdOwnController = true;
      }
    }
  }

  void _onScroll() {
    if (_scrollController == null) return;
    if (_scrollController!.position.pixels >= _scrollController!.position.maxScrollExtent - 200) {
      // Display more when 200 pixels from bottom
      _displayMoreRecords();
    }
  }

  Future<void> _loadInitialData() async {
    if (_isLoading) return;

    setState(() {
      _isLoading = true;
      _allRecords.clear();
      _displayedRecords.clear();
    });

    try {
      // Load records from provider cache (populated by start.dart)
      final provider = context.read<RecordsListProvider>();

      // Add listener for real-time updates
      provider.addListener(_onProviderChanged);

      final cachedData = provider.getCachedRecords('all', ClusterOrderBy.clusterName);

      if (cachedData != null) {
        final records = cachedData.map((item) => item['record'] as Record).toList();
        print('RecordsSelection: Loaded ${records.length} records from provider cache');

        // Process records: filter by search, sort, and add metadata
        final processedRecords = await _processRecords(records);

        if (mounted) {
          setState(() {
            _allRecords.clear();
            _allRecords.addAll(processedRecords);
            _displayedRecords.clear();
            _isLoading = false;
          });

          // Update pinned records list
          _updatePinnedRecordsList();

          // Display first batch
          _displayMoreRecords();
        }
      } else {
        print('RecordsSelection: No cached records available yet');
        if (mounted) {
          setState(() {
            _isLoading = false;
          });
        }
      }
    } catch (e) {
      print('RecordsSelection: Error loading from cache: $e');
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  Future<void> _loadPinnedRecords() async {
    final prefs = await SharedPreferences.getInstance();
    final pinnedIds = prefs.getStringList('pinned_records') ?? [];
    setState(() {
      _pinnedRecordIds.clear();
      _pinnedRecordIds.addAll(pinnedIds);
    });
  }

  Future<void> _togglePinRecord(Record record) async {
    final recordKey = '${record.clusterId}_${record.plotId}';

    setState(() {
      if (_pinnedRecordIds.contains(recordKey)) {
        _pinnedRecordIds.remove(recordKey);
        _pinnedRecords.removeWhere((r) => '${r.clusterId}_${r.plotId}' == recordKey);
      } else {
        _pinnedRecordIds.add(recordKey);
        _pinnedRecords.add(record);
      }
    });

    // Persist to shared preferences
    final prefs = await SharedPreferences.getInstance();
    await prefs.setStringList('pinned_records', _pinnedRecordIds.toList());
  }

  void _updatePinnedRecordsList() {
    // Update pinned records list from all records
    _pinnedRecords.clear();
    for (final item in _allRecords) {
      final record = item['record'] as Record;
      final recordKey = '${record.clusterId}_${record.plotId}';
      if (_pinnedRecordIds.contains(recordKey)) {
        _pinnedRecords.add(record);
      }
    }
  }

  void _onProviderChanged() {
    if (!mounted) return;
    // Reload data when provider updates (real-time changes from start.dart)
    _loadInitialData();
  }

  // Process records: filter, sort, and add metadata
  Future<List<Map<String, dynamic>>> _processRecords(List<Record> records) async {
    // Filter by search query if provided
    if (_searchQuery.isNotEmpty) {
      records = records.where((record) {
        return record.clusterName.toLowerCase().contains(_searchQuery.toLowerCase());
      }).toList();
    }

    // Filter by map extent if enabled
    if (_filterByMapExtent) {
      try {
        final mapControllerProvider = context.read<MapControllerProvider>();
        final bounds = mapControllerProvider.currentMapBounds;

        if (bounds != null) {
          records = records.where((record) {
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
        }
      } catch (e) {
        debugPrint('Error filtering by map extent: $e');
      }
    }

    // Filter by completion status
    if (!_showCompleted) {
      records = records.where((record) {
        final completedAtTroop = record.completedAtTroop;
        return completedAtTroop == null || completedAtTroop.toString().isEmpty;
      }).toList();
    }

    // Sort records based on order preference
    switch (_orderBy) {
      case ClusterOrderBy.distance:
        if (_currentPosition != null) {
          // Sort by distance
          records.sort((a, b) {
            final coordsA = a.getCoordinates();
            final coordsB = b.getCoordinates();

            // Records without coordinates go to the end
            if (coordsA == null && coordsB == null) return 0;
            if (coordsA == null) return 1;
            if (coordsB == null) return -1;

            final distA = _calculateDistance(
              _currentPosition!.latitude,
              _currentPosition!.longitude,
              coordsA['latitude']!,
              coordsA['longitude']!,
            );
            final distB = _calculateDistance(
              _currentPosition!.latitude,
              _currentPosition!.longitude,
              coordsB['latitude']!,
              coordsB['longitude']!,
            );

            return distA.compareTo(distB);
          });
        }

      case ClusterOrderBy.updatedAt:
        records.sort((a, b) {
          final dateA = a.properties['updated_at'];
          final dateB = b.properties['updated_at'];
          if (dateA == null && dateB == null) return 0;
          if (dateA == null) return 1;
          if (dateB == null) return -1;
          return DateTime.parse(dateB.toString()).compareTo(DateTime.parse(dateA.toString()));
        });

      case ClusterOrderBy.clusterName:
        records.sort((a, b) {
          final comparison = a.clusterName.compareTo(b.clusterName);
          if (comparison != 0) return comparison;
          return a.plotName.compareTo(b.plotName);
        });
    }

    // Add metadata to all records
    return records.map((record) {
      String? metadata;

      switch (_orderBy) {
        case ClusterOrderBy.distance:
          if (_currentPosition != null) {
            final coords = record.getCoordinates();
            if (coords != null) {
              final distance = _calculateDistance(
                _currentPosition!.latitude,
                _currentPosition!.longitude,
                coords['latitude']!,
                coords['longitude']!,
              );
              metadata = distance < 1.0
                  ? '${(distance * 1000).toStringAsFixed(0)} m'
                  : '${distance.toStringAsFixed(1)} km';
            }
          }

        case ClusterOrderBy.updatedAt:
          metadata = _formatDate(record.properties['updated_at']);

        case ClusterOrderBy.clusterName:
          // No metadata for name ordering
          break;
      }

      return {'record': record, 'metadata': metadata};
    }).toList();
  }

  void _displayMoreRecords() {
    if (_displayedRecords.length >= _allRecords.length) {
      // Already displaying all records
      return;
    }

    setState(() {
      final nextBatchEnd = (_displayedRecords.length + _displayPageSize).clamp(
        0,
        _allRecords.length,
      );
      _displayedRecords.addAll(_allRecords.sublist(_displayedRecords.length, nextBatchEnd));
    });
  }

  Future<void> _getCurrentLocation() async {
    // Check if we have cached location first
    final provider = context.read<RecordsListProvider>();
    if (provider.currentPosition != null) {
      if (mounted) {
        setState(() {
          _currentPosition = provider.currentPosition;
        });
      }
      return;
    }

    try {
      // Get position from GPS provider (Bluetooth GPS or internal GPS)
      final gpsProvider = context.read<GpsPositionProvider>();
      final lastPosition = gpsProvider.lastPosition;

      if (lastPosition != null) {
        if (mounted) {
          setState(() {
            _currentPosition = lastPosition;
          });

          // Cache the position after build completes
          WidgetsBinding.instance.addPostFrameCallback((_) {
            if (mounted) {
              provider.setCurrentPosition(lastPosition);
            }
          });

          // Reload data with distance ordering if we just got GPS position
          if (_orderBy == ClusterOrderBy.distance && _allRecords.isEmpty) {
            _loadInitialData();
          }
        }
      }
    } catch (e) {
      print('Error getting GPS position: $e');
    }
  }

  double _calculateDistance(double lat1, double lon1, double lat2, double lon2) {
    const earthRadiusKm = 6371.0;
    final dLat = _toRadians(lat2 - lat1);
    final dLon = _toRadians(lon2 - lon1);
    final a =
        math.sin(dLat / 2) * math.sin(dLat / 2) +
        math.cos(_toRadians(lat1)) *
            math.cos(_toRadians(lat2)) *
            math.sin(dLon / 2) *
            math.sin(dLon / 2);
    final c = 2 * math.atan2(math.sqrt(a), math.sqrt(1 - a));
    return earthRadiusKm * c;
  }

  double _toRadians(double degrees) {
    return degrees * math.pi / 180.0;
  }

  String? _formatDate(dynamic date) {
    if (date == null) return null;
    try {
      final DateTime dt = DateTime.parse(date.toString());
      return '${dt.day}/${dt.month}/${dt.year}';
    } catch (e) {
      return null;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: LayoutBuilder(
        builder: (context, constraints) {
          // Calculate available height for content
          final availableHeight = constraints.maxHeight;
          // Fixed height for pinned records section
          const pinnedRecordsHeight = 130.0;
          // Only show pinned records if there's enough space
          final showPinnedRecords =
              _pinnedRecords.isNotEmpty && (availableHeight - 71 - 50) >= pinnedRecordsHeight;

          return Column(
            children: [
              // Custom AppBar
              ListTile(
                title: _isSearching
                    ? TextField(
                        controller: _searchController,
                        autofocus: true,
                        decoration: const InputDecoration(
                          labelText: 'Suche Traktnummer...',
                          filled: true,
                          isDense: true,
                          border: const OutlineInputBorder(
                            borderRadius: BorderRadius.all(Radius.circular(50)),
                          ),
                        ),
                        keyboardType: TextInputType.numberWithOptions(
                          signed: false,
                          decimal: false,
                        ),
                        onChanged: (value) {
                          setState(() {
                            _searchQuery = value;
                          });
                          _loadInitialData();
                        },
                      )
                    : Container(
                        padding: const EdgeInsets.only(top: 10, bottom: 9),
                        child: const Text(
                          'Ecken',
                          style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
                        ),
                      ),
                trailing: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    IconButton(
                      icon: Icon(_isSearching ? Icons.close : Icons.search),
                      onPressed: () {
                        setState(() {
                          _isSearching = !_isSearching;
                          if (!_isSearching) {
                            _searchController.clear();
                            _searchQuery = '';
                            _loadInitialData();
                          }
                        });
                      },
                    ),
                    //IconButton(onPressed: _openFilterDialog, icon: Icon(Icons.filter_list)),
                    //IconButton(onPressed: _addRecord, icon: const Icon(Icons.add)),
                  ],
                ),
              ),
              // Pinned records horizontal scroll
              if (showPinnedRecords)
                SizedBox(
                  height: pinnedRecordsHeight,
                  child: ListView.builder(
                    scrollDirection: Axis.horizontal,
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 5),
                    itemCount: _pinnedRecords.length,
                    itemBuilder: (context, index) {
                      final record = _pinnedRecords[index];

                      // Calculate distance if we have position
                      String? distanceText;
                      if (_currentPosition != null) {
                        final coords = record.getCoordinates();
                        if (coords != null) {
                          final distance = _calculateDistance(
                            _currentPosition!.latitude,
                            _currentPosition!.longitude,
                            coords['latitude']!,
                            coords['longitude']!,
                          );
                          distanceText = distance < 1.0
                              ? '${(distance * 1000).toStringAsFixed(0)} m'
                              : '${distance.toStringAsFixed(1)} km';
                        }
                      }

                      return Container(
                        width: 280,
                        margin: const EdgeInsets.only(right: 8),
                        child: RecordCard(
                          record: record,
                          distanceText: distanceText,
                          onFocusOnMap: () => _focusRecordOnMap(record),
                          isPinned: true,
                          onPinToggle: () => _togglePinRecord(record),
                          isDense: true,
                        ),
                      );
                    },
                  ),
                ),
              if (showPinnedRecords) const Divider(height: 1),
              // Body
              Expanded(
                child: _isLoading
                    ? const Center(child: CircularProgressIndicator())
                    : _displayedRecords.isEmpty
                    ? Column(
                        mainAxisAlignment: MainAxisAlignment.start,
                        children: [
                          const SizedBox(height: 16),
                          Icon(Icons.inbox, color: Colors.grey[400]),
                          const SizedBox(height: 8),
                          Text(
                            'Dir wurde bisher noch keine Ecke zugewiesen.',
                            style: TextStyle(color: Colors.grey[600]),
                          ),
                        ],
                      )
                    : ListView.builder(
                        controller: _scrollController,
                        padding: const EdgeInsets.all(16),
                        itemCount:
                            _displayedRecords.length +
                            (_displayedRecords.length < _allRecords.length ? 1 : 0),
                        itemBuilder: (context, index) {
                          // Show loading indicator at the end if more records available
                          if (index == _displayedRecords.length) {
                            return Center(
                              child: Padding(
                                padding: const EdgeInsets.all(16.0),
                                child: Text(
                                  'Showing ${_displayedRecords.length} of ${_allRecords.length} records',
                                  style: TextStyle(color: Colors.grey[600]),
                                ),
                              ),
                            );
                          }

                          final item = _displayedRecords[index];
                          final record = item['record'] as Record;
                          final metadata = item['metadata'] as String?;
                          final recordKey = '${record.clusterId}_${record.plotId}';

                          // Calculate distance if not already in metadata
                          String? distanceText = metadata;
                          if (distanceText == null && _currentPosition != null) {
                            final coords = record.getCoordinates();
                            if (coords != null) {
                              final distance = _calculateDistance(
                                _currentPosition!.latitude,
                                _currentPosition!.longitude,
                                coords['latitude']!,
                                coords['longitude']!,
                              );
                              distanceText = distance < 1.0
                                  ? '${(distance * 1000).toStringAsFixed(0)} m'
                                  : '${distance.toStringAsFixed(1)} km';
                            }
                          }

                          return RecordCard(
                            record: record,
                            distanceText: distanceText,
                            onFocusOnMap: () => _focusRecordOnMap(record),
                            isPinned: _pinnedRecordIds.contains(recordKey),
                            onPinToggle: () => _togglePinRecord(record),
                            isDense: false,
                          );
                        },
                      ),
              ),
            ],
          );
        },
      ),
    );
  }

  void _addRecord() {
    // Navigate to properties-edit with NEW placeholders
    // The PropertiesEdit screen will detect this and show a cluster/plot input dialog
    Beamer.of(context).beamToNamed('/properties-edit/NEW/NEW');
  }

  void _focusRecordOnMap(Record record) {
    final coords = record.getCoordinates();
    if (coords == null) {
      debugPrint('No valid coordinates found for record');
      return;
    }

    final lat = coords['latitude'];
    final lng = coords['longitude'];

    if (lat == null || lng == null) {
      debugPrint('Invalid coordinates for record');
      return;
    }

    // Create bounds with padding around the single point
    const padding = 0.001; // Small padding for single point
    final bounds = LatLngBounds(
      LatLng(lat - padding, lng - padding),
      LatLng(lat + padding, lng + padding),
    );

    // Set focus bounds in provider (MapWidget will respond)
    final mapControllerProvider = context.read<MapControllerProvider>();
    mapControllerProvider.setFocusBounds(bounds);

    debugPrint('Focus bounds set for record at $lat, $lng');
  }

  void _openFilterDialog() {
    showDialog(
      context: context,
      builder: (context) => RecordsFilterDialog(
        currentOrderBy: _orderBy,
        showCompleted: _showCompleted,
        filterByMapExtent: _filterByMapExtent,
        onOrderByChanged: (newOrderBy) {
          setState(() {
            _orderBy = newOrderBy;
          });
          _loadInitialData();
        },
        onShowCompletedChanged: (value) {
          setState(() {
            _showCompleted = value;
          });
          _loadInitialData();
        },
        onFilterByMapExtentChanged: (value) {
          setState(() {
            _filterByMapExtent = value;
          });
          _loadInitialData();
        },
      ),
    );
  }

  @override
  void dispose() {
    _searchController.dispose();
    _scrollController?.removeListener(_onScroll);

    // Remove provider listener
    try {
      final provider = context.read<RecordsListProvider>();
      provider.removeListener(_onProviderChanged);
    } catch (e) {
      print('Error removing provider listener: $e');
    }

    // Remove map controller provider listener
    try {
      final mapControllerProvider = context.read<MapControllerProvider>();
      mapControllerProvider.removeListener(_onMapBoundsChanged);
    } catch (e) {
      print('Error removing map bounds listener: $e');
    }

    // Only dispose if we created the controller ourselves
    if (_createdOwnController && _scrollController != null) {
      _scrollController!.dispose();
    }
    super.dispose();
  }
}
