import 'package:flutter/material.dart';
import 'package:terrestrial_forest_monitor/services/validation_service.dart';
import 'package:terrestrial_forest_monitor/widgets/form-elements/array-element-syncfusion.dart';
import 'package:terrestrial_forest_monitor/widgets/form-elements/generic-form.dart';
import 'package:terrestrial_forest_monitor/widgets/form-elements/navigation-element.dart';
import 'package:terrestrial_forest_monitor/widgets/validation_errors_dialog.dart';

class FormWrapper extends StatefulWidget {
  final Map<String, dynamic>? jsonSchema;
  final Map<String, dynamic>? formData;
  final Map<String, dynamic>? previousFormData;
  final ValidationResult? validationResult;

  final Function(Map<String, dynamic>)? onFormDataChanged;

  const FormWrapper({
    super.key,
    this.jsonSchema,
    this.formData,
    this.previousFormData,
    this.onFormDataChanged,
    this.validationResult,
  });
  @override
  State<FormWrapper> createState() => _FormWrapperState();
}

class _FormWrapperState extends State<FormWrapper> with SingleTickerProviderStateMixin {
  late Map<String, dynamic> _localFormData;
  late Map<String, dynamic> _previousProperties;
  TabController? _tabController;
  List<String> _tabs = [];
  int? _previousTabIndex;

  @override
  void initState() {
    super.initState();
    _localFormData = Map<String, dynamic>.from(widget.formData ?? {});
    _previousProperties = Map<String, dynamic>.from(widget.previousFormData ?? {});

    // Initialize tabs and tab controller
    _tabs = _buildTabsList();
    if (_tabs.isNotEmpty) {
      _tabController = TabController(length: _tabs.length, vsync: this);
      _previousTabIndex = _tabController!.index;
    }
  }

  List<String> _buildTabsList() {
    if (widget.jsonSchema == null) return [];

    final schemaProperties = widget.jsonSchema!['properties'] as Map<String, dynamic>;
    final tabs = <String>[];

    if (schemaProperties.containsKey('position')) {
      tabs.add('Position');
    }
    tabs.add('Trakt');
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

    return tabs;
  }

  @override
  void didUpdateWidget(FormWrapper oldWidget) {
    super.didUpdateWidget(oldWidget);
    // Don't reset local form data when parent data changes
    // The parent data changes are triggered by our own _updateField calls via onFormDataChanged
    // Resetting here would discard in-flight user edits during validation cycles

    // Only update if it's truly external data (e.g., validation result changed without data change)
    if (widget.previousFormData != oldWidget.previousFormData) {
      _previousProperties = Map<String, dynamic>.from(widget.previousFormData ?? {});
    }

    // Rebuild tabs if schema changed
    if (widget.jsonSchema != oldWidget.jsonSchema) {
      final newTabs = _buildTabsList();
      if (newTabs.length != _tabs.length) {
        _tabs = newTabs;
        _tabController?.dispose();
        if (_tabs.isNotEmpty) {
          _tabController = TabController(length: _tabs.length, vsync: this);
        }
      }
    }
  }

  @override
  void dispose() {
    _tabController?.dispose();
    super.dispose();
  }

  void _onTabTapped(int index) {
    // Check if the tab was already active BEFORE this tap
    final wasAlreadyActive = _previousTabIndex == index;

    // Update the previous tab index for next tap
    _previousTabIndex = index;

    // Only show dialog if tab was already active
    if (wasAlreadyActive) {
      // Tab is already active - show validation errors for this tab
      debugPrint('Already active tab tapped: $index');

      if (index < _tabs.length) {
        final tabName = _tabs[index];

        // Check if there are validation errors for this tab
        if (widget.validationResult != null && !widget.validationResult!.isValid) {
          final tabErrors =
              widget.validationResult!.errors.where((error) {
                return _isErrorForTab(error, tabName);
              }).toList();

          if (tabErrors.isNotEmpty) {
            // Create a filtered validation result with only tab-specific errors
            final filteredResult = ValidationResult(isValid: false, errors: tabErrors);

            // Show dialog with filtered errors
            ValidationErrorsDialog.show(context, filteredResult, showActions: false);
          }
        } else {
          // No validation errors at all
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Keine Validierungsfehler'),
              backgroundColor: Colors.green,
              duration: Duration(seconds: 1),
            ),
          );
        }
      }
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
      case 'Position':
        propertyName = 'position';
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
      // Special case for Position tab which can also have 'position' errors
      if (tab == 'Position' && missingProperty == 'position') {
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

    if (_tabs.isEmpty) {
      return const Center(child: Text('No form tabs available'));
    }

    final schemaProperties = widget.jsonSchema!['properties'] as Map<String, dynamic>;

    return Column(
      children: [
        TabBar(
          controller: _tabController!,
          isScrollable: true,
          onTap: _onTabTapped,
          tabs:
              _tabs.map((tab) {
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
                          child: Text(
                            '${_getErrorCountForTab(tab)}',
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 10,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                      ],
                    ],
                  ),
                );
              }).toList(),
        ),
        Expanded(
          child: TabBarView(
            controller: _tabController!,
            physics: const NeverScrollableScrollPhysics(),
            children:
                _tabs.map((tab) {
                  if (tab == 'Position') {
                    return NavigationElement(
                      jsonSchema: schemaProperties['position'],
                      data: _localFormData,
                      propertyName: 'position',
                      previous_properties: _previousProperties,
                      validationResult: widget.validationResult,
                      onDataChanged: (updatedData) {
                        _updateField('position', updatedData);
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
    );
  }
}
