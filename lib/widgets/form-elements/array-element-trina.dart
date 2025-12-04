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
  final Function(List<dynamic>)? onDataChanged;

  const ArrayElementTrina({
    super.key,
    required this.jsonSchema,
    required this.data,
    this.propertyName,
    this.validationResult,
    this.onDataChanged,
  });

  @override
  State<ArrayElementTrina> createState() => _ArrayElementTrinaState();
}

class _ArrayElementTrinaState extends State<ArrayElementTrina> {
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
    // Only reinitialize if schema changes
    if (widget.jsonSchema != oldWidget.jsonSchema) {
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
      return isDark ? const Color(0xFF5A1F1F) : const Color(0xFFFFCDD2); // Light red
    }
    return null;
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

    // Create list of column entries with sortBy for sorting
    final columnEntries = <MapEntry<String, dynamic>>[];

    properties.forEach((key, value) {
      final propertySchema = value as Map<String, dynamic>;
      final tfm = propertySchema['\$tfm'] as Map<String, dynamic>?;
      final form = tfm?['form'] as Map<String, dynamic>?;
      final uiOptions = form?['ui:options'] as Map<String, dynamic>?;
      final display = uiOptions?['display'] as bool? ?? true;

      if (!display) {
        return;
      }

      final sortBy = form?['sortBy'] as int? ?? 999;
      final groupBy = form?['groupBy'] as Map<String, dynamic>?;
      final columnGroupShow = groupBy?['columnGroupShow'] as String?;
      final pinned = uiOptions?['pinned'] as String?;

      columnEntries.add(
        MapEntry(key, {
          'schema': propertySchema,
          'sortBy': sortBy,
          'groupBy': groupBy,
          'columnGroupShow': columnGroupShow,
          'pinned': pinned,
        }),
      );
    });

    // Sort columns by sortBy value
    columnEntries.sort((a, b) => a.value['sortBy'].compareTo(b.value['sortBy']));

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

