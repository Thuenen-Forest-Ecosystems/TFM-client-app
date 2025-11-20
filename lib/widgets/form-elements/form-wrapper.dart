import 'package:flutter/material.dart';
import 'package:terrestrial_forest_monitor/services/validation_service.dart';
import 'package:terrestrial_forest_monitor/widgets/form-elements/array-element-syncfusion.dart';
import 'package:terrestrial_forest_monitor/widgets/form-elements/generic-form.dart';
import 'package:terrestrial_forest_monitor/widgets/form-elements/navigation-element.dart';

class FormWrapper extends StatefulWidget {
  final Map<String, dynamic>? jsonSchema;
  final Map<String, dynamic>? formData;
  final Map<String, dynamic>? previousFormData;
  final ValidationResult? validationResult;

  final Function(Map<String, dynamic>)? onFormDataChanged;

  const FormWrapper({super.key, this.jsonSchema, this.formData, this.previousFormData, this.onFormDataChanged, this.validationResult});
  @override
  State<FormWrapper> createState() => _FormWrapperState();
}

class _FormWrapperState extends State<FormWrapper> {
  late Map<String, dynamic> _localFormData;
  late Map<String, dynamic> _previousProperties;

  @override
  void initState() {
    super.initState();
    _localFormData = Map<String, dynamic>.from(widget.formData ?? {});
    _previousProperties = Map<String, dynamic>.from(widget.previousFormData ?? {});
  }

  @override
  void didUpdateWidget(FormWrapper oldWidget) {
    super.didUpdateWidget(oldWidget);
    // Update local form data if parent data changes
    if (widget.formData != oldWidget.formData) {
      _localFormData = Map<String, dynamic>.from(widget.formData ?? {});
      _previousProperties = Map<String, dynamic>.from(widget.previousFormData ?? {});
    }
  }

  void _updateField(String key, dynamic value) {
    setState(() {
      _localFormData[key] = value;
    });

    // Notify parent of changes
    widget.onFormDataChanged?.call(Map<String, dynamic>.from(_localFormData));
  }

  bool _hasErrorsForTab(String tab) {
    if (widget.validationResult == null || widget.validationResult!.isValid) {
      return false;
    }

    return widget.validationResult!.errors.any((error) {
      return _isErrorForTab(error, tab);
    });
  }

  int _getErrorCountForTab(String tab) {
    if (widget.validationResult == null || widget.validationResult!.isValid) {
      return 0;
    }

    return widget.validationResult!.errors.where((error) {
      return _isErrorForTab(error, tab);
    }).length;
  }

  bool _isErrorForTab(ValidationError error, String tab) {
    final path = error.instancePath ?? '';

    // Map tab names to their corresponding property names in the schema
    String propertyName;
    switch (tab) {
      case 'Navigation':
        propertyName = 'plot_coordinates';
        break;
      case 'Tree':
        propertyName = 'tree';
        break;
      case 'Edges':
        propertyName = 'edges';
        break;
      case 'structure_lt4m':
        propertyName = 'structure_lt4m';
        break;
      case 'structure_gt4m':
        propertyName = 'structure_gt4m';
        break;
      case 'regeneration':
        propertyName = 'regeneration';
        break;
      case 'deadwood':
        propertyName = 'deadwood';
        break;
      default:
        return false;
    }

    // Check if error path starts with the property name
    if (path.startsWith('/$propertyName')) {
      return true;
    }

    // Check if it's a root-level required error for this property
    if (path.isEmpty && error.keyword == 'required') {
      final missingProperty = error.params?['missingProperty'] as String?;
      if (missingProperty == propertyName) {
        return true;
      }
      // Special case for Navigation tab which can also have 'position' errors
      if (tab == 'Navigation' && missingProperty == 'position') {
        return true;
      }
    }

    return false;
  }

