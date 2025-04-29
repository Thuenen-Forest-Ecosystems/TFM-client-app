import 'dart:convert';

import 'package:beamer/beamer.dart';
import 'package:flutter/material.dart';
import 'package:terrestrial_forest_monitor/services/powersync.dart';
import 'package:powersync/sqlite3_common.dart' as sqlite;

class PlotsByPermissions extends StatefulWidget {
  const PlotsByPermissions({super.key});

  @override
  State<PlotsByPermissions> createState() => _PlotsByPermissionsState();
}

class _PlotsByPermissionsState extends State<PlotsByPermissions> {
  List _records = [];

  Future<Map> _getAllRecords() async {
    Map clusterMap = {};
    // Get all records from the database
    _records = await db.getAll('SELECT * FROM records');

    // group by cluster_id
    for (var record in _records) {
      // record.previous_properties from json string to map
      Map<String, dynamic> previous_properties = record['previous_properties'] != null ? Map<String, dynamic>.from(jsonDecode(record['previous_properties'])) : {};
      if (previous_properties['cluster_id'] == null) {
        continue;
      }
      String clusterId = previous_properties['cluster_id'] ?? '';
      if (clusterMap[clusterId] == null) {
        clusterMap[clusterId] = [];
      }

      // Add the record to the clusterMap
      clusterMap[clusterId].add({...record, 'previous_properties': previous_properties});
    }

    return clusterMap;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: ListTile(title: Text('Plots')), automaticallyImplyLeading: false, centerTitle: false),
      body: FutureBuilder(
        future: db.getAll('SELECT * FROM records'), //_getAllRecords(),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.done && snapshot.hasData) {
            if (snapshot.data!.isEmpty) {
              return Center(child: Text('Melde dich bei deinem Admin um Daten freizugeben.'));
            }

            return ListView.builder(
              itemCount: snapshot.data?.length,
              itemBuilder: (context, index) {
                sqlite.Row? record = snapshot.data?.elementAt(index);
                if (record == null) {
                  return Container();
                }
                Map previous_properties = record['previous_properties'] != null ? jsonDecode(record['previous_properties']) : {};
                String clusterId = previous_properties['cluster_id'] ?? '';

                return ListTile(
                  title: Text('Ecke:' + previous_properties['plot_name'].toString()),
                  subtitle: Text('Trakt:' + previous_properties['cluster_name'].toString() ?? ''),
                  onTap: () {
                    Beamer.of(context).beamToNamed('/record/${record['id']}');
                  },
                  trailing: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      IconButton(
                        icon: Icon(Icons.edit),
                        onPressed: () {
                          Beamer.of(context).beamToNamed('/plot/edit/${record['schema_id']}/${previous_properties['cluster_id']}/${previous_properties['id']}');
                        },
                      ),
                      IconButton(
                        icon: Icon(Icons.delete),
                        onPressed: () {
                          setState(() {});
                        },
                      ),
                    ],
                  ),
                  leading: Icon(Icons.blur_circular),
                );
              },
            );
          } else if (!snapshot.hasData) {
            return Center(child: Text('no data'));
          } else {
            return Center(child: CircularProgressIndicator());
          }
        },
      ),
    );
  }
}
