import 'package:flutter/material.dart';
import 'package:terrestrial_forest_monitor/services/validation_service.dart';

import 'package:terrestrial_forest_monitor/widgets/form-elements/record-position.dart';

class NavigationElement extends StatefulWidget {
  final Map<String, dynamic>? jsonSchema;
  final Map<String, dynamic>? data;
  final Map<String, dynamic>? previous_properties;
  final String? propertyName;
  final TFMValidationResult? validationResult;
  final Function(Map<String, dynamic>)? onDataChanged;

  const NavigationElement({
    super.key,
    this.jsonSchema,
    this.data,
    this.previous_properties,
    this.propertyName,
    this.validationResult,
    this.onDataChanged,
  });

  @override
  State<NavigationElement> createState() => _NavigationElementState();
}

class _NavigationElementState extends State<NavigationElement> with AutomaticKeepAliveClientMixin {
  @override
  bool get wantKeepAlive => true;

  @override
  Widget build(BuildContext context) {
    super.build(context); // Required for AutomaticKeepAliveClientMixin

    /*if (widget.previous_properties?['plot_coordinates'] == null) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(16.0),
          child: Text(
            'No plot coordinates available for navigation.',
            style: TextStyle(color: Colors.grey[600], fontSize: 16),
          ),
        ),
      );
    }*/

    return Column(
      children: [
        RecordPosition(
          jsonSchema: widget.jsonSchema,
          data: widget.data,
          previous_properties: widget.previous_properties,
          propertyName: widget.propertyName,
          validationResult: widget.validationResult,
          onDataChanged: widget.onDataChanged,
        ),
      ],
    );
  }
}
