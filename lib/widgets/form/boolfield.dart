import 'package:flutter/material.dart';

class DynamicBoolField extends StatefulWidget {
  final Map<dynamic, dynamic> schema;
  final Map<dynamic, dynamic> values;
  final String elementKey;

  const DynamicBoolField({super.key, required this.schema, required this.values, required this.elementKey});

  @override
  State<DynamicBoolField> createState() => _DynamicBoolFieldState();
}

class _DynamicBoolFieldState extends State<DynamicBoolField> {
  late Map<dynamic, dynamic> _schema;
  late Map<dynamic, dynamic> _values;
  late String _elementKey;

  @override
  initState() {
    super.initState();
    _schema = widget.schema;
    _values = widget.values;
    _elementKey = widget.elementKey;
  }

  @override
  Widget build(BuildContext context) {
    return SwitchListTile(
      title: Text(_schema.containsKey('title') ? _schema['title'] : _elementKey),
      subtitle: Text(_schema.containsKey('description') ? _schema['description'] : ''),
      value: _values[_elementKey],
      onChanged: (value) {
        setState(() {
          _values[_elementKey] = value;
        });
      },
    );
  }
}
