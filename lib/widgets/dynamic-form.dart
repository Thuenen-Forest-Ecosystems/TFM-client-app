import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:terrestrial_forest_monitor/providers/json-schema.dart';
import 'package:terrestrial_forest_monitor/widgets/form/boolfield.dart';
import 'package:terrestrial_forest_monitor/widgets/form/tabbar.dart';
import 'package:terrestrial_forest_monitor/widgets/form/textfield.dart';

class DynamicForm extends StatefulWidget {
  final Map<dynamic, dynamic> schema;
  final Map<dynamic, dynamic> values;
  final String elementKey;

  const DynamicForm({super.key, required this.schema, required this.values, required this.elementKey});

  @override
  State<DynamicForm> createState() => _DynamicFormState();
}

class _DynamicFormState extends State<DynamicForm> {
  late Map<dynamic, dynamic> _schema;
  late Map<dynamic, dynamic> _values;
  late String _elementKey;

  Map test = {
    "name": "John Doe",
  };

  @override
  initState() {
    super.initState();
    _schema = widget.schema;
    _values = widget.values;
    _elementKey = widget.elementKey;

    //Provider.of<JsonSchemaProvider>(context, listen: false).initiate(_schema, _values[_elementKey]);
    //Provider.of<JsonSchemaProvider>(context, listen: false).validate();
  }

  Widget _getWidget(currentschema) {
    if (currentschema.containsKey('!thuenen') && currentschema['!thuenen'].containsKey('widgetType')) {
      if (currentschema['!thuenen']['widgetType'] == 'DynamicTabBar') {
        return DynamicTabBar(
          schema: currentschema['properties'],
          values: _values[_elementKey],
          elementKey: _elementKey,
        );
      } else {
        return Text('data');
      }
    } else if (currentschema['type'] == 'object') {
      List<Widget> columnChildren = [];
      currentschema['properties'].forEach((key, value) {
        if (_values.containsKey(_elementKey) && _values[_elementKey].containsKey(key)) {
          final dyForm = DynamicForm(
            schema: currentschema['properties'],
            values: _values[_elementKey],
            elementKey: key,
          );
          columnChildren.add(dyForm);
        }
      });
      return Column(
        children: columnChildren,
      );
    } else if (currentschema['type'] == 'boolean') {
      return DynamicBoolField(
        schema: currentschema,
        values: _values,
        elementKey: _elementKey,
      );
    } else if (currentschema['type'] == 'string' || currentschema['type'] == 'integer' || currentschema['type'] == 'number') {
      return DynamicTextField(
        schema: currentschema,
        values: _values,
        elementKey: _elementKey,
      );
    }

    return Text("Unknown type ${currentschema}");
  }

  @override
  Widget build(BuildContext context) {
    return _getWidget(_schema);
  }
}
