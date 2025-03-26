import 'package:flutter/material.dart';
import 'package:json_schema/json_schema.dart';
import 'package:terrestrial_forest_monitor/components/array-field-editor.dart';

class JsonSchemaForm extends StatefulWidget {
  final Map<String, dynamic> schema;
  final Map<String, dynamic>? initialData;
  final Map<String, dynamic>? uiSchema;
  final Map<String, dynamic>? formData;
  final Map<String, dynamic>? formErrors;
  final void Function(Map<String, dynamic>)? onChanged;
  final void Function(Map<String, dynamic>)? onError;
  final void Function()? onReset;
  final void Function()? onCancel;
  final void Function(Map<String, dynamic>) onSubmit;

  const JsonSchemaForm({Key? key, required this.schema, this.initialData, this.uiSchema, this.formData, this.formErrors, this.onChanged, this.onError, this.onReset, this.onCancel, required this.onSubmit}) : super(key: key);

  @override
  State<JsonSchemaForm> createState() => _JsonSchemaFormState();
}

class _JsonSchemaFormState extends State<JsonSchemaForm> {
  final _formKey = GlobalKey<FormState>();
  late Map<String, dynamic> _localFormData;
  late Map<String, dynamic> _localFormErrors;
  final Map<String, TextEditingController> _controllers = {};
  bool _formInitialized = false;
  late JsonSchema _jsonSchema;

  @override
  void initState() {
    super.initState();
    // Create a schema validator from the provided schema
    _jsonSchema = JsonSchema.create(widget.schema);
    _initializeForm();
  }

  @override
  void didUpdateWidget(JsonSchemaForm oldWidget) {
    super.didUpdateWidget(oldWidget);

    // If external formData changed, update our controllers
    if (widget.formData != oldWidget.formData) {
      _updateControllersFromFormData();
    }

    // If external errors changed, refresh the UI
    if (widget.formErrors != oldWidget.formErrors) {
      setState(() {
        _localFormErrors = _typeSafeMap<String, dynamic>(widget.formErrors) ?? {};
      });
    }
  }

  // Helper method to ensure maps have String keys
  Map<K, V> _typeSafeMap<K, V>(Map? map) {
    if (map == null) return <K, V>{};

    final result = <K, V>{};
    map.forEach((key, value) {
      if (key is K && (value is V || value == null)) {
        result[key] = value;
      }
    });
    return result;
  }

  void _initializeForm() {
    // Initialize with formData if provided, otherwise use initialData or empty map
    _localFormData = _typeSafeMap<String, dynamic>(widget.formData) ?? _typeSafeMap<String, dynamic>(widget.initialData) ?? {};
    _localFormErrors = _typeSafeMap<String, dynamic>(widget.formErrors) ?? {};
    _initializeControllers();
    _formInitialized = true;
  }

  void _initializeControllers() {
    if (widget.schema['properties'] != null) {
      final properties = widget.schema['properties'] as Map<String, dynamic>;

      for (final field in properties.entries) {
        final fieldName = field.key;
        final value = _getFieldValue(fieldName)?.toString() ?? '';

        _controllers[fieldName] = TextEditingController(text: value);
      }
    }
  }

  void _updateControllersFromFormData() {
    if (!_formInitialized) return;

    _localFormData = _typeSafeMap<String, dynamic>(widget.formData) ?? {};

    // Update controllers with new values
    if (widget.schema['properties'] != null) {
      final properties = widget.schema['properties'] as Map<String, dynamic>;

      for (final field in properties.entries) {
        final fieldName = field.key;
        final controller = _controllers[fieldName];

        if (controller != null) {
          final newValue = _getFieldValue(fieldName)?.toString() ?? '';

          // Only update if different to avoid cursor position resets
          if (controller.text != newValue) {
            controller.text = newValue;
          }
        }
      }
    }

    setState(() {});
  }

  dynamic _getFieldValue(String fieldName) {
    // Get value from formData if available
    if (widget.formData != null && widget.formData!.containsKey(fieldName)) {
      return widget.formData![fieldName];
    }

    return _localFormData[fieldName];
  }

