import 'package:flutter/material.dart';
import 'package:pluto_grid/pluto_grid.dart';

import 'package:terrestrial_forest_monitor/services/validation_service.dart';
import 'package:terrestrial_forest_monitor/widgets/form-elements/generic-enum-dialog.dart';
import 'package:terrestrial_forest_monitor/widgets/form-elements/generic-textfield.dart';

/// ArrayElementPluto - PlutoGrid-based array data editor widget
///
/// Features:
/// - Schema-driven column generation with sortBy support
/// - Type-aware column rendering (Text, Number, Boolean, Select/Enum)
/// - Automatic type conversion and formatting
/// - Unit display from schema ($tfm.unit_short)
/// - German enum labels support ($tfm.name_de)
/// - Inline editing with proper type handling
/// - Frozen/pinned columns support
/// - Add/delete row operations
/// - FAB for adding new rows
///
/// Similar functionality to ArrayElementTrina but using PlutoGrid library
class ArrayElementPluto extends StatefulWidget {
  final Map<String, dynamic> jsonSchema;
  final List<dynamic>? data;
  final TFMValidationResult? validationResult;
  final String? propertyName;
  final Function(List<dynamic>)? onDataChanged;

  const ArrayElementPluto({
    super.key,
    required this.jsonSchema,
    required this.data,
    this.propertyName,
    this.validationResult,
    this.onDataChanged,
  });

  @override
  State<ArrayElementPluto> createState() => _ArrayElementPlutoState();
}

class _ArrayElementPlutoState extends State<ArrayElementPluto> {
  List<PlutoColumn> _columns = [];
  List<PlutoRow> _rows = [];
  PlutoGridStateManager? _stateManager;
  int _frozenColumnCount = 0;

  @override
  void initState() {
    super.initState();
    debugPrint('Initializing ArrayElementPluto for property: ${widget.propertyName}');
    debugPrint('Initial data: ${widget.data}');
    _initializeGrid();
  }

  @override
  void didUpdateWidget(ArrayElementPluto oldWidget) {
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
  Color _getCellBackgroundColor(int rowIndex, String fieldKey, bool isDark) {
    if (_hasValidationError(rowIndex, fieldKey)) {
      return isDark ? const Color(0xFF5A1F1F) : const Color(0xFFFFCDD2); // Light red
    }
    return isDark ? const Color(0xFF252526) : Colors.white;
  }

  List<PlutoColumn> _buildColumns() {
    final columns = <PlutoColumn>[];
    final itemSchema = widget.jsonSchema['items'] as Map<String, dynamic>?;

    if (itemSchema == null) {
      debugPrint('No items found in schema');
      return columns;
    }

    final properties = itemSchema['properties'] as Map<String, dynamic>?;
    if (properties == null) {
      debugPrint('No properties found in items schema');
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
      final pinned = uiOptions?['pinned'] as String?;

      columnEntries.add(
        MapEntry(key, {'schema': propertySchema, 'sortBy': sortBy, 'pinned': pinned}),
      );
    });

    // Sort columns by sortBy value
    columnEntries.sort((a, b) => a.value['sortBy'].compareTo(b.value['sortBy']));

    // Count frozen columns (pinned left)
    _frozenColumnCount = 0;

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
      PlutoColumnType columnType;
      bool isEnum = false;
      bool isBoolean = false;

      if (propertySchema.containsKey('enum')) {
        columnType = PlutoColumnType.text();
        isEnum = true;
      } else if (type == 'boolean') {
        columnType = PlutoColumnType.text();
        isBoolean = true;
      } else if (type == 'integer' || type == 'number') {
        columnType = PlutoColumnType.number(
          format: type == 'number' ? '#,###.##' : '#,###',
          negative: true,
          applyFormatOnInit: false,
        );
      } else {
        columnType = PlutoColumnType.text();
      }

      final pinnedValue = entry.value['pinned'] as String?;

      // Check if field is readonly
      final isReadOnly = propertySchema['readonly'] as bool? ?? false;

      // Determine frozen position from pinned value
      PlutoColumnFrozen frozen = PlutoColumnFrozen.none;
      if (pinnedValue == 'left') {
        frozen = PlutoColumnFrozen.start;
        _frozenColumnCount++;
      } else if (pinnedValue == 'right') {
        frozen = PlutoColumnFrozen.end;
      }

      final isDark = Theme.of(context).brightness == Brightness.dark;

      columns.add(
        PlutoColumn(
          title: unit != null ? '$title ($unit)' : title,
          field: key,
          type: columnType,
          width: 150,
          frozen: frozen,
          enableSorting: false,
          enableColumnDrag: false,
          enableContextMenu: false,
          enableDropToResize: true,
          readOnly: isReadOnly,
          backgroundColor: isDark ? const Color(0xFF1E1E1E) : Colors.white,
          renderer: isEnum
              ? (rendererContext) => _buildEnumCell(rendererContext, propertySchema, key)
              : isBoolean
              ? (rendererContext) => _buildBooleanCell(rendererContext, key)
              : null,
        ),
      );
    }

