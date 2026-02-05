import 'package:flutter/material.dart';
import 'package:terrestrial_forest_monitor/services/validation_service.dart';
import 'package:terrestrial_forest_monitor/services/layout_service.dart';
import 'package:terrestrial_forest_monitor/models/layout_config.dart';
import 'package:terrestrial_forest_monitor/widgets/form-elements/array-element-trina.dart';
import 'package:terrestrial_forest_monitor/widgets/form-elements/card-dialog.dart';
import 'package:terrestrial_forest_monitor/widgets/form-elements/generic-form.dart';
import 'package:terrestrial_forest_monitor/widgets/form-elements/manuell-relative-position.dart';
import 'package:terrestrial_forest_monitor/widgets/form-elements/navigation-element.dart';
import 'package:terrestrial_forest_monitor/widgets/form-elements/nested-tabs.dart';
import 'package:terrestrial_forest_monitor/widgets/form-elements/plot-support-points.dart';
import 'package:terrestrial_forest_monitor/widgets/form-elements/previous-positions-navigation.dart';
import 'package:terrestrial_forest_monitor/widgets/form-elements/previous-positions-selection.dart';
import 'package:terrestrial_forest_monitor/widgets/form-elements/subplots-relative-position.dart';
import 'package:terrestrial_forest_monitor/widgets/validation_errors_dialog.dart';
import 'package:terrestrial_forest_monitor/repositories/records_repository.dart' as repo;

class FormWrapper extends StatefulWidget {
  final Map<String, dynamic>? jsonSchema;
  final Map<String, dynamic>? formData;
  final Map<String, dynamic>? previousFormData;
  final TFMValidationResult? validationResult;
  final Map<String, dynamic>? layoutStyleData;
  final String? layoutDirectory;
  final repo.Record? rawRecord;
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
    this.layoutStyleData,
    this.layoutDirectory,
    this.rawRecord,
  });
  @override
  State<FormWrapper> createState() => FormWrapperState();
}

class FormTab {
  final String id;
  final String label;

  FormTab({required this.id, required this.label});
}