  void _updateField(String name, dynamic value) {
    // Update the field value without validation
    if (widget.formData != null) {
      // Use provided external formData if available
      final updatedData = _typeSafeMap<String, dynamic>(widget.formData);
      updatedData[name] = value;

      // Call onChanged callback if available
      widget.onChanged?.call(updatedData);
    } else {
      // Otherwise update internal state
      setState(() {
        _localFormData[name] = value;
      });

      // Call onChanged with updated data
      widget.onChanged?.call(_typeSafeMap<String, dynamic>(_localFormData));
    }
  }

  String? _getFieldError(String name) {
    // Only use errors passed from parent component
    if (widget.formErrors != null && widget.formErrors!.containsKey(name)) {
      return widget.formErrors![name]?.toString();
    }
    return null;
  }

  @override
  void dispose() {
    for (final controller in _controllers.values) {
      controller.dispose();
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Form(key: _formKey, child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [const SizedBox(height: 16), ..._buildFormFields(), const SizedBox(height: 16)]));
  }

  List<Widget> _buildFormFields() {
    final List<Widget> fields = [];
    final properties = _typeSafeMap<String, dynamic>(widget.schema['properties']) ?? {};
    final required = List<String>.from(widget.schema['required'] ?? []);

    // Get global layout options from uiSchema
    final layoutOptions = _typeSafeMap<String, dynamic>(widget.uiSchema?['ui:layout']) ?? {};
    final double defaultFieldWidth = (layoutOptions['fieldWidth'] as double?) ?? 300.0;
    final double fieldSpacing = (layoutOptions['spacing'] as double?) ?? 16.0;
    final double rowSpacing = (layoutOptions['rowSpacing'] as double?) ?? 16.0;
    final String layoutType = (layoutOptions['type'] as String?) ?? 'column';

    // If layout type is responsive or grid, use Wrap layout
    if (layoutType == 'responsive' || layoutType == 'grid') {
      final List<Widget> fieldWidgets = [];

      for (final entry in properties.entries) {
        final fieldName = entry.key;
        final fieldSchema = _typeSafeMap<String, dynamic>(entry.value) ?? {};
        final isRequired = required.contains(fieldName);

        // Skip hidden fields
        if (widget.uiSchema != null && widget.uiSchema![fieldName] != null && widget.uiSchema![fieldName]['ui:widget'] == 'hidden') {
          continue;
        }

        // Get field-specific layout options
        final fieldUiOptions = _typeSafeMap<String, dynamic>(widget.uiSchema?[fieldName]) ?? {};
        final fieldLayoutOptions = _typeSafeMap<String, dynamic>(fieldUiOptions['ui:layout']) ?? {};

        // Calculate field width - default or specified in ui:layout
        double maxWidth = defaultFieldWidth;
        if (fieldLayoutOptions.containsKey('maxWidth')) {
          maxWidth = fieldLayoutOptions['maxWidth'] as double;
        } else if (fieldLayoutOptions.containsKey('span')) {
          // If using span (out of 12 columns), calculate proportional width
          // Handle span as either int or double
          final dynamic spanValue = fieldLayoutOptions['span'];
          final double spanDouble =
              spanValue is int
                  ? spanValue.toDouble()
                  : spanValue is double
                  ? spanValue
                  : 12.0;

          // Now safely use the double value
          maxWidth = (MediaQuery.of(context).size.width - 32) * (spanDouble / 12.0);
        }

        bool isFullWidth = fieldLayoutOptions['fullWidth'] == true;
        bool shouldClearFloat = fieldLayoutOptions['clearFloat'] == true;

        fieldWidgets.add(
          Padding(
            padding: EdgeInsets.only(right: fieldSpacing, bottom: rowSpacing),
            child: ConstrainedBox(
              constraints: BoxConstraints(
                // Fix: Properly handle numeric values in maxWidth
                maxWidth: isFullWidth ? double.infinity : (fieldLayoutOptions['maxWidth'] is num ? (fieldLayoutOptions['maxWidth'] as num).toDouble() : maxWidth),
                minWidth: isFullWidth ? MediaQuery.of(context).size.width - fieldSpacing : 200.0,
              ),
              child: _buildField(fieldName, fieldSchema, isRequired),
            ),
          ),
        );
      }

      fields.add(
        LayoutBuilder(
          builder: (context, constraints) {
            // Dynamic calculation based on actual available width
            final availableWidth = constraints.maxWidth;
            final columnsPerRow = (availableWidth / 300).floor().clamp(1, 4);
            // Make sure all numbers are doubles in this calculation
            final itemWidth = (availableWidth / columnsPerRow.toDouble()) - fieldSpacing;

            return Wrap(
              spacing: fieldSpacing,
              runSpacing: rowSpacing,
              children:
                  fieldWidgets.asMap().entries.map((entry) {
                    final fieldWidget = entry.value;
                    final fieldIndex = entry.key;
                    final fieldName = properties.keys.elementAt(fieldIndex);
                    final fieldUiOptions = _typeSafeMap<String, dynamic>(widget.uiSchema?[fieldName]) ?? {};
                    final fieldLayoutOptions = _typeSafeMap<String, dynamic>(fieldUiOptions['ui:layout']) ?? {};
                    final isFullWidth = fieldLayoutOptions['fullWidth'] == true;
                    final shouldClearFloat = fieldLayoutOptions['clearFloat'] == true;

                    if (isFullWidth || shouldClearFloat) {
                      // Add an empty SizedBox of full width to force a new line before this widget
                      // only if it's not the first widget
                      if (fieldIndex > 0 && shouldClearFloat) {
                        return SizedBox(
                          // Fix: Respect the original maxWidth setting when provided
                          width: isFullWidth ? constraints.maxWidth : (fieldLayoutOptions.containsKey('maxWidth') ? (fieldLayoutOptions['maxWidth'] is num ? (fieldLayoutOptions['maxWidth'] as num).toDouble() : defaultFieldWidth) : itemWidth),
                          child: fieldWidget,
                        );
                      }
                      return SizedBox(width: isFullWidth ? constraints.maxWidth : itemWidth, child: fieldWidget);
                    } else {
                      // Regular fields can be placed side by side
                      return SizedBox(width: itemWidth, child: fieldWidget);
                    }
                  }).toList(),
            );
          },
        ),
      );
    } else {
      // Original column layout
      for (final entry in properties.entries) {
        final fieldName = entry.key;
        final fieldSchema = _typeSafeMap<String, dynamic>(entry.value) ?? {};
        final isRequired = required.contains(fieldName);

        if (widget.uiSchema != null && widget.uiSchema![fieldName] != null && widget.uiSchema![fieldName]['ui:widget'] == 'hidden') {
          continue;
        }

        fields.add(Padding(padding: const EdgeInsets.only(bottom: 16), child: _buildField(fieldName, fieldSchema, isRequired)));
      }
    }

    return fields;
  }

