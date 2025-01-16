import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:beamer/beamer.dart';
import 'package:latlong2/latlong.dart';
import 'package:powersync/sqlite3.dart' as sqlite;
import 'package:provider/provider.dart';
import 'package:terrestrial_forest_monitor/components/navigation-car.dart';
import 'package:terrestrial_forest_monitor/components/navigation.dart';
import 'package:terrestrial_forest_monitor/providers/gps-position.dart';

import 'package:terrestrial_forest_monitor/providers/map-state.dart';
import 'package:terrestrial_forest_monitor/services/powersync.dart';
import 'package:terrestrial_forest_monitor/services/utils.dart';
import 'package:terrestrial_forest_monitor/widgets/ci2027/tree/overview.dart';
import 'package:url_launcher/url_launcher.dart';

class Plot extends StatefulWidget {
  final String schemaId;
  final String plotId;
  final String clusterId;
  const Plot({super.key, required this.schemaId, required this.plotId, required this.clusterId});

  @override
  State<Plot> createState() => _PlotState();
}

class _PlotState extends State<Plot> {
  Future<sqlite.Row>? _plotFuture;
  String? _plotName;

  @override
  void initState() {
    super.initState();
    _plotFuture = _getPlot();
  }

  Future<sqlite.Row> _getPlot() async {
    sqlite.Row plot = await db.get('SELECT * FROM PLOT WHERE id = ?', [widget.plotId]);
    setState(() {
      _plotName = plot['plot_name'];
    });
    _centerPlot();
    return plot;
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
    return Scaffold(
      appBar: AppBar(
        title: ListTile(
          contentPadding: EdgeInsets.all(0),
          leading: Icon(Icons.blur_circular),
          title: Text('Ecke $_plotName', overflow: TextOverflow.ellipsis, maxLines: 1),
          subtitle: Text('Trakt: ${widget.clusterId}', overflow: TextOverflow.ellipsis, maxLines: 1),
        ),
        backgroundColor: Colors.transparent,
        iconTheme: IconThemeData(color: Colors.white),
        leading: IconButton(
          icon: Icon(Icons.arrow_back),
          onPressed: () {
            //context.beamToNamed('/schema/${widget.schemaId}/cluster/${widget.clusterId}');
            Beamer.of(context).beamToNamed('/cluster/${widget.schemaId}/${widget.clusterId}');
          },
        ),
        actions: [
          ElevatedButton.icon(
            onPressed: () {
              Beamer.of(context).beamToNamed('/plot/edit/${widget.schemaId}/${widget.clusterId}/${widget.plotId}');
            },
            label: Text('Bearbeiten'),
            icon: Icon(Icons.edit),
          )
        ],
      ),
      body: FutureBuilder(
          future: _plotFuture, //db.get('SELECT * FROM PLOT WHERE id = ?', [widget.plotId]),
          builder: (context, snapshot) {
            if (snapshot.connectionState == ConnectionState.waiting) {
              return Center(child: CircularProgressIndicator());
            }
            if (snapshot.hasError) {
              return Center(child: Text('Error: ${snapshot.error}'));
            }
            if (snapshot.hasData) {
              Map plot = snapshot.data as Map;
              Map plotLocation = jsonDecode(plot['center_location_json']);
              LatLng plotCenter = LatLng(plotLocation['coordinates'][1], plotLocation['coordinates'][0]);

              return Center(
                child: ConstrainedBox(
                  constraints: BoxConstraints(
                    maxWidth: 800,
                    minWidth: 300,
                  ),
                  child: Container(
                    margin: EdgeInsets.all(10.0),
                    child: GridView.count(
                      crossAxisCount: 3,
                      children: [
                        Card(
                          child: Navigation(
                            target: plot,
                            position: plotCenter,
                          ),
                        ),
                        Card(
                          child: NavigationCar(
                            target: plot,
                            position: plotCenter,
                          ),
                        ),
                        Card(
                          child: ListTile(
                            title: Text('Ecke: ${plot['plot_name']}'),
                            subtitle: Text('Erstellt: ${plot['created_at']}'),
                          ),
                        ),
                        Card(
                          child: TreeOverview(
                            plotId: widget.plotId,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              );

              return ListView(
                children: [
                  ListTile(
                    title: Text(plot['plot_name']),
                    subtitle: Text('Erstellt: ${plot['created_at']}'),
                  ),
                ],
              );
            }
            return Center(child: Text('Keine Daten'));
          }),
    );
  }
}
