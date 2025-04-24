import 'package:flutter/material.dart';
import 'package:json_schema/json_schema.dart';
import 'package:terrestrial_forest_monitor/components/array-field-editor.dart';
import 'package:terrestrial_forest_monitor/components/stt-button.dart';

class JsonSchemaForm extends StatefulWidget {
  final Map<String, dynamic> schema;
  final Map<String, dynamic>? initialData;
  final Map<String, dynamic>? uiSchema;
  final Map<String, dynamic>? formData;
  final List<ValidationError> validationErrors;
  final void Function(Map<String, dynamic>)? onChanged;
  final void Function(Map<String, dynamic>)? onError;
  final void Function()? onReset;
  final void Function()? onCancel;
  final void Function(Map<String, dynamic>) onSubmit;

  const JsonSchemaForm({Key? key, required this.schema, required this.validationErrors, this.initialData, this.uiSchema, this.formData, this.onChanged, this.onError, this.onReset, this.onCancel, required this.onSubmit}) : super(key: key);

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

    // Deep copy the initial form data
    _localFormData = {};
    if (widget.formData != null) {
      _deepCopyData(widget.formData!, _localFormData);
      print('Initialized form data: $_localFormData');
    }

    // Create a schema validator from the provided schema
    _jsonSchema = JsonSchema.create(widget.schema);
    _initializeForm();
    // Convert validation errors to field errors
    _updateErrorsFromValidation();
  }

  // Add this helper method
  void _deepCopyData(Map<String, dynamic> source, Map<String, dynamic> target) {
    source.forEach((key, value) {
      if (value is Map) {
        target[key] = <String, dynamic>{};
        _deepCopyData(Map<String, dynamic>.from(value), target[key]);
      } else if (value is List) {
        target[key] = List.from(value);
      } else {
        target[key] = value;
      }
    });
  }

  @override
  void didUpdateWidget(JsonSchemaForm oldWidget) {
    super.didUpdateWidget(oldWidget);

    // If external formData changed, update our controllers
    if (widget.formData != oldWidget.formData) {
      _updateControllersFromFormData();
    }

    // If validation errors changed, update local errors
    if (widget.validationErrors != oldWidget.validationErrors) {
      _updateErrorsFromValidation();
    }
  }

  // Convert ValidationError list to field error map
  void _updateErrorsFromValidation() {
    Map<String, dynamic> newErrors = {};

    for (ValidationError error in widget.validationErrors) {
      // Extract field path from error - using property path or instance path
      String path = error.schemaPath ?? '';

      // Remove schema path prefix if present (like #/properties/)
      if (path.contains('/properties/')) {
        path = path.split('/properties/').last;
        // Handle nested paths
        if (path.contains('/')) {
          path = path.replaceAll('/', '.');
        }
      } else if (error.instancePath != null && error.instancePath!.isNotEmpty) {
        // Use instance path as fallback
        path = error.instancePath!.substring(1).replaceAll('/', '.');
      }

      if (path.isNotEmpty) {
        newErrors[path] = error.message;
      }
    }

    setState(() {
      _localFormErrors = newErrors;
    });
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
    _localFormData = _typeSafeMap<String, dynamic>(widget.formData);
    _localFormErrors = {};

    _initializeControllers();
    _formInitialized = true;
  }

  void _initializeControllers() {
    // Clear any existing controllers
    _controllers.forEach((key, controller) => controller.dispose());
    _controllers.clear();

    // Search through schema recursively to find all fields
    _initControllersFromSchema(widget.schema['properties'] ?? {}, '');
  }

  void _initControllersFromSchema(Map<String, dynamic> properties, String basePath) {
    properties.forEach((fieldName, fieldSchema) {
      final String fieldType = _getEffectiveType(fieldSchema['type']);
      final String fullPath = basePath.isEmpty ? fieldName : '$basePath.$fieldName';

      if (fieldType == 'string' || fieldType == 'number' || fieldType == 'integer') {
        // Create controller
        final controller = TextEditingController();
        _controllers[fullPath] = controller;

        // Set initial value from form data
        final value = _getFieldValue(fullPath);
        if (value != null) {
          controller.text = value.toString();
          print('Initialized controller for $fullPath with: ${controller.text}');
        }
      } else if (fieldType == 'object') {
        // Recursively process object fields
        final nestedProps = _typeSafeMap<String, dynamic>(fieldSchema['properties']) ?? {};
        _initControllersFromSchema(nestedProps, fullPath);
      }
    });
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
    if (fieldName.isEmpty) return null;

    // Handle nested paths with dots
    if (fieldName.contains('.')) {
      final parts = fieldName.split('.');
      dynamic currentValue = _localFormData;

      for (int i = 0; i < parts.length; i++) {
        final part = parts[i];

        if (currentValue is Map) {
          currentValue = currentValue[part];
          // If we hit null in the middle of the path, return null
          if (currentValue == null && i < parts.length - 1) {
            print('Path $fieldName returned null at part $part');
            return null;
          }
        } else {
          print('Path $fieldName is invalid at part $part - not a map');
          return null; // Path is invalid - not a map
        }
      }

      print('Retrieved value for $fieldName: $currentValue');
      return currentValue;
    }

    // Simple top-level field
    return _localFormData[fieldName];
  }

  void _updateField(String name, dynamic value) {
    setState(() {
      if (name.contains('.')) {
        // For nested fields
        final parts = name.split('.');
        final firstPart = parts[0];

        // Ensure the top-level object exists
        if (_localFormData[firstPart] == null) {
          _localFormData[firstPart] = {};
        }

        // Update the nested field
        _updateNestedValue(_localFormData, parts, value);
      } else {
        // For top-level fields
        _localFormData[name] = value;
      }
    });

    widget.onChanged?.call(_localFormData);
  }

  void _updateNestedValue(Map<String, dynamic> data, List<String> parts, dynamic value) {
    final currentPart = parts[0];

    if (parts.length == 1) {
      // Last part of path - set the value
      data[currentPart] = value;
      return;
    }

    // Ensure the nested object exists
    if (data[currentPart] == null) {
      data[currentPart] = <String, dynamic>{};
    } else if (data[currentPart] is! Map) {
      // Convert to map if not already
      data[currentPart] = <String, dynamic>{};
    }

    // Recurse with remaining path parts
    _updateNestedValue(data[currentPart] as Map<String, dynamic>, parts.sublist(1), value);
  }

  String? _getFieldError(String name) {
    // search for errors in widget.validationErrors
    for (final error in widget.validationErrors) {
      // Check if the error instancePath contains the field name
      // trim the leading / from instancePath
      if (error.instancePath.isEmpty) {
        continue;
      }
      final trimmedPath = error.instancePath.substring(1) ?? '';
      // replace all / with .
      final instancePath = trimmedPath.replaceAll('/', '.');

      if (instancePath == name) {
        return error.message;
      }
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
    return Form(key: _formKey, child: Column(crossAxisAlignment: CrossAxisAlignment.center, mainAxisSize: MainAxisSize.max, children: [..._buildFormFields()]));
  }

  List<Widget> _buildFormFields() {
    List<Widget> fields = [];
    final properties = _typeSafeMap<String, dynamic>(widget.schema['properties']) ?? {};
    final required = List<String>.from(widget.schema['required'] ?? []);

    // Original column layout
    final List<Widget> wrapChildren = [];

    // get Fullscreen fom entry.$tfm.ui.fullscreen

    bool fullSize = false; // Default value

    if (widget.schema.containsKey('\$tfm') && widget.schema['\$tfm'] is Map) {
      final tfm = widget.schema['\$tfm'] as Map<String, dynamic>;
      if (tfm.containsKey('ui') && tfm['ui'] is Map) {
        final ui = tfm['ui'] as Map<String, dynamic>;
        if (ui.containsKey('layout')) {
          fullSize = ui['layout'] == 'fullSize'; // Ensure boolean conversion
        }
      }
    }

    for (final entry in properties.entries) {
      final fieldName = entry.key;
      final fieldSchema = _typeSafeMap<String, dynamic>(entry.value) ?? {};
      final isRequired = required.contains(fieldName);

      if (fullSize) {
        fields.add(_buildField(fieldName, fieldSchema, isRequired));
      } else {
        double? maxWidth = 400.0;
        wrapChildren.add(Container(child: _buildField(fieldName, fieldSchema, isRequired), padding: EdgeInsets.only(bottom: 16), constraints: BoxConstraints(minWidth: 100, maxWidth: maxWidth)));
      }
    }

    if (!fullSize) {
      fields.add(Wrap(spacing: 16, runSpacing: 16, children: wrapChildren, alignment: WrapAlignment.start, runAlignment: WrapAlignment.start, crossAxisAlignment: WrapCrossAlignment.center));
    }

    return fields;
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
    final fieldUiOptions = _typeSafeMap<String, dynamic>(widget.uiSchema?[fieldName]);
    final widgetType = fieldUiOptions['ui:widget'] as String?;

    // Check for and apply default value if current value is null
    final currentValue = _getFieldValue(fieldName);
    if (currentValue == null && fieldSchema.containsKey('default')) {
      _updateField(fieldName, fieldSchema['default']);
    }

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
    final propUiOptions = _typeSafeMap<String, dynamic>(widget.uiSchema?[objectName]?[propertyName]);

    // This ensures consistent field generation between regular and tabbed views
    Widget field;
    switch (propType) {
      case 'string':
        // Create a controller for this nested field
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
        field = Text('Unsupported field type: $propType');
      /*field = TextField(
          decoration: InputDecoration(labelText: propTitle + (isRequired ? ' *' : '')),
          controller: TextEditingController(text: value?.toString() ?? ''),
          onChanged: (newValue) => _updateNestedField(path, newValue.isEmpty ? null : newValue),
        );*/
    }

    return field;
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

    // Determine if this field should take full width
    final layoutOptions = _typeSafeMap<String, dynamic>(uiOptions['ui:layout']) ?? {};
    final isFullWidth = layoutOptions['fullWidth'] == true;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        //Text('$title${isRequired ? ' *' : ''}'),
        //if (description != null) Text(description, style: Theme.of(context).textTheme.bodySmall),
        //const SizedBox(height: 8),
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
              decoration: InputDecoration(labelText: '$title${isRequired ? ' *' : ''}', border: const OutlineInputBorder(), hintText: schema['example']?.toString(), errorText: fieldError, helperText: description),

              onChanged: (value) {
                print('SAVED: $name = $value');
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
        // if (description != null) Text(description, style: Theme.of(context).textTheme.bodySmall),
        TextFormField(
          controller: controller,
          keyboardType: TextInputType.number,
          decoration: InputDecoration(
            helperText: description ?? '',
            labelText: '$title${isRequired ? ' *' : ''}',
            border: const OutlineInputBorder(),
            hintText: schema['example']?.toString(),
            errorText: fieldError,
            suffixIcon: SpeechToTextButton(
              onChanged: (value) {
                if (value != null && value.isNotEmpty) {
                  _updateField(name, value);
                }
              },
            ),
          ),
          onChanged: (value) {
            if (value.isNotEmpty) {
              if (schema['type'] == 'integer') {
                _updateField(name, int.tryParse(value) ?? null);
              } else {
                _updateField(name, double.tryParse(value) ?? null);
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
      //subtitle: description != null ? Text(description, style: Theme.of(context).textTheme.bodySmall) : null,
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
                if (idx >= 0) {
                  Future.delayed(Duration.zero, () {
                    textEditingController.text = displayNames[idx];
                  });
                }
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
                              Future.delayed(Duration.zero, () {
                                textEditingController.clear();
                                // Reset the form value
                                Future.delayed(Duration.zero, () {
                                  _updateField(name, null);
                                  // Focus
                                  Future.delayed(Duration.zero, () {
                                    focusNode.requestFocus();
                                  });
                                });
                              });
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

    return ArrayFieldEditor(
      name: name,
      title: title,
      description: description,
      schema: schema,
      value: values,
      formData: widget.formData,
      isRequired: isRequired,
      errorText: fieldError,
      validationErrors: widget.validationErrors,
      onChanged: (updatedValues) {
        _updateField(name, updatedValues);
      },
    );
  }

  Widget _buildObjectField(String name, String title, String? description, Map<String, dynamic> schema, bool isRequired) {
    // Ensure the object exists in form data
    if (_localFormData[name] == null) {
      setState(() {
        _localFormData[name] = <String, dynamic>{};
      });
    }

    List<Widget> fieldWidgets = [];
    final properties = _typeSafeMap<String, dynamic>(schema['properties']) ?? {};
    final requiredFields = List<String>.from(schema['required'] ?? []);

    properties.forEach((propName, propSchema) {
      final String nestedPath = '$name.$propName';
      final bool isPropRequired = requiredFields.contains(propName);

      fieldWidgets.add(Padding(padding: EdgeInsets.only(bottom: 16.0), child: _buildField(nestedPath, propSchema, isPropRequired)));
    });

    return Wrap(children: fieldWidgets);
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
