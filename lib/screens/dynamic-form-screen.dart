import 'dart:convert';

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
  // Example UI schema for tree array
  Map<String, dynamic> _uiSchema = {
    // MAKE deprecated
    "ui:layout": {"type": "grid"},
    "intkey": {"ui:widget": "hidden"},
    "cluster_name": {"ui:widget": "hidden"},
    "federal_state": {
      "ui:layout": {"maxWidth": 300.0, "autocomplete": true},
    },
    "growth_district": {
      "ui:layout": {"maxWidth": 300.0, "autocomplete": true},
    },
    "forest_office": {
      "ui:layout": {"maxWidth": 300.0, "autocomplete": true},
    },

    "tree": {
      "ui:layout": {"fullWidth": true, "clearFloat": true},
      "items": {
        "ui:layout": {"type": "grid"},
      },
    },
    "deadwood": {
      "ui:layout": {"fullWidth": true, "clearFloat": true},
      "items": {
        "ui:layout": {"type": "grid"},
      },
    },
    "position": {
      "ui:layout": {"fullWidth": true, "clearFloat": true},
      "items": {
        "ui:layout": {"type": "grid"},
      },
    },
    "edges": {
      "ui:layout": {"fullWidth": true, "clearFloat": true},
      "items": {
        "ui:layout": {"type": "grid"},
      },
    },
    "subplots_relative_position": {
      "ui:widget": "hidden",
      "ui:layout": {"fullWidth": true, "clearFloat": true},
      "items": {
        "ui:layout": {"type": "grid"},
      },
    },
    "regeneration": {
      "ui:layout": {"fullWidth": true, "clearFloat": true},
      "items": {
        "ui:layout": {"type": "grid"},
      },
    },
    "structure_lt4m": {
      "ui:layout": {"fullWidth": true, "clearFloat": true},
      "items": {
        "ui:layout": {"type": "grid"},
      },
    },
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
              Map<String, dynamic> plotSchemaData = clusterSchemaData['properties']['plot']['items'];

              // Make sure it's a valid map
              return JsonSchemaFormWrapper(schema: plotSchemaData, formData: {}, recordsId: widget.recordsId);
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
