import 'package:flutter/material.dart';
import 'package:trina_grid/trina_grid.dart';
import 'package:terrestrial_forest_monitor/services/validation_service.dart';
import 'package:terrestrial_forest_monitor/widgets/form-elements/generic-enum-dialog.dart';
import 'package:terrestrial_forest_monitor/widgets/form-elements/generic-textfield.dart';

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

  @override
  void initState() {
    super.initState();
    print('Initializing ArrayElementTrina for property: ${widget.propertyName}');
    print('Initial data: ${widget.data}');
    _initializeGrid();
  }

  @override
  void didUpdateWidget(ArrayElementTrina oldWidget) {
    super.didUpdateWidget(oldWidget);
    // Reinitialize if schema changes or data changes
    bool shouldRebuild = false;

    if (widget.jsonSchema != oldWidget.jsonSchema) {
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
    config['sortBy'] = form?['sortBy'] ?? 999;
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
      print('No items found in schema');
      return columns;
    }

    final properties = itemSchema['properties'] as Map<String, dynamic>?;
    if (properties == null) {
      print('No properties found in items schema');
      return columns;
    }

    // Add menu column (always first, pinned left)
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
                const PopupMenuItem(
                  value: 'copy',
                  child: Row(
                    children: [
                      Icon(Icons.content_copy, size: 18),
                      SizedBox(width: 8),
                      Text('Zeile kopieren'),
                    ],
                  ),
                ),
                PopupMenuItem(
                  value: 'delete',
                  enabled: !hasPreviousData, // Only allow delete if no previous data
                  child: Row(
                    children: [
                      Icon(Icons.delete, size: 18, color: hasPreviousData ? Colors.grey : null),
                      const SizedBox(width: 8),
                      Text(
                        'Zeile löschen',
                        style: TextStyle(color: hasPreviousData ? Colors.grey : null),
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

      final sortBy = config['sortBy'] ?? 999;
      final groupBy = config['groupBy'];
      final columnGroupShow = groupBy?['columnGroupShow'] as String?;
      final pinned = config['pinned'];

      columnEntries.add(
        MapEntry(key, {
          'schema': propertySchema,
          'sortBy': sortBy,
          'groupBy': groupBy,
          'columnGroupShow': columnGroupShow,
          'pinned': pinned,
          'width': config['width'],
          'readonly': config['readonly'],
        }),
      );
    }

    // Sort columns by sortBy value
    columnEntries.sort((a, b) => a.value['sortBy'].compareTo(b.value['sortBy']));

    // Count frozen columns (pinned left)
    int frozenColumnCount = 0;

    // Create columns from sorted entries
    for (final entry in columnEntries) {
      final key = entry.key;
      final propertySchema = entry.value['schema'] as Map<String, dynamic>;
      final title = propertySchema['title'] as String? ?? key;
      final tfm = propertySchema['\$tfm'] as Map<String, dynamic>?;
      final unit = tfm?['unit_short'] as String?;

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

      if (type == 'calculated') {
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
          title: unit != null ? '$title ($unit)' : title,
          field: key,
          type: columnType,
          width: columnWidth,
          frozen: frozen,
          enableSorting: false,
          enableColumnDrag: false,
          enableContextMenu: false,
          readOnly: isReadOnly || isCalculated,
          // Custom renderer for calculated, enum, numeric, boolean, or grouped columns
          renderer: isCalculated
              ? (rendererContext) => _buildGenericFieldCell(rendererContext, propertySchema, key)
              : isEnum
              ? (rendererContext) => _buildEnumCell(rendererContext, propertySchema, key)
              : isNumeric
              ? (rendererContext) => _buildNumericEditableCell(rendererContext, propertySchema, key)
              : isBoolean
              ? (rendererContext) => _buildBooleanCell(rendererContext, key)
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

      final sortBy = config['sortBy'] ?? 999;
      final groupBy = config['groupBy'] as Map<String, dynamic>?;
      final headerName = groupBy?['headerName'] as String?;
      final groupSortBy = groupBy?['sortBy'] as int? ?? 999;

      if (headerName != null) {
        columnEntries.add(
          MapEntry(key, {'headerName': headerName, 'sortBy': sortBy, 'groupSortBy': groupSortBy}),
        );
      }
    }

    // Sort by group sortBy, then by column sortBy
    columnEntries.sort((a, b) {
      final groupCompare = (a.value['groupSortBy'] as int).compareTo(b.value['groupSortBy'] as int);
      if (groupCompare != 0) return groupCompare;
      return (a.value['sortBy'] as int).compareTo(b.value['sortBy'] as int);
    });

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

    return widget.data!.map((item) {
      final rowData = Map<String, dynamic>.from(item is Map ? item : {});
      final cells = <String, TrinaCell>{};

      for (final column in _columns) {
        // Skip auto-generated fields
        if (column.field == '__row_number__' || column.field == '__row_menu__') {
          cells[column.field] = TrinaCell(value: null);
        } else {
          cells[column.field] = TrinaCell(value: rowData[column.field]);
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
      onTap: () => _openEnumDialog(rendererContext, propertySchema, fieldKey),
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
      alignment: Alignment.centerRight,
      color: bgColor,
      child: Text(displayText, overflow: TextOverflow.ellipsis, maxLines: 1),
    );
  }

  Widget _buildBooleanCell(TrinaColumnRendererContext rendererContext, String fieldKey) {
    final value = rendererContext.cell.value;
    final rowIndex = rendererContext.rowIdx;
    final boolValue = value == true;
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final bgColor = _getCellBackgroundColor(rowIndex, fieldKey, isDark);

    return Container(
      margin: const EdgeInsets.symmetric(vertical: 4),
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      alignment: Alignment.center,
      color: bgColor,
      child: Switch(
        value: boolValue,
        onChanged: (newValue) {
          rendererContext.cell.value = newValue;
          _stateManager?.notifyListeners();
          _notifyDataChanged();
        },
      ),
    );
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

    final result = await GenericEnumDialog.show(
      context: context,
      fieldName: fieldKey,
      fieldSchema: propertySchema,
      currentValue: rendererContext.cell.value,
      enumValues: enumValues,
      nameDe: nameDe,
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

    await showDialog(
      context: context,
      builder: (context) => Dialog(
        child: Container(
          constraints: BoxConstraints(
            maxWidth: 600,
            maxHeight: MediaQuery.of(context).size.height * 0.8,
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // Header
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: Theme.of(context).colorScheme.primaryContainer,
                  borderRadius: const BorderRadius.vertical(top: Radius.circular(4)),
                ),
                child: Row(
                  children: [
                    Expanded(
                      child: Text(
                        'Neue Zeile hinzufügen',
                        style: Theme.of(context).textTheme.titleLarge,
                      ),
                    ),
                    IconButton(
                      icon: const Icon(Icons.close),
                      onPressed: () => Navigator.of(context).pop(),
                    ),
                  ],
                ),
              ),
              // Form content
              Expanded(
                child: SingleChildScrollView(
                  padding: const EdgeInsets.all(16),
                  child: _buildFormFields(itemSchema),
                ),
              ),
              // Buttons
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  border: Border(top: BorderSide(color: Theme.of(context).dividerColor)),
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.end,
                  children: [
                    TextButton(
                      onPressed: () => Navigator.of(context).pop(),
                      child: const Text('Abbrechen'),
                    ),
                    const SizedBox(width: 8),
                    ElevatedButton(
                      onPressed: () {
                        addRow();
                        Navigator.of(context).pop();
                      },
                      child: const Text('Hinzufügen'),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildFormFields(Map<String, dynamic> itemSchema) {
    final properties = itemSchema['properties'] as Map<String, dynamic>?;
    if (properties == null) {
      return const Center(child: Text('Keine Felder verfügbar'));
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const Text(
          'Bitte füllen Sie die Felder aus:',
          style: TextStyle(fontStyle: FontStyle.italic),
        ),
        const SizedBox(height: 16),
        ...properties.entries.map((entry) {
          final config = _getColumnConfig(entry.key, entry.value as Map<String, dynamic>);
          if (config['display'] != true) return const SizedBox.shrink();

          final propertySchema = entry.value as Map<String, dynamic>;
          final title = propertySchema['title'] as String? ?? entry.key;

          return Padding(padding: const EdgeInsets.only(bottom: 12), child: Text('• $title'));
        }).toList(),
      ],
    );
  }

  void addRow() {
    final itemSchema = widget.jsonSchema['items'] as Map<String, dynamic>?;
    final properties = itemSchema?['properties'] as Map<String, dynamic>?;

    if (properties == null) return;

    final newRow = <String, dynamic>{};

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
      } else if (propertySchema.containsKey('default')) {
        newRow[key] = propertySchema['default'];
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

    rowToCopy.cells.forEach((key, cell) {
      // Copy all cell values
      newCells[key] = TrinaCell(value: cell.value);
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
              onPressed: addRow,
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
              OutlinedButton.icon(
                onPressed: addRow,
                label: Text('Zeile hinzufügen'),
                icon: const Icon(Icons.add),
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
                  // Sync state manager rows to our _rows list after load
                  _rows = event.stateManager.rows;
                },
                onChanged: (TrinaGridOnChangedEvent event) {
                  // Sync _rows from state manager
                  _rows = _stateManager?.rows ?? _rows;
                  _notifyDataChanged();
                },
                onSorted: (TrinaGridOnSortedEvent event) {
                  // Prevent sorting by doing nothing
                  return;
                },
                configuration: TrinaGridConfiguration(
                  columnSize: const TrinaGridColumnSizeConfig(resizeMode: TrinaResizeMode.normal),
                  enterKeyAction: TrinaGridEnterKeyAction.editingAndMoveDown,
                  enableMoveDownAfterSelecting: true,
                  enableMoveHorizontalInEditing: true,
                  tabKeyAction: TrinaGridTabKeyAction.moveToNextOnEdge,
                  style: TrinaGridStyleConfig(
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