  @override
  Widget build(BuildContext context) {
    if (widget.jsonSchema == null) {
      return const Center(child: Text('No schema available'));
    }

    // Extract tabs from schema properties
    final schemaProperties = widget.jsonSchema!['properties'] as Map<String, dynamic>;
    final tabs = <String>[];

    // Add tabs based on schema structure
    tabs.add('Trakt');

    if (schemaProperties.containsKey('plot_coordinates')) {
      tabs.add('Navigation');
    }
    if (schemaProperties.containsKey('tree')) {
      tabs.add('Tree');
    }
    if (schemaProperties.containsKey('edges')) {
      tabs.add('Edges');
    }
    if (schemaProperties.containsKey('structure_lt4m')) {
      tabs.add('structure_lt4m');
    }
    if (schemaProperties.containsKey('structure_gt4m')) {
      tabs.add('structure_gt4m');
    }
    if (schemaProperties.containsKey('regeneration')) {
      tabs.add('regeneration');
    }
    if (schemaProperties.containsKey('deadwood')) {
      tabs.add('deadwood');
    }

    if (tabs.isEmpty) {
      return const Center(child: Text('No form tabs available'));
    }

    return DefaultTabController(
      length: tabs.length,
      child: Column(
        children: [
          TabBar(
            isScrollable: true,
            tabs:
                tabs.map((tab) {
                  final hasErrors = _hasErrorsForTab(tab);
                  return Tab(
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(tab),
                        if (hasErrors) ...[
                          const SizedBox(width: 8),
                          Container(
                            padding: const EdgeInsets.all(6),
                            decoration: BoxDecoration(color: Colors.red, shape: BoxShape.circle),
                            child: Text('${_getErrorCountForTab(tab)}', style: const TextStyle(color: Colors.white, fontSize: 10, fontWeight: FontWeight.bold)),
                          ),
                        ],
                      ],
                    ),
                  );
                }).toList(),
          ),
          Expanded(
            child: TabBarView(
              physics: const NeverScrollableScrollPhysics(),
              children:
                  tabs.map((tab) {
                    if (tab == 'Navigation') {
                      return NavigationElement(
                        jsonSchema: schemaProperties['plot_coordinates'],
                        data: _localFormData,
                        propertyName: 'position',
                        previous_properties: _previousProperties,
                        validationResult: widget.validationResult,
                        onDataChanged: (updatedData) {
                          _updateField('plot_coordinates', updatedData);
                        },
                      );
                    } else if (tab == 'Trakt') {
                      return GenericForm(
                        jsonSchema: schemaProperties,
                        data: _localFormData,
                        propertyName: null,
                        previous_properties: _previousProperties,
                        validationResult: widget.validationResult,
                        onDataChanged: (updatedData) {
                          _updateField('', updatedData);
                        },
                      );
                    } else if (tab == 'Tree') {
                      return ArrayElementSyncfusion(
                        jsonSchema: schemaProperties['tree'],
                        data: _localFormData['tree'] ?? [],
                        propertyName: 'tree',
                        validationResult: widget.validationResult,
                        onDataChanged: (updatedData) {
                          _updateField('tree', updatedData);
                        },
                      );
                    } else if (tab == 'Edges') {
                      return ArrayElementSyncfusion(
                        jsonSchema: schemaProperties['edges'],
                        data: _localFormData['edges'] ?? [],
                        propertyName: 'edges',
                        validationResult: widget.validationResult,
                        onDataChanged: (updatedData) {
                          _updateField('edges', updatedData);
                        },
                      );
                    } else if (tab == 'structure_lt4m') {
                      return ArrayElementSyncfusion(
                        jsonSchema: schemaProperties['structure_lt4m'],
                        data: _localFormData['structure_lt4m'] ?? [],
                        propertyName: 'structure_lt4m',
                        validationResult: widget.validationResult,
                        onDataChanged: (updatedData) {
                          _updateField('structure_lt4m', updatedData);
                        },
                      );
                    } else if (tab == 'structure_gt4m') {
                      return ArrayElementSyncfusion(
                        jsonSchema: schemaProperties['structure_gt4m'],
                        data: _localFormData['structure_gt4m'] ?? [],
                        propertyName: 'structure_gt4m',
                        validationResult: widget.validationResult,
                        onDataChanged: (updatedData) {
                          _updateField('structure_gt4m', updatedData);
                        },
                      );
                    } else if (tab == 'regeneration') {
                      return ArrayElementSyncfusion(
                        jsonSchema: schemaProperties['regeneration'],
                        data: _localFormData['regeneration'] ?? [],
                        propertyName: 'regeneration',
                        validationResult: widget.validationResult,
                        onDataChanged: (updatedData) {
                          _updateField('regeneration', updatedData);
                        },
                      );
                    } else if (tab == 'deadwood') {
                      return ArrayElementSyncfusion(
                        jsonSchema: schemaProperties['deadwood'],
                        data: _localFormData['deadwood'] ?? [],
                        propertyName: 'deadwood',
                        validationResult: widget.validationResult,
                        onDataChanged: (updatedData) {
                          _updateField('deadwood', updatedData);
                        },
                      );
                    }
                    return Center(child: Text('$tab Form'));
                  }).toList(),
            ),
          ),
        ],
      ),
    );
  }
}