class FormWrapperState extends State<FormWrapper> with TickerProviderStateMixin {
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
    // Try to load layout configuration if styleData or layoutDirectory is provided
    if (widget.layoutStyleData != null || widget.layoutDirectory != null) {
      _layoutConfig = await LayoutService.loadLayout(
        styleData: widget.layoutStyleData,
        directory: widget.layoutDirectory,
      );
      if (_layoutConfig != null) {
        debugPrint('Loaded layout successfully');
      } else {
        debugPrint('Failed to load layout, using fallback');
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
        // Try to use defaultTab from layout config, fallback to 'position', then to 0
        int? defaultTabIndex;
        if (_layoutConfig?.layout is TabsLayout) {
          defaultTabIndex = (_layoutConfig!.layout as TabsLayout).defaultTab;
        }

        final positionTabIndex = _tabs.indexWhere((tab) => tab.id == 'position');

        final initialIndex =
            (defaultTabIndex != null && defaultTabIndex >= 0 && defaultTabIndex < _tabs.length)
            ? defaultTabIndex
            : (positionTabIndex >= 0 ? positionTabIndex : 0);

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

    // Reload layout if layoutDirectory changed
    if (widget.layoutDirectory != oldWidget.layoutDirectory) {
      _initializeLayout();
      return; // _initializeLayout will rebuild everything including tabs
    }

    // Rebuild tabs if schema changed
    if (widget.jsonSchema != oldWidget.jsonSchema) {
      final newTabs = _buildTabsList();
      if (newTabs.length != _tabs.length) {
        _tabs = newTabs;
        _tabController?.removeListener(_onTabChanged);
        _tabController?.dispose();
        if (_tabs.isNotEmpty) {
          // Try to use defaultTab from layout config, fallback to 'position', then to 0
          int? defaultTabIndex;
          if (_layoutConfig?.layout is TabsLayout) {
            defaultTabIndex = (_layoutConfig!.layout as TabsLayout).defaultTab;
          }

          final positionTabIndex = _tabs.indexWhere((tab) => tab.id == 'position');

          final initialIndex =
              (defaultTabIndex != null && defaultTabIndex >= 0 && defaultTabIndex < _tabs.length)
              ? defaultTabIndex
              : (positionTabIndex >= 0 ? positionTabIndex : 0);

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
    _navigateToTab(tabId);
  }

  void _navigateToTab(String? tabId) {
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
    // Force rebuild to update isVisible for PreviousPositionsNavigation
    setState(() {});
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

  /// Check if a layout item is in the currently visible tab
  bool _isLayoutItemInCurrentTab(LayoutItem item) {
    if (_tabController == null || _layoutConfig == null) return true;

    final currentIndex = _tabController!.index;
    if (currentIndex < 0 || currentIndex >= _tabs.length) return false;

    final currentTabId = _tabs[currentIndex].id;
    final currentTabItem = LayoutService.findItemById(_layoutConfig, currentTabId);

    if (currentTabItem == null) return false;

    // Check if the item is within the current tab's layout hierarchy
    return _isItemInLayout(item, currentTabItem);
  }

  /// Recursively check if an item is within a layout hierarchy
  bool _isItemInLayout(LayoutItem needle, LayoutItem haystack) {
    if (needle.id == haystack.id) return true;

    if (haystack is ColumnLayout) {
      return haystack.items.any((child) => _isItemInLayout(needle, child));
    } else if (haystack is CardLayout && haystack.children != null) {
      return haystack.children!.any((child) => _isItemInLayout(needle, child));
    } else if (haystack is TabsLayout) {
      return haystack.items.any((child) => _isItemInLayout(needle, child));
    }

    return false;
  }

  /// Build tab content based on layout configuration or fallback to hard-coded logic
  Widget _buildTabContent(FormTab tab, Map<String, dynamic> schemaProperties) {
    // Try to use layout configuration first
    if (_layoutConfig != null) {
      final layoutItem = LayoutService.findItemById(_layoutConfig, tab.id);
      if (layoutItem != null) {
        final content = _buildWidgetFromLayout(layoutItem, schemaProperties);
        // Don't wrap tabs or arrays in ScrollView - they manage their own scrolling/sizing
        // But DO wrap ColumnLayout in ScrollView to prevent overflow
        if (layoutItem is TabsLayout || layoutItem is ArrayLayout) {
          return content;
        }
        // Wrap ColumnLayout and other content in SingleChildScrollView
        // Use physics that allows parent scroll controller to take precedence
        return SingleChildScrollView(physics: const ClampingScrollPhysics(), child: content);
      }
    }

    // Fallback to hard-coded rendering
    return Center(child: Text('No layout found for tab: ${tab.label}'));
    //return _buildTabContentFallback(tab.id, schemaProperties);
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
      // Nested tabs - create a nested tab view using separate widget
      return NestedTabs(
        tabsLayout: layoutItem,
        schemaProperties: schemaProperties,
        buildWidgetFromLayout: _buildWidgetFromLayout,
      );
    } else if (layoutItem is FormLayout) {
      // Form layout for primitive fields
      // Check if a property path is specified for getting schema/data
      Map<String, dynamic> formSchema = schemaProperties;
      Map<String, dynamic> formData = _localFormData;
      Map<String, dynamic> previousData = _previousProperties;

      if (layoutItem.property != null) {
        // If property path ends with '.items', get the schema for array items
        final propertyPath = layoutItem.property!;
        if (propertyPath.endsWith('.items')) {
          final arrayPath = propertyPath.substring(0, propertyPath.length - 6);
          final arraySchema = LayoutService.getSchemaByPath(schemaProperties, arrayPath);
          if (arraySchema != null && arraySchema['items'] is Map<String, dynamic>) {
            final itemSchema = arraySchema['items'] as Map<String, dynamic>;
            formSchema = itemSchema['properties'] as Map<String, dynamic>? ?? {};
          }
          // For data, get filtered item from array or empty map
          final arrayData = LayoutService.getValueByPath(_localFormData, arrayPath);
          if (arrayData is List && arrayData.isNotEmpty) {
            // Apply filter if specified
            if (layoutItem.propertiesFilter != null && layoutItem.propertiesFilter!.isNotEmpty) {
              final filter = layoutItem.propertiesFilter![0] as Map<String, dynamic>;
              final tableName = filter['tableName'] as String?;
              if (tableName != null) {
                // Find item where parent_table matches tableName
                try {
                  final filteredItem = arrayData.firstWhere(
                    (item) => item is Map<String, dynamic> && item['parent_table'] == tableName,
                  );
                  formData = filteredItem as Map<String, dynamic>? ?? {};
                } catch (e) {
                  formData = {};
                }
              } else {
                formData = arrayData[0] as Map<String, dynamic>? ?? {};
              }
            } else {
              formData = arrayData[0] as Map<String, dynamic>? ?? {};
            }
          } else {
            formData = {};
          }
          final prevArrayData = LayoutService.getValueByPath(_previousProperties, arrayPath);
          if (prevArrayData is List && prevArrayData.isNotEmpty) {
            // Apply same filter to previous data
            if (layoutItem.propertiesFilter != null && layoutItem.propertiesFilter!.isNotEmpty) {
              final filter = layoutItem.propertiesFilter![0] as Map<String, dynamic>;
              final tableName = filter['tableName'] as String?;
              if (tableName != null) {
                try {
                  final filteredItem = prevArrayData.firstWhere(
                    (item) => item is Map<String, dynamic> && item['parent_table'] == tableName,
                  );
                  previousData = filteredItem as Map<String, dynamic>? ?? {};
                } catch (e) {
                  previousData = {};
                }
              } else {
                previousData = prevArrayData[0] as Map<String, dynamic>? ?? {};
              }
            } else {
              previousData = prevArrayData[0] as Map<String, dynamic>? ?? {};
            }
          } else {
            previousData = {};
          }
        } else {
          // Regular property path
          final propertySchema = LayoutService.getSchemaByPath(schemaProperties, propertyPath);
          if (propertySchema != null) {
            formSchema = propertySchema['properties'] as Map<String, dynamic>? ?? {};
          }
          formData =
              LayoutService.getValueByPath(_localFormData, propertyPath) as Map<String, dynamic>? ??
              {};
          previousData =
              LayoutService.getValueByPath(_previousProperties, propertyPath)
                  as Map<String, dynamic>? ??
              {};
        }
      }

      // Check if horizontal scrolling is enabled
      final typeProperties = layoutItem.typeProperties ?? {};
      final scrollHorizontal = typeProperties['scrollHorizontal'] as bool? ?? false;
      final dense = typeProperties['dense'] as bool? ?? false;
      final responsive = typeProperties['responsive'] as bool? ?? false;
      final wrap = typeProperties['wrap'] as bool? ?? false;

      // Extract field options from property configs
      final fieldOptions = <String, Map<String, dynamic>>{};
      for (final prop in layoutItem.properties) {
        if (prop.width != null ||
            prop.minWidth != null ||
            prop.maxWidth != null ||
            prop.useSpeechToText != null ||
            prop.upDownBtn != null) {
          fieldOptions[prop.name] = {
            if (prop.width != null) 'width': prop.width,
            if (prop.minWidth != null) 'minWidth': prop.minWidth,
            if (prop.maxWidth != null) 'maxWidth': prop.maxWidth,
            if (prop.useSpeechToText != null) 'useSpeechToText': prop.useSpeechToText,
            if (prop.upDownBtn != null) 'upDownBtn': prop.upDownBtn,
          };
        }
      }

      Widget formWidget = GenericForm(
        jsonSchema: {'properties': formSchema},
        data: formData,
        propertyName: null,
        previous_properties: previousData,
        validationResult: widget.validationResult,
        includeProperties: layoutItem.properties.map((p) => p.name).toList(),
        fieldOptions: fieldOptions.isNotEmpty ? fieldOptions : null,
        onDataChanged: (updatedData) {
          if (layoutItem.property != null) {
            // If we have a property path, update the nested data
            final propertyPath = layoutItem.property!;
            if (propertyPath.endsWith('.items')) {
              // Update filtered item in array - merge updated fields into existing item
              final arrayPath = propertyPath.substring(0, propertyPath.length - 6);
              final arrayData = LayoutService.getValueByPath(_localFormData, arrayPath);
              if (arrayData is List) {
                // Apply filter to find the item to update
                String? tableName;
                if (layoutItem.propertiesFilter != null &&
                    layoutItem.propertiesFilter!.isNotEmpty) {
                  final filter = layoutItem.propertiesFilter![0] as Map<String, dynamic>;
                  tableName = filter['tableName'] as String?;
                }

                if (arrayData.isEmpty) {
                  // Create first item if array is empty
                  if (tableName != null) {
                    updatedData['parent_table'] = tableName;
                  }
                  arrayData.add(updatedData);
                } else {
                  // Find and update the matching item
                  int itemIndex = -1;
                  if (tableName != null) {
                    itemIndex = arrayData.indexWhere(
                      (item) => item is Map<String, dynamic> && item['parent_table'] == tableName,
                    );
                  } else {
                    itemIndex = 0; // Default to first item if no filter
                  }

                  if (itemIndex >= 0) {
                    // Merge updated fields into existing item
                    final existingItem = arrayData[itemIndex] as Map<String, dynamic>;
                    existingItem.addAll(updatedData);
                  } else {
                    // Item doesn't exist, create new one with filter
                    if (tableName != null) {
                      updatedData['parent_table'] = tableName;
                    }
                    arrayData.add(updatedData);
                  }
                }
                LayoutService.setValueByPath(_localFormData, arrayPath, arrayData);
              } else {
                // Array doesn't exist - create it with first item
                if (layoutItem.propertiesFilter != null &&
                    layoutItem.propertiesFilter!.isNotEmpty) {
                  final filter = layoutItem.propertiesFilter![0] as Map<String, dynamic>;
                  final tableName = filter['tableName'] as String?;
                  if (tableName != null) {
                    updatedData['parent_table'] = tableName;
                  }
                }
                LayoutService.setValueByPath(_localFormData, arrayPath, [updatedData]);
              }
            } else {
              LayoutService.setValueByPath(_localFormData, propertyPath, updatedData);
            }
            widget.onFormDataChanged?.call(Map<String, dynamic>.from(_localFormData));
          } else {
            _updateField('', updatedData);
          }
        },
        isDense: dense,
        layout: scrollHorizontal
            ? 'horizontal-scroll'
            : (responsive || wrap)
            ? 'responsive-wrap'
            : null,
      );

      // Wrap in horizontal scroll if needed
      /*if (scrollHorizontal) {
        // Use SizedBox with fixed width to avoid infinite constraints
        // inside horizontal SingleChildScrollView
        formWidget = SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          child: SizedBox(width: 800, child: formWidget),
        );
      }*/

      return formWidget;
    } else if (layoutItem is ArrayLayout) {
      // Array layout - render with appropriate component (supports paths)
      final propertyPath = layoutItem.property;
      if (propertyPath == null) {
        return Center(child: Text('Array layout "${layoutItem.id}" is missing property field'));
      }
      final propertyName = propertyPath.split('.').last; // Use last segment for key

      // Use layoutItem.id as the key to ensure uniqueness (keys pre-created in _initializeLayout)
      final keyId = layoutItem.id;
      final key = _arrayElementKeys[keyId];

      // Get schema and data using path
      final propertySchema = LayoutService.getSchemaByPath(schemaProperties, propertyPath);
      final propertyData = LayoutService.getValueByPath(_localFormData, propertyPath);
      final previousPropertyData = LayoutService.getValueByPath(_previousProperties, propertyPath);

      if (propertySchema == null) {
        return Center(child: Text('Schema not found for property: $propertyPath'));
      }

      if (layoutItem.component == 'datagrid') {
        final arrayLayout = layoutItem as ArrayLayout;
        return ArrayElementTrina(
          key: key,
          jsonSchema: propertySchema,
          data: propertyData,
          previousData: previousPropertyData,
          propertyName: propertyName,
          identifierField: arrayLayout.identifierField,
          validationResult: widget.validationResult,
          columnConfig: arrayLayout.columns,
          columnItems: arrayLayout.items, // NEW STRUCTURE
          layoutOptions: arrayLayout.options,
          onDataChanged: (updatedData) {
            LayoutService.setValueByPath(_localFormData, propertyPath, updatedData);
            widget.onFormDataChanged?.call(Map<String, dynamic>.from(_localFormData));
          },
        );
      }

      return Center(child: Text('Unsupported array component: ${layoutItem.component}'));
    } else if (layoutItem is ObjectLayout) {
      // Object layout - render with appropriate component (supports paths)
      debugPrint(
        'ObjectLayout: id=${layoutItem.id}, component=${layoutItem.component}, property=${layoutItem.property}',
      );
      final propertyPath = layoutItem.property;

      // Special handling for components that don't require a property path
      if (layoutItem.component == 'previous_positions_selection') {
        // PreviousPositionsSelection component - works with entire form data
        debugPrint('object layout previous_positions_selection');
        return PreviousPositionsSelection(rawRecord: widget.rawRecord);
      }
      if (layoutItem.component == 'previous_positions_navigation') {
        // PreviousPositionsNavigation component - works with entire form data
        debugPrint('object layout previous_positions_navigation');

        // Determine if this component is in the currently visible tab
        final isVisible = _isLayoutItemInCurrentTab(layoutItem);

        return PreviousPositionsNavigation(
          rawRecord: widget.rawRecord,
          jsonSchema: widget.jsonSchema,
          isVisible: isVisible,
        );
      }
      if (layoutItem.component == 'plot_support_points') {
        // PlotSupportPoints component - for manual position entry
        debugPrint('object layout plot_support_points - rendering PlotSupportPoints');
        return PlotSupportPoints(
          jsonSchema: schemaProperties,
          data: _localFormData,
          previousProperties: _previousProperties,
          validationResult: widget.validationResult,
          onDataChanged: (updatedData) {
            setState(() {
              _localFormData.addAll(updatedData);
            });
            widget.onFormDataChanged?.call(Map<String, dynamic>.from(_localFormData));
          },
        );
      }
      if (layoutItem.component == 'manuell_relative_position') {
        // ManuellRelativePosition component - for manual navigation when GPS is unavailable
        debugPrint('object layout manuell_relative_position - rendering ManuellRelativePosition');
        return ManuellRelativePosition(formData: _localFormData, onFieldChanged: _updateField);
      }
      if (layoutItem.component == 'subplots_relative_position') {
        debugPrint('object layout subplots_relative_position - rendering SubplotsRelativePosition');

        final children = <Widget>[];
        if (layoutItem.children != null) {
          for (final childItem in layoutItem.children!) {
            children.add(_buildWidgetFromLayout(childItem, schemaProperties));
          }
        }

        return SubplotsRelativePosition(
          jsonSchema: schemaProperties,
          data: _localFormData,
          previous_properties: _previousProperties,
          children: children,
        );
      }

      // For other components, property path is required
      if (propertyPath == null) {
        debugPrint(
          'ObjectLayout ${layoutItem.id} is missing property field and has no special handling',
        );
        return Card(child: Text('Object layout "${layoutItem.id}" is missing property field'));
      }

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
            // Extract the updated property value from the returned data object
            // NavigationElement/RecordPosition returns the parent container with the updated field
            final newValue = updatedData[propertyName];
            LayoutService.setValueByPath(_localFormData, propertyPath, newValue);
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

  /// Build card with nested children
  Widget _buildCardWithChildren(CardLayout cardLayout, Map<String, dynamic> schemaProperties) {
    // Check if this is a card-dialog type
    if (cardLayout.type == 'card-dialog') {
      // Extract properties from children if they exist
      List<String>? properties;
      if (cardLayout.children != null && cardLayout.children!.isNotEmpty) {
        final firstChild = cardLayout.children!.first;
        if (firstChild is FormLayout) {
          properties = firstChild.properties.map((p) => p.name).toList();
        }
      } else if (cardLayout.properties != null) {
        properties = cardLayout.properties;
      }

      return CardDialog(
        label: cardLayout.label,
        jsonSchema: schemaProperties,
        data: _localFormData,
        validationResult: widget.validationResult,
        onDataChanged: (updatedData) {
          setState(() {
            _localFormData.addAll(updatedData);
          });
          widget.onFormDataChanged?.call(Map<String, dynamic>.from(_localFormData));
        },
        includeProperties: properties,
      );
    }

    // Get typeProperties for card styling
    final typeProperties = cardLayout.typeProperties ?? {};
    final padding = (typeProperties['padding'] as num?)?.toDouble() ?? 16.0;
    final margin = (typeProperties['margin'] as num?)?.toDouble() ?? 8.0;

    if (cardLayout.children == null || cardLayout.children!.isEmpty) {
      // Card with simple properties
      if (cardLayout.properties != null) {
        return Card(
          margin: EdgeInsets.all(margin),
          child: Padding(
            padding: EdgeInsets.all(padding),
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
        margin: EdgeInsets.all(margin),
        child: Padding(
          padding: EdgeInsets.all(padding),
          child: Center(child: Text(cardLayout.label ?? 'Card')),
        ),
      );
    }

    // Card with nested layout items
    return Card(
      margin: EdgeInsets.all(margin),
      child: Padding(
        padding: EdgeInsets.all(padding),
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

  /// Extract all property paths that belong to a specific tab based on layout
  List<String> _getPropertyPathsForTab(String tabId) {
    final propertyPaths = <String>[];

    if (_layoutConfig == null) {
      // Fallback for tabs without layout config
      return [tabId];
    }

    final tabItem = LayoutService.findItemById(_layoutConfig, tabId);
    if (tabItem == null) return [];

    _extractPropertyPaths(tabItem, propertyPaths);
    return propertyPaths;
  }

  /// Recursively extract property paths from layout items
  void _extractPropertyPaths(LayoutItem item, List<String> paths) {
    if (item is FormLayout) {
      // Add all properties from form
      paths.addAll(item.properties.map((p) => p.name));
    } else if (item is ArrayLayout) {
      // Add the array property path
      if (item.property != null) {
        paths.add(item.property!);
      }
    } else if (item is ObjectLayout) {
      // Add the object property path
      if (item.property != null) {
        paths.add(item.property!);
      }
    } else if (item is ColumnLayout) {
      // Recursively process children
      for (final child in item.items) {
        _extractPropertyPaths(child, paths);
      }
    } else if (item is TabsLayout) {
      // Recursively process tab items
      for (final child in item.items) {
        _extractPropertyPaths(child, paths);
      }
    } else if (item is CardLayout) {
      // Process card properties or children
      if (item.properties != null) {
        paths.addAll(item.properties!);
      }
      if (item.children != null) {
        for (final child in item.children!) {
          _extractPropertyPaths(child, paths);
        }
      }
    }
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

    // Get all property paths that belong to this tab
    final tabPropertyPaths = _getPropertyPathsForTab(tabId);
    if (tabPropertyPaths.isEmpty) return false;

    // Check if error path matches any of the tab's property paths
    for (final propertyPath in tabPropertyPaths) {
      // Check if error path starts with this property path
      if (path.startsWith('/$propertyPath')) {
        return true;
      }

      // Check if it's a root-level required error for this property
      final keyword = error is ValidationError ? error.keyword : null;
      if (path.isEmpty && keyword == 'required') {
        final params = error is ValidationError ? error.params : null;
        final missingProperty = params?['missingProperty'] as String?;
        if (missingProperty == propertyPath) {
          return true;
        }
      }
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
