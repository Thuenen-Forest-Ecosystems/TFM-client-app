import 'package:flutter/material.dart';
import 'package:json_schema/json_schema.dart';
import 'package:terrestrial_forest_monitor/components/json-schema-form.dart';

class JsonSchemaFormWrapper extends StatefulWidget {
  final Map<String, dynamic> schema;
  final Map<String, dynamic> formData;
  final Map<String, dynamic>? uiSchema;

  const JsonSchemaFormWrapper({Key? key, required this.schema, required this.formData, this.uiSchema}) : super(key: key);

  @override
  State<JsonSchemaFormWrapper> createState() => _JsonSchemaFormWrapperState();
}

class _JsonSchemaFormWrapperState extends State<JsonSchemaFormWrapper> {
  Map<String, dynamic> _formData = {};
  Map<String, dynamic> formErrors = {};
  late JsonSchema _jsonSchema;

  @override
  void initState() {
    super.initState();
    // Create schema validator when the widget initializes
    _jsonSchema = JsonSchema.create(widget.schema);
    _formData = widget.formData;
  }

  @override
  Widget build(BuildContext context) {
    // Extract schema properties
    final Map<String, dynamic> properties = widget.schema['properties'] as Map<String, dynamic>;

    // Separate simple fields from complex fields (objects and arrays)
    final Map<String, dynamic> simpleProperties = {};
    final Map<String, Map<String, dynamic>> complexProperties = {};

    properties.forEach((key, value) {
      if (value is Map<String, dynamic> &&
          (
          // Object types
          (value['type'] == 'object') ||
              (value['type'] is List && (value['type'] as List).contains('object')) ||
              // Array types - ALL arrays now get their own tab
              (value['type'] == 'array') ||
              (value['type'] is List && (value['type'] as List).contains('array')))) {
        complexProperties[key] = value;
      } else {
        simpleProperties[key] = value;
      }
    });

    // Create tab names list - first tab for simple fields, then each complex field
    final List<String> tabNames = ['Plot'];
    complexProperties.keys.forEach((propName) {
      // Use title if available, otherwise capitalize the property name
      final title = complexProperties[propName]!['title'] as String? ?? propName[0].toUpperCase() + propName.substring(1);
      tabNames.add(title);
    });

    return DefaultTabController(
      length: tabNames.length,
      child: Scaffold(
        appBar: AppBar(
          title: Text(widget.schema['title'] as String? ?? 'Form'),
          actions: [
            if (formErrors.isNotEmpty)
              ElevatedButton(
                onPressed: () {
                  ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Please correct the errors in the form'), backgroundColor: Colors.red));
                },
                child: Text('Fehler'),
              ),
            if (formErrors.isEmpty)
              ElevatedButton(
                onPressed: () {
                  if (_validateFormData(_formData)) {
                    print('Form data is valid: $_formData');
                  } else {
                    print('Form data is invalid: $_formData');
                  }
                },

                child: Text('Fertig'),
              ),
          ],
          bottom: TabBar(isScrollable: true, tabs: tabNames.map((name) => Tab(text: name)).toList()),
        ),
        body: TabBarView(
          children: [
            // First tab: Simple properties
            SingleChildScrollView(padding: EdgeInsets.all(16), child: _buildFormSection(simpleProperties, widget.schema['title'] as String? ?? 'Basic Information')),

            // Additional tabs: One per complex property (object or array)
            ...complexProperties.entries.map((entry) {
              final propName = entry.key;
              final propSchema = entry.value;

              return SingleChildScrollView(padding: EdgeInsets.all(16), child: _buildComplexSection(propName, propSchema));
            }).toList(),
          ],
        ),
      ),
    );
  }

