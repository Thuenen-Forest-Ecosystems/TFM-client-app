import 'dart:async';
import 'dart:convert';

import 'package:beamer/beamer.dart';
import 'package:flutter/material.dart';
import 'package:json_schema/json_schema.dart';
import 'package:terrestrial_forest_monitor/components/form-errors-dialog.dart';
import 'package:terrestrial_forest_monitor/components/json-schema-form.dart';
import 'package:terrestrial_forest_monitor/services/powersync.dart';
import 'package:speech_to_text/speech_to_text.dart' as stt;

class JsonSchemaFormWrapper extends StatefulWidget {
  final String recordsId;
  final Map<String, dynamic> schema;
  final Map<String, dynamic> formData;
  final Map<String, dynamic>? previousData;

  const JsonSchemaFormWrapper({Key? key, required this.recordsId, required this.schema, required this.formData, this.previousData}) : super(key: key);

  @override
  State<JsonSchemaFormWrapper> createState() => _JsonSchemaFormWrapperState();
}

class _JsonSchemaFormWrapperState extends State<JsonSchemaFormWrapper> with SingleTickerProviderStateMixin {
  Map<String, dynamic> _formData = {};
  Map<String, dynamic> formErrors = {};
  List<ValidationError> validationErrors = [];
  late JsonSchema _jsonSchema;
  late TabController _tabController;
  Map<String, Map<String, String>> _tabs = {};
  Timer? _timer;

  bool _speechInitialized = false;
  late stt.SpeechToText _speechToText;
  bool _speechEnabled = false;

  // Helper method to safely access nested maps
  Map<String, dynamic>? _typeSafeMap(dynamic value) {
    if (value is Map<String, dynamic>) {
      return value;
    }
    return null;
  }

  // Helper method to get the UI schema from schema.$tfm if it exists
  Map<String, dynamic>? _getUiSchema() {
    return _typeSafeMap(widget.schema['\$tfm'])?['ui:schema'];
  }

  Future _getFormData() async {
    try {
      // Get the form data from the database
      final record = await db.get('SELECT * FROM records WHERE id = ?', [widget.recordsId]);
      if (record.isNotEmpty) {
        _formData = jsonDecode(record['properties']);
      } else {
        _formData = widget.formData;
      }
    } catch (e) {
      print('Error fetching form data: $e');
    }

    _validateFormData(_formData);
  }

  @override
  void initState() {
    super.initState();
    int tabsCount = 9;
    //widget.schema['properties'].keys.toList().length + 1;
    _tabController = TabController(length: tabsCount, vsync: this);
    // Create schema validator when the widget initializes

    _jsonSchema = JsonSchema.create(widget.schema);
    _formData = widget.formData;
    _getFormData();

    //_validateFormData(_formData);
    // https://github.com/csdcorp/speech_to_text/issues/539
    // if not macOs
    _speechToText = stt.SpeechToText();
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();

    // Move platform check to didChangeDependencies
    if (!_speechInitialized && Theme.of(context).platform != TargetPlatform.macOS) {
      _initSpeech();
      _speechInitialized = true;
    }
  }

  // Add this method for async initialization
  Future<void> _initSpeech() async {
    try {
      _speechEnabled = await _speechToText.initialize();
      if (mounted) {
        setState(() {});
      }
    } catch (e) {
      print('Failed to initialize speech recognition: $e');
      _speechEnabled = false;
      if (mounted) {
        setState(() {});
      }
    }
  }

  @override
  void dispose() {
    _tabController.dispose();
    _timer?.cancel();
    super.dispose();
  }

  int? _getTabIndexByName(String instancePath) {
    // trim /
    if (instancePath.startsWith('/')) {
      instancePath = instancePath.substring(1);
    }
    for (int i = 0; i < _tabs.keys.length; i++) {
      if (_tabs.values.elementAt(i)['path'] == instancePath) {
        return i;
      }
    }
    return null;
  }

  void _selectTabByFormError(ValidationError error) {
    // Find the tab index based on the error path
    final tabIndex = _getTabIndexByName(error.instancePath);
    if (tabIndex == null) {
      // If no tab index is found, return early
      return;
    }

    if (tabIndex != null && tabIndex >= 0) {
      // Safely access the TabController

      //final tabController = DefaultTabController.of(context);
      if (mounted) {
        _tabController.animateTo(tabIndex);
      }
    }
  }

