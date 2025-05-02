import 'dart:convert';

import 'package:beamer/beamer.dart';
import 'package:flutter/material.dart';
import 'package:terrestrial_forest_monitor/components/json-schema-form-wrapper.dart';
import 'package:terrestrial_forest_monitor/services/powersync.dart';

class DynamicFormScreen extends StatefulWidget {
  final String schemaId;
  //final String plotId;
  final String recordsId;
  final String clusterId;
  const DynamicFormScreen({super.key, required this.schemaId, required this.recordsId, required this.clusterId});

  @override
  State<DynamicFormScreen> createState() => _DynamicFormScreenState();
}

class _DynamicFormScreenState extends State<DynamicFormScreen> {
  Map<String, dynamic> previousData = {};

  Future<Map> getPreviousData() async {
    // Get the previous data from the database
    Map<String, dynamic>? data = await db.get('SELECT * FROM records WHERE id = ?', [widget.recordsId]);
    previousData = Map<String, dynamic>.from(data);
    previousData['previous_properties'] = previousData['previous_properties'] != null ? jsonDecode(previousData['previous_properties']) : {};
    setState(() {});
    return data;
  }

  @override
  void initState() {
    // TODO: implement initState
    super.initState();
    // Get the previous data from the database
    getPreviousData();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: FutureBuilder<Map<String, dynamic>?>(
        future: db.get('SELECT * FROM schemas WHERE id = ?', [widget.schemaId]),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.done) {
            if (snapshot.hasData && snapshot.data != null && snapshot.data!['schema'] != null) {
              // Parse the schema as json from the database
              Map<String, dynamic> clusterSchemaData = jsonDecode(snapshot.data!['schema']);

              // Get Plot from schema
              Map<String, dynamic> plotSchemaData = clusterSchemaData['properties']['plot']['items'];

              // Make sure it's a valid map
              return JsonSchemaFormWrapper(schema: plotSchemaData, formData: {}, recordsId: widget.recordsId, previousData: previousData);
            } else if (snapshot.data!['schema'] == null) {
              // No schema found with the given ID
              return Center(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(Icons.search_off, size: 48, color: Colors.orange),
                    SizedBox(height: 16),
                    Text('Schema is null: ${widget.schemaId}'),
                    SizedBox(height: 8),
                    ElevatedButton(onPressed: () => {Beamer.of(context).beamToNamed('/')}, child: Text('Go Back')),
                  ],
                ),
              );
            } else {
              // No schema found with the given ID
              return Center(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(Icons.search_off, size: 48, color: Colors.orange),
                    SizedBox(height: 16),
                    Text('No schema-json found with ID: ${widget.schemaId}'),
                    SizedBox(height: 8),
                    ElevatedButton(onPressed: () => {Beamer.of(context).beamToNamed('/')}, child: Text('Go Back')),
                  ],
                ),
              );
            }
          } else if (snapshot.hasError) {
            // Error occurred during data fetch
            return Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.error, size: 48, color: Colors.red),
                  SizedBox(height: 16),
                  Text('Error: ${snapshot.error}'),
                  SizedBox(height: 8),
                  ElevatedButton(onPressed: () => {Beamer.of(context).beamToNamed('/')}, child: Text('Go Back')),
                ],
              ),
            );
          } else {
            // Still loading
            return Center(child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [CircularProgressIndicator(), SizedBox(height: 16), Text('Loading schema...')]));
          }
        },
      ),
    );
  }
}