  // Add this helper method to safely extract string values
  String? _safeStringValue(dynamic value) {
    if (value == null) return null;
    if (value is String) return value;
    return value.toString();
  }

  // Add this helper method to determine the effective type from schema
  String _getEffectiveType(dynamic typeValue) {
    if (typeValue == null) return 'string';

    if (typeValue is List) {
      // Find first non-null type in the array
      for (final type in typeValue) {
        if (type != null && type != 'null') {
          return type.toString();
        }
      }
      return 'string'; // Default if all null or only "null" type
    }

    return typeValue.toString();
  }

  Widget _buildField(String fieldName, Map<String, dynamic> fieldSchema, bool isRequired) {
    // Get field type safely
    final String fieldType = _getEffectiveType(fieldSchema['type']);

    // Get field title safely
    final dynamic titleValue = fieldSchema['title'];
    final String fieldTitle = titleValue is String ? titleValue : fieldName;

    // Get description safely
    final dynamic descriptionValue = fieldSchema['description'];
    final String? description = descriptionValue is String ? descriptionValue : null;

    // Get UI options
    final fieldUiOptions = _typeSafeMap<String, dynamic>(widget.uiSchema?[fieldName]) ?? {};
    final widgetType = fieldUiOptions['ui:widget'] as String?;

    // Check for enum fields first - this takes priority over other field types
    if (fieldSchema['enum'] != null) {
      final dynamic enumValues = fieldSchema['enum'];
      if (enumValues is List<dynamic>) {
        // Get enum names if available
        List<String>? enumNames;
        // Check standard JSON Schema enumNames
        if (fieldSchema['enumNames'] is List) {
          enumNames = List<String>.from(fieldSchema['enumNames'] as List);
        }
        // Check TFM-specific extension for enum names
        else if (fieldSchema['\$tfm'] != null && fieldSchema['\$tfm'] is Map && fieldSchema['\$tfm']['name_de'] is List) {
          final tempList = List<String?>.from(fieldSchema['\$tfm']['name_de'] as List);
          // if all values are null add "kein wert"
          enumNames = tempList.every((element) => element == null) ? ['kein wert'] : tempList.map((e) => e ?? 'kein wert').toList();
        }

        // Use the dedicated enum field builder
        return _buildEnumField(fieldName, fieldTitle, description, enumValues, enumNames, fieldSchema);
      }
    }

    // Handle tabs object
    if (fieldType == 'object' && widgetType == 'tabs') {
      return _buildTabsObjectField(fieldName, fieldTitle, fieldSchema, isRequired);
    }

    // Rest of your field type handling
    switch (fieldType) {
      case 'string':
        return _buildTextField(fieldName, fieldTitle, description, fieldSchema, isRequired, fieldUiOptions);
      case 'integer':
      case 'number':
        return _buildNumberField(fieldName, fieldTitle, description, fieldSchema, isRequired);
      case 'boolean':
        return _buildBooleanField(fieldName, fieldTitle, description, fieldSchema);
      case 'array':
        return _buildArrayField(fieldName, fieldTitle, description, fieldSchema, isRequired);
      case 'object':
        return _buildObjectField(fieldName, fieldTitle, description, fieldSchema, isRequired);
      default:
        return Text('Unsupported field type: $fieldType');
    }
  }

