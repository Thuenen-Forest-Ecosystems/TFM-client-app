/// Example: Creating a Custom Card Component for Layout System
///
/// This example shows how to create a new component type that can be
/// used in layout configurations.

import 'package:flutter/material.dart';
import 'package:terrestrial_forest_monitor/services/validation_service.dart';
import 'package:terrestrial_forest_monitor/widgets/form-elements/generic-form.dart';

/// Custom Card Component for displaying object data in an expandable card
///
/// Usage in layout JSON:
/// ```json
/// {
///   "id": "details",
///   "label": "Details",
///   "type": "object",
///   "component": "expandable-card",
///   "property": "plot_details"
/// }
/// ```
class ExpandableCardElement extends StatefulWidget {
  final Map<String, dynamic>? jsonSchema;
  final Map<String, dynamic>? data;
  final Map<String, dynamic>? previousProperties;
  final String? propertyName;
  final TFMValidationResult? validationResult;
  final Function(Map<String, dynamic>)? onDataChanged;
  final String? title;

  const ExpandableCardElement({
    super.key,
    this.jsonSchema,
    this.data,
    this.previousProperties,
    this.propertyName,
    this.validationResult,
    this.onDataChanged,
    this.title,
  });

  @override
  State<ExpandableCardElement> createState() => _ExpandableCardElementState();
}

class _ExpandableCardElementState extends State<ExpandableCardElement> {
  bool _isExpanded = false;

  @override
  Widget build(BuildContext context) {
    final schema = widget.propertyName != null
        ? {widget.propertyName!: widget.jsonSchema?[widget.propertyName]}
        : widget.jsonSchema;

    final title =
        widget.title ??
        widget.jsonSchema?[widget.propertyName]?['title'] as String? ??
        widget.propertyName ??
        'Details';

    return Card(
      margin: const EdgeInsets.all(8.0),
      elevation: 2,
      child: Column(
        children: [
          ListTile(
            title: Text(title, style: Theme.of(context).textTheme.titleMedium),
            trailing: Icon(_isExpanded ? Icons.expand_less : Icons.expand_more),
            onTap: () {
              setState(() {
                _isExpanded = !_isExpanded;
              });
            },
          ),
          if (_isExpanded)
            Padding(
              padding: const EdgeInsets.all(16.0),
              child: GenericForm(
                jsonSchema: schema,
                data: widget.data ?? {},
                propertyName: widget.propertyName,
                previous_properties: widget.previousProperties,
                validationResult: widget.validationResult,
                onDataChanged: widget.onDataChanged,
              ),
            ),
        ],
      ),
    );
  }
}

/// Example: How to integrate this component into FormWrapper
/// 
/// In form-wrapper.dart, add to _buildWidgetFromLayout method:
/// 
/// ```dart
/// } else if (layoutItem is ObjectLayout) {
///   final propertyName = layoutItem.property;
///   
///   if (layoutItem.component == 'navigation') {
///     // ... existing code
///   } else if (layoutItem.component == 'card') {
///     // ... existing code
///   } else if (layoutItem.component == 'expandable-card') {
///     // NEW: Add expandable card component
///     return ExpandableCardElement(
///       jsonSchema: schemaProperties,
///       data: _localFormData[propertyName],
///       propertyName: propertyName,
///       previous_properties: _previousProperties,
///       validationResult: widget.validationResult,
///       onDataChanged: (updatedData) {
///         _updateField(propertyName, updatedData);
///       },
///     );
///   }
/// }
/// ```
/// 
/// Then use in layout JSON:
/// 
/// ```json
/// {
///   "layout": {
///     "type": "tabs",
///     "items": [
///       {
///         "id": "plot_info",
///         "label": "Plot Information",
///         "type": "object",
///         "component": "expandable-card",
///         "property": "plot_coordinates"
///       }
///     ]
///   }
/// }
/// ```
