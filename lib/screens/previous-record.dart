import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:beamer/beamer.dart';
import 'package:latlong2/latlong.dart';
import 'package:powersync/sqlite3_common.dart' as sqlite;
import 'package:provider/provider.dart';
import 'package:terrestrial_forest_monitor/components/navigation-car.dart';
import 'package:terrestrial_forest_monitor/components/navigation.dart';
import 'package:terrestrial_forest_monitor/providers/gps-position.dart';

import 'package:terrestrial_forest_monitor/providers/map-state.dart';
import 'package:terrestrial_forest_monitor/services/powersync.dart';
import 'package:terrestrial_forest_monitor/widgets/ci2027/tree/overview.dart';

class PreviousRecord extends StatefulWidget {
  final String recordId;
  const PreviousRecord({super.key, required this.recordId});

  @override
  State<PreviousRecord> createState() => _PreviousRecordState();
}

class _PreviousRecordState extends State<PreviousRecord> {
  Future<sqlite.Row>? _plotFuture;

  @override
  void initState() {
    super.initState();
  }

  Future _centerPlot() async {
    sqlite.Row plot = await (_plotFuture as Future<sqlite.Row>);
    Map plotLocation = jsonDecode(plot['center_location_json']);
    LatLng plotCenter = LatLng(plotLocation['coordinates'][1], plotLocation['coordinates'][0]);

    context.read<MapState>().moveToPoint(plotCenter, 17.0);

    context.read<GpsPositionProvider>().navigateToTarget(plotCenter, plot);
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder(
      future: db.get('SELECT * FROM records WHERE id = ?', [widget.recordId]),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return Center(child: CircularProgressIndicator());
        }
        if (snapshot.hasError) {
          return Center(child: Text('Error: ${snapshot.error}'));
        }
        if (snapshot.hasData) {
          Map plot = jsonDecode(snapshot.data?['previous_properties']);

          Map plotLocation = plot['plot_coordinates'][0]['center_location'];
          LatLng plotCenter = LatLng(plotLocation['coordinates'][1], plotLocation['coordinates'][0]);

          return Scaffold(
            appBar: AppBar(
              title: ListTile(
                contentPadding: EdgeInsets.all(0),
                leading: Icon(Icons.blur_circular),
                title: Text('Ecke ${plot['plot_name']}', overflow: TextOverflow.ellipsis, maxLines: 1),
                subtitle: FutureBuilder(
                  future: db.get('SELECT * FROM cluster WHERE id = ?', [plot['cluster_id']]),
                  builder: (context, snapshot) {
                    if (snapshot.connectionState == ConnectionState.waiting) {
                      return Text('...');
                    }
                    if (snapshot.hasError) {
                      return Text('Error: ${snapshot.error}');
                    }
                    if (snapshot.hasData) {
                      Map cluster = snapshot.data as Map;
                      return Text('Trakt: ${cluster['cluster_name']}', overflow: TextOverflow.ellipsis, maxLines: 1);
                    }
                    return Text('Keine Daten');
                  },
                ),
              ),
              backgroundColor: Colors.transparent,
              iconTheme: IconThemeData(color: Colors.white),
              leading: IconButton(
                icon: Icon(Icons.arrow_back),
                onPressed: () {
                  Beamer.of(context).beamToNamed('/records');
                },
              ),
              actions: [
                ElevatedButton.icon(
                  onPressed: () {
                    Beamer.of(context).beamToNamed('/plot/edit/${snapshot.data?['schema_id']}/${plot['cluster_id']}/${plot['plot_id']}');
                  },
                  label: Text('Bearbeiten'),
                  icon: Icon(Icons.edit),
                ),
              ],
            ),

            body: ConstrainedBox(
              constraints: BoxConstraints(maxWidth: 800, minWidth: 300),
              child: Container(
                margin: EdgeInsets.all(10.0),
                child: LayoutBuilder(
                  builder: (context, constraints) {
                    // Calculate columns based on available width
                    int columns = 1;

                    if (constraints.maxWidth > 400) {
                      columns = 2;
                    }
                    if (constraints.maxWidth > 500) {
                      columns = 3;
                    }
                    return GridView.count(
                      crossAxisCount: columns,
                      children: [
                        Card(child: Navigation(target: plot, position: plotCenter)),
                        Card(child: NavigationCar(target: plot, position: plotCenter)),
                        Card(child: ListTile(title: Text('Ecke: ${plot['plot_name']}'), subtitle: Text('Erstellt: ${plot['created_at']}'))),
                        Card(child: TreeOverview(plot: plot)),
                      ],
                    );
                  },
                ),
              ),
            ),
          );
        }
        return Center(child: Text('Keine Daten'));
      },
    );
  }
}