  Widget _buildTabsObjectField(String fieldName, String fieldTitle, Map<String, dynamic> fieldSchema, bool isRequired) {
    // Get object properties
    final properties = _typeSafeMap<String, dynamic>(fieldSchema['properties']) ?? {};
    final required = List<String>.from(fieldSchema['required'] ?? {});

    // Get UI options for the object field
    final objectUiOptions = _typeSafeMap<String, dynamic>(widget.uiSchema?[fieldName]) ?? {};
    final tabOptions = _typeSafeMap<String, dynamic>(objectUiOptions['ui:options']) ?? {};

    // Get tab position and type
    final tabPosition = tabOptions['tabPosition'] as String? ?? 'top';
    final tabType = tabOptions['tabType'] as String? ?? 'fixed';

    // Extract the current object value
    final objectValue = (_localFormData[fieldName] as Map<String, dynamic>?) ?? {};

    return DefaultTabController(
      length: properties.length,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Field title
          if (fieldTitle.isNotEmpty) Padding(padding: const EdgeInsets.only(bottom: 8.0), child: Text(fieldTitle + (isRequired ? ' *' : ''), style: TextStyle(fontWeight: FontWeight.bold))),

          // Tab bar
          TabBar(
            isScrollable: tabType == 'scrollable',
            labelColor: Theme.of(context).primaryColor,
            unselectedLabelColor: Theme.of(context).textTheme.bodyLarge?.color,
            tabs:
                properties.entries.map((entry) {
                  final propName = entry.key;
                  final propSchema = _typeSafeMap<String, dynamic>(entry.value) ?? {};
                  final propTitle = propSchema['title'] as String? ?? propName;

                  // Get custom tab label and icon if specified
                  final propUiOptions = _typeSafeMap<String, dynamic>(widget.uiSchema?[fieldName]?[propName]) ?? {};
                  final tabLabel = propUiOptions['ui:tabLabel'] as String? ?? propTitle;
                  final tabIcon = propUiOptions['ui:tabIcon'];

                  return Tab(icon: tabIcon != null ? Icon(tabIcon) : null, text: tabLabel);
                }).toList(),
          ),

          // Tab content
          SizedBox(
            height: 300, // You may want to adjust this or make it configurable
            child: TabBarView(
              children:
                  properties.entries.map((entry) {
                    final propName = entry.key;
                    final propSchema = _typeSafeMap<String, dynamic>(entry.value) ?? {};
                    final isPropRequired = required.contains(propName);

                    // For each property, build a single field editor
                    return Padding(padding: const EdgeInsets.all(16.0), child: _buildPropertyField('$fieldName.$propName', propName, propSchema, isPropRequired, objectValue[propName]));
                  }).toList(),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPropertyField(String path, String propName, Map<String, dynamic> propSchema, bool isRequired, dynamic value) {
    // Similar to your existing field building logic but adapted for nested properties
    final propType = _getEffectiveType(propSchema['type']);
    final propTitle = propSchema['title'] as String? ?? propName;

    // Get potential UI options for this nested field
    final pathParts = path.split('.');
    final objectName = pathParts[0];
    final propertyName = pathParts[1];
    final propUiOptions = _typeSafeMap<String, dynamic>(widget.uiSchema?[objectName]?[propertyName]) ?? {};

    // Instead of creating a basic TextField, use the appropriate field builder based on type
    // This ensures consistent field generation between regular and tabbed views
    Widget field;
    switch (propType) {
      case 'string':
        // Create a controller for this nested field
        final controller = TextEditingController(text: value?.toString() ?? '');

        field = _buildTextField(path, propTitle, propSchema['description'], propSchema, isRequired, propUiOptions);
        break;
      case 'integer':
      case 'number':
        field = _buildNumberField(path, propTitle, propSchema['description'], propSchema, isRequired);
        break;
      case 'boolean':
        field = _buildBooleanField(path, propTitle, propSchema['description'], propSchema);
        break;
      default:
        // Fallback to simple text field for unsupported types in tabs
        field = TextField(
          decoration: InputDecoration(labelText: propTitle + (isRequired ? ' *' : '')),
          controller: TextEditingController(text: value?.toString() ?? ''),
          onChanged: (newValue) => _updateNestedField(path, newValue.isEmpty ? null : newValue),
        );
    }

    return field;
  }

  // Add a helper method to update nested fields
  void _updateNestedField(String path, dynamic value) {
    final pathParts = path.split('.');
    final objectName = pathParts[0];
    final propertyName = pathParts[1];

    final objectData = Map<String, dynamic>.from(_localFormData[objectName] ?? {});
    objectData[propertyName] = value;

    setState(() {
      _localFormData[objectName] = objectData;
    });

    if (widget.onChanged != null) {
      widget.onChanged!(_localFormData);
    }
  }

  Widget _buildTextField(String name, String title, String? description, Map<String, dynamic> schema, bool isRequired, [Map<String, dynamic> uiOptions = const {}]) {
    final controller = _controllers[name] ?? TextEditingController();
    _controllers[name] = controller;

    final format = schema['format'] as String?;
    final TextInputType keyboardType = _getKeyboardType(format);
    final bool isMultiline = format == 'textarea' || uiOptions['ui:widget'] == 'textarea';
    final bool isObscure = format == 'password' || uiOptions['ui:widget'] == 'password';

    // Get existing error for this field
    final fieldError = _getFieldError(name);

    // Get additional styling options
    final options = _typeSafeMap<String, dynamic>(uiOptions['ui:options']) ?? {};
    final inputStyle = _typeSafeMap<String, dynamic>(options['inputStyle']) ?? {};
    final width = inputStyle['width']; // Could be '100%' or specific width

    // Determine if this field should take full width
    final layoutOptions = _typeSafeMap<String, dynamic>(uiOptions['ui:layout']) ?? {};
    final isFullWidth = layoutOptions['fullWidth'] == true;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('$title${isRequired ? ' *' : ''}'),
        if (description != null) Text(description, style: Theme.of(context).textTheme.bodySmall),
        const SizedBox(height: 8),
        if (schema['enum'] != null)
          _buildDropdown(name, title, schema['enum'] as List<dynamic>, isRequired)
        else
          SizedBox(
            width: isFullWidth ? double.infinity : null,
            child: TextFormField(
              controller: controller,
              keyboardType: keyboardType,
              maxLines: isMultiline ? options['rows'] ?? 5 : 1,
              obscureText: isObscure,
              decoration: InputDecoration(border: const OutlineInputBorder(), hintText: schema['example']?.toString(), errorText: fieldError, helperText: uiOptions['ui:help']),
              validator: (value) {
                if (isRequired && (value == null || value.isEmpty)) {
                  return '$title is required';
                }
                if (value != null && value.isNotEmpty) {
                  if (schema['minLength'] != null && value.length < schema['minLength']) {
                    return '$title must be at least ${schema['minLength']} characters';
                  }
                  if (schema['maxLength'] != null && value.length > schema['maxLength']) {
                    return '$title must be at most ${schema['maxLength']} characters';
                  }
                  if (schema['pattern'] != null) {
                    final pattern = RegExp(schema['pattern']);
                    if (!pattern.hasMatch(value)) {
                      return '$title does not match the required pattern';
                    }
                  }
                }
                return null;
              },
              onChanged: (value) {
                // Set to null if empty, otherwise keep the string value
                _updateField(name, value.isEmpty ? null : value);
              },
            ),
          ),
      ],
    );
  }

  Widget _buildNumberField(String name, String title, String? description, Map<String, dynamic> schema, bool isRequired) {
    final controller = _controllers[name] ?? TextEditingController();
    _controllers[name] = controller;

    // Get existing error for this field
    final fieldError = _getFieldError(name);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        //Text('$title${isRequired ? ' *' : ''}'),
        // if (description != null) Text(description, style: Theme.of(context).textTheme.bodySmall),
        //const SizedBox(height: 8),
        TextFormField(
          controller: controller,
          keyboardType: TextInputType.number,
          decoration: InputDecoration(helperText: description != null ? description : '', labelText: '$title${isRequired ? ' *' : ''}', border: const OutlineInputBorder(), hintText: schema['example']?.toString(), errorText: fieldError),
          validator: (value) {
            if (isRequired && (value == null || value.isEmpty)) {
              return '$title is required';
            }
            if (value != null && value.isNotEmpty) {
              final numValue = num.tryParse(value);
              if (numValue == null) {
                return '$title must be a number';
              }
              if (schema['minimum'] != null && numValue < schema['minimum']) {
                return '$title must be at least ${schema['minimum']}';
              }
              if (schema['maximum'] != null && numValue > schema['maximum']) {
                return '$title must be at most ${schema['maximum']}';
              }
            }
            return null;
          },
          onChanged: (value) {
            if (value.isNotEmpty) {
              if (schema['type'] == 'integer') {
                _updateField(name, int.tryParse(value) ?? 0);
              } else {
                _updateField(name, double.tryParse(value) ?? 0.0);
              }
            } else {
              _updateField(name, null);
            }
          },
        ),
      ],
    );
  }

