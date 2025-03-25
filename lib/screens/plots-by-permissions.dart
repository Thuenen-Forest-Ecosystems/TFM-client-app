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
  _syncPlotsNestedJson() async {
    List<Map> rows = await getPlotsNestedJson();
    print(rows);
  }

  @override
  void initState() {
    // TODO: implement initState
    super.initState();
    _syncPlotsNestedJson();
  }

  @override
  Widget build(BuildContext context) {
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
          return Center(child: Text('no data'));
        } else {
          return Center(child: CircularProgressIndicator());
        }
      },
    );
  }
}
