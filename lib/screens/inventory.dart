import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:terrestrial_forest_monitor/widgets/dynamic-form.dart';

class Inventory extends StatefulWidget {
  final String schemaName;

  const Inventory({super.key, required this.schemaName});

  @override
  State<Inventory> createState() => _InventoryState();
}

class _InventoryState extends State<Inventory> {
  late String _schemaName;

  final schemas = {
    'type': 'object',
    '!thuenen': {
      'widgetType': 'DynamicTabBar',
    },
    'properties': {
      'name': {'type': 'string', 'title': 'Name'},
      'email': {'type': 'string', 'title': 'Email'},
      'age': {'type': 'integer', 'title': 'Age'},
      'address': {
        'type': 'object',
        'properties': {
          'street': {'type': 'string'},
          'city': {'type': 'string'},
          'country': {'type': 'string'},
        }
      }
    }
  };

  final clusters = [
    {
      'name': 'John Doe',
      'email': 'afsdf@sdfsf.de',
      'age': 25,
      'address': {
        'street': '123 Main Street',
        'city': 'Berlin',
        'country': 'Germany',
      }
    },
    {
      'name': 'John Doe2',
      'email': 'afsdf@sdfsf.de2',
      'age': 25,
      'address': {
        'street': '123 Main Street',
        'city': 'Berlin',
        'country': 'Germany',
      }
    }
  ];
  Map<String, dynamic>? _firstCluster;

  Future<Map<String, dynamic>> _loadSampleData() async {
    String data = await DefaultAssetBundle.of(context).loadString("assets/sample/select-response.json");

    List<dynamic> jsonResult = jsonDecode(data);

    if (jsonResult.isEmpty || jsonResult[0] == null) {
      return Future.value({});
    }

    return jsonResult[0];
  }

  Future<Map<dynamic, dynamic>> _loadSampleSchema() async {
    String data = await DefaultAssetBundle.of(context).loadString("assets/sample/schema.json");
    final jsonResult = jsonDecode(data);
    return jsonResult;
  }

  @override
  initState() {
    super.initState();
    _schemaName = widget.schemaName;
    //_firstCluster = clusters[0];
    //_loadSampleData();
    //_loadSampleSchema();
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder(
      future: Future.wait([
        _loadSampleData(),
        _loadSampleSchema(),
      ]),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return Center(
            child: CircularProgressIndicator(),
          );
        }
        if (snapshot.hasError) {
          return Center(
            child: Text('Error: ${snapshot.error}'),
          );
        }
        if (!snapshot.hasData || snapshot.data!.isEmpty) {
          return Center(
            child: Text('No data available'),
          );
        }

        // Assuming you want to use the data in DynamicForm
        return DynamicForm(
          schema: snapshot.data?[1] as Map<String, dynamic>,
          values: {
            'initialValues': snapshot.data?[0] as Map<String, dynamic>,
          } as Map<String, dynamic>,
          elementKey: 'initialValues',
        );
      },
    );
  }
}
