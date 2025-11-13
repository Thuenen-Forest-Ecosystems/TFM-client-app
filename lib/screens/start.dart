import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:beamer/beamer.dart';
import 'package:maplibre_gl/maplibre_gl.dart';

import 'package:terrestrial_forest_monitor/screens/inventory/test-ajv.dart';
import 'package:terrestrial_forest_monitor/widgets/bluetooth-icon-combined.dart';
//import 'package:terrestrial_forest_monitor/widgets/bluetooth-icon.dart';
import 'package:terrestrial_forest_monitor/widgets/map_widget_maplibre.dart';

import 'package:terrestrial_forest_monitor/screens/inventory/schema-selection.dart';
import 'package:terrestrial_forest_monitor/screens/inventory/records-selection.dart';
import 'package:terrestrial_forest_monitor/screens/inventory/properties-edit.dart';
import 'package:terrestrial_forest_monitor/widgets/map_widget_maplibre.dart';
import 'package:terrestrial_forest_monitor/widgets/profil-icon.dart';
import 'package:terrestrial_forest_monitor/widgets/sync-status-button.dart';

class Start extends StatefulWidget {
  const Start({super.key});

  @override
  State<Start> createState() => _StartState();
}

class _StartState extends State<Start> {
  final DraggableScrollableController _sheetController = DraggableScrollableController();
  late final BeamerDelegate _beamerDelegate;

  // Initial position of bottom sheet (25% of screen height)
  final double _initialChildSize = 0.25;
  final double _minChildSize = 0.15;
  double _maxChildSize = 0.9; // Will be calculated in build

  @override
  void initState() {
    super.initState();

    _beamerDelegate = BeamerDelegate(
      initialPath: '/',
      locationBuilder: RoutesLocationBuilder(
        routes: {
          //'/': (context, state, data) => BeamPage(key: const ValueKey('schema-selection'), child: const SchemaSelection()),
          //'/schema-selection': (context, state, data) => BeamPage(key: const ValueKey('schema-selection'), child: const SchemaSelection()),
          '/records-selection/:intervalName': (context, state, data) {
            final intervalName = state.pathParameters['intervalName'];
            if (intervalName == null || intervalName.isEmpty) {
              return BeamPage(key: const ValueKey('schema-selection'), child: const SchemaSelection());
            }
            final decodedIntervalName = Uri.decodeComponent(intervalName);
            return BeamPage(key: ValueKey('records-selection-$decodedIntervalName'), child: RecordsSelection(intervalName: decodedIntervalName));
          },
          '/properties-edit/:clusterName/:plotName': (context, state, data) {
            final clusterName = state.pathParameters['clusterName'];
            final plotName = state.pathParameters['plotName'];
            if (clusterName == null || plotName == null) {
              return BeamPage(key: const ValueKey('schema-selection'), child: const SchemaSelection());
            }
            final decodedClusterName = Uri.decodeComponent(clusterName);
            final decodedPlotName = Uri.decodeComponent(plotName);
            return BeamPage(key: ValueKey('properties-edit-$decodedClusterName-$decodedPlotName'), child: PropertiesEdit(clusterName: decodedClusterName, plotName: decodedPlotName));
          },
        },
      ),
      notFoundPage: BeamPage(key: const ValueKey('not-found'), child: const SchemaSelection()),
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
          // Background Map (Full Screen) - Keep static, don't transform
          const SizedBox.expand(
            child: RepaintBoundary(
              child: MapWidgetMapLibre(
                initialCenter: LatLng(52.2688, 10.5268), // Braunschweig
                initialZoom: 4,
              ),
            ),
          ),
          SafeArea(child: Container(alignment: Alignment.topLeft, padding: EdgeInsets.only(left: 16), child: Row(children: [const SyncStatusButton(), const Expanded(child: SizedBox()), const BluetoothIconCombined()]))),

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
    final maxHeight = screenHeight - 120;
    _maxChildSize = maxHeight / screenHeight;

    return DraggableScrollableSheet(
      controller: _sheetController,
      initialChildSize: _initialChildSize,
      minChildSize: _minChildSize,
      maxChildSize: _maxChildSize,
      builder: (BuildContext context, ScrollController scrollController) {
        return ChangeNotifierProvider<ScrollController>.value(
          value: scrollController,
          child: Container(
            decoration: BoxDecoration(
              color: Theme.of(context).scaffoldBackgroundColor,
              borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
              boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.2), blurRadius: 10, offset: const Offset(0, -2))],
            ),
            child: CustomScrollView(
              controller: scrollController,
              slivers: [
                // Drag Handle as a pinned header
                SliverPersistentHeader(pinned: true, delegate: _DragHandleDelegate()),

                // Content Area with Beamer routing
                SliverToBoxAdapter(
                  child: SizedBox(
                    height: maxHeight - 28, // Subtract drag handle height
                    child: Beamer(routerDelegate: _beamerDelegate),
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  @override
  void dispose() {
    _beamerDelegate.dispose();
    _sheetController.dispose();
    super.dispose();
  }
}

// Delegate for the drag handle that stays pinned at the top
class _DragHandleDelegate extends SliverPersistentHeaderDelegate {
  @override
  double get minExtent => 28.0;

  @override
  double get maxExtent => 28.0;

  @override
  Widget build(BuildContext context, double shrinkOffset, bool overlapsContent) {
    return Container(
      color: Theme.of(context).scaffoldBackgroundColor,
      padding: const EdgeInsets.symmetric(vertical: 12),
      child: Center(child: Container(width: 40, height: 4, decoration: BoxDecoration(color: Colors.grey[300], borderRadius: BorderRadius.circular(2)))),
    );
  }

  @override
  bool shouldRebuild(covariant SliverPersistentHeaderDelegate oldDelegate) => false;
}
