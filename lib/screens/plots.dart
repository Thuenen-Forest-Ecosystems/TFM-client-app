import 'package:beamer/beamer.dart';
import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:provider/provider.dart';

import 'package:terrestrial_forest_monitor/providers/map-state.dart';
import 'package:terrestrial_forest_monitor/services/api.dart';
import 'package:terrestrial_forest_monitor/services/powersync.dart';
import 'package:terrestrial_forest_monitor/services/utils.dart';
//import 'package:terrestrial_forest_monitor/widgets/breadcrumb.dart';
//import 'package:terrestrial_forest_monitor/widgets/table-from-json2.dart';
import 'package:powersync/sqlite3_common.dart' as sqlite;

class Plots extends StatefulWidget {
  final String clusterId;
  final String schemaId;
  const Plots({super.key, required this.clusterId, required this.schemaId});

  @override
  State<Plots> createState() => _PlotsState();
}

class _PlotsState extends State<Plots> {
  late String _clusterId;
  String? _clusterName;
  String _viewType = 'table';
  double _tuneHeight = 0;

  Future<sqlite.ResultSet>? _plotFuture;
  Future<sqlite.Row>? _clusterFuture;

  Future<sqlite.Row> _getCluster() async {
    sqlite.Row cluster = await db.get('SELECT * FROM cluster WHERE cluster_name= ? ', [widget.clusterId]);

    setState(() {
      _clusterName = cluster['cluster_name'];
    });

    return cluster;
  }

  Future<sqlite.ResultSet> _getPlots() async {
    sqlite.ResultSet plots = await db.getAll('SELECT * FROM plot WHERE cluster_id=$_clusterName ORDER BY plot_name ASC');

    return plots;
  }

  _getAll() async {
    _clusterFuture = _getCluster();
    _clusterFuture?.then((value) {
      _plotFuture = _getPlots();
      _plotFuture?.then((value) {
        _focusBounds(value);
      });
    });
  }

  @override
  initState() {
    super.initState();
    _clusterId = widget.clusterId;

    _getAll();
  }

  Future _refreshData() async {
    return await ApiService().getCluster(_clusterId);
  }

  void _focusBounds(plots) async {
    LatLngBounds bounds = getBounds(plots, 'center_location_json');
    //moveToPoint(bounds.center, null);
    //context.read<MapState>().fitCameraBounds(bounds, 50);
    context.read<MapState>().moveToPoint(bounds.center, 15);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: ListTile(contentPadding: EdgeInsets.all(0), leading: Icon(Icons.crop_square), title: Text('Ecken', overflow: TextOverflow.ellipsis, maxLines: 1), subtitle: Text('Trakt: $_clusterId', overflow: TextOverflow.ellipsis, maxLines: 1)),
        backgroundColor: Colors.transparent,
        iconTheme: IconThemeData(color: Colors.white),
        leading: IconButton(
          icon: Icon(Icons.arrow_back),
          onPressed: () {
            context.beamToNamed('/schema/${widget.schemaId}');
          },
        ),
      ),
      body: SingleChildScrollView(
        child: FutureBuilder(
          future: _plotFuture, //
          builder: (context, snapshot) {
            if (snapshot.connectionState == ConnectionState.waiting) {
              return Center(child: CircularProgressIndicator());
            } else if (snapshot.hasError) {
              return Center(child: Text('Error: Plot $_clusterName does not exist.'));
            } else if (!snapshot.hasData || snapshot.data == null) {
              return Center(child: Text('No data'));
            }

            return Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                ...snapshot.data!.map((plot) {
                  return GestureDetector(
                    onTap: () {
                      //Navigator.pushNamed(context, '/schema/private_ci2027_001/$_clusterId/${plot['id']}');
                      Beamer.of(context).beamToNamed('/plot/${widget.schemaId}/$_clusterId/${plot['id']}');
                    },
                    child: Card(
                      child: Padding(
                        padding: EdgeInsets.all(10),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            ListTile(
                              title: Text(plot['plot_name']),
                              subtitle: Text(plot['id']),
                              /*trailing: IconButton(
                                        onPressed: () {
                                          showDialog<String>(
                                            context: context,
                                            builder: (BuildContext context) => AlertDialog(
                                              title: Text('Trakt: ${plot['cluster_id']} ${plot['plot_name']}'),
                                              content: Text('Plot ID: ${plot['id']}'),
                                            ),
                                          );
                                        },
                                        icon: Icon(Icons.info),
                                      ),*/
                            ),
                          ],
                        ),
                      ),
                    ),
                  );
                }),
              ],
            );
          },
        ),
      ),
    );
  }
}
