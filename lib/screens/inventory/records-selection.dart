import 'package:flutter/material.dart';
import 'package:beamer/beamer.dart';
import 'package:provider/provider.dart';
import 'package:terrestrial_forest_monitor/repositories/records_repository.dart';
import 'package:terrestrial_forest_monitor/widgets/cluster/filter-cluster-by.dart';
import 'package:terrestrial_forest_monitor/widgets/cluster/order-cluster-by.dart';
import 'package:terrestrial_forest_monitor/providers/records_list_provider.dart';
import 'package:terrestrial_forest_monitor/providers/gps-position.dart';
import 'package:geolocator/geolocator.dart';
import 'dart:math' as math;
import 'package:flutter/scheduler.dart';

class RecordsSelection extends StatefulWidget {
  final String intervalName;
  const RecordsSelection({super.key, required this.intervalName});

  @override
  State<RecordsSelection> createState() => _RecordsSelectionState();
}

class _RecordsSelectionState extends State<RecordsSelection> {
  ClusterOrderBy _orderBy = ClusterOrderBy.clusterName;
  ClusterFilter _filter = const ClusterFilter();
  Position? _currentPosition;
  bool _isLoadingLocation = false;

  // Pagination variables
  final List<Map<String, dynamic>> _allRecords = [];
  int _currentPage = 0;
  final int _pageSize = 100;
  bool _isLoadingMore = false;
  bool _hasMoreData = true;
  ScrollController? _scrollController;
  bool _createdOwnController = false;

