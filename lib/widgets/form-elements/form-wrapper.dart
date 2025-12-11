import 'package:flutter/material.dart';
import 'package:terrestrial_forest_monitor/services/validation_service.dart';
import 'package:terrestrial_forest_monitor/widgets/form-elements/add-row-dialog.dart';
import 'package:terrestrial_forest_monitor/widgets/form-elements/array-element-trina.dart';
import 'package:terrestrial_forest_monitor/widgets/form-elements/generic-form.dart';
import 'package:terrestrial_forest_monitor/widgets/form-elements/navigation-element.dart';
import 'package:terrestrial_forest_monitor/widgets/validation_errors_dialog.dart';

class FormWrapper extends StatefulWidget {
  final Map<String, dynamic>? jsonSchema;
  final Map<String, dynamic>? formData;
  final Map<String, dynamic>? previousFormData;
  final TFMValidationResult? validationResult;

  final Function(Map<String, dynamic>)? onFormDataChanged;
  final Function(String?)? onNavigateToTab;

  const FormWrapper({super.key, this.jsonSchema, this.formData, this.previousFormData, this.onFormDataChanged, this.validationResult, this.onNavigateToTab});
  @override
  State<FormWrapper> createState() => FormWrapperState();
}

class FormTab {
  final String id;
  final String label;

  FormTab({required this.id, required this.label});
}

class FormWrapperState extends State<FormWrapper> with SingleTickerProviderStateMixin {
  late Map<String, dynamic> _localFormData;
  late Map<String, dynamic> _previousProperties;
  TabController? _tabController;
  List<FormTab> _tabs = [];
  int? _previousTabIndex;

  // Track current tab type and ArrayElementTrina widgets
  String? _currentTabType;
  final Map<String, GlobalKey<ArrayElementTrinaState>> _arrayElementKeys = {};

  @override
  void initState() {
    super.initState();
    _localFormData = Map<String, dynamic>.from(widget.formData ?? {});
    _previousProperties = Map<String, dynamic>.from(widget.previousFormData ?? {});

    // Initialize tabs and tab controller
    _tabs = _buildTabsList();
    if (_tabs.isNotEmpty) {
      // Find position tab index, default to 0 if not found
      final positionTabIndex = _tabs.indexWhere((tab) => tab.id == 'position');
      final initialIndex = positionTabIndex >= 0 ? positionTabIndex : 0;

      _tabController = TabController(length: _tabs.length, vsync: this, initialIndex: initialIndex);
      _previousTabIndex = _tabController!.index;

      // Listen to tab changes to update current tab type
      _tabController!.addListener(_onTabChanged);
      _updateCurrentTabType();
    }
  }