  // Helper method to build a section of the form with specific properties
  Widget _buildFormSection(Map<String, dynamic> properties, String title) {
    // Create a schema for just this section
    final sectionSchema = {
      "title": title,
      "type": "object",
      "properties": properties,
      // Copy required fields that are in this section
      "required": (widget.schema['required'] as List<dynamic>?)?.where((field) => properties.containsKey(field))?.toList() ?? [],
    };

    // Extract just the form data for these properties
    final Map<String, dynamic> sectionData = {};
    for (final key in properties.keys) {
      if (_formData.containsKey(key)) {
        sectionData[key] = _formData[key];
      }
    }

    // Extract errors for this section
    final Map<String, dynamic> sectionErrors = {};
    for (final entry in formErrors.entries) {
      final key = entry.key.split('.').first;
      if (properties.containsKey(key)) {
        sectionErrors[entry.key] = entry.value;
      }
    }

    // Create UI schema for this section
    final sectionUiSchema = _extractUiSchemaForSection(properties.keys.toList());

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // This JsonSchemaForm only handles the fields for this section
        JsonSchemaForm(
          schema: sectionSchema,
          formData: sectionData,
          formErrors: sectionErrors,
          uiSchema: sectionUiSchema,
          onChanged: (data) {
            // Merge the changed data back into the main form data
            setState(() {
              data.forEach((key, value) {
                _formData[key] = value;
              });
            });
            _validateFormData(_formData);
          },
          onSubmit: (data) {
            // This shouldn't be triggered from a sub-form, but just in case
            _validateFormData(_formData);
          },
        ),
      ],
    );
  }

  // Helper method to build a complex property section (object or array)
  Widget _buildComplexSection(String propName, Map<String, dynamic> propSchema) {
    // Handle both objects and arrays
    final isArray = propSchema['type'] == 'array' || (propSchema['type'] is List && (propSchema['type'] as List).contains('array'));

    // Create data and errors for this property
    final Map<String, dynamic> propData = {propName: _formData[propName] ?? (isArray ? [] : {})};
    final Map<String, dynamic> propErrors = {};

    // Filter errors for this property
    for (final entry in formErrors.entries) {
      if (entry.key == propName || entry.key.startsWith('$propName.')) {
        propErrors[entry.key] = entry.value;
      }
    }

    // Create schema for just this property
    final Map<String, dynamic> sectionSchema = {
      "title": propSchema['title'] ?? propName,
      "type": "object",
      "properties": {propName: propSchema},
      "required": widget.schema['required'] != null && (widget.schema['required'] as List<dynamic>).contains(propName) ? [propName] : [],
    };

    // Extract UI schema for this property
    final Map<String, dynamic> sectionUiSchema = widget.uiSchema != null ? {propName: widget.uiSchema![propName] ?? {}} : {};

    // Add special UI layout for arrays if needed
    if (isArray && !sectionUiSchema.containsKey('ui:layout')) {
      sectionUiSchema['ui:layout'] = {"fullWidth": true, "type": "grid"};
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Fix: Remove the "data" debug text in _ArrayFormEditor
        JsonSchemaForm(
          schema: sectionSchema,
          formData: propData,
          formErrors: propErrors,
          uiSchema: sectionUiSchema,
          onChanged: (data) {
            // Update the main form data with this property's data
            setState(() {
              if (data[propName] != null) {
                _formData[propName] = data[propName];
              }
            });
            _validateFormData(_formData);
          },
          onSubmit: (data) {
            _validateFormData(_formData);
          },
        ),
      ],
    );
  }

  // Helper to extract UI schema for specific fields
  Map<String, dynamic> _extractUiSchemaForSection(List<String> fields) {
    final result = {'ui:layout': widget.uiSchema?['ui:layout'] ?? {}};

    for (final field in fields) {
      if (widget.uiSchema != null && widget.uiSchema![field] != null) {
        result[field] = widget.uiSchema![field];
      }
    }

    return result;
  }

  // Returns true if the form is valid, false otherwise
  bool _validateFormData(Map<String, dynamic> data) {
    try {
      // Validate the data against the schema
      final result = _jsonSchema.validate(data);

      if (result.isValid) {
        // Clear errors if valid
        setState(() {
          formErrors = {};
        });
        return true;
      } else {
        // Process validation errors
        final Map<String, dynamic> errors = {};

        for (var error in result.errors) {
          // Parse the error path to identify the field
          String path = error.instancePath;

          // Handle empty path (top-level errors)
          if (path.isEmpty) {
            errors['_form'] = error.message;
            continue;
          }

          // Clean up path format
          if (path.startsWith('/')) {
            path = path.substring(1);
          }

          // Handle nested paths using JSON pointer format
          path = path.replaceAll('/', '.');

          // Add errors to the map
          errors[path] = error.message;

          // Also add top-level errors for array and object fields
          if (path.contains('.')) {
            final topField = path.split('.').first;
            if (!errors.containsKey(topField)) {
              errors[topField] = 'Contains invalid entries';
            }
          }
        }

        // Update errors state
        setState(() {
          formErrors = errors;
        });

        return false;
      }
    } catch (e) {
      print('Error validating form data: $e');

      setState(() {
        formErrors = {'_form': 'Validation error: ${e.toString()}'};
      });

      return false;
    }
  }
}