  @override
  void initState() {
    super.initState();
    _getCurrentLocation();
    // Try to load from cache first
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _loadFromCacheOrFetch();
    });
  }

  void _loadFromCacheOrFetch() {
    final provider = context.read<RecordsListProvider>();
    final cachedRecords = provider.getCachedRecords(widget.intervalName, _orderBy);

    if (cachedRecords != null && cachedRecords.isNotEmpty) {
      // Load from cache
      setState(() {
        _allRecords.clear();
        _allRecords.addAll(cachedRecords);
        _currentPage = provider.getCachedPage(widget.intervalName, _orderBy);
        _hasMoreData = provider.getHasMoreData(widget.intervalName, _orderBy);
        _currentPosition = provider.currentPosition;
      });
    } else {
      // Load fresh data
      _loadInitialData();
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
      // Load more when 200 pixels from bottom
      if (!_isLoadingMore && _hasMoreData) {
        _loadMoreData();
      }
    }
  }

  Future<void> _loadInitialData() async {
    setState(() {
      _allRecords.clear();
      _currentPage = 0;
      _hasMoreData = true;
    });
    await _loadMoreData();

    // Cache the loaded data
    final provider = context.read<RecordsListProvider>();
    provider.cacheRecords(widget.intervalName, _orderBy, _allRecords, _currentPage, _hasMoreData);
  }

  Future<void> _loadMoreData() async {
    if (_isLoadingMore || !_hasMoreData) return;

    setState(() {
      _isLoadingMore = true;
    });

    try {
      final newRecords = await _fetchRecordsWithMetadata(_currentPage * _pageSize, _pageSize);

      if (mounted) {
        setState(() {
          _allRecords.addAll(newRecords);
          _currentPage++;
          _hasMoreData = newRecords.length == _pageSize;
          _isLoadingMore = false;
        });

        // Update cache
        final provider = context.read<RecordsListProvider>();
        provider.cacheRecords(widget.intervalName, _orderBy, _allRecords, _currentPage, _hasMoreData);
      }
    } catch (e) {
      print('Error loading more data: $e');
      if (mounted) {
        setState(() {
          _isLoadingMore = false;
        });
      }
    }
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

          // Cache the position
          provider.setCurrentPosition(lastPosition);
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

  Future<List<Map<String, dynamic>>> _fetchRecordsWithMetadata(int offset, int limit) async {
    List<Record> records;

    switch (_orderBy) {
      case ClusterOrderBy.distance:
        if (_currentPosition == null) {
          // Fallback to name ordering if no location
          records = await RecordsRepository().getRecordsGroupedByCluster(orderBy: 'cluster_name', offset: offset, limit: limit);
        } else {
          // For distance ordering, we need to fetch all and sort in Dart, then paginate
          // This is a limitation of calculating distance in Dart
          final allRecords = await RecordsRepository().getRecordsGroupedByClusterOrderedByDistance(latitude: _currentPosition!.latitude, longitude: _currentPosition!.longitude);
          // Apply filters before pagination
          final filteredRecords = _applyFilters(allRecords);
          // Paginate the sorted results
          records = filteredRecords.skip(offset).take(limit).toList();
        }

        // Calculate distances for display
        if (_currentPosition != null) {
          return records.map((record) {
            final coords = record.getCoordinates();
            if (coords != null) {
              final distance = _calculateDistance(_currentPosition!.latitude, _currentPosition!.longitude, coords['latitude']!, coords['longitude']!);
              return {'record': record, 'metadata': '${distance.toStringAsFixed(1)} km'};
            }
            return {'record': record, 'metadata': null};
          }).toList();
        } else {
          return records.map((r) => {'record': r, 'metadata': null}).toList();
        }

      case ClusterOrderBy.updatedAt:
        records = await RecordsRepository().getRecordsGroupedByCluster(orderBy: 'updated_at DESC', offset: offset, limit: limit);
        records = _applyFilters(records);
        return records.map((r) => {'record': r, 'metadata': _formatDate(r.properties['updated_at'])}).toList();

      case ClusterOrderBy.clusterName:
        records = await RecordsRepository().getRecordsGroupedByCluster(orderBy: 'cluster_name', offset: offset, limit: limit);
        records = _applyFilters(records);
        return records.map((r) => {'record': r, 'metadata': null}).toList();
    }
  }

  List<Record> _applyFilters(List<Record> records) {
    if (!_filter.isActive) return records;

    return records.where((record) {
      // Filter by cluster name
      if (_filter.clusterNameFilter != null && _filter.clusterNameFilter!.isNotEmpty) {
        if (!record.clusterName.toLowerCase().contains(_filter.clusterNameFilter!.toLowerCase())) {
          return false;
        }
      }

      // Filter by plot name
      if (_filter.plotNameFilters.isNotEmpty) {
        if (!_filter.plotNameFilters.contains(record.plotName)) {
          return false;
        }
      }

      return true;
    }).toList();
  }

  double _calculateDistance(double lat1, double lon1, double lat2, double lon2) {
    const earthRadiusKm = 6371.0;
    final dLat = _toRadians(lat2 - lat1);
    final dLon = _toRadians(lon2 - lon1);
    final a = math.sin(dLat / 2) * math.sin(dLat / 2) + math.cos(_toRadians(lat1)) * math.cos(_toRadians(lat2)) * math.sin(dLon / 2) * math.sin(dLon / 2);
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
          Container(
            height: 40.0,
            child: Row(
              children: [
                IconButton(
                  icon: const Icon(Icons.close),
                  onPressed: () {
                    SchedulerBinding.instance.addPostFrameCallback((_) async {
                      final shouldNavigate = await showDialog<bool>(
                        context: context,
                        builder:
                            (context) => AlertDialog(
                              title: const Text('Zurückgehen bestätigen'),
                              content: const Text('Sind Sie sicher, dass Sie zurück zur Inventur-Auswahl gehen möchten?'),
                              actions: [TextButton(onPressed: () => Navigator.of(context).pop(false), child: const Text('Abbrechen')), const Spacer(), TextButton(onPressed: () => Navigator.of(context).pop(true), child: const Text('Ja'))],
                            ),
                      );
                      if (shouldNavigate == true) {
                        // Navigate to root in main router, not nested Beamer
                        Beamer.of(context, root: true).beamToNamed('/');
                      }
                    });
                  },
                ),
                const SizedBox(width: 5),
                const Text('All Records'),
                if (_isLoadingLocation) ...[const SizedBox(width: 8), const SizedBox(width: 12, height: 12, child: CircularProgressIndicator(strokeWidth: 2))],
                //align right
                Expanded(child: Container()),
                OrderClusterBy(
                  initialOrderBy: _orderBy,
                  onOrderChanged: (order) {
                    setState(() {
                      _orderBy = order;
                    });

                    // Check if we have cached data for this order
                    final provider = context.read<RecordsListProvider>();
                    final cachedRecords = provider.getCachedRecords(widget.intervalName, order);

                    if (cachedRecords != null && cachedRecords.isNotEmpty) {
                      // Use cached data
                      setState(() {
                        _allRecords.clear();
                        _allRecords.addAll(cachedRecords);
                        _currentPage = provider.getCachedPage(widget.intervalName, order);
                        _hasMoreData = provider.getHasMoreData(widget.intervalName, order);
                      });
                    } else {
                      // Reload data with new ordering
                      _loadInitialData();
                    }
                  },
                ),
                FilterClusterBy(
                  initialFilter: _filter,
                  onFilterChanged: (filter) {
                    setState(() {
                      _filter = filter;
                    });
                    // Reload data with new filter
                    _loadInitialData();
                  },
                ),
              ],
            ),
          ),
          // Body
          Expanded(
            child:
                _allRecords.isEmpty && !_isLoadingMore
                    ? const Center(child: CircularProgressIndicator())
                    : _allRecords.isEmpty
                    ? const Center(child: Text('No records found'))
                    : ListView.builder(
                      controller: _scrollController,
                      padding: const EdgeInsets.all(16),
                      itemCount: _allRecords.length + (_hasMoreData ? 1 : 0),
                      itemBuilder: (context, index) {
                        // Show loading indicator at the end
                        if (index == _allRecords.length) {
                          return const Center(child: Padding(padding: EdgeInsets.all(16.0), child: CircularProgressIndicator()));
                        }

                        final item = _allRecords[index];
                        final record = item['record'] as Record;
                        final metadata = item['metadata'] as String?;

                        return GestureDetector(
                          onTap: () {
                            Beamer.of(context).beamToNamed('/properties-edit/${Uri.encodeComponent(record.clusterName)}/${Uri.encodeComponent(record.plotName)}');
                          },
                          child: Container(
                            margin: const EdgeInsets.only(bottom: 12),
                            padding: const EdgeInsets.all(12),
                            child: Row(
                              children: [
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [Text(record.clusterName, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold)), const SizedBox(height: 4), Text(record.plotName, style: TextStyle(fontSize: 14, color: Colors.grey[600]))],
                                  ),
                                ),
                                if (metadata != null)
                                  Container(
                                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                    decoration: BoxDecoration(color: Colors.blue[100], borderRadius: BorderRadius.circular(4)),
                                    child: Text(metadata, style: TextStyle(fontSize: 12, color: Colors.blue[900])),
                                  ),
                              ],
                            ),
                          ),
                        );
                      },
                    ),
          ),
        ],
      ),
    );
  }

  @override
  void dispose() {
    _scrollController?.removeListener(_onScroll);
    // Only dispose if we created the controller ourselves
    if (_createdOwnController && _scrollController != null) {
      _scrollController!.dispose();
    }
    super.dispose();
  }
}
