import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:terrestrial_forest_monitor/services/powersync.dart';
import 'package:terrestrial_forest_monitor/widgets/tabs-table-form.dart';

class PlotEditBySchema extends StatefulWidget {
  final String schemaId;
  final String plotId;
  final String clusterId;
  const PlotEditBySchema({super.key, required this.schemaId, required this.plotId, required this.clusterId});

  @override
  State<PlotEditBySchema> createState() => _PlotEditBySchemaState();
}

class _PlotEditBySchemaState extends State<PlotEditBySchema> {
  Map schema = {};

  Future<Map> _getSchema() async {
    schema = await db.get('SELECT * FROM schemas WHERE id = ?', [widget.schemaId]);
    return schema;
  }

  @override
  void initState() {
    super.initState();
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Text('schemaId: ${widget.schemaId}'),
        Text('plotId: ${widget.plotId}'),
        Text('clusterId: ${widget.clusterId}'),
        Expanded(
          child: FutureBuilder(
            future: _getSchema(),
            builder: (context, snapshot) {
              if (snapshot.connectionState == ConnectionState.done) {
                return TabsTableForm(schema: jsonDecode(schema['schema']));
              } else {
                return Center(child: CircularProgressIndicator());
              }
            },
          ),
        ),
      ],
    );
  }
}