  Future _autosave() async {
    if (_timer != null) {
      _timer!.cancel();
    }
    print('Autosaving...');
    _timer = Timer(Duration(seconds: 3), () {
      _timer = null;
      _save();
    });
    return;
  }

  bool _saveInProgress = false;
  Future _save() async {
    // Save the form data to the database or perform any other action

    _saveInProgress = true;
    try {
      final record = await db.get('SELECT * FROM records WHERE id = ?', [widget.recordsId]);
      if (record.isNotEmpty) {
        print('Record exists, updating...');
        // Update the record
        await db.execute('UPDATE records SET properties = ? WHERE id = ?', [jsonEncode(_formData), widget.recordsId]);
      } else {
        print('Record does not exist, inserting...');
        // Insert a new record
        await db.execute('INSERT INTO records (properties, schema_id) VALUES (?, ?)', [jsonEncode(_formData), widget.schema['id']]);
      }
    } catch (e) {
      print('Error saving form data: $e');
    }
    _saveInProgress = false;
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
    _tabs['Plot'] = {"name": 'Plot', "path": ""};
    complexProperties.keys.forEach((propName) {
      // Use title if available, otherwise capitalize the property name
      String title = complexProperties[propName]!['title'] as String? ?? propName[0].toUpperCase() + propName.substring(1);
      _tabs[propName] = {"name": title, "path": propName};
    });

    String title = widget.schema['title'] as String? ?? 'Form';

    if (widget.previousData != null && widget.previousData!['previous_properties'] is Map && widget.previousData!['previous_properties']['plot_name'] != null) {
      title += ': ' + widget.previousData!['previous_properties']['plot_name'].toString();
    }

    String subTitle = widget.schema['description'] as String? ?? 'Clusters:';
    if (widget.previousData != null && widget.previousData!['previous_properties'] is Map && widget.previousData!['previous_properties']['cluster_name'] != null) {
      subTitle += ' ' + widget.previousData!['previous_properties']['cluster_name'].toString();
    }

    return Scaffold(
      appBar: AppBar(
        leading: IconButton(
          icon: Icon(Icons.arrow_back),
          onPressed: () {
            Beamer.of(context).beamToNamed('/');
          },
        ),
        title: ListTile(title: Text(title, style: TextStyle(color: Colors.black)), subtitle: Text(subTitle, style: TextStyle(color: Colors.black)), minLeadingWidth: 0),
        backgroundColor: Color.fromARGB(255, 224, 241, 203),
        actions: [
          SizedBox(width: 16),
          if (validationErrors.isNotEmpty)
            ElevatedButton.icon(
              icon: Icon(Icons.error),
              onPressed: () async {
                // show errors Dialog
                final focusError = await showDialog<ValidationError>(
                  context: context,
                  builder: (context) {
                    return FormErrorsDialog(validationErrors: validationErrors, schema: widget.schema);
                  },
                );

                if (focusError != null && mounted) {
                  // Make sure the widget is still mounted before accessing the controller
                  WidgetsBinding.instance.addPostFrameCallback((_) {
                    _selectTabByFormError(focusError);
                  });
                }
              },
              label: Text('Fehler (${validationErrors.length})'),
            ),
          SizedBox(width: 16),
          ElevatedButton.icon(
            onPressed:
                validationErrors.isEmpty
                    ? () {
                      if (validationErrors.isEmpty) {
                        _save();
                      } else {
                        print('Form data is invalid: $_formData');
                      }
                    }
                    : null,
            icon: Icon(Icons.check),
            label: Text('FERTIG'),
          ),
          SizedBox(width: 16),
        ],
        bottom: TabBar(
          isScrollable: true,
          controller: _tabController,
          tabs:
              _tabs.entries.map((tab) {
                int errorCount = 0;

                String tabName = tab.value['name'] ?? 'Unknown';
                String? path = tab.value['path'];

                if (tabName == 'Plot') {
                  errorCount = simpleProperties.keys.where((key) => formErrors.containsKey(key)).length;
                } else {
                  final propName = complexProperties.keys.firstWhere((key) => complexProperties[key]!['title'] == tabName || key[0].toUpperCase() + key.substring(1) == tabName, orElse: () => '');
                  if (propName.isNotEmpty) {
                    errorCount = formErrors.keys.where((key) => key.startsWith(propName)).length;
                  }
                }

                return Tab(
                  child: Row(
                    children: [
                      Text(
                        tabName,
                        style: TextStyle(color: Colors.black), // Set the text color to black
                      ),
                      if (errorCount > 0) Padding(padding: const EdgeInsets.only(left: 4.0), child: CircleAvatar(backgroundColor: Colors.red, radius: 10, child: Text(errorCount.toString(), style: TextStyle(color: Colors.white, fontSize: 12)))),
                    ],
                  ),
                );
              }).toList(),
        ),
      ),
      body: TabBarView(
        physics: const NeverScrollableScrollPhysics(),
        controller: _tabController,
        children: [
          // First tab: Simple properties
          SingleChildScrollView(padding: EdgeInsets.all(16), child: _buildFormSection(simpleProperties, widget.schema['title'] as String? ?? 'Basic Information')),

          // Additional tabs: One per complex property (object or array)
          ...complexProperties.entries.map((entry) {
            final propName = entry.key;
            final propSchema = entry.value;
            final isArray = propSchema['type'] == 'array' || (propSchema['type'] is List && (propSchema['type'] as List).contains('array'));

            return isArray ? _buildComplexSection(propName, propSchema, false) : SingleChildScrollView(padding: EdgeInsets.all(16), child: _buildComplexSection(propName, propSchema, true));
          }).toList(),
        ],
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

    return JsonSchemaForm(
      schema: sectionSchema,
      formData: sectionData,
      uiSchema: sectionUiSchema,
      validationErrors: validationErrors,
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
    );
  }

  // Helper method to build a complex property section (object or array)
  Widget _buildComplexSection(String propName, Map<String, dynamic> propSchema, bool isInScrollView) {
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
      ...propSchema,
      "title": propSchema['title'] ?? propName,
      "type": "object",
      "properties": {propName: propSchema},
      "required": widget.schema['required'] != null && (widget.schema['required'] as List<dynamic>).contains(propName) ? [propName] : [],
    };

    // Extract UI schema for this property
    final Map<String, dynamic> sectionUiSchema = _getUiSchema() != null ? {propName: _getUiSchema()![propName] ?? {}} : {};

    // Add special UI layout for arrays if needed
    if (isArray && !sectionUiSchema.containsKey('ui:layout')) {
      sectionUiSchema['ui:layout'] = {"fullWidth": true, "type": "grid"};
    }

    Widget formWidget = JsonSchemaForm(
      schema: sectionSchema,
      formData: propData,
      uiSchema: sectionUiSchema,
      validationErrors: validationErrors,
      onChanged: (data) {
        // Update the main form data with this property's data
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (mounted) {
            setState(() {
              if (data[propName] != null) {
                _formData[propName] = data[propName];
              }
            });
            _validateFormData(_formData);
          }
        });
      },
      onSubmit: (data) {
        _validateFormData(_formData);
      },
    );

    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [if (isInScrollView) formWidget else Expanded(child: formWidget)]);
  }

  // Helper to extract UI schema for specific fields
  Map<String, dynamic> _extractUiSchemaForSection(List<String> fields) {
    final result = {'ui:layout': _getUiSchema()?['ui:layout'] ?? {}};

    for (final field in fields) {
      if (_getUiSchema() != null && _getUiSchema()![field] != null) {
        result[field] = _getUiSchema()![field];
      }
    }

    return result;
  }

  // Returns true if the form is valid, false otherwise
  bool _validateFormData(Map<String, dynamic> data) {
    print(' -- VALIDATE --');
    try {
      // Validate the data against the schema
      final result = _jsonSchema.validate(data);
      // Filter out validation errors that not have instancePath or instancePath is empty
      validationErrors = result.errors.where((error) => error.instancePath.isNotEmpty).toList();
      //validationErrors = result.errors;

      if (!result.isValid) {
        // Process validation errors
        final Map<String, dynamic> errors = {};

        for (var error in validationErrors) {
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
        formErrors = errors;
      } else {
        print('Form is valid $validationErrors');
        // Clear errors if validation is successful
        validationErrors = [];
        formErrors = {};
      }
      setState(() {});

      _autosave();
      return validationErrors.isEmpty;
    } catch (e) {
      setState(() {
        formErrors = {'_form': 'Validation error: ${e.toString()}'};
      });

      return false;
    }
  }
}
