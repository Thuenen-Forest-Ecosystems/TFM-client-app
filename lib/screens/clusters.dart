import 'package:flutter/material.dart';
import 'package:latlong2/latlong.dart';
import 'package:powersync/sqlite3_common.dart';
import 'package:terrestrial_forest_monitor/services/api.dart';
import 'package:terrestrial_forest_monitor/services/powersync.dart';
import 'package:terrestrial_forest_monitor/services/utils.dart';
import 'package:terrestrial_forest_monitor/widgets/ci2027/cluster_preview.dart';

import 'package:beamer/beamer.dart';

class Clusters extends StatefulWidget {
  final String schemaId;
  const Clusters({super.key, required this.schemaId});

  @override
  State<Clusters> createState() => _ClustersState();
}

class _ClustersState extends State<Clusters> {
  String _viewType = 'table';
  double _tuneHeight = 0;
  bool _fullTextSearch = false;
  String _sqlWhere = '';

  @override
  initState() {
    super.initState();
    db.get('SELECT * FROM settings WHERE user_id = ?', [getUserId()]).then((value) {
      print(value);
    }).catchError((error) {
      print('Error: $error');
    });
  }

  /*Future _refreshClusters() async {
    return await ApiService().getAllClusters();
  }*/

  Future<List> _orderBY() async {
    ResultSet plots = await db.getAll('SELECT * FROM plot WHERE center_location_json IS NOT NULL group by center_location_json');
    List<Map> plot = await orderPlotByDistance(plots, 'center_location_json', LatLng(10, 10));
    print(plot.length);
    return plot;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        iconTheme: IconThemeData(color: Colors.white),
        leading: IconButton(
          icon: Icon(Icons.arrow_back),
          onPressed: () {
            context.beamToNamed('/');
          },
        ),
        title: ListTile(
          contentPadding: EdgeInsets.all(0),
          leading: Icon(Icons.apps),
          title: Text(
            'Clusters',
            overflow: TextOverflow.ellipsis,
            maxLines: 1,
          ),
          //subtitle: Text('${widget.schemaId}', overflow: TextOverflow.ellipsis, maxLines: 1),
        ),
        actions: [
          IconButton(
            icon: Icon(Icons.search),
            onPressed: () {
              setState(() {
                _fullTextSearch = !_fullTextSearch;
              });
            },
          ),
          IconButton(
            icon: Icon(Icons.tune),
            onPressed: () {
              setState(() {
                _tuneHeight = _tuneHeight == 0 ? 100 : 0;
              });
            },
          ),
        ],
      ),
      body: Column(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          Expanded(
            child: StreamBuilder(
              stream: db.watch('SELECT * FROM cluster ORDER BY cluster_name $_sqlWhere'),
              builder: (context, snapshot) {
                if (snapshot.hasData) {
                  return SingleChildScrollView(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        ...snapshot.data!.map(
                          (cluster) {
                            return GestureDetector(
                              child: ClusterPreview(
                                clusterId: cluster['id'],
                                clusterRow: cluster,
                              ),
                              onTap: () {
                                Beamer.of(context).beamToNamed('/cluster/${widget.schemaId}/${cluster['cluster_name']}');
                              },
                            );
                          },
                        ),
                      ],
                    ),
                  );
                } else if (snapshot.hasError) {
                  return Center(
                    child: Text('Error: ${snapshot.error}'),
                  );
                } else {
                  return Center(
                    child: CircularProgressIndicator(),
                  );
                }
              },
            ),
          )
        ],
      ),
    );
  }
}
