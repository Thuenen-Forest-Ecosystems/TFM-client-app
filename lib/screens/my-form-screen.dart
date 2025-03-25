import 'package:flutter/material.dart';
import 'package:json_schema/json_schema.dart';
import 'package:terrestrial_forest_monitor/components/json-schema-form.dart';

class MyFormScreen extends StatefulWidget {
  @override
  State<MyFormScreen> createState() => _MyFormScreenState();
}

class _MyFormScreenState extends State<MyFormScreen> {
  Map<String, dynamic> formData = {
    "name": "Gerrit",
    "email": "",
    "password": "",
    "comments": "",
    "plot": {"plot_id": "P001", "plot_name": "Test Plot"},
    "tree": [
      {"tree_id": "T001", "species": "Oak", "diameter": 45.2, "height": 12.5},
    ],
  };
  Map<String, dynamic> formErrors = {};
  late JsonSchema _jsonSchema;

  @override
  void initState() {
    super.initState();
    // Create schema validator when the widget initializes
    _jsonSchema = JsonSchema.create(mySchema);
  }

  // Example schema
  Map<String, dynamic> mySchema = {
    "title": "My Form",
    "type": "object",
    "properties": {
      "name": {"type": "string", "title": "Name"},
      "email": {"type": "string", "format": "email", "title": "Email"},
      "password": {"type": "string", "title": "Password"},
      "comments": {"type": "string", "title": "Comments"},
      "plot": {
        "type": "object",
        "properties": {
          "plot_id": {"type": "string", "title": "Plot ID"},
          "plot_name": {"type": "string", "title": "Plot Name"},
          "plot_description": {"type": "string", "title": "Plot Description"},
        },
        "required": ["plot_id", "plot_name"],
        "additionalProperties": false,
      },
      "tree": {
        "type": "array",
        "items": {
          "type": "object",
          "properties": {
            "tree_id": {"type": "string", "title": "Tree ID"},
            "species": {"type": "string", "title": "Species"},
            "diameter": {"type": "number", "title": "Diameter"},
            "height": {"type": "number", "title": "Height"},
          },
          "required": ["tree_id", "species"],
          "additionalProperties": false,
        },
      },
    },
    "required": ["name", "email"],
  };