      if (propertySchema.containsKey('enum')) {
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
      final isReadOnly = propertySchema['readonly'] as bool? ?? false;

      // Determine frozen position from pinned value
      final frozen = pinnedValue == 'left'
          ? TrinaColumnFrozen.start
          : pinnedValue == 'right'
          ? TrinaColumnFrozen.end
          : TrinaColumnFrozen.none;

      columns.add(
        TrinaColumn(
          title: unit != null ? '$title ($unit)' : title,
          field: key,
          type: columnType,
          width: 150,
          frozen: frozen,
          enableSorting: false,
          enableColumnDrag: false,
          readOnly: isReadOnly,
          // Custom renderer for enum, numeric, boolean, or grouped columns
          renderer: isEnum
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

    return columns;
  }

  List<TrinaColumnGroup> _buildColumnGroups() {
    final groups = <String, List<TrinaColumn>>{};
    final itemSchema = widget.jsonSchema['items'] as Map<String, dynamic>?;
    final properties = itemSchema?['properties'] as Map<String, dynamic>?;

    if (properties == null) return [];

    // Group columns by headerName
    final columnEntries = <MapEntry<String, dynamic>>[];

    properties.forEach((key, value) {
      final propertySchema = value as Map<String, dynamic>;
      final tfm = propertySchema['\$tfm'] as Map<String, dynamic>?;
      final form = tfm?['form'] as Map<String, dynamic>?;
      final uiOptions = form?['ui:options'] as Map<String, dynamic>?;
      final display = uiOptions?['display'] as bool? ?? true;

      if (!display) return;

      final sortBy = form?['sortBy'] as int? ?? 999;
      final groupBy = form?['groupBy'] as Map<String, dynamic>?;
      final headerName = groupBy?['headerName'] as String?;
      final groupSortBy = groupBy?['sortBy'] as int? ?? 999;

      if (headerName != null) {
        columnEntries.add(
          MapEntry(key, {'headerName': headerName, 'sortBy': sortBy, 'groupSortBy': groupSortBy}),
        );
      }
    });

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
        cells[column.field] = TrinaCell(value: rowData[column.field]);
      }

      return TrinaRow(cells: cells);
    }).toList();
  }

  Widget _buildTextCell(TrinaColumnRendererContext rendererContext, String fieldKey) {
    final value = rendererContext.cell.value;
    final rowIndex = rendererContext.rowIdx;
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final bgColor = _getCellBackgroundColor(rowIndex, fieldKey, isDark);

    return Container(
      alignment: Alignment.centerLeft,
      padding: const EdgeInsets.symmetric(horizontal: 8),
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
        displayText = nameDe[index]?.toString() ?? value.toString();
      } else {
        displayText = value.toString();
      }
    } else if (value != null) {
      displayText = value.toString();
    }

    return InkWell(
      onTap: () => _openEnumDialog(rendererContext, propertySchema, fieldKey),
      child: Container(
        alignment: Alignment.centerLeft,
        padding: const EdgeInsets.symmetric(horizontal: 8),
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

    // Check if cell is in edit mode
    final isCurrentCell = rendererContext.stateManager.currentCell?.key == rendererContext.cell.key;

    if (isCurrentCell) {
      // Edit mode: use GenericTextField in compact mode for grid
      return Container(
        color: bgColor,
        child: GenericTextField(
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
      alignment: Alignment.centerRight,
      padding: const EdgeInsets.symmetric(horizontal: 8),
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
      alignment: Alignment.center,
      padding: const EdgeInsets.symmetric(horizontal: 8),
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
    // data is null and should be set to empty array
    _rows.clear();
    _stateManager?.removeAllRows();
    _notifyDataChanged();
  }

  void _addRow() {
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
      cells[column.field] = TrinaCell(value: newRow[column.field]);
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

  void _notifyDataChanged() {
    // Sync _rows from state manager if available (source of truth)
    final rowsToUse = _stateManager?.rows ?? _rows;

    final data = rowsToUse.map((row) {
      final rowData = <String, dynamic>{};
      row.cells.forEach((key, cell) {
        rowData[key] = cell.value;
      });
      return rowData;
    }).toList();

    widget.onDataChanged?.call(data);
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
              onPressed: _addRow,
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

    return Stack(
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
            enterKeyAction: TrinaGridEnterKeyAction.none,
            style: TrinaGridStyleConfig(
              iconSize: 0,
              gridBorderRadius: BorderRadius.zero,
              enableGridBorderShadow: false,
              gridBackgroundColor: isDark ? const Color(0xFF1E1E1E) : Colors.white,
              rowColor: isDark ? const Color(0xFF252526) : Colors.white,
              activatedColor: isDark ? const Color(0xFF094771) : const Color(0xFFDCF2FF),
              cellTextStyle: TextStyle(color: isDark ? Colors.white : Colors.black87, fontSize: 14),
              columnTextStyle: TextStyle(
                color: isDark ? Colors.white : Colors.black87,
                fontSize: 14,
                fontWeight: FontWeight.bold,
              ),
              gridBorderColor: isDark ? const Color(0xFF3E3E42) : Colors.grey.shade300,
              borderColor: isDark ? const Color(0xFF3E3E42) : Colors.grey.shade300,
              activatedBorderColor: isDark ? const Color(0xFF007ACC) : Colors.blue,
              inactivatedBorderColor: isDark ? const Color(0xFF3E3E42) : Colors.grey.shade300,
              iconColor: isDark ? Colors.white70 : Colors.black54,
              disabledIconColor: isDark ? Colors.white24 : Colors.black26,
              menuBackgroundColor: isDark ? const Color(0xFF252526) : Colors.white,
              cellColorInEditState: isDark ? const Color(0xFF1E1E1E) : Colors.white,
              cellColorInReadOnlyState: isDark ? const Color(0xFF2D2D30) : Colors.grey.shade100,
            ),
          ),
        ),
        Positioned(
          bottom: 16,
          right: 16,
          child: FloatingActionButton(onPressed: _addRow, child: const Icon(Icons.add)),
        ),
      ],
    );
  }
}
