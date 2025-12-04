import 'package:flutter/material.dart';
import 'package:syncfusion_flutter_datagrid/datagrid.dart';
import 'package:syncfusion_flutter_core/theme.dart';
import 'package:terrestrial_forest_monitor/services/validation_service.dart';
import 'package:terrestrial_forest_monitor/widgets/form-elements/generic-textfield.dart';

class ArrayElementSyncfusion extends StatefulWidget {
  final Map<String, dynamic> jsonSchema;
  final List<dynamic> data;
  final TFMValidationResult? validationResult;
  final String? propertyName;
  final Function(List<dynamic>)? onDataChanged;

  const ArrayElementSyncfusion({
    super.key,
    required this.jsonSchema,
    required this.data,
    this.propertyName,
    this.validationResult,
    this.onDataChanged,
  });
  @override
  State<ArrayElementSyncfusion> createState() => _ArrayElementSyncfusionState();
}

class _ArrayElementSyncfusionState extends State<ArrayElementSyncfusion> {
  late DataGridSource _dataGridSource;
  late List<GridColumn> _columns;
  late List<Map<String, dynamic>> _rows;
  final DataGridController _dataGridController = DataGridController();
  int _frozenColumnsCount = 0;
  Map<String, double> _columnWidths = {};

  @override
  void initState() {
    super.initState();
    _initializeGrid();
  }

  @override
  void didUpdateWidget(ArrayElementSyncfusion oldWidget) {
    super.didUpdateWidget(oldWidget);
    // Only reinitialize if schema changes
    // Don't reinitialize on data changes during validation as this resets user edits
    if (widget.jsonSchema != oldWidget.jsonSchema) {
      _initializeGrid();
    }
  }

  void _initializeGrid() {
    _rows = List<Map<String, dynamic>>.from(
      widget.data.map((item) => Map<String, dynamic>.from(item is Map ? item : {})),
    );
    print('Initialized ${_rows.length} rows');
    _columns = _buildColumns();
    print('Initialized ${_columns.length} columns');

    // Get schema for use in DataSource
    final itemSchema = widget.jsonSchema['items'] as Map<String, dynamic>?;
    final properties = itemSchema?['properties'] as Map<String, dynamic>?;

    _dataGridSource = _ArrayDataSource(
      rows: _rows,
      columns: _columns,
      schema: properties ?? {},
      onCellUpdate: _onCellUpdate,
      context: context,
    );
  }

  List<GridColumn> _buildColumns() {
    final columns = <GridColumn>[];
    int frozenColumnsCount = 0;

    // The schema IS the array schema, so items is at the root level
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

    print('Found ${properties.length} properties in schema');

    // Separate pinned and unpinned columns
    final pinnedColumns = <MapEntry<String, dynamic>>[];
    final unpinnedColumns = <MapEntry<String, dynamic>>[];

    properties.forEach((key, value) {
      final propertySchema = value as Map<String, dynamic>;

      // Check if field should be displayed
      final tfm = propertySchema['\$tfm'] as Map<String, dynamic>?;
      final form = tfm?['form'] as Map<String, dynamic>?;
      final uiOptions = form?['ui:options'] as Map<String, dynamic>?;
      final display = uiOptions?['display'] as bool? ?? true;

      if (!display) {
        print('Skipping column $key (display: false)');
        return; // Skip this column
      }

      // Check for pinned attribute
      final pinned = uiOptions?['pinned'] as String?;
      if (pinned == 'left') {
        pinnedColumns.add(MapEntry(key, propertySchema));
      } else {
        unpinnedColumns.add(MapEntry(key, propertySchema));
      }
    });

    // Add pinned columns first
    for (var entry in pinnedColumns) {
      final key = entry.key;
      final propertySchema = entry.value as Map<String, dynamic>;
      final title = propertySchema['title'] as String? ?? key;

      // Determine alignment based on type
      final typeValue = propertySchema['type'];
      String? type;
      if (typeValue is String) {
        type = typeValue;
      } else if (typeValue is List) {
        type = typeValue.firstWhere((t) => t != 'null' && t != null, orElse: () => null) as String?;
      }

      Alignment headerAlignment = Alignment.centerLeft; // Default for text/enum
      if (type == 'integer' || type == 'number') {
        headerAlignment = Alignment.centerRight;
      } else if (type == 'boolean') {
        headerAlignment = Alignment.center;
      }

      columns.add(
        GridColumn(
          columnName: key,
          width: _columnWidths[key] ?? double.nan,
          label: Container(
            padding: const EdgeInsets.all(16.0),
            alignment: headerAlignment,
            child: Text(
              title,
              style: const TextStyle(fontWeight: FontWeight.bold),
              overflow: TextOverflow.ellipsis,
            ),
          ),
        ),
      );
      _columnWidths[key] ??= double.nan;
      frozenColumnsCount++;
    }

    // Add unpinned columns
    for (var entry in unpinnedColumns) {
      final key = entry.key;
      final propertySchema = entry.value as Map<String, dynamic>;
      final title = propertySchema['title'] as String? ?? key;

      // Determine alignment based on type
      final typeValue = propertySchema['type'];
      String? type;
      if (typeValue is String) {
        type = typeValue;
      } else if (typeValue is List) {
        type = typeValue.firstWhere((t) => t != 'null' && t != null, orElse: () => null) as String?;
      }

      Alignment headerAlignment = Alignment.centerLeft; // Default for text/enum
      if (type == 'integer' || type == 'number') {
        headerAlignment = Alignment.centerRight;
      } else if (type == 'boolean') {
        headerAlignment = Alignment.center;
      }

      columns.add(
        GridColumn(
          columnName: key,
          width: _columnWidths[key] ?? double.nan,
          label: Container(
            padding: const EdgeInsets.all(16.0),
            alignment: headerAlignment,
            child: Text(
              title,
              style: const TextStyle(fontWeight: FontWeight.bold),
              overflow: TextOverflow.ellipsis,
            ),
          ),
        ),
      );
      _columnWidths[key] ??= double.nan;
    }

    // Store frozen columns count for use in DataGrid
    _frozenColumnsCount = frozenColumnsCount;

    return columns;
  }

