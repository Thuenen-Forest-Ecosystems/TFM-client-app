import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:trina_grid/trina_grid.dart';
import 'package:terrestrial_forest_monitor/services/validation_service.dart';
import 'package:terrestrial_forest_monitor/providers/map_controller_provider.dart';
import 'package:terrestrial_forest_monitor/widgets/form-elements/generic-enum-dialog.dart';
import 'package:terrestrial_forest_monitor/widgets/form-elements/generic-textfield.dart';
import 'package:terrestrial_forest_monitor/widgets/form-elements/array-grid-dialog.dart';
import 'package:terrestrial_forest_monitor/widgets/form-elements/array-row-form-dialog.dart';
import 'package:terrestrial_forest_monitor/widgets/form-elements/validation_status_indicator.dart';

/// ArrayElementTrina - TrinaGrid-based array data editor widget
///
/// Features:
/// - Schema-driven column generation with sortBy support
/// - Type-aware column rendering (Text, Number, Boolean, Select/Enum)
/// - Automatic type conversion and formatting
/// - Unit display from schema ($tfm.unit_short)
/// - German enum labels support ($tfm.name_de)
/// - Inline editing with proper type handling
/// - Add/delete row operations
/// - FAB for adding new rows
///
/// Similar functionality to ArrayElementSyncfusion but using TrinaGrid library
class ArrayElementTrina extends StatefulWidget {
  final Map<String, dynamic> jsonSchema;
  final List<dynamic>? data;
  final TFMValidationResult? validationResult;
  final String? propertyName;
  final Function(List<dynamic>?)? onDataChanged;

  /// Optional column styling configuration from layout (takes precedence over schema $tfm.form)
  final Map<String, dynamic>? columnConfig;

  /// Optional column items array from layout (new structure with groups)
  final List<dynamic>? columnItems;

  /// Optional layout options (e.g., fullSize, autoIncrement defaults)
  final Map<String, dynamic>? layoutOptions;

  /// Previous data array for calculated fields (same-index matching)
  final List<dynamic>? previousData;

  /// Optional identifier field for matching rows between current and previous data
  final String? identifierField;

  const ArrayElementTrina({
    super.key,
    required this.jsonSchema,
    required this.data,
    this.propertyName,
    this.validationResult,
    this.onDataChanged,
    this.columnConfig,
    this.columnItems,
    this.layoutOptions,
    this.previousData,
    this.identifierField,
  });

  @override
  State<ArrayElementTrina> createState() => ArrayElementTrinaState();
}

class ArrayElementTrinaState extends State<ArrayElementTrina> {
  List<TrinaColumn> _columns = [];
  List<TrinaRow> _rows = [];
  List<TrinaColumnGroup> _columnGroups = [];
  TrinaGridStateManager? _stateManager;
  bool _isArrayReadOnly = false;
  DateTime? _lastSelectionTimestamp;
  MapControllerProvider? _mapControllerProvider;

  @override
  void initState() {
    super.initState();
    print('Initializing ArrayElementTrina for property: ${widget.propertyName}');
    print('Initial data: ${widget.data}');
    _initializeGrid();
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();

    // Set up listener for MapControllerProvider if not already done
    if (_mapControllerProvider == null) {
      try {
        _mapControllerProvider = context.read<MapControllerProvider>();
        _mapControllerProvider!.addListener(_onMapControllerChanged);
        debugPrint('${widget.propertyName}: Listener added to MapControllerProvider');
      } catch (e) {
        debugPrint('Error setting up MapControllerProvider listener: $e');
      }
    }
  }