  Widget _buildBooleanField(String name, String title, String? description, Map<String, dynamic> schema) {
    // Get current value - prefer widget.formData if available
    bool isChecked = _getFieldValue(name) ?? schema['default'] ?? false;

    // Get existing error for this field
    final fieldError = _getFieldError(name);

    return CheckboxListTile(
      title: Text(title),
      subtitle: description != null ? Text(description, style: Theme.of(context).textTheme.bodySmall) : null,
      value: isChecked,
      onChanged: (bool? value) {
        _updateField(name, value ?? false);
      },
    );
  }

  Widget _buildDropdown(String name, String title, List<dynamic> options, bool isRequired) {
    // Get current value - prefer widget.formData if available
    final currentValue = _getFieldValue(name)?.toString();

    // Get existing error for this field
    final fieldError = _getFieldError(name);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        DropdownButtonFormField<String>(
          decoration: InputDecoration(border: const OutlineInputBorder(), errorText: fieldError),
          value: currentValue,
          hint: Text('$title'),
          isExpanded: true,
          validator: isRequired ? (value) => value == null || value.isEmpty ? '$title is required' : null : null,
          items:
              options.map<DropdownMenuItem<String>>((dynamic value) {
                return DropdownMenuItem<String>(value: value.toString(), child: Text(value.toString()));
              }).toList(),
          onChanged: (String? newValue) {
            _updateField(name, newValue);
          },
        ),
      ],
    );
  }

  Widget _buildEnumField(String name, String title, String? description, List<dynamic> enumValues, List<String>? enumNames, Map<String, dynamic> fieldSchema) {
    // Get UI options for this field
    final fieldUiOptions = _typeSafeMap<String, dynamic>(widget.uiSchema?[name]) ?? {};
    final fieldLayoutOptions = _typeSafeMap<String, dynamic>(fieldUiOptions['ui:layout']) ?? {};

    // Check if autocomplete should be used
    final bool useDropdown = fieldLayoutOptions['dropdown'] == true;

    // Get the field type from schema
    final fieldType = _getEffectiveType(fieldSchema['type']);

    // Rest of your existing code...
    final bool isIntegerEnum = fieldType == 'integer';
    final List<dynamic> originalValues = enumValues;
    final List<String> stringOptions = enumValues.map((value) => value.toString()).toList();
    final currentValue = _getFieldValue(name);
    String? currentStringValue = currentValue?.toString();
    final fieldError = _getFieldError(name);

    // Build the display names list
    final List<String> displayNames =
        stringOptions.asMap().entries.map((entry) {
          final int idx = entry.key;
          final String value = entry.value;
          return enumNames != null && idx < enumNames.length ? '$value | ${enumNames[idx]}' : value;
        }).toList();
    // Use autocomplete if specified, otherwise use dropdown
    if (!useDropdown) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Autocomplete<String>(
            optionsBuilder: (TextEditingValue textEditingValue) {
              if (textEditingValue.text == '') {
                return displayNames;
              }
              return displayNames.where((option) => option.toLowerCase().contains(textEditingValue.text.toLowerCase())).toList();
            },
            fieldViewBuilder: (BuildContext context, TextEditingController textEditingController, FocusNode focusNode, VoidCallback onFieldSubmitted) {
              // Set initial text if value exists
              if (currentStringValue != null && textEditingController.text.isEmpty) {
                final idx = stringOptions.indexOf(currentStringValue);
                textEditingController.text = displayNames[idx];
              }
              return TextFormField(
                controller: textEditingController,
                focusNode: focusNode,
                decoration: InputDecoration(
                  labelText: title,
                  helperText: description,
                  errorText: fieldError,
                  border: OutlineInputBorder(),
                  suffixIcon:
                      textEditingController.text.isNotEmpty
                          ? IconButton(
                            icon: Icon(Icons.clear),
                            onPressed: () {
                              // Clear the text field
                              textEditingController.clear();
                              // Reset the form value
                              _updateField(name, null);
                              // Unfocus to dismiss keyboard
                              focusNode.unfocus();
                            },
                          )
                          : Icon(Icons.arrow_drop_down),
                ),
                onFieldSubmitted: (String value) {
                  onFieldSubmitted();
                },
              );
            },
            onSelected: (String selection) {
              // Find the original value from the selection
              int selectedIdx = -1;
              for (int i = 0; i < displayNames.length; i++) {
                if (displayNames[i] == selection) {
                  selectedIdx = i;
                  break;
                }
              }

              if (selectedIdx >= 0) {
                if (isIntegerEnum) {
                  _updateField(name, originalValues[selectedIdx]);
                } else {
                  _updateField(name, stringOptions[selectedIdx]);
                }
              }
            },
            optionsViewBuilder: (BuildContext context, AutocompleteOnSelected<String> onSelected, Iterable<String> options) {
              return Align(
                alignment: Alignment.topLeft,
                child: Material(
                  elevation: 4.0,
                  child: ConstrainedBox(
                    constraints: BoxConstraints(maxWidth: MediaQuery.of(context).size.width * 0.9), // maxHeight: 200,
                    child: ListView.builder(
                      padding: EdgeInsets.all(8.0),
                      itemCount: options.length,
                      itemBuilder: (BuildContext context, int index) {
                        final String option = options.elementAt(index);
                        return ListTile(
                          title: Text(option),
                          onTap: () {
                            onSelected(option);
                          },
                        );
                      },
                    ),
                  ),
                ),
              );
            },
          ),
        ],
      );
    } else {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          //if (description != null) Padding(padding: const EdgeInsets.only(bottom: 8.0), child: Text(description, style: Theme.of(context).textTheme.bodySmall)),
          DropdownButtonFormField<String>(
            decoration: InputDecoration(labelText: title, border: const OutlineInputBorder(), errorText: fieldError, contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 8), helperText: description),
            value: currentStringValue,
            isExpanded: true,
            menuMaxHeight: 300,
            //hint: Text('Select $title'),
            selectedItemBuilder: (BuildContext context) {
              return stringOptions.map<Widget>((String value) {
                final idx = stringOptions.indexOf(value);
                String displayName = enumNames != null && idx < enumNames.length ? enumNames[idx] : value;
                // add value to dispay name
                displayName = '$value | $displayName';
                return Text(displayName, overflow: TextOverflow.ellipsis, maxLines: 1);
              }).toList();
            },
            items:
                stringOptions.asMap().entries.map((entry) {
                  final int idx = entry.key;
                  final String value = entry.value;
                  final String displayName = enumNames != null && idx < enumNames.length ? value + ' | ' + enumNames[idx] : value;

                  return DropdownMenuItem<String>(value: value, child: Container(constraints: BoxConstraints(maxWidth: MediaQuery.of(context).size.width * 0.8), child: Text(displayName, overflow: TextOverflow.ellipsis, maxLines: 2)));
                }).toList(),
            onChanged: (String? newValue) {
              if (newValue != null && isIntegerEnum) {
                // Convert back to integer when needed
                final idx = stringOptions.indexOf(newValue);
                if (idx >= 0) {
                  // Use the original value to maintain the correct type
                  _updateField(name, originalValues[idx]);
                } else {
                  // Fallback to trying to parse as int
                  _updateField(name, int.tryParse(newValue));
                }
              } else {
                // Otherwise use as-is
                _updateField(name, newValue);
              }
            },
          ),
        ],
      );
    }
  }

  Widget _buildArrayField(String name, String title, String? description, Map<String, dynamic> schema, bool isRequired) {
    // Get current values - prefer widget.formData if available
    final List<dynamic> values = List<dynamic>.from(_getFieldValue(name) ?? []);

    // Get existing error for this field
    final fieldError = _getFieldError(name);

    // Choose which implementation to use
    // Uncomment the below line and comment out the ArrayFieldEditor if you want to use the placeholder

    return ArrayFieldEditor(
      name: name,
      title: title,
      description: description,
      schema: schema,
      value: values,
      isRequired: isRequired,
      errorText: fieldError,
      onChanged: (updatedValues) {
        _updateField(name, updatedValues);
      },
    );
  }

  Widget _buildObjectField(String name, String title, String? description, Map<String, dynamic> schema, bool isRequired) {
    // For nested objects, get the current data
    //final nestedData = _getFieldValue(name) as Map<String, dynamic>? ?? {};

    // Get existing error for this field
    final fieldError = _getFieldError(name);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (fieldError != null) Padding(padding: const EdgeInsets.only(bottom: 8.0), child: Text(fieldError, style: TextStyle(color: Theme.of(context).colorScheme.error))),
        ExpansionTile(
          title: Text('$title${isRequired ? ' *' : ''}'),
          subtitle: description != null ? Text(description) : null,
          children: [
            if (schema['properties'] != null)
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16.0),
                child: Column(
                  children:
                      (schema['properties'] as Map<String, dynamic>).entries.map((entry) {
                        final fieldName = entry.key;
                        final fieldSchema = entry.value as Map<String, dynamic>;
                        final isFieldRequired = (schema['required'] as List<dynamic>? ?? []).contains(fieldName);

                        return _buildField('$name.$fieldName', fieldSchema, isFieldRequired);
                      }).toList(),
                ),
              ),
          ],
        ),
      ],
    );
  }

  TextInputType _getKeyboardType(String? format) {
    switch (format) {
      case 'email':
        return TextInputType.emailAddress;
      case 'uri':
        return TextInputType.url;
      case 'tel':
        return TextInputType.phone;
      case 'textarea':
        return TextInputType.multiline;
      case 'password':
        return TextInputType.visiblePassword;
      default:
        return TextInputType.text;
    }
  }

  // Implement other methods with proper type safety
}