  @override
  Widget build(BuildContext context) {
    // Calculate optimal field width based on screen size
    final screenWidth = MediaQuery.of(context).size.width;
    final fieldWidth =
        screenWidth > 900
            ? 300.0
            : screenWidth > 600
            ? screenWidth * 0.45
            : screenWidth - 32;

    return Scaffold(
      body: SingleChildScrollView(
        padding: EdgeInsets.all(16),
        child: Column(
          children: [
            JsonSchemaForm(
              schema: mySchema,
              formData: formData,
              formErrors: formErrors,
              uiSchema: {
                "ui:layout": {
                  "type": "responsive",
                  "fieldWidth": 300.0, // Default field width
                  "spacing": 16.0, // Horizontal spacing
                  "rowSpacing": 20.0, // Vertical spacing
                },
                "name": {
                  "ui:widget": "text",
                  "ui:layout": {
                    "maxWidth": 300.0, // Explicit max width
                  },
                },
                "email": {
                  "ui:layout": {
                    "span": 6, // Use int instead of double to avoid type errors
                  },
                },
                "password": {
                  "ui:widget": "password",
                  "ui:layout": {
                    "span": 6, // Use int instead of double to avoid type errors
                  },
                },
                "comments": {
                  "ui:widget": "textarea",
                  "ui:layout": {
                    "span": 12, // Use int instead of double to avoid type errors
                    "maxWidth": double.infinity, // Remove max width constraint
                    "fullWidth": true, // Explicit flag for full width
                    "clearFloat": true, // Ensure it starts on a new line
                  },
                  "ui:options": {
                    "rows": 4, // Make textarea taller
                    "inputStyle": {
                      "width": "100%", // Explicit CSS-style width
                    },
                  },
                },
                "plot": {
                  "ui:widget": "tabs", // This tells the form to use tabs for this object
                  "ui:options": {
                    "tabPosition": "top",
                    "tabType": "fixed", // or "scrollable"
                  },
                  // Configure individual property tabs
                  "plot_id": {
                    "ui:tabLabel": "ID", // Custom tab label
                    "ui:tabIcon": Icons.tag, // Optional icon
                  },
                  "plot_name": {"ui:tabLabel": "Name"},
                  "plot_description": {"ui:tabLabel": "Description"},
                },
                "tree": {
                  "ui:layout": {
                    "span": 12, // Use int instead of double to avoid type errors
                    "maxWidth": double.infinity, // Remove max width constraint
                    "fullWidth": true, // Explicit flag for full width
                    "clearFloat": true, // Ensure it starts on a new line
                  },
                  "ui:widget": "table", // This tells the form to use a table for this array
                  "ui:options": {
                    "addable": true, // Allow adding new items
                    "removable": true, // Allow removing items
                    "sortable": true, // Allow sorting items
                    "tableHeaders": ["ID", "Species", "Diameter", "Height"], // Custom table headers
                  },
                  "items": {
                    "tree_id": {"ui:widget": "text"},
                    "species": {"ui:widget": "text"},
                    "diameter": {"ui:widget": "number"},
                    "height": {"ui:widget": "number"},
                  },
                },
              },
              onChanged: (data) {
                // Update the form data first
                setState(() {
                  formData = data;
                });

                // Then validate the changed data
                _validateFormData(data);
              },
              onSubmit: (data) {
                // Validate one last time before submission
                if (_validateFormData(data)) {
                  // Process valid form data
                  print('Form submitted successfully: $data');
                }
              },
              // No need for onError since we're handling errors ourselves
            ),

            // Display all current errors for debugging
            if (formErrors.isNotEmpty)
              Container(
                margin: EdgeInsets.only(top: 20),
                padding: EdgeInsets.all(16),
                decoration: BoxDecoration(border: Border.all(color: Colors.red), borderRadius: BorderRadius.circular(8), color: Colors.red.withOpacity(0.1)),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text("Validation Errors:", style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                    SizedBox(height: 12),
                    ...formErrors.entries.map((e) {
                      // Format the error key for display
                      String fieldName = e.key;
                      if (fieldName == '_form') fieldName = 'Form';

                      // Display each error as a row
                      return Padding(
                        padding: EdgeInsets.only(bottom: 8),
                        child: Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Icon(Icons.error_outline, color: Colors.red, size: 18),
                            SizedBox(width: 8),
                            Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [Text(fieldName, style: TextStyle(fontWeight: FontWeight.bold)), Text(e.value.toString(), style: TextStyle(color: Colors.red[700]))])),
                          ],
                        ),
                      );
                    }).toList(),
                  ],
                ),
              ),
          ],
        ),
      ),
    );
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

  // For field-specific validation for real-time feedback
  void _validateField(String fieldName, dynamic value) {
    // Create a copy of the current form data
    final updatedData = {...formData};

    // Update the specific field
    updatedData[fieldName] = value;

    // Validate the entire form with this change
    _validateFormData(updatedData);
  }

  // Add handler for nested fields
  void _validateNestedField(String path, dynamic value) {
    // Create a copy of the current form data
    final updatedData = {...formData};

    // Parse the path to update the correct nested field
    final pathParts = path.split('.');

    // Handle multi-level nesting
    dynamic current = updatedData;
    for (int i = 0; i < pathParts.length - 1; i++) {
      if (current[pathParts[i]] == null) {
        current[pathParts[i]] = {};
      }
      current = current[pathParts[i]];
    }

    // Set the value at the final path
    current[pathParts.last] = value;

    // Validate the updated data
    _validateFormData(updatedData);
  }
}