  void _onCellUpdate(int rowIndex, String columnName, dynamic newValue) {
    setState(() {
      if (rowIndex < _rows.length) {
        _rows[rowIndex][columnName] = newValue;
      }
    });

    // Notify parent of changes
    widget.onDataChanged?.call(_rows);
  }

  void _addRow() {
    final newRow = <String, dynamic>{};

    // Initialize with default values from schema
    final itemSchema = widget.jsonSchema['items'] as Map<String, dynamic>?;
    final properties = itemSchema?['properties'] as Map<String, dynamic>?;

    properties?.forEach((key, value) {
      final propertySchema = value as Map<String, dynamic>;
      final typeValue = propertySchema['type'];

      // Handle type as either String or List<dynamic>
      String? type;
      if (typeValue is String) {
        type = typeValue;
      } else if (typeValue is List) {
        // Get the first non-null type from the list
        type = typeValue.firstWhere((t) => t != 'null' && t != null, orElse: () => null) as String?;
      }

      // Check for autoIncrement
      final tfm = propertySchema['\$tfm'] as Map<String, dynamic>?;
      final form = tfm?['form'] as Map<String, dynamic>?;
      final autoIncrement = form?['autoIncrement'] as bool? ?? false;

      if (autoIncrement && (type == 'integer' || type == 'number')) {
        // Find max value in existing rows and increment
        int maxValue = 0;
        for (var row in _rows) {
          final value = row[key];
          if (value is int && value > maxValue) {
            maxValue = value;
          } else if (value is double && value.toInt() > maxValue) {
            maxValue = value.toInt();
          }
        }
        newRow[key] = maxValue + 1;
        return;
      }

      // set default value from schema if available
      if (propertySchema.containsKey('default')) {
        newRow[key] = propertySchema['default'];
        return;
      }

      // Set default values based on type
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
    });

    setState(() {
      _rows.add(newRow);

      // Get schema for DataSource
      final itemSchema = widget.jsonSchema['items'] as Map<String, dynamic>?;
      final properties = itemSchema?['properties'] as Map<String, dynamic>?;

      _dataGridSource = _ArrayDataSource(
        rows: _rows,
        columns: _columns,
        schema: properties ?? {},
        onCellUpdate: _onCellUpdate,
        context: context,
      );
    });
    widget.onDataChanged?.call(_rows);
  }