    debugPrint('Total frozen columns: $_frozenColumnCount');

    return columns;
  }

  List<PlutoRow> _buildRows() {
    if (widget.data == null) return [];

    return widget.data!.asMap().entries.map((entry) {
      final index = entry.key;
      final item = entry.value;
      final rowData = Map<String, dynamic>.from(item is Map ? item : {});
      final cells = <String, PlutoCell>{};

      final isDark = Theme.of(context).brightness == Brightness.dark;

      for (final column in _columns) {
        final fieldKey = column.field;
        final value = rowData[fieldKey];
        final bgColor = _getCellBackgroundColor(index, fieldKey, isDark);

        cells[fieldKey] = PlutoCell(value: value)
          ..setRow(PlutoRow(cells: {})); // Temporary row reference
      }

      return PlutoRow(cells: cells);
    }).toList();
  }

  Widget _buildEnumCell(
    PlutoColumnRendererContext rendererContext,
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
        child: Text(
          displayText,
          overflow: TextOverflow.ellipsis,
          maxLines: 1,
          style: TextStyle(color: isDark ? Colors.white : Colors.black87),
        ),
      ),
    );
  }

  Widget _buildBooleanCell(PlutoColumnRendererContext rendererContext, String fieldKey) {
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
    PlutoColumnRendererContext rendererContext,
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
        final existingValues =
            _stateManager?.rows
                .map((row) => row.cells[key]?.value)
                .where((v) => v != null && v is num)
                .map((v) => (v as num).toInt())
                .toList() ??
            [];

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

    final cells = <String, PlutoCell>{};
    for (final column in _columns) {
      cells[column.field] = PlutoCell(value: newRow[column.field]);
    }

    final newPlutoRow = PlutoRow(cells: cells);

    if (_stateManager != null) {
      _stateManager!.appendRows([newPlutoRow]);
      _notifyDataChanged();
    } else {
      // If grid not loaded yet (empty state), add to rows list
      _rows.add(newPlutoRow);
      _notifyDataChanged();
      // Trigger rebuild to show the grid
      setState(() {});
    }
  }

  void _notifyDataChanged() {
    // Get rows from state manager if available (source of truth)
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
        PlutoGrid(
          columns: _columns,
          rows: _rows,
          onLoaded: (PlutoGridOnLoadedEvent event) {
            _stateManager = event.stateManager;

            // Set frozen columns
            if (_frozenColumnCount > 0) {
              _stateManager!.setLayout(PlutoGridLayoutType.normal);
            }
          },
          onChanged: (PlutoGridOnChangedEvent event) {
            _notifyDataChanged();
          },
          configuration: PlutoGridConfiguration(
            style: PlutoGridStyleConfig(
              gridBackgroundColor: isDark ? const Color(0xFF1E1E1E) : Colors.white,
              rowColor: isDark ? const Color(0xFF252526) : Colors.white,
              oddRowColor: isDark ? const Color(0xFF2D2D30) : Colors.grey.shade50,
              activatedColor: isDark ? const Color(0xFF094771) : const Color(0xFFDCF2FF),
              checkedColor: isDark ? const Color(0xFF094771) : const Color(0xFFDCF2FF),
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
              gridBorderRadius: BorderRadius.zero,
              enableGridBorderShadow: false,
              enableColumnBorderVertical: true,
              enableColumnBorderHorizontal: true,
              enableCellBorderVertical: true,
              enableCellBorderHorizontal: true,
              columnHeight: 56,
              rowHeight: 56,
            ),
            columnSize: const PlutoGridColumnSizeConfig(
              autoSizeMode: PlutoAutoSizeMode.none,
              resizeMode: PlutoResizeMode.normal,
            ),
            enterKeyAction: PlutoGridEnterKeyAction.moveDown,
            enableMoveDownAfterSelecting: true,
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
