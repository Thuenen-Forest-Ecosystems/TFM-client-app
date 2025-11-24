import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';
import 'package:latlong2/latlong.dart';
import 'package:beamer/beamer.dart';
//import 'package:maplibre_gl/maplibre_gl.dart'; // not supported in windows

//import 'package:terrestrial_forest_monitor/screens/inventory/test-ajv.dart';
import 'package:terrestrial_forest_monitor/widgets/bluetooth-icon-combined.dart';
//import 'package:terrestrial_forest_monitor/widgets/bluetooth-icon.dart';
//import 'package:terrestrial_forest_monitor/widgets/map_widget_maplibre.dart'; // not supported in windows
import 'package:terrestrial_forest_monitor/widgets/map_widget.dart';

import 'package:terrestrial_forest_monitor/screens/inventory/schema-selection.dart';
import 'package:terrestrial_forest_monitor/screens/inventory/records-selection.dart';
import 'package:terrestrial_forest_monitor/screens/inventory/properties-edit.dart';
import 'package:terrestrial_forest_monitor/repositories/records_repository.dart';
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

  // Initial position of bottom sheet (25% of screen height)
  final double _initialChildSize = 0.25;
  final double _minChildSize = 0.15;
  double _maxChildSize = 1; // Will be calculated in build

  @override
  void initState() {
    super.initState();

    // Listen to sheet controller changes
    _sheetController.addListener(_onSheetChanged);

    _beamerDelegate = BeamerDelegate(
      initialPath: '/',
      locationBuilder: RoutesLocationBuilder(
        routes: {
          //'/': (context, state, data) => BeamPage(key: const ValueKey('schema-selection'), child: const SchemaSelection()),
          //'/schema-selection': (context, state, data) => BeamPage(key: const ValueKey('schema-selection'), child: const SchemaSelection()),
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
              child: RecordsSelection(intervalName: decodedIntervalName),
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
              child: PropertiesEdit(clusterName: decodedClusterName, plotName: decodedPlotName),
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

  @override
  void dispose() {
    _sheetController.removeListener(_onSheetChanged);
    _beamerDelegate.dispose();
    _sheetController.dispose();
    super.dispose();
  }

  Widget _buildTopBar() {
    return Container(
      // add scaffold background color and rounded corners
      height: 60,
      decoration: BoxDecoration(
        color: Theme.of(context).scaffoldBackgroundColor,
        borderRadius: const BorderRadius.all(Radius.circular(30)),
      ),
      padding: EdgeInsets.symmetric(horizontal: 10),
      child: Row(
        children: [
          //const SyncStatusButton(),
          const BluetoothIconCombined(),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return BackButtonListener(
      onBackButtonPressed: () async {
        final currentPath = _beamerDelegate.currentBeamLocation.state.routeInformation.uri.path;

        // If on records-selection, go back to schema-selection
        if (currentPath.startsWith('/records-selection')) {
          _beamerDelegate.beamToNamed('/');
          return true;
        }

        // If on schema-selection (root), don't consume the back button
        return false;
      },
      child: Stack(
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
            child: const MapWidget(
              initialCenter: LatLng(52.2688, 10.5268), // Braunschweig
              initialZoom: 4,
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
                      onPressed: () {
                        SchedulerBinding.instance.addPostFrameCallback((_) async {
                          final currentPath =
                              _beamerDelegate.currentBeamLocation.state.routeInformation.uri.path;

                          String title = 'Zurückgehen bestätigen';
                          bool? shouldNavigate = true;

                          if (currentPath.startsWith('/properties-edit')) {
                            title = 'Aufnahme abbrechen';

                            shouldNavigate = await showDialog<bool>(
                              context: context,
                              builder:
                                  (context) => AlertDialog(
                                    title: Text(title),
                                    content: const Text(
                                      'Ungespeicherten Änderungen gehen verloren.',
                                    ),
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
                                  return;
                                }
                              }
                            } else {
                              Beamer.of(context, root: true).beamToNamed('/');
                            }
                          }
                        });
                      },
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
      ),
    );
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
                // Drag Handle
                Container(
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
                // Content Area with Beamer routing
                Expanded(
                  child: ListView(
                    controller: scrollController,
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