  void _onMapControllerChanged() {
    if (!mounted) return;

    try {
      final selectedArrayName = _mapControllerProvider?.selectedArrayName;
      final selectedIdentifier = _mapControllerProvider?.selectedRowIdentifier;
      final selectionTimestamp = _mapControllerProvider?.selectionTimestamp;

      // Check if selection is for this grid and hasn't been processed yet
      if (selectedArrayName == widget.propertyName &&
          selectedIdentifier != null &&
          selectionTimestamp != null &&
          selectionTimestamp != _lastSelectionTimestamp) {
        _lastSelectionTimestamp = selectionTimestamp;
        debugPrint(
          'Grid selection event for ${widget.propertyName}: identifier=$selectedIdentifier',
        );

        // Scroll and select the matching row
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (mounted) {
            _scrollToAndSelectRow(selectedIdentifier);
            // Clear the selection request after processing
            _mapControllerProvider?.clearGridRowSelection();
          }
        });
      }
    } catch (e) {
      debugPrint('Error handling map controller change: $e');
    }
  }

  void _scrollToAndSelectRow(dynamic identifier) {
    if (_stateManager == null || widget.data == null) return;

    final identifierField = widget.identifierField ?? 'tree_number';
    debugPrint('Searching for row with $identifierField=$identifier');

    // Find the row index with matching identifier
    int? matchingRowIndex;
    for (int i = 0; i < widget.data!.length; i++) {
      final rowData = widget.data![i];
      if (rowData is Map<String, dynamic> && rowData[identifierField] == identifier) {
        matchingRowIndex = i;
        break;
      }
    }

    if (matchingRowIndex == null) {
      debugPrint('No row found with $identifierField=$identifier');
      return;
    }

    debugPrint('Found matching row at index $matchingRowIndex');

    // Select the row in the grid
    try {
      _stateManager!.setCurrentCell(
        _stateManager!.rows[matchingRowIndex].cells.entries.first.value,
        matchingRowIndex,
      );
      _stateManager!.setKeepFocus(true);

      debugPrint('Successfully selected row $matchingRowIndex');
    } catch (e) {
      debugPrint('Error selecting row: $e');
    }
  }

  @override
  void didUpdateWidget(ArrayElementTrina oldWidget) {
    super.didUpdateWidget(oldWidget);
    // Reinitialize if schema changes or data changes
    bool shouldRebuild = false;

    if (widget.jsonSchema != oldWidget.jsonSchema) {
      // Debug: Check if readonly status changed in schema
      final oldItems = oldWidget.jsonSchema['items'] as Map<String, dynamic>?;
      final newItems = widget.jsonSchema['items'] as Map<String, dynamic>?;
      final oldProps = oldItems?['properties'] as Map<String, dynamic>?;
      final newProps = newItems?['properties'] as Map<String, dynamic>?;

      if (oldProps != null && newProps != null) {
        newProps.forEach((key, value) {
          final oldReadOnly = oldProps[key]?['readOnly'];
          final newReadOnly = value['readOnly'];
          if (oldReadOnly != newReadOnly) {
            debugPrint('  📝 Field $key: readOnly changed from $oldReadOnly to $newReadOnly');
          }
        });
      }

      shouldRebuild = true;
    }

    // Check if data has changed
    if (widget.data != oldWidget.data) {
      shouldRebuild = true;
    }

    if (shouldRebuild) {
      _initializeGrid();
    }

    // If validation result changes, force grid to rebuild cells
    if (widget.validationResult != oldWidget.validationResult) {
      _stateManager?.notifyListeners();
    }
  }

  void _initializeGrid() {
    // Check if the entire array is readonly
    _isArrayReadOnly = widget.jsonSchema['readonly'] as bool? ?? false;
    if (_isArrayReadOnly) {
      debugPrint('🔒 Array ${widget.propertyName} is READONLY - row operations disabled');
    }

    _columns = _buildColumns();
    _columnGroups = _buildColumnGroups();
    _rows = _buildRows();
  }

  /// Get column configuration for a field (layout takes precedence over schema)
  Map<String, dynamic> _getColumnConfig(String fieldKey, Map<String, dynamic> propertySchema) {
    final config = <String, dynamic>{};

    // First, check layout column config
    if (widget.columnConfig != null && widget.columnConfig!.containsKey(fieldKey)) {
      final layoutConfig = widget.columnConfig![fieldKey] as Map<String, dynamic>;

      // Layout properties
      config['pinned'] = layoutConfig['pinned'];
      config['width'] = layoutConfig['width'];
      config['display'] = layoutConfig['display'] ?? true;
      config['autoIncrement'] = layoutConfig['autoIncrement'];
      config['groupBy'] = layoutConfig['groupBy'];
      config['readonly'] = layoutConfig['readonly'];
      config['title'] = layoutConfig['title'];
    }

    // Fallback to schema $tfm.form if layout config not provided
    final tfm = propertySchema['\$tfm'] as Map<String, dynamic>?;
    final form = tfm?['form'] as Map<String, dynamic>?;
    final uiOptions = form?['ui:options'] as Map<String, dynamic>?;

    config['pinned'] ??= uiOptions?['pinned'];
    config['width'] ??= uiOptions?['width'];
    config['display'] ??= uiOptions?['display'] ?? true;
    config['autoIncrement'] ??= form?['autoIncrement'];
    config['groupBy'] ??= form?['groupBy'];
    config['readonly'] ??= propertySchema['readonly'];

    return config;
  }

  /// Check if a specific cell has validation errors
  bool _hasValidationError(int rowIndex, String fieldKey) {
    if (widget.validationResult == null || widget.propertyName == null) {
      return false;
    }

    final errors = widget.validationResult!.ajvErrors;

    // Check for errors like: "/propertyName/0/fieldKey" or "/propertyName/0"
    final cellPath = '/${widget.propertyName}/$rowIndex/$fieldKey';
    final rowPath = '/${widget.propertyName}/$rowIndex';

    return errors.any((error) => error.instancePath == cellPath || error.instancePath == rowPath);
  }

  /// Get background color for cell based on validation state
  Color? _getCellBackgroundColor(int rowIndex, String fieldKey, bool isDark) {
    if (_hasValidationError(rowIndex, fieldKey)) {
      return isDark ? const Color.fromARGB(137, 90, 31, 31) : const Color(0xFFFFCDD2); // Light red
    }
    return null;
  }

  /// Check if current row has matching data in previous inventory (by identifier)
  bool _hasMatchingPreviousData(Map<String, dynamic> currentRowData) {
    if (widget.previousData == null) return false;

    if (widget.identifierField == null) {
      debugPrint(
        '⚠️ No identifierField provided for matching previous data in ${widget.propertyName}',
      );
    }

    // Use configured identifier field or fall back to common fields
    final identifierFields = widget.identifierField != null
        ? [widget.identifierField!]
        : ['tree_number', 'edge_number', 'row_number', 'id'];

    for (final idField in identifierFields) {
      if (currentRowData.containsKey(idField) && currentRowData[idField] != null) {
        final currentId = currentRowData[idField];

        // Find matching row in previousData by this identifier
        final matchFound = (widget.previousData as List).cast<Map<String, dynamic>?>().any(
          (prevRow) => prevRow != null && prevRow[idField] == currentId,
        );

        if (matchFound) return true;
      }
    }

    return false;
  }

  List<TrinaColumn> _buildColumns() {
    final columns = <TrinaColumn>[];
    final itemSchema = widget.jsonSchema['items'] as Map<String, dynamic>?;

    if (itemSchema == null) {
      debugPrint('❌ No items found in schema for ${widget.propertyName}');
      debugPrint('Schema keys: ${widget.jsonSchema.keys}');
      return columns;
    }

    final properties = itemSchema['properties'] as Map<String, dynamic>?;
    if (properties == null) {
      debugPrint('❌ No properties found in items schema for ${widget.propertyName}');
      debugPrint('ItemSchema keys: ${itemSchema.keys}');
      return columns;
    }

    // Add menu column (always second, pinned left)
    columns.add(
      TrinaColumn(
        title: '',
        field: '__row_menu__',
        type: TrinaColumnTypeText(),
        width: 50,
        frozen: TrinaColumnFrozen.start,
        enableSorting: false,
        enableColumnDrag: false,
        enableContextMenu: false,
        readOnly: true,
        enableEditingMode: false,
        renderer: (rendererContext) {
          // Check if row has previous data (exists in previous inventory)
          final currentRowData = rendererContext.row.cells.map(
            (key, cell) => MapEntry(key, cell.value),
          );

          final hasPreviousData = _hasMatchingPreviousData(currentRowData);

          return Container(
            alignment: Alignment.center,
            child: PopupMenuButton<String>(
              padding: EdgeInsets.zero,
              icon: const Icon(Icons.more_vert, size: 20),
              tooltip: 'Zeilenoptionen',
              onSelected: (value) {
                if (value == 'delete') {
                  _deleteRow(rendererContext.rowIdx);
                } else if (value == 'copy') {
                  _copyRow(rendererContext.rowIdx);
                }
              },
              itemBuilder: (context) => [
                PopupMenuItem(
                  value: 'copy',
                  enabled: !_isArrayReadOnly,
                  child: Row(
                    children: [
                      Icon(
                        Icons.content_copy,
                        size: 18,
                        color: _isArrayReadOnly ? Colors.grey : null,
                      ),
                      SizedBox(width: 8),
                      Text(
                        'Zeile kopieren',
                        style: TextStyle(color: _isArrayReadOnly ? Colors.grey : null),
                      ),
                    ],
                  ),
                ),
                PopupMenuItem(
                  value: 'delete',
                  enabled: !hasPreviousData && !_isArrayReadOnly,
                  child: Row(
                    children: [
                      Icon(
                        Icons.delete,
                        size: 18,
                        color: (hasPreviousData || _isArrayReadOnly) ? Colors.grey : null,
                      ),
                      const SizedBox(width: 8),
                      Text(
                        'Zeile löschen',
                        style: TextStyle(
                          color: (hasPreviousData || _isArrayReadOnly) ? Colors.grey : null,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          );
        },
      ),
    );

    // Add validation status column (first, before menu, pinned left)
    columns.add(
      TrinaColumn(
        title: '',
        field: '__validation_status__',
        type: TrinaColumnTypeText(),
        width: 50,
        frozen: TrinaColumnFrozen.start,
        enableSorting: false,
        enableColumnDrag: false,
        enableContextMenu: false,
        readOnly: true,
        enableEditingMode: false,
        renderer: (rendererContext) {
          return ValidationStatusIndicator.build(
            context: context,
            rowIndex: rendererContext.rowIdx,
            propertyName: widget.propertyName ?? 'unknown',
            validationResult: widget.validationResult,
          );
        },
      ),
    );

    // Add row number column if enabled
    if (widget.layoutOptions?['rowNumber'] == true) {
      columns.add(
        TrinaColumn(
          title: '#',
          field: '__row_number__',
          type: TrinaColumnTypeText(),
          width: 50,
          frozen: TrinaColumnFrozen.start,
          enableSorting: false,
          enableColumnDrag: false,
          enableContextMenu: false,
          readOnly: true,
          enableEditingMode: false,
          renderer: (rendererContext) {
            return Container(
              alignment: Alignment.center,
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
              child: Text(
                '${rendererContext.rowIdx + 1}',
                style: const TextStyle(fontWeight: FontWeight.w500),
              ),
            );
          },
        ),
      );
    }

    // NEW STRUCTURE: Use columnItems array if provided (items with groups)
    if (widget.columnItems != null && widget.columnItems!.isNotEmpty) {
      debugPrint('📋 Using NEW columnItems structure for ${widget.propertyName}');

      int frozenColumnCount = 0;

      // Helper function to create a column from item config
      TrinaColumn? createColumnFromItem(Map<String, dynamic> itemConfig) {
        final fieldName = itemConfig['name'] as String?;
        if (fieldName == null) return null;

        // Get schema for this field (or create synthetic for calculated)
        Map<String, dynamic> propertySchema;

        if (!properties.containsKey(fieldName)) {
          // Calculated or nested array field defined only in layout
          if (itemConfig['type'] == 'calculated') {
            propertySchema = {
              'type': 'calculated',
              'title': itemConfig['title'] ?? fieldName,
              'expression': itemConfig['expression'],
              if (itemConfig['variables'] != null) 'variables': itemConfig['variables'],
              'readonly': true,
              if (itemConfig['unit_short'] != null)
                '\$tfm': {'unit_short': itemConfig['unit_short']},
            };
          } else if (itemConfig['type'] == 'array' && itemConfig['component'] == 'datagrid') {
            // Nested array column
            propertySchema = properties[fieldName] ?? {'type': 'array'};
          } else {
            debugPrint('⚠️ Field $fieldName not found in schema and not calculated');
            return null;
          }
        } else {
          propertySchema = properties[fieldName] as Map<String, dynamic>;
        }

        // Merge config from item with schema defaults
        final title =
            itemConfig['title'] as String? ?? propertySchema['title'] as String? ?? fieldName;
        final width = (itemConfig['width'] as num?)?.toDouble() ?? 150.0;
        final pinnedValue = itemConfig['pinned'] as String?;
        final isReadOnly =
            itemConfig['readonly'] as bool? ?? propertySchema['readonly'] as bool? ?? false;

        // Determine frozen position
        final frozen = pinnedValue == 'left'
            ? TrinaColumnFrozen.start
            : pinnedValue == 'right'
            ? TrinaColumnFrozen.end
            : TrinaColumnFrozen.none;

        if (frozen == TrinaColumnFrozen.start) {
          frozenColumnCount++;
        }

        // Determine type and renderer
        final typeValue = itemConfig['type'] ?? propertySchema['type'];
        String? type;
        if (typeValue is String) {
          type = typeValue;
        } else if (typeValue is List) {
          type =
              typeValue.firstWhere((t) => t != 'null' && t != null, orElse: () => null) as String?;
        }

        final tfm = propertySchema['\$tfm'] as Map<String, dynamic>?;

        TrinaColumnType columnType = TrinaColumnTypeText();
        bool isEnum = false;
        bool isNumeric = false;
        bool isBoolean = false;
        bool isCalculated = type == 'calculated';
        bool isNestedArray = false;
        Map<String, dynamic>? nestedArrayConfig;

        if (type == 'array' && itemConfig['component'] == 'datagrid') {
          isNestedArray = true;
          nestedArrayConfig = itemConfig;
        } else if (propertySchema.containsKey('enum')) {
          isEnum = true;
        } else if (type == 'boolean') {
          isBoolean = true;
        } else if (type == 'integer' || type == 'number') {
          isNumeric = true;
        }

        return TrinaColumn(
          title: title, //unit != null ? '$title ($unit)' : title,
          field: fieldName,
          type: columnType,
          width: width,
          frozen: frozen,
          enableSorting: true,
          enableColumnDrag: false,
          enableContextMenu: false,
          readOnly: isReadOnly || isCalculated,
          renderer: isNestedArray
              ? (rendererContext) => _buildNestedArrayCell(
                  rendererContext,
                  propertySchema,
                  fieldName,
                  nestedArrayConfig!,
                )
              : isCalculated
              ? (rendererContext) =>
                    _buildGenericFieldCell(rendererContext, propertySchema, fieldName)
              : isEnum
              ? (rendererContext) => _buildEnumCell(rendererContext, propertySchema, fieldName)
              : isNumeric
              ? (rendererContext) =>
                    _buildNumericEditableCell(rendererContext, propertySchema, fieldName)
              : isBoolean
              ? (rendererContext) => _buildBooleanCell(rendererContext, propertySchema, fieldName)
              : (rendererContext) => _buildTextCell(rendererContext, fieldName),
        );
      }

      // Process items in order
      for (final item in widget.columnItems!) {
        final itemMap = item as Map<String, dynamic>;

        if (itemMap['type'] == 'group') {
          // This is a group - process its nested items
          final groupItems = itemMap['items'] as List?;
          if (groupItems != null) {
            for (final groupItem in groupItems) {
              final groupItemMap = groupItem as Map<String, dynamic>;
              final column = createColumnFromItem(groupItemMap);
              if (column != null) {
                columns.add(column);
              }
            }
          }
        } else {
          // This is an ungrouped column
          final column = createColumnFromItem(itemMap);
          if (column != null) {
            columns.add(column);
          }
        }
      }

      debugPrint('Total frozen columns: $frozenColumnCount');
      return columns;
    }

    // OLD STRUCTURE: Fallback to columnConfig/properties approach
    debugPrint('📋 Using OLD columnConfig structure for ${widget.propertyName}');

    // Create list of column entries with sortBy for sorting
    final columnEntries = <MapEntry<String, dynamic>>[];

    // If columnConfig is provided, ONLY use fields defined there (layout-driven)
    // Otherwise, fall back to using all schema properties
    final fieldsToProcess = widget.columnConfig != null
        ? widget.columnConfig!.keys
        : properties.keys;

    for (final key in fieldsToProcess) {
      // For calculated fields defined only in layout, create a synthetic schema
      Map<String, dynamic> propertySchema;

      if (!properties.containsKey(key)) {
        // Check if this is a calculated field defined in columnConfig
        final layoutConfig = widget.columnConfig?[key] as Map<String, dynamic>?;
        if (layoutConfig != null && layoutConfig['type'] == 'calculated') {
          // Create synthetic schema for calculated field
          propertySchema = {
            'type': 'calculated',
            'title': layoutConfig['title'] ?? key,
            'expression': layoutConfig['expression'],
            if (layoutConfig['variables'] != null) 'variables': layoutConfig['variables'],
            if (layoutConfig['unit_short'] != null)
              '\$tfm': {'unit_short': layoutConfig['unit_short']},
          };
        } else {
          // Skip if property doesn't exist in schema and isn't a calculated field
          continue;
        }
      } else {
        propertySchema = properties[key] as Map<String, dynamic>;
      }

      final config = _getColumnConfig(key, propertySchema);

      // Skip if explicitly set to not display
      if (config['display'] == false) {
        continue;
      }

      final groupBy = config['groupBy'];
      final columnGroupShow = groupBy?['columnGroupShow'] as String?;
      final pinned = config['pinned'];

      columnEntries.add(
        MapEntry(key, {
          'schema': propertySchema,
          'groupBy': groupBy,
          'columnGroupShow': columnGroupShow,
          'pinned': pinned,
          'width': config['width'],
          'readonly': config['readonly'],
          'title': config['title'],
        }),
      );
    }

    // Column order determined by position in columnConfig/properties

    // Count frozen columns (pinned left)
    int frozenColumnCount = 0;

    // Create columns from sorted entries
    for (final entry in columnEntries) {
      final key = entry.key;
      final propertySchema = entry.value['schema'] as Map<String, dynamic>;
      // Use title from layout config if provided, otherwise from schema
      final title = entry.value['title'] as String? ?? propertySchema['title'] as String? ?? key;

      // Determine type
      final typeValue = propertySchema['type'];
      String? type;
      if (typeValue is String) {
        type = typeValue;
      } else if (typeValue is List) {
        type = typeValue.firstWhere((t) => t != 'null' && t != null, orElse: () => null) as String?;
      }

      // Create appropriate column type based on schema
      TrinaColumnType columnType;
      bool isEnum = false;
      bool isNumeric = false;
      bool isBoolean = false;
      bool isCalculated = false;
      bool isNestedArray = false;
      Map<String, dynamic>? nestedArrayConfig;

      // Check if this is a nested array column
      if (type == 'array') {
        // This is a nested array - check if layout defines it as datagrid
        final layoutConfig = widget.columnConfig?[key] as Map<String, dynamic>?;
        if (layoutConfig?['component'] == 'datagrid') {
          isNestedArray = true;
          nestedArrayConfig = layoutConfig;
          columnType = TrinaColumnTypeText();
        } else {
          // Not configured as datagrid, skip this column
          continue;
        }
      } else if (type == 'calculated') {
        // Calculated column - always readonly
        columnType = TrinaColumnTypeText();
        isCalculated = true;
      } else if (propertySchema.containsKey('enum')) {
        // Enum column - will use custom renderer with GenericEnumDialog
        columnType = TrinaColumnTypeText();
        isEnum = true;
      } else if (type == 'boolean') {
        columnType = TrinaColumnTypeText();
        isBoolean = true;
      } else if (type == 'integer' || type == 'number') {
        /*columnType = TrinaColumnTypeNumber(
          negative: true,
          format: type == 'number' ? '#,###.##' : '#,###',
          applyFormatOnInit: false,
          allowFirstDot: true,
          locale: 'de_DE',
        );*/
        isNumeric = true;
        columnType = TrinaColumnTypeText();
      } else {
        columnType = TrinaColumnTypeText();
      }

      final groupBy = entry.value['groupBy'] as Map<String, dynamic>?;
      final groupName = groupBy?['headerName'] as String?;
      final pinnedValue = entry.value['pinned'] as String?;

      // Check if field is readonly
      final isReadOnly = entry.value['readonly'] as bool? ?? false;

      /*if (isReadOnly) {
        debugPrint('🔒 Column $key is READONLY');
      }*/

      // Determine frozen position from pinned value
      final frozen = pinnedValue == 'left'
          ? TrinaColumnFrozen.start
          : pinnedValue == 'right'
          ? TrinaColumnFrozen.end
          : TrinaColumnFrozen.none;

      // Count frozen columns at start
      if (frozen == TrinaColumnFrozen.start) {
        frozenColumnCount++;
      }

      // Get column width (default 150)
      final columnWidth = (entry.value['width'] as num?)?.toDouble() ?? 150.0;

      columns.add(
        TrinaColumn(
          title: title, //unit != null ? '$title ($unit)' : title,
          field: key,
          type: columnType,
          width: columnWidth,
          frozen: frozen,
          enableSorting: true,
          enableColumnDrag: false,
          enableContextMenu: false,
          readOnly: isReadOnly || isCalculated,
          // Custom renderer for calculated, enum, numeric, boolean, nested array, or grouped columns
          renderer: isNestedArray
              ? (rendererContext) =>
                    _buildNestedArrayCell(rendererContext, propertySchema, key, nestedArrayConfig!)
              : isCalculated
              ? (rendererContext) => _buildGenericFieldCell(rendererContext, propertySchema, key)
              : isEnum
              ? (rendererContext) => _buildEnumCell(rendererContext, propertySchema, key)
              : isNumeric
              ? (rendererContext) => _buildNumericEditableCell(rendererContext, propertySchema, key)
              : isBoolean
              ? (rendererContext) => _buildBooleanCell(rendererContext, propertySchema, key)
              : groupName != null
              ? (rendererContext) => _buildTextCell(rendererContext, key)
              : (rendererContext) => _buildTextCell(rendererContext, key),
        ),
      );
    }

    // Store frozen column count for configuration
    debugPrint('Total frozen columns: $frozenColumnCount');

    return columns;
  }

  List<TrinaColumnGroup> _buildColumnGroups() {
    // NEW STRUCTURE: Extract groups from columnItems
    if (widget.columnItems != null && widget.columnItems!.isNotEmpty) {
      final groups = <TrinaColumnGroup>[];

      for (final item in widget.columnItems!) {
        final itemMap = item as Map<String, dynamic>;

        if (itemMap['type'] == 'group') {
          final groupLabel = itemMap['label'] as String;
          final groupItems = itemMap['items'] as List?;

          if (groupItems != null) {
            final fields = <String>[];
            for (final groupItem in groupItems) {
              final groupItemMap = groupItem as Map<String, dynamic>;
              final fieldName = groupItemMap['name'] as String?;
              if (fieldName != null) {
                fields.add(fieldName);
              }
            }

            if (fields.isNotEmpty) {
              final canExpand = fields.length == 1;
              groups.add(
                TrinaColumnGroup(title: groupLabel, fields: fields, expandedColumn: canExpand),
              );
            }
          }
        }
      }

      return groups;
    }

    // OLD STRUCTURE: Fallback to groupBy approach
    final groups = <String, List<TrinaColumn>>{};
    final itemSchema = widget.jsonSchema['items'] as Map<String, dynamic>?;
    final properties = itemSchema?['properties'] as Map<String, dynamic>?;

    if (properties == null) return [];

    // Group columns by headerName
    final columnEntries = <MapEntry<String, dynamic>>[];

    // If columnConfig is provided, ONLY use fields defined there (layout-driven)
    // Otherwise, fall back to using all schema properties
    final fieldsToProcess = widget.columnConfig != null
        ? widget.columnConfig!.keys
        : properties.keys;

    for (final key in fieldsToProcess) {
      // For calculated fields defined only in layout, create a synthetic schema
      Map<String, dynamic> propertySchema;
      Map<String, dynamic> config;

      if (!properties.containsKey(key)) {
        // Check if this is a calculated field defined in columnConfig
        final layoutConfig = widget.columnConfig?[key] as Map<String, dynamic>?;
        if (layoutConfig != null && layoutConfig['type'] == 'calculated') {
          // For calculated fields, extract groupBy directly from layout config
          config = <String, dynamic>{
            'groupBy': layoutConfig['groupBy'],
            'display': layoutConfig['display'] ?? true,
            'sortBy': 999,
          };
        } else {
          // Skip if property doesn't exist in schema and isn't a calculated field
          continue;
        }
      } else {
        propertySchema = properties[key] as Map<String, dynamic>;
        config = _getColumnConfig(key, propertySchema);
      }

      // Skip if explicitly set to not display
      if (config['display'] == false) {
        continue;
      }

      final groupBy = config['groupBy'] as Map<String, dynamic>?;
      final headerName = groupBy?['headerName'] as String?;

      if (headerName != null) {
        columnEntries.add(MapEntry(key, {'headerName': headerName}));
      }
    }

    // Column order determined by position in columnConfig/properties

    // Group columns by headerName
    for (final entry in columnEntries) {
      final headerName = entry.value['headerName'] as String;
      final column = _columns.firstWhere((col) => col.field == entry.key);

      if (!groups.containsKey(headerName)) {
        groups[headerName] = [];
      }

      groups[headerName]!.add(column);
    }

    // Create TrinaColumnGroup for each group
    return groups.entries.map((entry) {
      final fields = entry.value.map((col) => col.field).toList();
      final canExpand = fields.length == 1;
      return TrinaColumnGroup(title: entry.key, fields: fields, expandedColumn: canExpand);
    }).toList();
  }

  List<TrinaRow> _buildRows() {
    if (widget.data == null) return [];

    final itemSchema = widget.jsonSchema['items'] as Map<String, dynamic>?;
    final properties = itemSchema?['properties'] as Map<String, dynamic>?;

    return widget.data!.map((item) {
      final rowData = Map<String, dynamic>.from(item is Map ? item : {});
      final cells = <String, TrinaCell>{};

      for (final column in _columns) {
        // Skip auto-generated fields
        if (column.field == '__row_number__' || column.field == '__row_menu__') {
          cells[column.field] = TrinaCell(value: null);
        } else {
          // Get value from data, or apply schema default if missing/null
          dynamic cellValue = rowData[column.field];

          // Apply schema default if value is null and schema has a default
          if (cellValue == null && properties != null && properties.containsKey(column.field)) {
            final propertySchema = properties[column.field] as Map<String, dynamic>;
            if (propertySchema.containsKey('default')) {
              cellValue = propertySchema['default'];
              // Also update the rowData so the default is persisted
              rowData[column.field] = cellValue;
              debugPrint('  ⚙️ Applied default for ${column.field} = $cellValue during grid init');
            }
          }

          cells[column.field] = TrinaCell(value: cellValue);
        }
      }

      return TrinaRow(cells: cells);
    }).toList();
  }

  Widget _buildTextCell(TrinaColumnRendererContext rendererContext, String fieldKey) {
    final value = rendererContext.cell.value;
    final rowIndex = rendererContext.rowIdx;
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final bgColor = _getCellBackgroundColor(rowIndex, fieldKey, isDark);

    // Check if cell is in edit mode (current cell) and row is selected
    final isCurrentCell = rendererContext.stateManager.currentCell?.key == rendererContext.cell.key;
    final isRowSelected = rendererContext.stateManager.currentRowIdx == rowIndex;

    if (isCurrentCell && isRowSelected && !rendererContext.column.readOnly) {
      // Edit mode: use GenericTextField
      return Padding(
        padding: const EdgeInsets.all(4.0),
        child: Container(
          margin: const EdgeInsets.symmetric(vertical: 4),
          color: bgColor,
          child: GenericTextField(
            key: ValueKey('cell_${rowIndex}_${fieldKey}'),
            autofocus: true,
            fieldName: fieldKey,
            fieldSchema: const {'type': 'string'},
            value: value,
            errors: const [],
            compact: true,
            currentData: rendererContext.row.cells.map((k, v) => MapEntry(k, v.value)),
            onChanged: (newValue) {
              rendererContext.cell.value = newValue;
              _stateManager?.notifyListeners();
              _notifyDataChanged();
            },
          ),
        ),
      );
    }

    // Display mode
    return Container(
      margin: const EdgeInsets.symmetric(vertical: 4),
      padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 4),
      alignment: Alignment.centerLeft,
      color: bgColor,
      child: Text(value?.toString() ?? '', overflow: TextOverflow.ellipsis, maxLines: 1),
    );
  }

  Widget _buildEnumCell(
    TrinaColumnRendererContext rendererContext,
    Map<String, dynamic> propertySchema,
    String fieldKey,
  ) {
    final value = rendererContext.cell.value;
    final rowIndex = rendererContext.rowIdx;
    final tfm = propertySchema['\$tfm'] as Map<String, dynamic>?;
    final nameDe = tfm?['name_de'] as List?;
    final enumValues = propertySchema['enum'] as List?;
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final bgColor = _getCellBackgroundColor(rowIndex, fieldKey, isDark);

    // Check if field is readonly
    final isReadOnly = propertySchema['readonly'] as bool? ?? false;

    // Get display text
    String displayText = '';
    if (value != null && nameDe != null && enumValues != null) {
      final index = enumValues.indexOf(value);
      if (index >= 0 && index < nameDe.length) {
        final germanName = nameDe[index];
        displayText = germanName != null ? '$value | $germanName' : value.toString();
      } else {
        displayText = value.toString();
      }
    } else if (value != null) {
      displayText = value.toString();
    }

    return InkWell(
      onTap: isReadOnly ? null : () => _openEnumDialog(rendererContext, propertySchema, fieldKey),
      child: Container(
        margin: const EdgeInsets.symmetric(vertical: 4),
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
        alignment: Alignment.centerLeft,
        color: bgColor,
        child: Text(displayText, overflow: TextOverflow.ellipsis, maxLines: 1),
      ),
    );
  }

  Widget _buildNumericEditableCell(
    TrinaColumnRendererContext rendererContext,
    Map<String, dynamic> propertySchema,
    String fieldKey,
  ) {
    final value = rendererContext.cell.value;
    final rowIndex = rendererContext.rowIdx;
    final tfm = propertySchema['\$tfm'] as Map<String, dynamic>?;
    final unit = tfm?['unit_short'] as String?;
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final bgColor = _getCellBackgroundColor(rowIndex, fieldKey, isDark);

    // Check if this column has upDownBtn (spinner buttons)
    bool hasSpinner = false;
    if (widget.columnConfig != null && widget.columnConfig!.containsKey(fieldKey)) {
      final columnCfg = widget.columnConfig![fieldKey] as Map<String, dynamic>?;
      hasSpinner = columnCfg?['upDownBtn'] != null;
    } else if (widget.columnItems != null) {
      // Check in columnItems structure
      for (final item in widget.columnItems!) {
        final itemMap = item as Map<String, dynamic>;
        if (itemMap['type'] == 'group') {
          final groupItems = itemMap['items'] as List?;
          if (groupItems != null) {
            for (final groupItem in groupItems) {
              final groupItemMap = groupItem as Map<String, dynamic>;
              if (groupItemMap['name'] == fieldKey && groupItemMap['upDownBtn'] != null) {
                hasSpinner = true;
                break;
              }
            }
          }
        } else if (itemMap['name'] == fieldKey && itemMap['upDownBtn'] != null) {
          hasSpinner = true;
          break;
        }
      }
    }

    // Check if cell is in edit mode and row is selected
    final isCurrentCell = rendererContext.stateManager.currentCell?.key == rendererContext.cell.key;
    final isRowSelected = rendererContext.stateManager.currentRowIdx == rowIndex;

    if (isCurrentCell && isRowSelected) {
      // Edit mode: use GenericTextField in compact mode for grid
      return Container(
        color: bgColor,
        child: GenericTextField(
          key: ValueKey('cell_${rowIndex}_${fieldKey}'),
          autofocus: true,
          fieldName: fieldKey,
          fieldSchema: propertySchema,
          value: value,
          errors: const [],
          compact: true,
          onChanged: (newValue) {
            rendererContext.cell.value = newValue;
            _stateManager?.notifyListeners();
            _notifyDataChanged();
          },
        ),
      );
    }

    // Display mode: show text
    String displayText = '';
    if (value != null && value.toString() != 'null') {
      displayText = value.toString();
      if (unit != null && unit.isNotEmpty) {
        displayText = '$displayText $unit';
      }
    }

    return Container(
      margin: const EdgeInsets.symmetric(vertical: 4),
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      alignment: hasSpinner ? Alignment.center : Alignment.centerRight,
      color: bgColor,
      child: Text(displayText, overflow: TextOverflow.ellipsis, maxLines: 1),
    );
  }

  Widget _buildBooleanCell(
    TrinaColumnRendererContext rendererContext,
    Map<String, dynamic> propertySchema,
    String fieldKey,
  ) {
    final value = rendererContext.cell.value;
    final rowIndex = rendererContext.rowIdx;
    final boolValue = value == true;
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final bgColor = _getCellBackgroundColor(rowIndex, fieldKey, isDark);

    // Check if field is readonly
    final isReadOnly = propertySchema['readonly'] as bool? ?? false;

    // Check if cell is in edit mode and row is selected
    final isCurrentCell = rendererContext.stateManager.currentCell?.key == rendererContext.cell.key;
    final isRowSelected = rendererContext.stateManager.currentRowIdx == rowIndex;

    if (isCurrentCell && isRowSelected && !isReadOnly) {
      // Edit mode: use GenericTextField with switch
      return Container(
        color: bgColor,
        alignment: Alignment.center,
        child: GenericTextField(
          key: ValueKey('cell_${rowIndex}_${fieldKey}'),
          autofocus: true,
          fieldName: fieldKey,
          fieldSchema: propertySchema,
          value: value,
          errors: const [],
          compact: true,
          onChanged: (newValue) {
            rendererContext.cell.value = newValue;
            _stateManager?.notifyListeners();
            _notifyDataChanged();
          },
        ),
      );
    }

    // Display mode: show "Ja" or "Nein" text
    final displayText = boolValue ? 'Ja' : 'Nein';

    return Container(
      margin: const EdgeInsets.symmetric(vertical: 4),
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      alignment: Alignment.center,
      child: Text(displayText),
    );
  }

  Widget _buildNestedArrayCell(
    TrinaColumnRendererContext rendererContext,
    Map<String, dynamic> propertySchema,
    String fieldKey,
    Map<String, dynamic> nestedArrayConfig,
  ) {
    final value = rendererContext.cell.value;
    final rowIndex = rendererContext.rowIdx;
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final bgColor = _getCellBackgroundColor(rowIndex, fieldKey, isDark);

    // Get nested array data
    List<dynamic>? nestedData;
    if (value is List) {
      nestedData = value;
    } else if (value is String && nestedArrayConfig['options']?['asJson'] == true) {
      // Try to parse JSON string
      try {
        final decoded = jsonDecode(value);
        if (decoded is List) {
          nestedData = decoded;
        }
      } catch (e) {
        debugPrint('Failed to parse nested array JSON: $e');
      }
    }

    final itemCount = nestedData?.length ?? 0;
    final displayText = itemCount == 0 ? 'Leer' : '$itemCount Einträge';

    // Check if parent array or this field is readonly
    final isReadOnly = _isArrayReadOnly || (propertySchema['readonly'] as bool? ?? false);

    return Container(
      color: bgColor,
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Expanded(
            child: Text(
              displayText,
              style: TextStyle(fontSize: 14, color: itemCount == 0 ? Colors.grey : null),
            ),
          ),
          IconButton(
            icon: const Icon(Icons.edit, size: 18),
            padding: EdgeInsets.zero,
            constraints: const BoxConstraints(),
            tooltip: 'Bearbeiten',
            onPressed: isReadOnly
                ? null
                : () => _openNestedArrayDialog(
                    rendererContext,
                    propertySchema,
                    fieldKey,
                    nestedArrayConfig,
                    nestedData,
                  ),
          ),
        ],
      ),
    );
  }

  Future<void> _openNestedArrayDialog(
    TrinaColumnRendererContext rendererContext,
    Map<String, dynamic> propertySchema,
    String fieldKey,
    Map<String, dynamic> nestedArrayConfig,
    List<dynamic>? currentData,
  ) async {
    // Create schema for nested array from property schema
    final nestedArraySchema = Map<String, dynamic>.from(propertySchema);

    // Get nested columns config and options
    final nestedColumns = nestedArrayConfig['columns'] as Map<String, dynamic>?;
    final nestedOptions = nestedArrayConfig['options'] as Map<String, dynamic>?;

    // Build property path for validation
    final rowIndex = rendererContext.rowIdx;
    final nestedPath = widget.propertyName != null
        ? '${widget.propertyName}/$rowIndex/$fieldKey'
        : '$rowIndex/$fieldKey';

    final result = await ArrayGridDialog.show(
      context: context,
      nestedArraySchema: nestedArraySchema,
      data: currentData,
      title: propertySchema['title'] as String? ?? fieldKey,
      validationResult: widget.validationResult,
      propertyPath: nestedPath,
      columnConfig: nestedColumns,
      layoutOptions: nestedOptions,
      parentReadOnly: _isArrayReadOnly,
    );

    if (result != null) {
      // Update cell value based on storage format
      if (nestedOptions?['asJson'] == true) {
        // Store as JSON string
        rendererContext.cell.value = jsonEncode(result);
      } else {
        // Store as List
        rendererContext.cell.value = result;
      }
      _stateManager?.notifyListeners();
      _notifyDataChanged();
    }
  }

  Widget _buildGenericFieldCell(
    TrinaColumnRendererContext rendererContext,
    Map<String, dynamic> propertySchema,
    String fieldKey,
  ) {
    final rowIndex = rendererContext.rowIdx;
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final bgColor = _getCellBackgroundColor(rowIndex, fieldKey, isDark);

    // Get current row data to find matching previous row by identifier
    final currentRowData = rendererContext.row.cells.map((key, cell) => MapEntry(key, cell.value));

    // Find matching previous row by identifier (tree_number, edge_number, etc.)
    Map<String, dynamic>? previousRowData;
    if (widget.previousData != null) {
      // Use configured identifier field or fall back to common fields
      final identifierFields = widget.identifierField != null
          ? [widget.identifierField!]
          : ['tree_number', 'edge_number', 'row_number', 'id'];

      for (final idField in identifierFields) {
        if (currentRowData.containsKey(idField) && currentRowData[idField] != null) {
          final currentId = currentRowData[idField];

          // Find matching row in previousData by this identifier
          previousRowData = (widget.previousData as List).cast<Map<String, dynamic>?>().firstWhere(
            (prevRow) => prevRow != null && prevRow[idField] == currentId,
            orElse: () => null,
          );

          if (previousRowData != null) {
            break;
          }
        }
      }
    }

    return Container(
      color: bgColor,
      child: GenericTextField(
        key: ValueKey('cell_${rowIndex}_${fieldKey}'),
        fieldName: fieldKey,
        fieldSchema: propertySchema,
        value: rendererContext.cell.value,
        errors: const [],
        compact: true,
        previousData: previousRowData,
        currentData: rendererContext.row.cells.map((k, v) => MapEntry(k, v.value)),
      ),
    );
  }

  Future<void> _openEnumDialog(
    TrinaColumnRendererContext rendererContext,
    Map<String, dynamic> propertySchema,
    String fieldKey,
  ) async {
    final enumValues = propertySchema['enum'] as List? ?? [];
    final tfm = propertySchema['\$tfm'] as Map<String, dynamic>?;
    final nameDe = tfm?['name_de'] as List?;
    final interval = tfm?['interval'] as List?;

    final result = await GenericEnumDialog.show(
      context: context,
      fieldName: fieldKey,
      fieldSchema: propertySchema,
      currentValue: rendererContext.cell.value,
      enumValues: enumValues,
      nameDe: nameDe,
      interval: interval,
      fullscreen: true,
    );

    if (result != null) {
      // Check if user selected "Leeren" (clear selection)
      if (result is ClearSelection) {
        rendererContext.cell.value = null;
      } else {
        rendererContext.cell.value = result;
      }
      _stateManager?.notifyListeners();
      _notifyDataChanged();
    }
  }

  void _setEmptyArray() {
    // Clear all rows - this will set data to null via _notifyDataChanged
    _rows.clear();
    _stateManager?.removeAllRows();
    _notifyDataChanged(true);
  }

  Future<void> _addRowAsFormDialog() async {
    final itemSchema = widget.jsonSchema['items'] as Map<String, dynamic>?;
    if (itemSchema == null) return;

    final result = await ArrayRowFormDialog.show(
      context: context,
      itemSchema: itemSchema,
      columnConfig: widget.columnConfig,
      layoutOptions: widget.layoutOptions,
      title: 'Zeile hinzufügen',
      readOnly: _isArrayReadOnly,
    );

    if (result != null) {
      // Add the row with data from form
      final properties = itemSchema['properties'] as Map<String, dynamic>?;
      if (properties == null) return;

      final newRow = <String, dynamic>{};

      // Initialize with form data and apply defaults/auto-increment
      properties.forEach((key, value) {
        final propertySchema = value as Map<String, dynamic>;
        final typeValue = propertySchema['type'];

        String? type;
        if (typeValue is String) {
          type = typeValue;
        } else if (typeValue is List) {
          type =
              typeValue.firstWhere((t) => t != 'null' && t != null, orElse: () => null) as String?;
        }

        // Check if field has autoIncrement enabled
        final tfm = propertySchema['\$tfm'] as Map<String, dynamic>?;
        final form = tfm?['form'] as Map<String, dynamic>?;
        final autoIncrement = form?['autoIncrement'] as bool? ?? false;

        if (autoIncrement && (type == 'integer' || type == 'number')) {
          // Auto-increment: find max value and add 1
          final existingValues = _rows
              .map((row) => row.cells[key]?.value)
              .where((v) => v != null && v is num)
              .map((v) => (v as num).toInt())
              .toList();

          final defaultValue = propertySchema['default'] as int? ?? 1;
          newRow[key] = existingValues.isEmpty
              ? defaultValue
              : (existingValues.reduce((a, b) => a > b ? a : b) + 1);
        } else {
          // Use value from form, or default, or type-based default
          newRow[key] = result[key] ?? propertySchema['default'] ?? _getDefaultValue(type);
        }
      });

      // Create cells and add row
      final cells = <String, TrinaCell>{};
      for (final column in _columns) {
        if (column.field == '__row_number__' || column.field == '__row_menu__') {
          cells[column.field] = TrinaCell(value: null);
        } else {
          cells[column.field] = TrinaCell(value: newRow[column.field]);
        }
      }

      final newTrinaRow = TrinaRow(cells: cells);
      _rows.add(newTrinaRow);

      if (_stateManager != null) {
        _stateManager!.insertRows(_stateManager!.rows.length, [newTrinaRow]);
        _notifyDataChanged();
      } else {
        _notifyDataChanged();
        setState(() {});
      }
    }
  }

  dynamic _getDefaultValue(String? type) {
    switch (type) {
      case 'string':
        return '';
      case 'number':
      case 'integer':
        return null;
      case 'boolean':
        return false;
      case 'array':
        return [];
      case 'object':
        return {};
      default:
        return null;
    }
  }

  void addRow() {
    final itemSchema = widget.jsonSchema['items'] as Map<String, dynamic>?;
    final properties = itemSchema?['properties'] as Map<String, dynamic>?;

    if (properties == null) return;

    final newRow = <String, dynamic>{};

    debugPrint('🆕 Adding new row for ${widget.propertyName}');

    properties.forEach((key, value) {
      final propertySchema = value as Map<String, dynamic>;
      final typeValue = propertySchema['type'];

      String? type;
      if (typeValue is String) {
        type = typeValue;
      } else if (typeValue is List) {
        type = typeValue.firstWhere((t) => t != 'null' && t != null, orElse: () => null) as String?;
      }

      // Check if field has autoIncrement enabled
      final tfm = propertySchema['\$tfm'] as Map<String, dynamic>?;
      final form = tfm?['form'] as Map<String, dynamic>?;
      final autoIncrement = form?['autoIncrement'] as bool? ?? false;

      if (autoIncrement && (type == 'integer' || type == 'number')) {
        // Auto-increment: find max value and add 1
        final existingValues = _rows
            .map((row) => row.cells[key]?.value)
            .where((v) => v != null && v is num)
            .map((v) => (v as num).toInt())
            .toList();

        final defaultValue = propertySchema['default'] as int? ?? 1;
        newRow[key] = existingValues.isEmpty
            ? defaultValue
            : (existingValues.reduce((a, b) => a > b ? a : b) + 1);
        debugPrint('  ✅ $key = ${newRow[key]} (autoIncrement, default: $defaultValue)');
      } else if (propertySchema.containsKey('default')) {
        newRow[key] = propertySchema['default'];
        debugPrint('  ✅ $key = ${newRow[key]} (default from schema)');
      } else {
        switch (type) {
          case 'string':
            newRow[key] = '';
            break;
          case 'number':
          case 'integer':
            newRow[key] = null;
            break;
          case 'boolean':
            newRow[key] = false;
            break;
          case 'array':
            newRow[key] = [];
            break;
          case 'object':
            newRow[key] = {};
            break;
          default:
            newRow[key] = null;
        }
      }
    });

    final cells = <String, TrinaCell>{};
    for (final column in _columns) {
      // Skip auto-generated fields
      if (column.field == '__row_number__' || column.field == '__row_menu__') {
        cells[column.field] = TrinaCell(value: null);
      } else {
        cells[column.field] = TrinaCell(value: newRow[column.field]);
      }
    }

    final newTrinaRow = TrinaRow(cells: cells);

    // Add to internal state first
    _rows.add(newTrinaRow);

    if (_stateManager != null) {
      // Sync to state manager - this should trigger onChanged but it doesn't always
      _stateManager!.insertRows(_stateManager!.rows.length, [newTrinaRow]);
      // Explicitly notify parent since onChanged might not fire for insertRows
      _notifyDataChanged();
    } else {
      // If grid not loaded yet (empty state), notify parent directly
      _notifyDataChanged();
      // Trigger rebuild to show the grid
      setState(() {});
    }
  }

  void _deleteRow(int rowIndex) {
    if (_stateManager != null) {
      _stateManager!.removeRows([_stateManager!.rows[rowIndex]]);
      _rows = _stateManager!.rows;
      _notifyDataChanged();
    } else {
      _rows.removeAt(rowIndex);
      _notifyDataChanged();
      setState(() {});
    }
  }

  void _copyRow(int rowIndex) {
    final rowToCopy = _rows[rowIndex];
    final newCells = <String, TrinaCell>{};

    // Get schema to check for autoIncrement fields
    final itemSchema = widget.jsonSchema['items'] as Map<String, dynamic>?;
    final properties = itemSchema?['properties'] as Map<String, dynamic>?;

    rowToCopy.cells.forEach((key, cell) {
      // Skip auto-generated fields
      if (key == '__row_number__' || key == '__row_menu__') {
        newCells[key] = TrinaCell(value: null);
        return;
      }

      // Check if this field has autoIncrement enabled
      if (properties != null && properties.containsKey(key)) {
        final propertySchema = properties[key] as Map<String, dynamic>;
        final typeValue = propertySchema['type'];

        String? type;
        if (typeValue is String) {
          type = typeValue;
        } else if (typeValue is List) {
          type =
              typeValue.firstWhere((t) => t != 'null' && t != null, orElse: () => null) as String?;
        }

        // Check for autoIncrement
        final tfm = propertySchema['\$tfm'] as Map<String, dynamic>?;
        final form = tfm?['form'] as Map<String, dynamic>?;
        final autoIncrement = form?['autoIncrement'] as bool? ?? false;

        if (autoIncrement && (type == 'integer' || type == 'number')) {
          // Auto-increment: find max value and add 1 (don't copy the original value)
          final existingValues = _rows
              .map((row) => row.cells[key]?.value)
              .where((v) => v != null && v is num)
              .map((v) => (v as num).toInt())
              .toList();

          final defaultValue = propertySchema['default'] as int? ?? 1;
          final nextValue = existingValues.isEmpty
              ? defaultValue
              : (existingValues.reduce((a, b) => a > b ? a : b) + 1);

          newCells[key] = TrinaCell(value: nextValue);
          debugPrint('  🔢 AutoIncrement field $key: copied value ignored, using $nextValue');
        } else {
          // Normal field: copy the value
          newCells[key] = TrinaCell(value: cell.value);
        }
      } else {
        // No schema info, just copy
        newCells[key] = TrinaCell(value: cell.value);
      }
    });

    final newTrinaRow = TrinaRow(cells: newCells);

    if (_stateManager != null) {
      // Insert after the copied row
      _stateManager!.insertRows(rowIndex + 1, [newTrinaRow]);
      _rows = _stateManager!.rows;
      _notifyDataChanged();
    } else {
      _rows.insert(rowIndex + 1, newTrinaRow);
      _notifyDataChanged();
      setState(() {});
    }
  }

  void _notifyDataChanged([bool forceData = false]) {
    // Sync _rows from state manager if available (source of truth)
    final rowsToUse = _stateManager?.rows ?? _rows;

    final data = rowsToUse.map((row) {
      final rowData = <String, dynamic>{};
      row.cells.forEach((key, cell) {
        // Skip auto-generated fields - they're not part of the data
        if (key != '__row_number__' && key != '__row_menu__') {
          rowData[key] = cell.value;
        }
      });
      return rowData;
    }).toList();

    if (forceData) {
      widget.onDataChanged?.call(data);
      return;
    }

    // If last row is deleted, data should be null not empty array.
    if (data.isEmpty) {
      widget.onDataChanged?.call(null);
    } else {
      widget.onDataChanged?.call(data);
    }
  }

  @override
  void dispose() {
    // Remove listener from MapControllerProvider
    if (_mapControllerProvider != null) {
      _mapControllerProvider!.removeListener(_onMapControllerChanged);
      debugPrint('${widget.propertyName}: Listener removed from MapControllerProvider');
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (_columns.isEmpty) {
      return const Center(child: Text('No schema properties found'));
    }

    if (_rows.isEmpty) {
      return Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.start,
          children: [
            const Icon(Icons.table_chart, size: 48, color: Colors.grey),
            const SizedBox(height: 16),
            //const Text('Kein Eintrag vorhanden', style: TextStyle(color: Colors.grey)),
            //const SizedBox(height: 8),
            ElevatedButton.icon(
              onPressed: _isArrayReadOnly ? null : addRow,
              icon: const Icon(Icons.add),
              label: const Text('Eintrag hinzufügen'),
            ),
            const SizedBox(height: 8),
            if (widget.data == null) // if data is null
              ElevatedButton(
                onPressed: _setEmptyArray,
                child: const Text('Kein Eintrag erforderlich'),
              ),
          ],
        ),
      );
    }

    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Column(
      children: [
        // Add row button bar
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 8.0, vertical: 4.0),
          decoration: BoxDecoration(
            color: isDark ? const Color(0xFF2D2D30) : Colors.grey.shade100,
            border: Border(
              bottom: BorderSide(
                color: isDark ? const Color(0xFF3E3E42) : Colors.grey.shade300,
                width: 1,
              ),
            ),
          ),
          child: Row(
            children: [
              Text(
                '${_rows.length} Einträge',
                style: TextStyle(color: isDark ? Colors.white70 : Colors.black54, fontSize: 12),
              ),
              Spacer(),
              Container(
                margin: const EdgeInsets.only(right: 8, top: 4, bottom: 4),
                decoration: BoxDecoration(
                  // card background color
                  color: Theme.of(context).colorScheme.surface,
                  borderRadius: BorderRadius.circular(50),
                ),
                child: Row(
                  children: [
                    TextButton(
                      onPressed: _isArrayReadOnly ? null : addRow,
                      child: Text('Zeile hinzufügen'),
                    ),
                    /*Container(width: 1, height: 24, color: Colors.white54),
                    IconButton(
                      onPressed: _addRowAsFormDialog,
                      icon: const Icon(Icons.playlist_add),
                      tooltip: 'Zeile über Formular hinzufügen',
                      color: Theme.of(context).colorScheme.primary,
                    ),*/
                  ],
                ),
              ),
            ],
          ),
        ),
        // Grid
        Expanded(
          child: Stack(
            children: [
              TrinaGrid(
                columns: _columns,
                rows: _rows,
                columnGroups: _columnGroups.isNotEmpty ? _columnGroups : null,
                onLoaded: (TrinaGridOnLoadedEvent event) {
                  _stateManager = event.stateManager;
                  _rows = event.stateManager.rows;
                  // Auto-size columns to fit headers
                  /*for (final column in event.stateManager.columns) {
                    event.stateManager.autoFitColumn(context, column);
                  }*/
                },
                onChanged: (TrinaGridOnChangedEvent event) {
                  // Sync _rows from state manager
                  _rows = _stateManager?.rows ?? _rows;
                  _notifyDataChanged();
                },
                onSorted: (TrinaGridOnSortedEvent event) {
                  final column = event.column;

                  // Simple toggle: if currently ascending, go descending, otherwise go ascending
                  if (column.sort == TrinaColumnSort.ascending) {
                    _stateManager?.sortDescending(column);
                  } else {
                    _stateManager?.sortAscending(column);
                  }

                  _rows = _stateManager?.rows ?? _rows;
                },
                configuration: TrinaGridConfiguration(
                  scrollbar: const TrinaGridScrollbarConfig(isAlwaysShown: true),
                  columnSize: const TrinaGridColumnSizeConfig(resizeMode: TrinaResizeMode.normal),
                  enterKeyAction: TrinaGridEnterKeyAction.editingAndMoveDown,
                  enableMoveDownAfterSelecting: true,
                  enableMoveHorizontalInEditing: true,
                  tabKeyAction: TrinaGridTabKeyAction.moveToNextOnEdge,
                  style: TrinaGridStyleConfig(
                    rowHeight: 60,
                    iconSize: 0,
                    gridBorderRadius: BorderRadius.zero,
                    enableGridBorderShadow: false,
                    gridBackgroundColor: isDark ? const Color(0xFF1E1E1E) : Colors.white,
                    rowColor: isDark ? const Color(0xFF252526) : Colors.white,
                    activatedColor: isDark
                        ? const Color.fromARGB(10, 0, 255, 0)
                        : const Color(0xFFDCF2FF),
                    cellTextStyle: TextStyle(
                      color: isDark ? Colors.white : Colors.black87,
                      fontSize: 14,
                    ),
                    columnTextStyle: TextStyle(
                      color: isDark ? Colors.white : Colors.black87,
                      fontSize: 14,
                      fontWeight: FontWeight.bold,
                    ),
                    gridBorderColor: isDark ? const Color(0xFF3E3E42) : Colors.grey.shade300,
                    borderColor: isDark ? const Color(0xFF3E3E42) : Colors.grey.shade300,
                    activatedBorderColor: isDark
                        ? const Color.fromARGB(100, 0, 255, 0)
                        : Colors.blue,
                    inactivatedBorderColor: isDark ? const Color(0xFF3E3E42) : Colors.grey.shade300,
                    iconColor: isDark ? Colors.white70 : Colors.black54,
                    disabledIconColor: isDark ? Colors.white24 : Colors.black26,
                    menuBackgroundColor: isDark ? const Color(0xFF252526) : Colors.white,
                    cellColorInEditState: isDark ? const Color(0xFF1E1E1E) : Colors.white,
                    cellColorInReadOnlyState: isDark
                        ? const Color(0xFF2D2D30)
                        : Colors.grey.shade100,
                  ),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}
