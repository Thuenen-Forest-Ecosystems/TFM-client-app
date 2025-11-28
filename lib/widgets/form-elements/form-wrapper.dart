import 'package:flutter/material.dart';
import 'package:terrestrial_forest_monitor/services/validation_service.dart';
import 'package:terrestrial_forest_monitor/widgets/form-elements/array-element-syncfusion.dart';
import 'package:terrestrial_forest_monitor/widgets/form-elements/array-element-trina.dart';
import 'package:terrestrial_forest_monitor/widgets/form-elements/generic-form.dart';
import 'package:terrestrial_forest_monitor/widgets/form-elements/navigation-element.dart';
import 'package:terrestrial_forest_monitor/widgets/test_trina_grid.dart';
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

class FormTab {
  final String id;
  final String label;

  FormTab({required this.id, required this.label});
}

class _FormWrapperState extends State<FormWrapper> with SingleTickerProviderStateMixin {
  late Map<String, dynamic> _localFormData;
  late Map<String, dynamic> _previousProperties;
  TabController? _tabController;
  List<FormTab> _tabs = [];
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

  List<FormTab> _buildTabsList() {
    if (widget.jsonSchema == null) return <FormTab>[];

    final schemaProperties = widget.jsonSchema!['properties'] as Map<String, dynamic>;
    final tabs = <FormTab>[];

    if (schemaProperties.containsKey('position')) {
      final title = schemaProperties['position']?['title'] as String?;
      tabs.add(FormTab(id: 'position', label: title ?? 'Position'));
    }
    tabs.add(FormTab(id: 'info', label: widget.jsonSchema!['title'] as String? ?? 'Trakt'));
    if (schemaProperties.containsKey('tree')) {
      final title = schemaProperties['tree']?['title'] as String?;
      tabs.add(FormTab(id: 'tree', label: title ?? 'WZP'));
    }
    if (schemaProperties.containsKey('edges')) {
      final title = schemaProperties['edges']?['title'] as String?;
      tabs.add(FormTab(id: 'edges', label: title ?? 'Ecken'));
    }
    if (schemaProperties.containsKey('structure_lt4m')) {
      final title = schemaProperties['structure_lt4m']?['title'] as String?;
      tabs.add(FormTab(id: 'structure_lt4m', label: title ?? 'Struktur <4m'));
    }
    if (schemaProperties.containsKey('structure_gt4m')) {
      final title = schemaProperties['structure_gt4m']?['title'] as String?;
      tabs.add(FormTab(id: 'structure_gt4m', label: title ?? 'Struktur >4m'));
    }
    if (schemaProperties.containsKey('regeneration')) {
      final title = schemaProperties['regeneration']?['title'] as String?;
      tabs.add(FormTab(id: 'regeneration', label: title ?? 'Verjüngung'));
    }
    if (schemaProperties.containsKey('deadwood')) {
      final title = schemaProperties['deadwood']?['title'] as String?;
      tabs.add(FormTab(id: 'deadwood', label: title ?? 'Totholz'));
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
        final tabId = _tabs[index].id;

        // Check if there are validation errors for this tab
        if (widget.validationResult != null && !widget.validationResult!.isValid) {
          final tabErrors = widget.validationResult!.errors.where((error) {
            return _isErrorForTab(error, tabId);
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
      if (key.isEmpty) {
        // For root-level fields (info tab), merge the values into _localFormData
        if (value is Map<String, dynamic>) {
          _localFormData.addAll(value);
        }
      } else {
        // For nested properties, set the value directly
        _localFormData[key] = value;
      }
    });

    // Notify parent of changes
    widget.onFormDataChanged?.call(Map<String, dynamic>.from(_localFormData));
  }

  bool _hasErrorsForTab(String tabId) {
    if (widget.validationResult == null || widget.validationResult!.isValid) {
      return false;
    }

    return widget.validationResult!.errors.any((error) {
      return _isErrorForTab(error, tabId);
    });
  }

  int _getErrorCountForTab(String tabId) {
    if (widget.validationResult == null || widget.validationResult!.isValid) {
      return 0;
    }

    return widget.validationResult!.errors.where((error) {
      return _isErrorForTab(error, tabId);
    }).length;
  }

  bool _isErrorForTab(ValidationError error, String tabId) {
    final path = error.instancePath ?? '';

    // Use tabId directly as property name (except for 'info' tab)
    String propertyName = tabId == 'info' ? '' : tabId;

    // Check if error path starts with the property name
    if (propertyName.isNotEmpty && path.startsWith('/$propertyName')) {
      return true;
    }

    // Check if it's a root-level required error for this property
    if (path.isEmpty && error.keyword == 'required') {
      final missingProperty = error.params?['missingProperty'] as String?;
      if (missingProperty == propertyName) {
        return true;
      }
      // Special case for position tab
      if (tabId == 'position' && missingProperty == 'position') {
        return true;
      }

      // For 'info' tab, only show required errors for root-level scalar fields
      // Exclude errors for array/object properties that have their own tabs
      if (tabId == 'info') {
        final excludedProperties = [
          'position',
          'tree',
          'edges',
          'structure_lt4m',
          'structure_gt4m',
          'regeneration',
          'deadwood',
        ];
        if (missingProperty != null && !excludedProperties.contains(missingProperty)) {
          return true;
        }
      }
    }

    // For 'info' tab, only show root-level field errors (not nested in arrays/objects)
    if (tabId == 'info' && path.isNotEmpty) {
      // Only include errors for direct root fields (e.g., "/fieldName")
      // Exclude errors in nested structures (e.g., "/tree/0/field", "/position/field")
      final pathSegments = path.split('/').where((s) => s.isNotEmpty).toList();
      if (pathSegments.length == 1) {
        // Single segment means root-level field error
        final excludedProperties = [
          'position',
          'tree',
          'edges',
          'structure_lt4m',
          'structure_gt4m',
          'regeneration',
          'deadwood',
        ];
        if (!excludedProperties.contains(pathSegments[0])) {
          return true;
        }
      }
      return false;
    }

    // For 'info' tab, show root-level errors only
    if (tabId == 'info' && path.isEmpty) {
      return true;
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
          tabs: _tabs.map((tab) {
            final hasErrors = _hasErrorsForTab(tab.id);
            return Tab(
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(tab.label),
                  if (hasErrors) ...[
                    const SizedBox(width: 8),
                    Container(
                      padding: const EdgeInsets.all(6),
                      decoration: BoxDecoration(color: Colors.red, shape: BoxShape.circle),
                      child: Text(
                        '${_getErrorCountForTab(tab.id)}',
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
            children: _tabs.map((tab) {
              switch (tab.id) {
                case 'position':
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
                case 'info':
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
                case 'tree':
                  return ArrayElementTrina(
                    jsonSchema: schemaProperties['tree'],
                    data: _localFormData['tree'],
                    propertyName: 'tree',
                    validationResult: widget.validationResult,
                    onDataChanged: (updatedData) {
                      _updateField('tree', updatedData);
                    },
                  );
                case 'edges':
                  return ArrayElementTrina(
                    jsonSchema: schemaProperties['edges'],
                    data: _localFormData['edges'],
                    propertyName: 'edges',
                    validationResult: widget.validationResult,
                    onDataChanged: (updatedData) {
                      _updateField('edges', updatedData);
                    },
                  );
                case 'structure_lt4m':
                  return ArrayElementTrina(
                    jsonSchema: schemaProperties['structure_lt4m'],
                    data: _localFormData['structure_lt4m'],
                    propertyName: 'structure_lt4m',
                    validationResult: widget.validationResult,
                    onDataChanged: (updatedData) {
                      _updateField('structure_lt4m', updatedData);
                    },
                  );
                case 'structure_gt4m':
                  return ArrayElementTrina(
                    jsonSchema: schemaProperties['structure_gt4m'],
                    data: _localFormData['structure_gt4m'],
                    propertyName: 'structure_gt4m',
                    validationResult: widget.validationResult,
                    onDataChanged: (updatedData) {
                      _updateField('structure_gt4m', updatedData);
                    },
                  );
                case 'regeneration':
                  return ArrayElementTrina(
                    jsonSchema: schemaProperties['regeneration'],
                    data: _localFormData['regeneration'],
                    propertyName: 'regeneration',
                    validationResult: widget.validationResult,
                    onDataChanged: (updatedData) {
                      _updateField('regeneration', updatedData);
                    },
                  );
                case 'deadwood':
                  return ArrayElementTrina(
                    jsonSchema: schemaProperties['deadwood'],
                    data: _localFormData['deadwood'],
                    propertyName: 'deadwood',
                    validationResult: widget.validationResult,
                    onDataChanged: (updatedData) {
                      _updateField('deadwood', updatedData);
                    },
                  );
                default:
                  return Center(child: Text('${tab.label} Form'));
              }
            }).toList(),
          ),
        ),
      ],
    );
  }
}
