import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:terrestrial_forest_monitor/components/json-schema-form-wrapper.dart';
import 'package:terrestrial_forest_monitor/services/powersync.dart';

class DynamicFormScreen extends StatefulWidget {
  final String schemaId;
  final String plotId;
  final String clusterId;
  const DynamicFormScreen({super.key, required this.schemaId, required this.plotId, required this.clusterId});

  @override
  State<DynamicFormScreen> createState() => _DynamicFormScreenState();
}

class _DynamicFormScreenState extends State<DynamicFormScreen> {
  Map<String, dynamic>? _uiSchema = {
    'plot': {},
    'tree': {
      'ui:layout': {'type': 'grid'},
    },
    'id': {},
  };

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
              Map<String, dynamic> plotSchemaData = clusterSchemaData['items']['properties']['plot']['items'];

              // Make sure it's a valid map
              return JsonSchemaFormWrapper(schema: plotSchemaData, formData: {}, uiSchema: _uiSchema);
            } else {
              // No schema found with the given ID
              return Center(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(Icons.search_off, size: 48, color: Colors.orange),
                    SizedBox(height: 16),
                    Text('No schema found with ID: ${widget.schemaId}'),
                    SizedBox(height: 8),
                    ElevatedButton(onPressed: () => Navigator.of(context).pop(), child: Text('Go Back')),
                  ],
                ),
              );
            }
          } else if (snapshot.hasError) {
            // Error occurred during data fetch
            return Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [Icon(Icons.error, size: 48, color: Colors.red), SizedBox(height: 16), Text('Error: ${snapshot.error}'), SizedBox(height: 8), ElevatedButton(onPressed: () => Navigator.of(context).pop(), child: Text('Go Back'))],
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