  void _deleteRow(int index) {
    if (index >= 0 && index < _rows.length) {
      setState(() {
        _rows.removeAt(index);

        // Get schema for DataSource
        final itemSchema = widget.jsonSchema['items'] as Map<String, dynamic>?;
        final properties = itemSchema?['properties'] as Map<String, dynamic>?;

        _dataGridSource = _ArrayDataSource(
          rows: _rows,
          columns: _columns,
          schema: properties ?? {},
          onCellUpdate: _onCellUpdate,
          context: context,
        );
      });

      widget.onDataChanged?.call(_rows);
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_columns.isEmpty) {
      return const Center(child: Text('No schema properties found'));
    }

    // Check orientation - only freeze columns in landscape
    final isLandscape = MediaQuery.of(context).orientation == Orientation.landscape;
    final frozenColumns = isLandscape ? _frozenColumnsCount : 0;

    return Stack(
      children: [
        Column(
          children: [
            // DataGrid
            Expanded(
              child: Theme(
                data: Theme.of(context).copyWith(
                  // Disable background color when editing
                  colorScheme: Theme.of(context).colorScheme.copyWith(primary: Colors.transparent),
                  dividerColor: Colors.grey.withAlpha((0.2 * 255).toInt()),
                ),
                child: SfDataGridTheme(
                  data: SfDataGridThemeData(
                    selectionColor: Colors.blue.withOpacity(0.1),
                    currentCellStyle: DataGridCurrentCellStyle(
                      borderColor: Colors.blue,
                      borderWidth: 2,
                    ),
                  ),
                  child: Stack(
                    children: [
                      SfDataGrid(
                        source: _dataGridSource,
                        controller: _dataGridController,
                        columns: _columns,
                        frozenColumnsCount: frozenColumns,
                        allowEditing: true,
                        allowSorting: false,
                        allowColumnsResizing: true,
                        columnResizeMode: ColumnResizeMode.onResize,
                        onColumnResizeUpdate: (ColumnResizeUpdateDetails details) {
                          setState(() {
                            _columnWidths[details.column.columnName] = details.width;
                          });
                          return true;
                        },
                        allowColumnsDragging: false,
                        selectionMode: SelectionMode.single,
                        navigationMode: GridNavigationMode.cell,
                        columnWidthMode: ColumnWidthMode.auto,
                        editingGestureType: EditingGestureType.tap,
                        gridLinesVisibility: GridLinesVisibility.both,
                        headerGridLinesVisibility: GridLinesVisibility.both,
                        horizontalScrollPhysics: const AlwaysScrollableScrollPhysics(),
                        verticalScrollPhysics: const AlwaysScrollableScrollPhysics(),
                        rowHeight: 56.0,
                        headerRowHeight: 56.0,
                      ),
                      if (_rows.isEmpty)
                        Positioned.fill(
                          top: 56.0, // Position below header
                          child: Center(
                            child: SingleChildScrollView(
                              child: Padding(
                                padding: const EdgeInsets.all(16.0),
                                child: Column(
                                  mainAxisSize: MainAxisSize.min,
                                  mainAxisAlignment: MainAxisAlignment.center,
                                  children: [
                                    const Icon(Icons.table_chart, size: 48, color: Colors.grey),
                                    const SizedBox(height: 16),
                                    const Text(
                                      'No data available',
                                      style: TextStyle(color: Colors.grey),
                                    ),
                                    const SizedBox(height: 8),
                                    ElevatedButton.icon(
                                      onPressed: _addRow,
                                      icon: const Icon(Icons.add),
                                      label: const Text('Add First Row'),
                                    ),
                                  ],
                                ),
                              ),
                            ),
                          ),
                        ),
                    ],
                  ),
                ),
              ),
            ),
          ],
        ),
      ],
    );
  }
}

class _ArrayDataSource extends DataGridSource {
  _ArrayDataSource({
    required List<Map<String, dynamic>> rows,
    required List<GridColumn> columns,
    required Map<String, dynamic> schema,
    required this.onCellUpdate,
    required this.context,
  }) {
    _rows = rows;
    _columns = columns;
    _schema = schema;
    _buildDataGridRows();
  }

  List<Map<String, dynamic>> _rows = [];
  List<GridColumn> _columns = [];
  List<DataGridRow> _dataGridRows = [];
  Map<String, dynamic> _schema = {};
  final Function(int rowIndex, String columnName, dynamic newValue) onCellUpdate;
  final BuildContext context;

  void _buildDataGridRows() {
    _dataGridRows = _rows.map<DataGridRow>((row) {
      return DataGridRow(
        cells: _columns.map<DataGridCell>((column) {
          final columnName = column.columnName;
          return DataGridCell<dynamic>(columnName: columnName, value: row[columnName]);
        }).toList(),
      );
    }).toList();
  }

  @override
  List<DataGridRow> get rows => _dataGridRows;

