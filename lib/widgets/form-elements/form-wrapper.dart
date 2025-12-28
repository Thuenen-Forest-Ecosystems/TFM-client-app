import 'package:flutter/material.dart';
import 'package:terrestrial_forest_monitor/services/validation_service.dart';
import 'package:terrestrial_forest_monitor/services/layout_service.dart';
import 'package:terrestrial_forest_monitor/models/layout_config.dart';
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
  final String? layoutName;

  final Function(Map<String, dynamic>)? onFormDataChanged;
  final Function(String?)? onNavigateToTab;

  const FormWrapper({
    super.key,
    this.jsonSchema,
    this.formData,
    this.previousFormData,
    this.onFormDataChanged,
    this.validationResult,
    this.onNavigateToTab,
    this.layoutName,
  });
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

  // Layout configuration
  LayoutConfig? _layoutConfig;
  bool _layoutLoaded = false;

  // Track current tab type and ArrayElementTrina widgets
  String? _currentTabType;
  final Map<String, GlobalKey<ArrayElementTrinaState>> _arrayElementKeys = {};

  @override
  void initState() {
    super.initState();
    _localFormData = Map<String, dynamic>.from(widget.formData ?? {});
    _previousProperties = Map<String, dynamic>.from(widget.previousFormData ?? {});

    // Load layout configuration asynchronously
    _initializeLayout();
  }

  Future<void> _initializeLayout() async {
    // Try to load layout configuration if layoutName is provided
    if (widget.layoutName != null) {
      _layoutConfig = await LayoutService.loadLayout(widget.layoutName!);
      if (_layoutConfig != null) {
        debugPrint('Loaded layout configuration: ${widget.layoutName}');
      } else {
        debugPrint('Failed to load layout ${widget.layoutName}, using fallback');
      }
    }

    setState(() {
      _layoutLoaded = true;
      // Rebuild tabs with layout configuration
      _tabs = _buildTabsList();

      // Pre-create all GlobalKeys for array elements to avoid duplicates in TabBarView
      if (_layoutConfig != null) {
        _preCreateArrayKeys(_layoutConfig!.layout);
      }

      // Initialize tab controller
      if (_tabs.isNotEmpty) {
        final positionTabIndex = _tabs.indexWhere((tab) => tab.id == 'position');
        final initialIndex = positionTabIndex >= 0 ? positionTabIndex : 0;

        _tabController = TabController(
          length: _tabs.length,
          vsync: this,
          initialIndex: initialIndex,
        );
        _previousTabIndex = _tabController!.index;
        _tabController!.addListener(_onTabChanged);
        _updateCurrentTabType();
      }
    });
  }

  List<FormTab> _buildTabsList() {
    if (widget.jsonSchema == null) return <FormTab>[];

    // Use layout configuration if available
    if (_layoutConfig != null) {
      return _buildTabsFromLayout();
    }

    // Fallback to hard-coded structure
    return _buildTabsListFallback();
  }

  /// Build tabs from layout configuration
  List<FormTab> _buildTabsFromLayout() {
    final tabs = <FormTab>[];
    final tabItems = LayoutService.getTabItems(_layoutConfig);

    for (final item in tabItems) {
      // Get label from layout, fallback to schema title
      String label = item.label ?? item.id;

      // Try to get more descriptive label from schema if not in layout
      if (item.label == null) {
        if (item is FormLayout) {
          label = widget.jsonSchema!['title'] as String? ?? label;
        } else {
          final property = LayoutService.getPropertyForItem(item);
          if (property is String) {
            final schemaProperties = widget.jsonSchema!['properties'] as Map<String, dynamic>?;
            // Handle path-based properties
            final propertySchema = LayoutService.getSchemaByPath(schemaProperties ?? {}, property);
            label = propertySchema?['title'] as String? ?? label;
          }
        }
      }

      tabs.add(FormTab(id: item.id, label: label));
    }

    return tabs;
  }

  /// Pre-create GlobalKeys for all array layouts to avoid duplicates in TabBarView
  void _preCreateArrayKeys(LayoutItem item) {
    if (item is ArrayLayout) {
      _arrayElementKeys[item.id] ??= GlobalKey<ArrayElementTrinaState>();
    } else if (item is TabsLayout) {
      for (final child in item.items) {
        _preCreateArrayKeys(child);
      }
    } else if (item is ColumnLayout) {
      for (final child in item.items) {
        _preCreateArrayKeys(child);
      }
    } else if (item is CardLayout) {
      if (item.children != null) {
        for (final child in item.children!) {
          _preCreateArrayKeys(child);
        }
      }
    }
  }

  /// Fallback to hard-coded tab structure (backward compatibility)
  List<FormTab> _buildTabsListFallback() {
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

          _tabController = TabController(
            length: _tabs.length,
            vsync: this,
            initialIndex: initialIndex,
          );
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
    // Use layout config if available
    if (_layoutConfig != null) {
      final item = LayoutService.findItemById(_layoutConfig, tabId);
      return item != null && LayoutService.isArrayLayout(item);
    }

    // Fallback to hard-coded list
    return [
      'tree',
      'edges',
      'structure_lt4m',
      'structure_gt4m',
      'regeneration',
      'deadwood',
    ].contains(tabId);
  }

  /// Build tab content based on layout configuration or fallback to hard-coded logic
  Widget _buildTabContent(FormTab tab, Map<String, dynamic> schemaProperties) {
    // Try to use layout configuration first
    if (_layoutConfig != null) {
      final layoutItem = LayoutService.findItemById(_layoutConfig, tab.id);
      if (layoutItem != null) {
        final content = _buildWidgetFromLayout(layoutItem, schemaProperties);
        // Don't wrap tabs or arrays in ScrollView - they manage their own scrolling/sizing
        if (layoutItem is TabsLayout || layoutItem is ArrayLayout) {
          return content;
        }
        // Wrap other content in SingleChildScrollView for scrollable tabs
        return SingleChildScrollView(child: content);
      }
    }

    // Fallback to hard-coded rendering
    return _buildTabContentFallback(tab.id, schemaProperties);
  }

  /// Build widget from layout configuration (recursive)
  Widget _buildWidgetFromLayout(LayoutItem layoutItem, Map<String, dynamic> schemaProperties) {
    if (layoutItem is ColumnLayout) {
      // Column layout - stack children vertically
      return Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        mainAxisSize: MainAxisSize.min,
        children: layoutItem.items.map((child) {
          Widget childWidget = _buildWidgetFromLayout(child, schemaProperties);

          // Wrap array layouts in fixed height container since Column has unbounded height
          if (child is ArrayLayout) {
            childWidget = SizedBox(
              height: 400, // Fixed height for arrays in column layout
              child: childWidget,
            );
          }

          return Padding(padding: const EdgeInsets.only(bottom: 8.0), child: childWidget);
        }).toList(),
      );
    } else if (layoutItem is TabsLayout) {
      // Nested tabs - create a nested tab view
      return _buildNestedTabs(layoutItem, schemaProperties);
    } else if (layoutItem is FormLayout) {
      // Form layout for primitive fields
      return GenericForm(
        jsonSchema: schemaProperties,
        data: _localFormData,
        propertyName: null,
        previous_properties: _previousProperties,
        validationResult: widget.validationResult,
        includeProperties: layoutItem.properties, // Filter to only show specified properties
        onDataChanged: (updatedData) {
          _updateField('', updatedData);
        },
      );
    } else if (layoutItem is ArrayLayout) {
      // Array layout - render with appropriate component (supports paths)
      final propertyPath = layoutItem.property;
      final propertyName = propertyPath.split('.').last; // Use last segment for key

      // Use layoutItem.id as the key to ensure uniqueness (keys pre-created in _initializeLayout)
      final keyId = layoutItem.id;
      final key = _arrayElementKeys[keyId];

      // Get schema and data using path
      final propertySchema = LayoutService.getSchemaByPath(schemaProperties, propertyPath);
      final propertyData = LayoutService.getValueByPath(_localFormData, propertyPath);

      if (propertySchema == null) {
        return Center(child: Text('Schema not found for property: $propertyPath'));
      }

      if (layoutItem.component == 'datagrid') {
        return ArrayElementTrina(
          key: key,
          jsonSchema: propertySchema,
          data: propertyData,
          propertyName: propertyName,
          validationResult: widget.validationResult,
          columnConfig: layoutItem.columns,
          layoutOptions: layoutItem.options,
          onDataChanged: (updatedData) {
            LayoutService.setValueByPath(_localFormData, propertyPath, updatedData);
            widget.onFormDataChanged?.call(Map<String, dynamic>.from(_localFormData));
          },
        );
      }

      return Center(child: Text('Unsupported array component: ${layoutItem.component}'));
    } else if (layoutItem is ObjectLayout) {
      // Object layout - render with appropriate component (supports paths)
      final propertyPath = layoutItem.property;

      // Get schema and data using path
      final propertySchema = LayoutService.getSchemaByPath(schemaProperties, propertyPath);
      final propertyData = LayoutService.getValueByPath(_localFormData, propertyPath);

      if (propertySchema == null) {
        return Center(child: Text('Schema not found for property: $propertyPath'));
      }

      if (layoutItem.component == 'navigation') {
        // NavigationElement expects the parent schema, not the property schema
        final parentPath = propertyPath.split('.');
        final propertyName = parentPath.last;

        return NavigationElement(
          jsonSchema: schemaProperties,
          data: _localFormData,
          propertyName: propertyName,
          previous_properties: _previousProperties,
          validationResult: widget.validationResult,
          onDataChanged: (updatedData) {
            LayoutService.setValueByPath(_localFormData, propertyPath, updatedData);
            widget.onFormDataChanged?.call(Map<String, dynamic>.from(_localFormData));
          },
        );
      } else if (layoutItem.component == 'card') {
        // Card component
        final propertyName = propertyPath.split('.').last;
        return Card(
          child: Padding(
            padding: const EdgeInsets.all(16.0),
            child: GenericForm(
              jsonSchema: {propertyName: propertySchema},
              data: propertyData ?? {},
              propertyName: propertyName,
              previous_properties: _previousProperties,
              validationResult: widget.validationResult,
              onDataChanged: (updatedData) {
                LayoutService.setValueByPath(_localFormData, propertyPath, updatedData);
                widget.onFormDataChanged?.call(Map<String, dynamic>.from(_localFormData));
              },
            ),
          ),
        );
      }

      return Center(child: Text('Unsupported object component: ${layoutItem.component}'));
    } else if (layoutItem is CardLayout) {
      // Card layout with children
      return _buildCardWithChildren(layoutItem, schemaProperties);
    }

    return Center(child: Text('Unknown layout type: ${layoutItem.type}'));
  }

  /// Build nested tabs widget
  Widget _buildNestedTabs(TabsLayout tabsLayout, Map<String, dynamic> schemaProperties) {
    return DefaultTabController(
      length: tabsLayout.items.length,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          TabBar(
            isScrollable: true,
            tabs: tabsLayout.items.map((item) {
              final label = item.label ?? item.id;
              return Tab(text: label);
            }).toList(),
          ),
          // Use SizedBox with specific height instead of Expanded
          // This works inside SingleChildScrollView
          SizedBox(
            height: 400, // Fixed height for nested tab content
            child: TabBarView(
              physics: const NeverScrollableScrollPhysics(),
              children: tabsLayout.items.map((item) {
                return SingleChildScrollView(child: _buildWidgetFromLayout(item, schemaProperties));
              }).toList(),
            ),
          ),
        ],
      ),
    );
  }

  /// Build card with nested children
  Widget _buildCardWithChildren(CardLayout cardLayout, Map<String, dynamic> schemaProperties) {
    if (cardLayout.children == null || cardLayout.children!.isEmpty) {
      // Card with simple properties
      if (cardLayout.properties != null) {
        return Card(
          margin: const EdgeInsets.all(8.0),
          child: Padding(
            padding: const EdgeInsets.all(16.0),
            child: GenericForm(
              jsonSchema: schemaProperties,
              data: _localFormData,
              propertyName: null,
              previous_properties: _previousProperties,
              validationResult: widget.validationResult,
              onDataChanged: (updatedData) {
                _updateField('', updatedData);
              },
            ),
          ),
        );
      }
      return Card(
        child: Padding(
          padding: const EdgeInsets.all(16.0),
          child: Center(child: Text(cardLayout.label ?? 'Card')),
        ),
      );
    }

    // Card with nested layout items - no scrolling, just stacked children
    return Card(
      margin: const EdgeInsets.all(8.0),
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            if (cardLayout.label != null)
              Padding(
                padding: const EdgeInsets.only(bottom: 16.0),
                child: Text(cardLayout.label!, style: Theme.of(context).textTheme.titleMedium),
              ),
            ...cardLayout.children!.map((child) {
              return Padding(
                padding: const EdgeInsets.only(bottom: 8.0),
                child: _buildWidgetFromLayout(child, schemaProperties),
              );
            }).toList(),
          ],
        ),
      ),
    );
  }

  /// Fallback rendering for backward compatibility
  Widget _buildTabContentFallback(String tabId, Map<String, dynamic> schemaProperties) {
    switch (tabId) {
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
      case 'edges':
      case 'structure_lt4m':
      case 'structure_gt4m':
      case 'regeneration':
      case 'deadwood':
        _arrayElementKeys[tabId] ??= GlobalKey<ArrayElementTrinaState>();
        return ArrayElementTrina(
          key: _arrayElementKeys[tabId],
          jsonSchema: schemaProperties[tabId],
          data: _localFormData[tabId],
          propertyName: tabId,
          validationResult: widget.validationResult,
          onDataChanged: (updatedData) {
            _updateField(tabId, updatedData);
          },
        );
      default:
        return Center(child: Text('$tabId Form'));
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
            final filteredResult = TFMValidationResult(
              ajvValid: false,
              ajvErrors: tabErrors.whereType<ValidationError>().toList(),
              tfmAvailable: widget.validationResult!.tfmAvailable,
              tfmErrors: tabErrors.whereType<TFMValidationError>().toList(),
            );

            // Show dialog with filtered errors
            ValidationErrorsDialog.show(
              context,
              filteredResult,
              showActions: false,
              onNavigateToTab: widget.onNavigateToTab ?? _navigateToTab,
            );
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
    final path = error is ValidationError
        ? (error.instancePath ?? '')
        : ((error as TFMValidationError).instancePath ?? '');

    // For 'info' tab, only show errors for primitive fields (not arrays/objects)
    if (tabId == 'info') {
      // List of properties that are arrays/objects and have their own tabs
      final excludedProperties = [
        'position',
        'tree',
        'edges',
        'structure_lt4m',
        'structure_gt4m',
        'regeneration',
        'deadwood',
      ];

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

    // Show loading indicator while layout is being loaded
    if (!_layoutLoaded) {
      return const Center(child: CircularProgressIndicator());
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
            controller: _tabController,
            physics: const NeverScrollableScrollPhysics(),
            children: _tabs.map((tab) => _buildTabContent(tab, schemaProperties)).toList(),
          ),
        ),
      ],
    );
  }
}
