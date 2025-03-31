import 'dart:convert';

import 'package:beamer/beamer.dart';
import 'package:flutter/material.dart';
import 'package:terrestrial_forest_monitor/services/powersync.dart';

class PlotsByPermissions extends StatefulWidget {
  final String schemaId;
  const PlotsByPermissions({super.key, required this.schemaId});

  @override
  State<PlotsByPermissions> createState() => _PlotsByPermissionsState();
}

class _PlotsByPermissionsState extends State<PlotsByPermissions> {
  Future<Map> _getAllRecords() async {
    Map clusterMap = {};
    // Get all records from the database
    List records = await db.getAll('SELECT * FROM records');

    // group by cluster_id
    for (var record in records) {
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
    print('-----');
    print(clusterMap);
    return clusterMap;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text('Cluster')),
      body: FutureBuilder(
        future: _getAllRecords(),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.done && snapshot.hasData) {
            return ListView.builder(
              itemCount: snapshot.data?.entries.length,
              itemBuilder: (context, index) {
                List records = snapshot.data?.values.elementAt(index);
                String clusterId = records[0]['previous_properties']['cluster_id'] ?? '';

                return ListTile(
                  title: Text('Cluster:' + clusterId),
                  subtitle: Text('First Plot:' + records[0]['plot_id'] ?? ''),
                  onTap: () {
                    Beamer.of(context).beamToNamed('/plot/edit/${records[0]['schema_id']}/$clusterId/${records[0]['id']}');
                  },
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
    return FutureBuilder(
      future: _getAllRecords(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.done) {
          return Scaffold(appBar: AppBar(title: Text('Plots by Permissions')), body: Text(snapshot.data.toString() ?? 'no data'));
        } else {
          return Center(child: CircularProgressIndicator());
        }
      },
    );
    return FutureBuilder(
      future: getPlotsByPermissions(widget.schemaId),
      builder: (context, snapshot) {
        // List of Plots accessible by the user
        if (snapshot.connectionState == ConnectionState.done && snapshot.hasData) {
          List ids = snapshot.data;
          String placeholders = snapshot.data.map((e) => '?').join(',');
          print('getPlotsByPermissions');
          print(snapshot.data);
          return FutureBuilder(
            future: db.getAll('SELECT * FROM plot_nested_json WHERE id IN ($placeholders)', ids),
            builder: (context, snapshot) {
              print(snapshot.data);
              if (snapshot.connectionState == ConnectionState.done) {
                return ListView.builder(
                  itemCount: snapshot.data?.length,
                  itemBuilder: (context, index) {
                    return ListTile(
                      title: Text(snapshot.data?[index]['id']),
                      subtitle: Text(snapshot.data?[index]['cluster_id'] ?? ''),
                      onTap: () {
                        Beamer.of(context).beamToNamed('/plot/edit/${widget.schemaId}/${snapshot.data?[index]['cluster_id']}/${snapshot.data?[index]['id']}');
                      },
                    );
                  },
                );
              } else {
                return Center(child: CircularProgressIndicator());
              }
            },
          );
        } else if (!snapshot.hasData) {
          return Center(child: Text('no datas'));
        } else {
          return Center(child: CircularProgressIndicator());
        }
      },
    );
  }
}