  List<FormTab> _buildTabsList() {
    if (widget.jsonSchema == null) return <FormTab>[];

    final schemaProperties = widget.jsonSchema!['properties'] as Map<String, dynamic>;
    final tabs = <FormTab>[];

    tabs.add(FormTab(id: 'info', label: widget.jsonSchema!['title'] as String? ?? 'Trakt'));

    if (schemaProperties.containsKey('position')) {
      final title = schemaProperties['position']?['title'] as String?;
      tabs.add(FormTab(id: 'position', label: title ?? 'Position'));
    }

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
        _tabController?.removeListener(_onTabChanged);
        _tabController?.dispose();
        if (_tabs.isNotEmpty) {
          // Find position tab index, default to 0 if not found
          final positionTabIndex = _tabs.indexWhere((tab) => tab.id == 'position');
          final initialIndex = positionTabIndex >= 0 ? positionTabIndex : 0;

          _tabController = TabController(length: _tabs.length, vsync: this, initialIndex: initialIndex);
          _tabController!.addListener(_onTabChanged);
          _updateCurrentTabType();
        }
      }
    }
  }

  // Public method to allow external navigation to tabs
  void navigateToTab(String? tabId) {
    debugPrint('FormWrapperState.navigateToTab called with: $tabId');
    debugPrint('Current tab index: ${_tabController?.index}, length: ${_tabController?.length}');
    debugPrint('Tabs: ${_tabs.map((t) => '${t.id}:${t.label}').toList()}');
    _navigateToTab(tabId);
  }

  void _navigateToTab(String? tabId) {
    debugPrint('_navigateToTab called with tabId: $tabId');
    if (tabId == null) {
      debugPrint('Early return: tabId is null');
      return;
    }

    if (_tabController == null) {
      debugPrint('Early return: _tabController is null');
      return;
    }

    debugPrint('Available tabs: ${_tabs.map((t) => t.id).toList()}');
    final tabIndex = _tabs.indexWhere((tab) => tab.id == tabId);
    debugPrint('Found tabIndex: $tabIndex for tabId: $tabId');

    if (tabIndex >= 0) {
      debugPrint('Calling animateTo($tabIndex)');
      _tabController!.animateTo(tabIndex);
      _previousTabIndex = tabIndex;
      debugPrint('Tab animation completed, new index should be: $tabIndex');
    } else {
      debugPrint('Tab not found! tabId=$tabId not in ${_tabs.map((t) => t.id).toList()}');
    }
  }

  void _onTabChanged() {
    _updateCurrentTabType();
  }

  void _updateCurrentTabType() {
    if (_tabController == null || _tabs.isEmpty) {
      _currentTabType = null;
      return;
    }

    final currentIndex = _tabController!.index;
    if (currentIndex >= 0 && currentIndex < _tabs.length) {
      final tabId = _tabs[currentIndex].id;
      final isArrayTab = _isArrayElementTrinaTab(tabId);
      debugPrint('Tab changed to: $tabId (index: $currentIndex), isArrayTab: $isArrayTab');
      setState(() {
        _currentTabType = isArrayTab ? 'array' : 'other';
      });
      debugPrint('Current tab type set to: $_currentTabType');
    }
  }

  bool _isArrayElementTrinaTab(String tabId) {
    return ['tree', 'edges', 'structure_lt4m', 'structure_gt4m', 'regeneration', 'deadwood'].contains(tabId);
  }

  void _addRowToCurrentTab() {
    if (_tabController == null || _tabs.isEmpty) return;

    final currentIndex = _tabController!.index;
    if (currentIndex >= 0 && currentIndex < _tabs.length) {
      final tabId = _tabs[currentIndex].id;
      if (_isArrayElementTrinaTab(tabId)) {
        final key = _arrayElementKeys[tabId];
        key?.currentState?.addRow();
      }
    }
  }

  void _addRowToCurrentTabAsFormDialog() async {
    if (_tabController == null || _tabs.isEmpty || widget.jsonSchema == null) return;

    final currentIndex = _tabController!.index;
    if (currentIndex >= 0 && currentIndex < _tabs.length) {
      final tabId = _tabs[currentIndex].id;
      if (_isArrayElementTrinaTab(tabId)) {
        final schemaProperties = widget.jsonSchema!['properties'] as Map<String, dynamic>;
        final arraySchema = schemaProperties[tabId] as Map<String, dynamic>?;

        if (arraySchema != null) {
          await AddRowDialog.show(
            context: context,
            jsonSchema: arraySchema,
            propertyName: tabId,
            onRowAdded: (newRowData) {
              // Add the new row data to the current array
              final currentArray = List<dynamic>.from(_localFormData[tabId] ?? []);

              // Handle auto-increment fields
              final itemSchema = arraySchema['items'] as Map<String, dynamic>?;
              final properties = itemSchema?['properties'] as Map<String, dynamic>?;

              if (properties != null) {
                properties.forEach((key, value) {
                  final propertySchema = value as Map<String, dynamic>;
                  final typeValue = propertySchema['type'];

                  String? type;
                  if (typeValue is String) {
                    type = typeValue;
                  } else if (typeValue is List) {
                    type = typeValue.firstWhere((t) => t != 'null' && t != null, orElse: () => null) as String?;
                  }

                  final tfm = propertySchema['\$tfm'] as Map<String, dynamic>?;
                  final form = tfm?['form'] as Map<String, dynamic>?;
                  final autoIncrement = form?['autoIncrement'] as bool? ?? false;

                  if (autoIncrement && (type == 'integer' || type == 'number')) {
                    // Find max value and increment
                    final existingValues = currentArray.map((row) => row is Map ? row[key] : null).where((v) => v != null && v is num).map((v) => (v as num).toInt()).toList();

                    final defaultValue = propertySchema['default'] as int? ?? 1;
                    newRowData[key] = existingValues.isEmpty ? defaultValue : (existingValues.reduce((a, b) => a > b ? a : b) + 1);
                  }
                });
              }

              currentArray.add(newRowData);
              _updateField(tabId, currentArray);
            },
          );
        }
      }
    }
  }

  @override
  void dispose() {
    _tabController?.removeListener(_onTabChanged);
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
          final tabErrors = widget.validationResult!.allErrors.where((error) {
            return _isErrorForTab(error, tabId);
          }).toList();

          if (tabErrors.isNotEmpty) {
            // Create a filtered validation result with only tab-specific errors
            final filteredResult = TFMValidationResult(ajvValid: false, ajvErrors: tabErrors.whereType<ValidationError>().toList(), tfmAvailable: widget.validationResult!.tfmAvailable, tfmErrors: tabErrors.whereType<TFMValidationError>().toList());

            // Show dialog with filtered errors
            ValidationErrorsDialog.show(context, filteredResult, showActions: false, onNavigateToTab: widget.onNavigateToTab ?? _navigateToTab);
          }
        } else {
          // No validation errors at all
          ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Keine Validierungsfehler'), backgroundColor: Colors.green, duration: Duration(seconds: 1)));
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

    return widget.validationResult!.allErrors.any((error) {
      return _isErrorForTab(error, tabId);
    });
  }

  int _getErrorCountForTab(String tabId) {
    if (widget.validationResult == null || widget.validationResult!.isValid) {
      return 0;
    }

    return widget.validationResult!.allErrors.where((error) {
      return _isErrorForTab(error, tabId);
    }).length;
  }

  bool _isErrorForTab(dynamic error, String tabId) {
    final path = error is ValidationError ? (error.instancePath ?? '') : ((error as TFMValidationError).instancePath ?? '');

    // For 'info' tab, only show errors for primitive fields (not arrays/objects)
    if (tabId == 'info') {
      // List of properties that are arrays/objects and have their own tabs
      final excludedProperties = ['position', 'tree', 'edges', 'structure_lt4m', 'structure_gt4m', 'regeneration', 'deadwood'];

      // Handle required errors at root level
      final keyword = error is ValidationError ? error.keyword : null;
      if (path.isEmpty && keyword == 'required') {
        final params = error is ValidationError ? error.params : null;
        final missingProperty = params?['missingProperty'] as String?;
        // Only show if it's NOT one of the excluded (array/object) properties
        return missingProperty != null && !excludedProperties.contains(missingProperty);
      }

      // Handle field-specific errors
      if (path.isNotEmpty) {
        final pathSegments = path.split('/').where((s) => s.isNotEmpty).toList();
        if (pathSegments.length == 1) {
          // Single segment = root-level field error
          // Only show if it's NOT one of the excluded properties
          return !excludedProperties.contains(pathSegments[0]);
        }
        // Multiple segments = nested error, don't show in info tab
        return false;
      }

      // Other root-level errors (not field-specific)
      return false;
    }

    // For other tabs, use tabId as property name
    String propertyName = tabId;

    // Check if error path starts with the property name
    if (path.startsWith('/$propertyName')) {
      return true;
    }

    // Check if it's a root-level required error for this property
    final keyword = error is ValidationError ? error.keyword : null;
    if (path.isEmpty && keyword == 'required') {
      final params = error is ValidationError ? error.params : null;
      final missingProperty = params?['missingProperty'] as String?;
      return missingProperty == propertyName;
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
                        style: const TextStyle(color: Colors.white, fontSize: 10, fontWeight: FontWeight.bold),
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
                    jsonSchema: schemaProperties,
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
                  _arrayElementKeys['tree'] ??= GlobalKey<ArrayElementTrinaState>();
                  return ArrayElementTrina(
                    key: _arrayElementKeys['tree'],
                    jsonSchema: schemaProperties['tree'],
                    data: _localFormData['tree'],
                    propertyName: 'tree',
                    validationResult: widget.validationResult,
                    onDataChanged: (updatedData) {
                      _updateField('tree', updatedData);
                    },
                  );
                case 'edges':
                  _arrayElementKeys['edges'] ??= GlobalKey<ArrayElementTrinaState>();
                  return ArrayElementTrina(
                    key: _arrayElementKeys['edges'],
                    jsonSchema: schemaProperties['edges'],
                    data: _localFormData['edges'],
                    propertyName: 'edges',
                    validationResult: widget.validationResult,
                    onDataChanged: (updatedData) {
                      _updateField('edges', updatedData);
                    },
                  );
                case 'structure_lt4m':
                  _arrayElementKeys['structure_lt4m'] ??= GlobalKey<ArrayElementTrinaState>();
                  return ArrayElementTrina(
                    key: _arrayElementKeys['structure_lt4m'],
                    jsonSchema: schemaProperties['structure_lt4m'],
                    data: _localFormData['structure_lt4m'],
                    propertyName: 'structure_lt4m',
                    validationResult: widget.validationResult,
                    onDataChanged: (updatedData) {
                      _updateField('structure_lt4m', updatedData);
                    },
                  );
                case 'structure_gt4m':
                  _arrayElementKeys['structure_gt4m'] ??= GlobalKey<ArrayElementTrinaState>();
                  return ArrayElementTrina(
                    key: _arrayElementKeys['structure_gt4m'],
                    jsonSchema: schemaProperties['structure_gt4m'],
                    data: _localFormData['structure_gt4m'],
                    propertyName: 'structure_gt4m',
                    validationResult: widget.validationResult,
                    onDataChanged: (updatedData) {
                      _updateField('structure_gt4m', updatedData);
                    },
                  );
                case 'regeneration':
                  _arrayElementKeys['regeneration'] ??= GlobalKey<ArrayElementTrinaState>();
                  return ArrayElementTrina(
                    key: _arrayElementKeys['regeneration'],
                    jsonSchema: schemaProperties['regeneration'],
                    data: _localFormData['regeneration'],
                    propertyName: 'regeneration',
                    validationResult: widget.validationResult,
                    onDataChanged: (updatedData) {
                      _updateField('regeneration', updatedData);
                    },
                  );
                case 'deadwood':
                  _arrayElementKeys['deadwood'] ??= GlobalKey<ArrayElementTrinaState>();
                  return ArrayElementTrina(
                    key: _arrayElementKeys['deadwood'],
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
        // Only show BottomAppBar for ArrayElementTrina tabs
        if (_currentTabType == 'array')
          BottomAppBar(
            child: Container(
              height: 56,
              padding: const EdgeInsets.symmetric(horizontal: 16.0),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                children: [
                  ElevatedButton.icon(
                    onPressed: _addRowToCurrentTab,
                    icon: const Icon(Icons.add),
                    label: Text('Add Row'),
                    style: ElevatedButton.styleFrom(backgroundColor: Theme.of(context).colorScheme.primary, foregroundColor: Theme.of(context).colorScheme.onPrimary),
                  ),
                  ElevatedButton.icon(
                    onPressed: _addRowToCurrentTabAsFormDialog,
                    icon: const Icon(Icons.add),
                    label: Text('Add Row (Form)'),
                    style: ElevatedButton.styleFrom(backgroundColor: Theme.of(context).colorScheme.primary, foregroundColor: Theme.of(context).colorScheme.onPrimary),
                  ),
                ],
              ),
            ),
          ),
      ],
    );
  }
}
