import 'package:flutter/material.dart';
import 'package:json_schema/json_schema.dart';
import 'dart:convert';

class SchemaValidBtn extends StatefulWidget {
  final Map values;
  const SchemaValidBtn({super.key, required this.values});

  @override
  State<SchemaValidBtn> createState() => _SchemaValidBtnState();
}

class _SchemaValidBtnState extends State<SchemaValidBtn> {
  late JsonSchema _jsonSchema;
  //ValidationResults? validationResult;

  @override
  initState() {
    super.initState();
    _loadSchema();
  }

  Future _loadSchema() async {
    String _schema = await DefaultAssetBundle.of(context).loadString("assets/sample/schema_dereferenced.json");
    Map _schemaMap = jsonDecode(_schema);
    _jsonSchema = JsonSchema.create(_schemaMap);
  }

  ValidationResults _checkIfValidJson(data) {
    ValidationResults validationResult = _jsonSchema.validate(data);
    // Get the errors
    for (var error in validationResult!.errors) {
      print(error.instancePath);
      print(error.runtimeType);
      print(error.schemaPath);
    }
    return validationResult;
  }

  Future<void> _errorsDialog(ValidationResults validationResults) async {
    return showDialog<void>(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: Text('Errors'),
          content: Column(
            mainAxisAlignment: MainAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: validationResults.errors.map((error) {
              return ListTile(
                title: Text(error.instancePath ?? ''),
                subtitle: Text(error.schemaPath ?? ''),
              );
            }).toList(),
          ),
          actions: <Widget>[
            TextButton(
              onPressed: () {
                Navigator.of(context).pop();
              },
              child: Text('Close'),
            ),
          ],
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder(
        future: _loadSchema(),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.done) {
            ValidationResults validationResult = _checkIfValidJson(widget.values);
            if (validationResult.errors.isEmpty) {
              return ChoiceChip(
                label: Text('Valid'),
                selected: validationResult.errors.isEmpty,
                onSelected: (bool selected) {
                  /*if (!validationResult) {
                    print('Invalid');
                  }*/
                  _errorsDialog(validationResult);
                },
              );
            } else {
              return Text(validationResult!.errors.length.toString());
            }
          } else {
            return Text('Loading...');
          }
        });
  }
}
