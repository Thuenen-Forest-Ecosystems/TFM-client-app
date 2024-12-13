import 'package:flutter/material.dart';
import 'package:terrestrial_forest_monitor/services/api.dart';
import 'package:terrestrial_forest_monitor/widgets/dynamic-form.dart';
import 'dart:convert';

class PlotEdit extends StatefulWidget {
  final String schemaId;
  final String plotId;
  final String clusterId;
  const PlotEdit({super.key, required this.schemaId, required this.plotId, required this.clusterId});

  @override
  State<PlotEdit> createState() => _PlotEditState();
}

class _PlotEditState extends State<PlotEdit> {
  final GlobalKey<FormState> _formKey = GlobalKey<FormState>();
  String? _plotId;
  String? _clusterId;
  String? _schemaId;

  @override
  void initState() {
    super.initState();
    _plotId = widget.plotId;
    _clusterId = widget.clusterId;
    _schemaId = widget.schemaId;
  }

  Future<Map<dynamic, dynamic>> _loadSampleSchema() async {
    String data = await DefaultAssetBundle.of(context).loadString("assets/sample/schema.json");
    final jsonResult = jsonDecode(data);
    return jsonResult;
  }

  Future<Map<dynamic, dynamic>> _loadSampleData() async {
    return await ApiService().getCluster(_clusterId);
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

        print('---------');
        print(snapshot.data![1]['properties']['plot']['items']);

        // Assuming you want to use the data in DynamicForm
        return Form(
          key: _formKey,
          onChanged: () {
            print('Form changed');

            Future.delayed(Duration(milliseconds: 1), () {
              print(snapshot.data?[0]['id']);
            });
          },
          child: DynamicForm(
            schema: snapshot.data![1]['properties']['plot']['items'],
            values: {
              'initialValues': snapshot.data?[0]['plot'][0],
            },
            elementKey: 'initialValues',
          ),
        );
      },
    );
  }
}
