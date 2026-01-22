import 'dart:async';
import 'dart:io' show Platform;
import 'package:flutter/material.dart';
import 'package:latlong2/latlong.dart';
import 'package:beamer/beamer.dart';
import 'package:provider/provider.dart';
//import 'package:maplibre_gl/maplibre_gl.dart'; // not supported in windows
//import 'package:terrestrial_forest_monitor/screens/inventory/test-ajv.dart';
import 'package:terrestrial_forest_monitor/widgets/bluetooth-icon-combined.dart';
import 'package:terrestrial_forest_monitor/widgets/serial-port-gps-icon.dart';
//import 'package:terrestrial_forest_monitor/widgets/bluetooth-icon.dart';
//import 'package:terrestrial_forest_monitor/widgets/map_widget_maplibre.dart'; // not supported in windows
import 'package:terrestrial_forest_monitor/widgets/map_widget.dart';

import 'package:terrestrial_forest_monitor/screens/inventory/schema-selection.dart';
import 'package:terrestrial_forest_monitor/screens/inventory/records-selection.dart';
import 'package:terrestrial_forest_monitor/screens/inventory/properties-edit.dart';
import 'package:terrestrial_forest_monitor/repositories/records_repository.dart';
import 'package:terrestrial_forest_monitor/providers/records_list_provider.dart';
import 'package:terrestrial_forest_monitor/providers/gps-position.dart';
import 'package:terrestrial_forest_monitor/providers/map_controller_provider.dart';
import 'package:terrestrial_forest_monitor/widgets/cluster/order-cluster-by.dart';
//import 'package:terrestrial_forest_monitor/widgets/profil-icon.dart';

class Start extends StatefulWidget {
  const Start({super.key});

  @override
  State<Start> createState() => _StartState();
}

class _StartState extends State<Start> {
  final DraggableScrollableController _sheetController = DraggableScrollableController();
  late final BeamerDelegate _beamerDelegate;
  double _currentSheetSize = 0.25; // Track current sheet size
  bool _isLoadingData = true;
  StreamSubscription? _recordsWatchSubscription;

  // Initial position of bottom sheet (25% of screen height)
  final double _initialChildSize = 0.25;
  final double _minChildSize = 0.15;
  double _maxChildSize = 1; // Will be calculated in build

