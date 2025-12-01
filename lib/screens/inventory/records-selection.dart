import 'package:flutter/material.dart';
import 'package:beamer/beamer.dart';
import 'package:provider/provider.dart';
import 'package:terrestrial_forest_monitor/repositories/records_repository.dart';
import 'package:terrestrial_forest_monitor/widgets/cluster/order-cluster-by.dart';
import 'package:terrestrial_forest_monitor/providers/records_list_provider.dart';
import 'package:terrestrial_forest_monitor/providers/gps-position.dart';
import 'package:terrestrial_forest_monitor/providers/map_controller_provider.dart';
import 'package:terrestrial_forest_monitor/widgets/records/record_card.dart';
import 'package:flutter_map/flutter_map.dart' show LatLngBounds;
import 'package:latlong2/latlong.dart';
import 'package:geolocator/geolocator.dart';
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
  bool _isLoadingLocation = false;

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

  @override
  void initState() {
    super.initState();
    _getCurrentLocation();
    // Load data
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _loadInitialData();
    });
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
      final provider = context.read<RecordsListProvider>();

      // First try to get cached data (preloaded in start.dart)
      final cachedRecords = provider.getCachedRecords('all', ClusterOrderBy.clusterName);

      List<Map<String, dynamic>> records;

      if (cachedRecords != null && cachedRecords.isNotEmpty) {
        print('RecordsSelection: Using ${cachedRecords.length} cached records from start.dart');
        // Apply filtering, sorting, and metadata to cached records
        records = await _processRecords(
          cachedRecords.map((item) => item['record'] as Record).toList(),
        );
      } else {
        print('RecordsSelection: No cache found, loading fresh data');
        records = await _fetchAllRecordsWithMetadata();
      }

      if (mounted) {
        setState(() {
          _allRecords.addAll(records);
          _isLoading = false;
        });

        // Display first batch
        _displayMoreRecords();

        // Update cache with processed data
        provider.cacheRecords(widget.intervalName, _orderBy, _allRecords, 0, false);
      }
    } catch (e) {
      print('Error loading data: $e');
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  // Process records: filter, sort, and add metadata
  Future<List<Map<String, dynamic>>> _processRecords(List<Record> records) async {
    // Filter by search query if provided
    if (_searchQuery.isNotEmpty) {
      records = records.where((record) {
        return record.clusterName.toLowerCase().contains(_searchQuery.toLowerCase());
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
        break;

      case ClusterOrderBy.updatedAt:
        records.sort((a, b) {
          final dateA = a.properties['updated_at'];
          final dateB = b.properties['updated_at'];
          if (dateA == null && dateB == null) return 0;
          if (dateA == null) return 1;
          if (dateB == null) return -1;
          return DateTime.parse(dateB.toString()).compareTo(DateTime.parse(dateA.toString()));
        });
        break;

      case ClusterOrderBy.clusterName:
        records.sort((a, b) {
          final comparison = a.clusterName.compareTo(b.clusterName);
          if (comparison != 0) return comparison;
          return a.plotName.compareTo(b.plotName);
        });
        break;
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
              metadata = '${distance.toStringAsFixed(1)} km';
            }
          }
          break;

        case ClusterOrderBy.updatedAt:
          metadata = _formatDate(record.properties['updated_at']);
          break;

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

    if (mounted) {
      setState(() {
        _isLoadingLocation = true;
      });
    }

    try {
      // Get position from GPS provider (Bluetooth GPS or internal GPS)
      final gpsProvider = context.read<GpsPositionProvider>();
      final lastPosition = gpsProvider.lastPosition;

      if (lastPosition != null) {
        if (mounted) {
          setState(() {
            _currentPosition = lastPosition;
            _isLoadingLocation = false;
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
      } else {
        // No GPS position available yet
        if (mounted) {
          setState(() {
            _isLoadingLocation = false;
          });
        }
      }
    } catch (e) {
      print('Error getting GPS position: $e');
      if (mounted) {
        setState(() {
          _isLoadingLocation = false;
        });
      }
    }
  }

  Future<List<Map<String, dynamic>>> _fetchAllRecordsWithMetadata() async {
    // Get all records from repository
    List<Record> records = await RecordsRepository().getAllRecords();

    // Filter by search query if provided
    if (_searchQuery.isNotEmpty) {
      records = records.where((record) {
        return record.clusterName.toLowerCase().contains(_searchQuery.toLowerCase());
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
        break;

      case ClusterOrderBy.updatedAt:
        records.sort((a, b) {
          final dateA = a.properties['updated_at'];
          final dateB = b.properties['updated_at'];
          if (dateA == null && dateB == null) return 0;
          if (dateA == null) return 1;
          if (dateB == null) return -1;
          return DateTime.parse(dateB.toString()).compareTo(DateTime.parse(dateA.toString()));
        });
        break;

      case ClusterOrderBy.clusterName:
        records.sort((a, b) {
          final comparison = a.clusterName.compareTo(b.clusterName);
          if (comparison != 0) return comparison;
          return a.plotName.compareTo(b.plotName);
        });
        break;
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
              metadata = '${distance.toStringAsFixed(1)} km';
            }
          }
          break;

        case ClusterOrderBy.updatedAt:
          metadata = _formatDate(record.properties['updated_at']);
          break;

        case ClusterOrderBy.clusterName:
          // No metadata for name ordering
          break;
      }

      return {'record': record, 'metadata': metadata};
    }).toList();
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
      body: Column(
        children: [
          // Custom AppBar
          ListTile(
            title: _isSearching
                ? TextField(
                    controller: _searchController,
                    autofocus: true,
                    decoration: const InputDecoration(
                      hintText: 'Search by cluster name...',
                      border: InputBorder.none,
                    ),
                    onChanged: (value) {
                      setState(() {
                        _searchQuery = value;
                      });
                      _loadInitialData();
                    },
                  )
                : const Text('Ecken', style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
            trailing: IconButton(
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
          ),
          // Body
          Expanded(
            child: _isLoading
                ? const Center(child: CircularProgressIndicator())
                : _displayedRecords.isEmpty
                ? const Center(child: Text('No records found'))
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
                          distanceText = '${distance.toStringAsFixed(1)} km';
                        }
                      }

                      return RecordCard(
                        record: record,
                        distanceText: distanceText,
                        onFocusOnMap: () => _focusRecordOnMap(record),
                      );
                    },
                  ),
          ),
        ],
      ),
    );
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

  @override
  void dispose() {
    _searchController.dispose();
    _scrollController?.removeListener(_onScroll);
    // Only dispose if we created the controller ourselves
    if (_createdOwnController && _scrollController != null) {
      _scrollController!.dispose();
    }
    super.dispose();
  }
}
