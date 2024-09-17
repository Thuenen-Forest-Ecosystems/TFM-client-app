import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

class DynamicTextField extends StatefulWidget {
  final Map<dynamic, dynamic> schema;
  final Map<dynamic, dynamic> values;
  final String elementKey;

  const DynamicTextField({super.key, required this.schema, required this.values, required this.elementKey});

  @override
  State<DynamicTextField> createState() => _DynamicTextFieldState();
}

class _DynamicTextFieldState extends State<DynamicTextField> {
  late Map<dynamic, dynamic> _schema;
  late Map<dynamic, dynamic> _values;
  late String _elementKey;
  late TextEditingController _controller;

  List<TextInputFormatter> _inputFormatters = [];

  @override
  initState() {
    super.initState();
    _schema = widget.schema;
    _values = widget.values;
    _elementKey = widget.elementKey;
    _controller = TextEditingController(text: _values[_elementKey].toString());

    if (_schema['type'] == 'integer') {
      _inputFormatters.add(FilteringTextInputFormatter.digitsOnly);
    } else {
      //_values[_elementKey] = 'sdfdf';
    }

    _controller.addListener(() {
      //widget.valueNotifier.value[_elementKey] = _controller.text;
      //widget.valueNotifier.notifyListeners();
    });
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: EdgeInsets.all(10),
      child: TextFormField(
        readOnly: _schema['readOnly'] ?? false,
        onChanged: (value) => _values[_elementKey] = value,
        controller: _controller,
        inputFormatters: _inputFormatters,
        decoration: InputDecoration(
          hintText: 'What do people call you?',
          border: OutlineInputBorder(),
          labelText: _schema.containsKey('title') ? _schema['title'] : _elementKey,
        ),
      ),
    );
  }
}
