import 'dart:convert';

import 'package:beamer/beamer.dart';
import 'package:flutter/material.dart';
import 'package:terrestrial_forest_monitor/services/powersync.dart';
import 'package:powersync/sqlite3_common.dart' as sqlite;
import 'package:terrestrial_forest_monitor/widgets/cluster-grid.dart';
import 'package:terrestrial_forest_monitor/widgets/order-selection.dart';

class PlotsByPermissions extends StatefulWidget {
  const PlotsByPermissions({super.key});

  @override
  State<PlotsByPermissions> createState() => _PlotsByPermissionsState();
}

class _PlotsByPermissionsState extends State<PlotsByPermissions> {
  bool direction = true;
  List<Map<String, dynamic>> orderBtns = [
    {'column': 'time', 'order': 'asc', 'icon': Icons.schedule, 'label': 'Zeit'},
    {'column': 'distance', 'order': 'asc', 'icon': Icons.explore, 'label': 'Entfernung'},
  ];
  final List<bool> _selectedOrder = [true, false, false];

  List _filterRecords(sqlite.ResultSet data) {
    // Filter the records based on the user's permissions
    List filteredRecords = [];

    for (var record in data) {
      Map<String, dynamic> previousProperties = record['previous_properties'] != null ? Map<String, dynamic>.from(jsonDecode(record['previous_properties'])) : {};

      // Add the record to the filteredRecords
      filteredRecords.add({...record, 'previous_properties': previousProperties});
    }

    return filteredRecords;
  }

  List _orderRecords(List data) {
    // Order the records by cluster_id
    data.sort((a, b) {
      // Get the cluster names, converting them to strings first to handle potential ints/nulls
      String clusterNameAStr = a['previous_properties']?['cluster_name']?.toString() ?? '';
      String clusterNameBStr = b['previous_properties']?['cluster_name']?.toString() ?? '';

      // Attempt to parse cluster_name to integers for numerical comparison
      int? clusterNumA = int.tryParse(clusterNameAStr);
      int? clusterNumB = int.tryParse(clusterNameBStr);

      // If both are valid numbers, compare them numerically
      if (clusterNumA != null && clusterNumB != null) {
        return clusterNumA.compareTo(clusterNumB);
      }

      // Fallback to string comparison if parsing fails or values were not numbers
      return clusterNameAStr.compareTo(clusterNameBStr);
    });

    return data;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        leading: IconButton(
          icon: Icon(Icons.arrow_back, color: Colors.black),
          onPressed: () {
            Beamer.of(context).beamToNamed('/');
          },
        ),
        title: ListTile(
          contentPadding: EdgeInsets.all(0),
          title: Text('Ecken', style: TextStyle(color: Colors.black)),
          //subtitle: Text('Dir zugewiesene Ecken', style: TextStyle(color: Colors.black), overflow: TextOverflow.ellipsis, maxLines: 1),
          // ToDo: Sort By
          //trailing: Row(mainAxisSize: MainAxisSize.min, children: [OrderSelection(selectionList: orderBtns), OutlinedButton.icon(onPressed: () {}, label: Text('Sortieren'), icon: Icon(Icons.sort))]),
        ),
        automaticallyImplyLeading: false,
      ),
      body: FutureBuilder(
        future: db.getAll('SELECT id, cluster_name, plot_name FROM records LIMIT 100'), //_getAllRecords(),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.done && snapshot.hasData) {
            if (snapshot.data!.isEmpty) {
              return Center(child: Text('Melde dich bei deinem Admin um Daten freizugeben.'));
            }

            return ClusterGrid(data: snapshot.data!);

            // Filter the records based json filter settings
            List filteredData = _filterRecords(snapshot.data!);
            List orderedData = _orderRecords(filteredData);

            return ListView.builder(
              itemCount: orderedData.length,
              itemBuilder: (context, index) {
                Map record = orderedData[index];

                double screenWidth = MediaQuery.of(context).size.width;

                //Map previous_properties = record['previous_properties'] != null ? jsonDecode(record['previous_properties']) : {};
                //String clusterId = previous_properties['cluster_id'] ?? '';

                return ListTile(
                  title: Text('Ecke: ${record['plot_name']}', overflow: TextOverflow.ellipsis, maxLines: 1),
                  subtitle: Text('Trakt: ${record['cluster_name']}', overflow: TextOverflow.ellipsis, maxLines: 1),
                  onTap: () {
                    Beamer.of(context).beamToNamed('/record/${record['id']}');
                  },
                  trailing: ElevatedButton.icon(
                    icon: Icon(Icons.edit),
                    label: screenWidth > 500 ? Text('Bearbeiten') : SizedBox.shrink(),
                    onPressed: () {
                      Beamer.of(context).beamToNamed('/plot/edit/${record['schema_id']}/${record['previous_properties']['cluster_id']}/${record['id']}');
                    },
                  ),

                  leading: Chip(label: Text(record['is_valid'] == 1 ? 'Valid' : 'Invalid')),
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