  @override
  void initState() {
    super.initState();

    // Listen to sheet controller changes
    _sheetController.addListener(_onSheetChanged);

    // Initialize GPS provider now that user is authenticated
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) {
        final gpsProvider = context.read<GpsPositionProvider>();
        gpsProvider.initialize();

        // Listen for navigation requests from map
        final mapProvider = context.read<MapControllerProvider>();
        mapProvider.addListener(_onMapNavigationRequest);

        // Start watching records and cache in provider
        _startWatchingRecords();
      }
    });

    _beamerDelegate = BeamerDelegate(
      initialPath: '/',
      locationBuilder: RoutesLocationBuilder(
        routes: {
          '/': (context, state, data) => BeamPage(
            key: const ValueKey('schema-selection'),
            child: PopScope(
              canPop: false,
              onPopInvokedWithResult: (didPop, result) async {
                if (didPop) return;
                await _handleCloseButtonPressed();
              },
              child: const SchemaSelection(),
            ),
          ),
          '/records-selection/:intervalName': (context, state, data) {
            final intervalName = state.pathParameters['intervalName'];
            if (intervalName == null || intervalName.isEmpty) {
              return BeamPage(
                key: const ValueKey('schema-selection'),
                child: const SchemaSelection(),
              );
            }
            final decodedIntervalName = Uri.decodeComponent(intervalName);
            return BeamPage(
              key: ValueKey('records-selection-$decodedIntervalName'),
              child: PopScope(
                canPop: false,
                onPopInvokedWithResult: (didPop, result) async {
                  if (didPop) return;
                  await _handleCloseButtonPressed();
                },
                child: RecordsSelection(intervalName: decodedIntervalName),
              ),
            );
          },
          '/properties-edit/:clusterName/:plotName': (context, state, data) {
            final clusterName = state.pathParameters['clusterName'];
            final plotName = state.pathParameters['plotName'];
            if (clusterName == null || plotName == null) {
              return BeamPage(
                key: const ValueKey('schema-selection'),
                child: const SchemaSelection(),
              );
            }
            final decodedClusterName = Uri.decodeComponent(clusterName);
            final decodedPlotName = Uri.decodeComponent(plotName);

            return BeamPage(
              key: ValueKey('properties-edit-$decodedClusterName-$decodedPlotName'),
              child: PopScope(
                canPop: false,
                onPopInvokedWithResult: (didPop, result) async {
                  if (didPop) return;
                  await _handleCloseButtonPressed();
                },
                child: PropertiesEdit(clusterName: decodedClusterName, plotName: decodedPlotName),
              ),
            );
          },
        },
      ),
      notFoundPage: BeamPage(key: const ValueKey('not-found'), child: const SchemaSelection()),
    );
  }

  void _onSheetChanged() {
    if (_sheetController.isAttached && mounted) {
      final newSize = _sheetController.size;
      if (newSize != _currentSheetSize) {
        setState(() {
          _currentSheetSize = newSize;
        });
      }
    }
  }

  void _onMapNavigationRequest() {
    if (!mounted) return;

    try {
      final mapProvider = context.read<MapControllerProvider>();
      final navPath = mapProvider.navigationPath;

      if (navPath != null) {
        _beamerDelegate.beamToNamed(navPath);
        mapProvider.clearNavigationRequest();
      }
    } catch (e) {
      debugPrint('Start: Error handling navigation request: $e');
    }
  }

  Future<void> _startWatchingRecords() async {
    // Wait for provider to initialize and load permission ID
    if (!mounted) return;

    final provider = context.read<RecordsListProvider>();

    // Wait for permission ID to be loaded (up to 2 seconds)
    int waitCount = 0;
    while (!provider.isPermissionIdLoaded && waitCount < 20) {
      await Future.delayed(const Duration(milliseconds: 100));
      waitCount++;
    }

    try {
      // Cancel any existing subscription
      await _recordsWatchSubscription?.cancel();

      // Watch records filtered by selected permissions
      _recordsWatchSubscription = RecordsRepository().watchAllRecords().listen(
        (records) {
          if (!mounted) return;

          // Store in provider cache with metadata structure
          final recordsWithMetadata = records.map((record) {
            return {'record': record, 'metadata': null};
          }).toList();

          // Cache in provider with a generic key that both map and records-selection can use
          provider.cacheRecords(
            'all', // Generic key for all records
            ClusterOrderBy.clusterName, // Default order (will be re-sorted by consumers)
            recordsWithMetadata,
            0, // page
            false, // hasMore
          );

          if (mounted && _isLoadingData) {
            setState(() {
              _isLoadingData = false;
            });
          }
        },
        onError: (error) {
          debugPrint('Start: Error watching records: $error');
          if (mounted) {
            setState(() {
              _isLoadingData = false;
            });
          }
        },
      );
    } catch (e) {
      debugPrint('Start: Error setting up watch: $e');
      if (mounted) {
        setState(() {
          _isLoadingData = false;
        });
      }
    }
  }

  @override
  void dispose() {
    _sheetController.removeListener(_onSheetChanged);

    // Remove map navigation listener
    try {
      final mapProvider = context.read<MapControllerProvider>();
      mapProvider.removeListener(_onMapNavigationRequest);
    } catch (e) {
      debugPrint('Start: Error removing map navigation listener: $e');
    }

    _beamerDelegate.dispose();
    _sheetController.dispose();
    super.dispose();
  }

  Widget _buildTopBar() {
    return Container(
      // add scaffold background color and rounded corners
      decoration: BoxDecoration(
        color: Theme.of(context).scaffoldBackgroundColor,
        borderRadius: const BorderRadius.all(Radius.circular(30)),
      ),
      child: Row(
        children: [
          //const SyncStatusButton(),
          // Use platform-specific GPS widget
          if (Platform.isWindows) const SerialPortGpsIcon() else const BluetoothIconCombined(),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    // Show loading screen while preloading data
    /*if (_isLoadingData) {
      return Scaffold(
        body: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              CircularProgressIndicator(),
              SizedBox(height: 16),
              Text('Lade Aufnahmepunkte...'),
            ],
          ),
        ),
      );
    }*/

    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (bool didPop, dynamic result) async {
        if (didPop) return;
        // Handle system back/gesture same as close button
        await _handleCloseButtonPressed();
      },
      child: BackButtonListener(
        onBackButtonPressed: _handleCloseButtonPressed,
        child: _buildContent(context),
      ),
    );
  }

  Widget _buildContent(BuildContext context) {
    return Stack(
      children: [
        // Background Map (Fixed Height) - Move up based on sheet position
        // The map center should align with the center of visible area (above the sheet)
        Positioned(
          top:
              -(_currentSheetSize - _minChildSize) * MediaQuery.of(context).size.height * 0.5 -
              MediaQuery.of(context).padding.top,
          left: 0,
          right: 0,
          height: MediaQuery.of(context).size.height + MediaQuery.of(context).padding.top,
          child: MapWidget(
            key: const ValueKey('main-map-widget'),
            initialCenter: const LatLng(52.2688, 10.5268), // Braunschweig
            initialZoom: 4,
            sheetPosition: _currentSheetSize,
          ),
        ),
        SafeArea(
          child: Container(
            alignment: Alignment.topLeft,
            child: Row(
              children: [
                Container(
                  decoration: BoxDecoration(
                    color: Theme.of(context).scaffoldBackgroundColor,
                    borderRadius: const BorderRadius.only(
                      topRight: Radius.circular(30),
                      bottomRight: Radius.circular(30),
                    ),
                  ),
                  child: IconButton(
                    icon: const Icon(Icons.close),
                    onPressed: _handleCloseButtonPressed,
                  ),
                ),
                const Expanded(child: SizedBox()),
                _buildTopBar(),
                SizedBox(width: 16),
              ],
            ),
          ),
        ),

        // Bottom Sheet with Content
        _buildBottomSheet(),
      ],
    );
  }

  Future<bool> _handleCloseButtonPressed() async {
    if (!mounted) return true;

    final currentPath = _beamerDelegate.currentBeamLocation.state.routeInformation.uri.path;

    String title = 'Zurückgehen bestätigen';
    bool? shouldNavigate = true;

    if (currentPath.startsWith('/properties-edit')) {
      title = 'Abbrechen';

      shouldNavigate = await showDialog<bool>(
        context: context,
        builder: (context) => AlertDialog(
          title: Text(title),
          content: const Text('Ungespeicherten Änderungen gehen verloren.'),
          actionsAlignment: MainAxisAlignment.spaceBetween,
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(false),
              child: const Text('zurück'),
            ),
            ElevatedButton(
              onPressed: () => Navigator.of(context).pop(true),
              style: ElevatedButton.styleFrom(
                backgroundColor: Theme.of(context).colorScheme.error,
                foregroundColor: Colors.white,
              ),
              child: const Text('Änderungen verwerfen'),
            ),
          ],
        ),
      );
    }

    if (shouldNavigate == true) {
      // If on properties-edit, navigate back to records-selection with intervalName
      if (currentPath.startsWith('/properties-edit')) {
        // Extract clusterName and plotName from URI path: /properties-edit/:clusterName/:plotName
        final pathSegments = Uri.parse(currentPath).pathSegments;
        if (pathSegments.length >= 3) {
          final clusterName = Uri.decodeComponent(pathSegments[1]);
          final plotName = Uri.decodeComponent(pathSegments[2]);

          // Load the record to get the schemaName/intervalName
          try {
            final recordsRepository = RecordsRepository();
            final records = await recordsRepository.getRecordsByClusterAndPlot(
              clusterName,
              plotName,
            );

            if (records.isNotEmpty) {
              final intervalName = records.first.schemaName;
              _beamerDelegate.beamToNamed(
                '/records-selection/${Uri.encodeComponent(intervalName)}',
              );
              return true;
            }
          } catch (e) {
            debugPrint('Error loading record for back navigation: $e');
          }
        }
      }

      // Default: go to schema-selection (Root)
      if (mounted) {
        Beamer.of(context, root: true).beamToNamed('/');
      }
    }

    return true;
  }

  // Draggable Bottom Sheet
  Widget _buildBottomSheet() {
    // Calculate maxChildSize based on screen height minus 100px
    final screenHeight = MediaQuery.of(context).size.height;
    final maxHeight = screenHeight - 20;
    _maxChildSize = maxHeight / screenHeight;

    return DraggableScrollableSheet(
      controller: _sheetController,
      initialChildSize: _initialChildSize,
      minChildSize: _minChildSize,
      maxChildSize: _maxChildSize,
      builder: (BuildContext context, ScrollController scrollController) {
        return Container(
          decoration: BoxDecoration(
            color: Theme.of(context).scaffoldBackgroundColor,
            borderRadius: const BorderRadius.vertical(top: Radius.circular(15)),
            boxShadow: [BoxShadow(blurRadius: 5)],
          ),
          child: ClipRRect(
            borderRadius: const BorderRadius.vertical(top: Radius.circular(15)),
            child: Column(
              children: [
                // Drag Handle with mouse support for Windows
                GestureDetector(
                  onVerticalDragUpdate: (details) {
                    if (_sheetController.isAttached) {
                      final screenHeight = MediaQuery.of(context).size.height;
                      final delta = -details.delta.dy / screenHeight;
                      final newSize = (_sheetController.size + delta).clamp(
                        _minChildSize,
                        _maxChildSize,
                      );
                      _sheetController.jumpTo(newSize);
                    }
                  },
                  child: MouseRegion(
                    cursor: SystemMouseCursors.resizeUpDown,
                    child: Container(
                      padding: const EdgeInsets.symmetric(vertical: 12),
                      child: Center(
                        child: Container(
                          width: 40,
                          height: 4,
                          decoration: BoxDecoration(
                            color: Colors.grey[300],
                            borderRadius: BorderRadius.circular(2),
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
                // Content Area with Beamer routing
                Expanded(
                  child: ListView(
                    controller: scrollController,
                    padding: EdgeInsets.zero,
                    children: [
                      SizedBox(
                        height: MediaQuery.of(context).size.height * _maxChildSize - 28,
                        child: Beamer(routerDelegate: _beamerDelegate),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}
