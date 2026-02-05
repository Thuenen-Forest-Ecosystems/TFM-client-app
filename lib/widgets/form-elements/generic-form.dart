import 'package:flutter/material.dart';
import 'package:terrestrial_forest_monitor/services/validation_service.dart';
import 'package:terrestrial_forest_monitor/widgets/form-elements/generic-textfield.dart';

class GenericForm extends StatefulWidget {
  final Map<String, dynamic>? jsonSchema;
  final Map<String, dynamic> data;
  final Map<String, dynamic>? previous_properties;
  final String? propertyName;
  final TFMValidationResult? validationResult;
  final Function(Map<String, dynamic>)? onDataChanged;
  final List<String>? includeProperties; // Optional filter for which properties to show
  final Map<String, dynamic>? fieldOptions; // Per-field configuration (width, etc.)
  final Map<String, dynamic>? layoutOptions; // General layout configuration
  final bool isDense;
  final String? layout;
  const GenericForm({
    super.key,
    this.jsonSchema,
    required this.data,
    this.previous_properties,
    this.propertyName,
    this.validationResult,
    this.onDataChanged,
    this.includeProperties,
    this.fieldOptions,
    this.layoutOptions,
    this.isDense = false,
    this.layout,
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

    final propertyPath = widget.propertyName != null
        ? '/${widget.propertyName}/$fieldName'
        : '/$fieldName';

    return widget.validationResult!.ajvErrors.where((error) {
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
    final properties = widget.jsonSchema!.containsKey('properties')
        ? widget.jsonSchema!['properties'] as Map<String, dynamic>?
        : widget.jsonSchema;

    if (properties == null || properties.isEmpty) {
      return const Center(child: Text('No properties in schema'));
    }

    // Filter properties based on includeProperties and collect primitive types
    final fieldsToShow = <MapEntry<String, Map<String, dynamic>>>[];

    // If includeProperties is specified, iterate in that order to maintain layout order
    final propertiesToProcess = widget.includeProperties ?? properties.keys.toList();

    for (final key in propertiesToProcess) {
      final value = properties[key];
      if (value == null) continue; // Skip if property not in schema

      if (value is Map<String, dynamic>) {
        // Check if field should be hidden via $tfm.form.ui:options.display
        // However, if includeProperties is specified (from layout), it overrides the schema display setting
        final tfmData = value['\$tfm'] as Map<String, dynamic>?;
        final formOptions = tfmData?['form'] as Map<String, dynamic>?;
        final uiOptions = formOptions?['ui:options'] as Map<String, dynamic>?;
        final shouldDisplay = uiOptions?['display'] as bool? ?? true;

        // If includeProperties is set, layout takes precedence - show the field
        if (!shouldDisplay && widget.includeProperties == null) {
          continue; // Skip this field only if not explicitly included by layout
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
          fieldsToShow.add(MapEntry(key, value));
        }
      }
    }

    if (fieldsToShow.isEmpty) {
      return const Center(child: Text('No primitive fields in schema'));
    }

    debugPrint('GenericForm layout mode: ${widget.layout}');
    debugPrint('GenericForm fieldOptions: ${widget.fieldOptions}');

    return LayoutBuilder(
      builder: (context, constraints) {
        Widget buildFieldWidget(
          MapEntry<String, Map<String, dynamic>> entry, {
          bool isFlexible = false,
        }) {
          final fieldName = entry.key;
          final fieldSchema = entry.value;
          final fieldErrors = _getErrorsForField(fieldName);
          final fieldConfig = widget.fieldOptions?[fieldName] as Map<String, dynamic>?;

          // Support width, minWidth, maxWidth
          final width = (fieldConfig?['width'] as num?)?.toDouble();
          final minWidth = (fieldConfig?['minWidth'] as num?)?.toDouble() ?? 100.0;
          final maxWidth = (fieldConfig?['maxWidth'] as num?)?.toDouble() ?? double.infinity;

          final textField = GenericTextField(
            fieldName: fieldName,
            fieldSchema: fieldSchema,
            value: _localData[fieldName],
            errors: fieldErrors,
            onChanged: (value) => _updateField(fieldName, value),
            dense: widget.isDense,
            previousData: widget.previous_properties,
            currentData: _localData,
            fieldOptions: fieldConfig,
          );

          // If fixed width is specified, use SizedBox
          if (width != null) {
            return Padding(
              padding: const EdgeInsets.all(10),
              child: SizedBox(width: width, child: textField),
            );
          }

          // If flexible layout, use Expanded with constraints
          if (isFlexible) {
            return Expanded(
              child: Padding(
                padding: const EdgeInsets.all(10),
                child: ConstrainedBox(
                  constraints: BoxConstraints(minWidth: minWidth, maxWidth: maxWidth),
                  child: textField,
                ),
              ),
            );
          }

          // Default: fixed width of 200
          return Padding(
            padding: const EdgeInsets.all(10),
            child: SizedBox(child: textField),
          );
        }

        if (widget.layout == 'horizontal-scroll') {
          final fieldWidgets = fieldsToShow.map((e) => buildFieldWidget(e)).toList();
          return SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Row(children: fieldWidgets),
          );
        } else if (widget.layout == 'responsive-wrap') {
          // Grid system based on screen width
          final screenWidth = constraints.maxWidth;
          int columns;

          // Determine number of columns based on screen width breakpoints
          if (screenWidth >= 1200) {
            columns = 3; // Large screens: 3 columns
          } else if (screenWidth >= 700) {
            columns = 2; // Medium screens: 2 columns
          } else {
            columns = 1; // Small screens: 1 column
          }

          debugPrint('Responsive grid: screenWidth=$screenWidth, columns=$columns');

          // Calculate column width
          final spacing = 10.0;
          final totalSpacing = spacing * (columns - 1);
          final columnWidth = (screenWidth - totalSpacing) / columns;

          // Build fields with fixed column width
          final fieldWidgets = fieldsToShow.map((entry) {
            final fieldName = entry.key;
            final fieldSchema = entry.value;
            final fieldErrors = _getErrorsForField(fieldName);
            final fieldConfig = widget.fieldOptions?[fieldName] as Map<String, dynamic>?;

            return Padding(
              padding: const EdgeInsets.all(5),
              child: SizedBox(
                width: columnWidth - 10, // Account for padding
                child: GenericTextField(
                  fieldName: fieldName,
                  fieldSchema: fieldSchema,
                  value: _localData[fieldName],
                  errors: fieldErrors,
                  onChanged: (value) => _updateField(fieldName, value),
                  dense: widget.isDense,
                  previousData: widget.previous_properties,
                  currentData: _localData,
                  fieldOptions: fieldConfig,
                ),
              ),
            );
          }).toList();

          // Wrap layout will automatically flow to next row
          return Wrap(spacing: spacing, runSpacing: spacing, children: fieldWidgets);
        } else {
          // Default Wrap layout with fixed widths
          final fieldWidgets = fieldsToShow.map((e) => buildFieldWidget(e)).toList();
          return Wrap(spacing: 5, runSpacing: 5, children: fieldWidgets);
        }
        /*
        if (columns == 1) {
          // Single column: use Column instead of ListView to avoid scrolling
          return Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            mainAxisSize: MainAxisSize.min,
            children: fieldWidgets,
          );
        } else {
          // Multiple columns: use Wrap layout
          return Wrap(
            spacing: 20, // Horizontal spacing between items
            runSpacing: 20, // Vertical spacing between rows
            children: fieldWidgets.map((widget) {
              return SizedBox(
                width: (constraints.maxWidth - 32 - (20 * (columns - 1))) / columns,
                child: widget,
              );
            }).toList(),
          );
        }*/
      },
    );
  }
}
