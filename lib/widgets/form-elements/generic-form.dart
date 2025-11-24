import 'package:flutter/material.dart';
import 'package:terrestrial_forest_monitor/services/validation_service.dart';
import 'package:terrestrial_forest_monitor/widgets/form-elements/generic-textfield.dart';

class GenericForm extends StatefulWidget {
  final Map<String, dynamic>? jsonSchema;
  final Map<String, dynamic> data;
  final Map<String, dynamic>? previous_properties;
  final String? propertyName;
  final ValidationResult? validationResult;
  final Function(Map<String, dynamic>)? onDataChanged;
  const GenericForm({
    super.key,
    this.jsonSchema,
    required this.data,
    this.previous_properties,
    this.propertyName,
    this.validationResult,
    this.onDataChanged,
  });

  @override
  State<GenericForm> createState() => _GenericFormState();
}

class _GenericFormState extends State<GenericForm> {
  late Map<String, dynamic> _localData;

  @override
  void initState() {
    super.initState();
    _localData = Map<String, dynamic>.from(widget.data);
  }

  @override
  void didUpdateWidget(GenericForm oldWidget) {
    super.didUpdateWidget(oldWidget);
    // Don't reset local data when parent data changes during validation
    // This would discard user edits in progress
    // The parent data updates are triggered by our own _updateField calls
  }

  void _updateField(String key, dynamic value) {
    setState(() {
      _localData[key] = value;
    });
    widget.onDataChanged?.call(Map<String, dynamic>.from(_localData));
  }

  List<ValidationError> _getErrorsForField(String fieldName) {
    if (widget.validationResult == null) return [];

    final propertyPath =
        widget.propertyName != null ? '/${widget.propertyName}/$fieldName' : '/$fieldName';

    return widget.validationResult!.errors.where((error) {
      final path = error.instancePath ?? '';
      // Match exact field or nested within field
      return path == propertyPath || path.startsWith('$propertyPath/');
    }).toList();
  }

  @override
  Widget build(BuildContext context) {
    if (widget.jsonSchema == null) {
      return const Center(child: Text('No schema available'));
    }

    // The jsonSchema might already be the properties object, or it might have a 'properties' key
    final properties =
        widget.jsonSchema!.containsKey('properties')
            ? widget.jsonSchema!['properties'] as Map<String, dynamic>?
            : widget.jsonSchema;

    if (properties == null || properties.isEmpty) {
      return const Center(child: Text('No properties in schema'));
    }

    // Filter out arrays and objects, keep only primitive types
    final primitiveFields = <String, Map<String, dynamic>>{};
    properties.forEach((key, value) {
      if (value is Map<String, dynamic>) {
        // Check if field should be hidden via $tfm.form.ui:options.display
        final tfmData = value['\$tfm'] as Map<String, dynamic>?;
        final formOptions = tfmData?['form'] as Map<String, dynamic>?;
        final uiOptions = formOptions?['ui:options'] as Map<String, dynamic>?;
        final shouldDisplay = uiOptions?['display'] as bool? ?? true;

        if (!shouldDisplay) {
          return; // Skip this field
        }

        final typeValue = value['type'];

        // Handle type as string or array
        String? type;
        if (typeValue is String) {
          type = typeValue;
        } else if (typeValue is List) {
          // Find first non-null type in the array
          type = typeValue.firstWhere((t) => t != 'null', orElse: () => null) as String?;
        }

        // Include only primitive types (string, number, integer, boolean)
        // Exclude array and object types
        if (type == 'string' || type == 'number' || type == 'integer' || type == 'boolean') {
          primitiveFields[key] = value;
        }
      }
    });

    if (primitiveFields.isEmpty) {
      return const Center(child: Text('No primitive fields in schema'));
    }

    return ListView(
      padding: const EdgeInsets.all(16),
      children:
          primitiveFields.entries.map((entry) {
            final fieldName = entry.key;
            final fieldSchema = entry.value;
            final fieldErrors = _getErrorsForField(fieldName);

            return Padding(
              padding: const EdgeInsets.only(bottom: 26),
              child: GenericTextField(
                fieldName: fieldName,
                fieldSchema: fieldSchema,
                value: _localData[fieldName],
                errors: fieldErrors,
                onChanged: (value) => _updateField(fieldName, value),
              ),
            );
          }).toList(),
    );
  }
}