  @override
  DataGridRowAdapter buildRow(DataGridRow row) {
    return DataGridRowAdapter(
      cells: row.getCells().map<Widget>((cell) {
        final columnName = _columns
            .firstWhere((col) => col.columnName == cell.columnName)
            .columnName;
        final columnSchema = _schema[columnName] as Map<String, dynamic>?;

        // Determine alignment based on type
        Alignment alignment = Alignment.centerLeft; // Default for strings
        if (columnSchema != null) {
          final typeValue = columnSchema['type'];
          String? type;
          if (typeValue is String) {
            type = typeValue;
          } else if (typeValue is List) {
            type =
                typeValue.firstWhere((t) => t != 'null' && t != null, orElse: () => null)
                    as String?;
          }

          // Set alignment based on type
          if (type == 'integer' || type == 'number') {
            alignment = Alignment.centerRight;
          } else if (type == 'boolean') {
            alignment = Alignment.center;
          }
        }

        // Get unit from $tfm.unit_short
        String? unit;
        if (columnSchema != null) {
          final tfm = columnSchema['\$tfm'] as Map<String, dynamic>?;
          unit = tfm?['unit_short'] as String?;
        }

        // Check if this column has enum values
        if (columnSchema != null && columnSchema.containsKey('enum')) {
          final enumValues = columnSchema['enum'] as List;
          final tfm = columnSchema['\$tfm'] as Map<String, dynamic>?;
          final namesDe = tfm?['name_de'] as List?;
          final cellValue = cell.value;

          if (namesDe != null && enumValues.contains(cellValue)) {
            final index = enumValues.indexOf(cellValue);
            if (index >= 0 && index < namesDe.length) {
              final name = namesDe[index]?.toString() ?? cellValue?.toString() ?? '';
              final displayText =
                  '${cellValue?.toString() ?? ''} | $name ${unit != null ? ' $unit' : ''}';
              return Container(
                alignment: alignment,
                padding: const EdgeInsets.all(8.0),
                child: Text(displayText, overflow: TextOverflow.ellipsis),
              );
            }
          }
        }

        // Default display for non-enum fields with unit
        final cellValueStr = cell.value?.toString() ?? '';
        final displayText = cellValueStr.isNotEmpty && unit != null
            ? '$cellValueStr $unit'
            : cellValueStr;
        return Container(
          alignment: alignment,
          padding: const EdgeInsets.all(12.0),
          child: Text(displayText, overflow: TextOverflow.ellipsis),
        );
      }).toList(),
    );
  }

  @override
  Future<void> onCellSubmit(
    DataGridRow dataGridRow,
    RowColumnIndex rowColumnIndex,
    GridColumn column,
  ) async {
    final dynamic oldValue = dataGridRow.getCells()[rowColumnIndex.columnIndex].value;
    final int dataRowIndex = _dataGridRows.indexOf(dataGridRow);

    if (dataRowIndex != -1) {
      // Get the new value from the editing controller
      final dynamic newValue = oldValue; // This will be updated by handleCellUpdate

      // Update the data source
      _rows[dataRowIndex][column.columnName] = newValue;

      // Rebuild rows
      _buildDataGridRows();

      // Notify parent
      onCellUpdate(dataRowIndex, column.columnName, newValue);
    }

    await super.onCellSubmit(dataGridRow, rowColumnIndex, column);
  }

  @override
  Widget? buildEditWidget(
    DataGridRow dataGridRow,
    RowColumnIndex rowColumnIndex,
    GridColumn column,
    CellSubmit submitCell,
  ) {
    final dynamic cellValue = dataGridRow.getCells()[rowColumnIndex.columnIndex].value;
    final columnName = column.columnName;

    // Get schema for this column
    final columnSchema = _schema[columnName] as Map<String, dynamic>?;
    if (columnSchema == null) {
      // Fallback if no schema
      return null;
    }

    // Check if field is readonly (JSON Schema standard property)
    final isReadonly = columnSchema['readOnly'] as bool? ?? false;

    // If readonly, don't allow editing
    if (isReadonly) {
      return null;
    }

    // Use GenericTextField for editing
    return _buildGenericTextField(
      dataGridRow,
      rowColumnIndex,
      column,
      submitCell,
      cellValue,
      columnSchema,
    );
  }

  Widget _buildGenericTextField(
    DataGridRow dataGridRow,
    RowColumnIndex rowColumnIndex,
    GridColumn column,
    CellSubmit submitCell,
    dynamic cellValue,
    Map<String, dynamic> columnSchema,
  ) {
    final int dataRowIndex = _dataGridRows.indexOf(dataGridRow);
    if (dataRowIndex == -1) return Container();

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8.0, vertical: 4.0),
      child: GenericTextField(
        fieldName: column.columnName,
        fieldSchema: columnSchema,
        value: cellValue,
        errors: const [], // Grid doesn't show validation errors inline
        compact: true,
        onChanged: (newValue) {
          _rows[dataRowIndex][column.columnName] = newValue;
          _buildDataGridRows();
          onCellUpdate(dataRowIndex, column.columnName, newValue);
          // Auto-submit after change
          Future.microtask(() => submitCell());
        },
      ),
    );
  }
}
