import 'package:flutter/material.dart';
import 'package:syncfusion_flutter_datagrid/datagrid.dart';
import 'package:terrestrial_forest_monitor/widgets/speech_to_text_button.dart';
import 'package:terrestrial_forest_monitor/services/validation_service.dart';

class ArrayElementSyncfusion extends StatefulWidget {
  final Map<String, dynamic> jsonSchema;
  final List<dynamic> data;
  final ValidationResult? validationResult;
  final String? propertyName;
  final Function(List<dynamic>)? onDataChanged;

  const ArrayElementSyncfusion({super.key, required this.jsonSchema, required this.data, this.propertyName, this.validationResult, this.onDataChanged});
  @override
  State<ArrayElementSyncfusion> createState() => _ArrayElementSyncfusionState();
}

class _ArrayElementSyncfusionState extends State<ArrayElementSyncfusion> {
  late DataGridSource _dataGridSource;
  late List<GridColumn> _columns;
  late List<Map<String, dynamic>> _rows;

  @override
  void initState() {
    super.initState();
    print('ArrayElementSyncfusion initialized');
    print('jsonSchema: ${widget.jsonSchema}');
    print('data: ${widget.data}');
    print('data length: ${widget.data.length}');
    _initializeGrid();
  }

  @override
  void didUpdateWidget(ArrayElementSyncfusion oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.data != oldWidget.data || widget.jsonSchema != oldWidget.jsonSchema) {
      _initializeGrid();
    }
  }

  void _initializeGrid() {
    _rows = List<Map<String, dynamic>>.from(widget.data.map((item) => Map<String, dynamic>.from(item is Map ? item : {})));
    print('Initialized ${_rows.length} rows');
    _columns = _buildColumns();
    print('Initialized ${_columns.length} columns');

    // Get schema for use in DataSource
    final itemSchema = widget.jsonSchema['items'] as Map<String, dynamic>?;
    final properties = itemSchema?['properties'] as Map<String, dynamic>?;

    _dataGridSource = _ArrayDataSource(rows: _rows, columns: _columns, schema: properties ?? {}, onCellUpdate: _onCellUpdate);
  }

  List<GridColumn> _buildColumns() {
    final columns = <GridColumn>[];

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

    // Create column for each property
    properties.forEach((key, value) {
      final propertySchema = value as Map<String, dynamic>;
      final title = propertySchema['title'] as String? ?? key;

      // Check if field should be displayed
      final tfm = propertySchema['\$tfm'] as Map<String, dynamic>?;
      final form = tfm?['form'] as Map<String, dynamic>?;
      final uiOptions = form?['ui:options'] as Map<String, dynamic>?;
      final display = uiOptions?['display'] as bool? ?? true;

      if (!display) {
        print('Skipping column $key (display: false)');
        return; // Skip this column
      }

      columns.add(GridColumn(columnName: key, label: Container(padding: const EdgeInsets.all(16.0), alignment: Alignment.center, child: Text(title, style: const TextStyle(fontWeight: FontWeight.bold), overflow: TextOverflow.ellipsis))));
    });

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

      _dataGridSource = _ArrayDataSource(rows: _rows, columns: _columns, schema: properties ?? {}, onCellUpdate: _onCellUpdate);
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

        _dataGridSource = _ArrayDataSource(rows: _rows, columns: _columns, schema: properties ?? {}, onCellUpdate: _onCellUpdate);
      });

      widget.onDataChanged?.call(_rows);
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_columns.isEmpty) {
      return const Center(child: Text('No schema properties found'));
    }

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
                child: Stack(
                  children: [
                    SfDataGrid(
                      source: _dataGridSource,
                      columns: _columns,
                      allowEditing: true,
                      allowSorting: false,
                      allowColumnsResizing: true,
                      allowColumnsDragging: true,
                      selectionMode: SelectionMode.single,
                      navigationMode: GridNavigationMode.cell,
                      columnWidthMode: ColumnWidthMode.auto,
                      editingGestureType: EditingGestureType.tap,
                      gridLinesVisibility: GridLinesVisibility.both,
                      headerGridLinesVisibility: GridLinesVisibility.both,
                      horizontalScrollPhysics: const AlwaysScrollableScrollPhysics(),
                      verticalScrollPhysics: const AlwaysScrollableScrollPhysics(),
                      selectionManager: SelectionManagerBase(),
                      rowHeight: 56.0,
                      headerRowHeight: 56.0,
                    ),
                    if (_rows.isEmpty)
                      Positioned.fill(
                        top: 56.0, // Position below header
                        child: Center(
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              const Icon(Icons.table_chart, size: 48, color: Colors.grey),
                              const SizedBox(height: 16),
                              const Text('No data available', style: TextStyle(color: Colors.grey)),
                              const SizedBox(height: 8),
                              ElevatedButton.icon(onPressed: _addRow, icon: const Icon(Icons.add), label: const Text('Add First Row')),
                            ],
                          ),
                        ),
                      ),
                  ],
                ),
              ),
            ),
          ],
        ),
        // Floating Action Button
        Positioned(right: 16, bottom: 16, child: FloatingActionButton(onPressed: _addRow, child: const Icon(Icons.add))),
      ],
    );
  }
}

class _ArrayDataSource extends DataGridSource {
  _ArrayDataSource({required List<Map<String, dynamic>> rows, required List<GridColumn> columns, required Map<String, dynamic> schema, required this.onCellUpdate}) {
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

  void _buildDataGridRows() {
    _dataGridRows =
        _rows.map<DataGridRow>((row) {
          return DataGridRow(
            cells:
                _columns.map<DataGridCell>((column) {
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
      cells:
          row.getCells().map<Widget>((cell) {
            final columnName = _columns.firstWhere((col) => col.columnName == cell.columnName).columnName;
            final columnSchema = _schema[columnName] as Map<String, dynamic>?;

            // Determine alignment based on type
            Alignment alignment = Alignment.centerLeft; // Default for strings
            if (columnSchema != null) {
              final typeValue = columnSchema['type'];
              String? type;
              if (typeValue is String) {
                type = typeValue;
              } else if (typeValue is List) {
                type = typeValue.firstWhere((t) => t != 'null' && t != null, orElse: () => null) as String?;
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
                  final displayText = '$name (${cellValue?.toString() ?? ''})${unit != null ? ' $unit' : ''}';
                  return Container(alignment: alignment, padding: const EdgeInsets.all(8.0), child: Text(displayText, overflow: TextOverflow.ellipsis));
                }
              }
            }

            // Default display for non-enum fields with unit
            final cellValueStr = cell.value?.toString() ?? '';
            final displayText = cellValueStr.isNotEmpty && unit != null ? '$cellValueStr $unit' : cellValueStr;
            return Container(alignment: alignment, padding: const EdgeInsets.all(12.0), child: Text(displayText, overflow: TextOverflow.ellipsis));
          }).toList(),
    );
  }

  @override
  Future<void> onCellSubmit(DataGridRow dataGridRow, RowColumnIndex rowColumnIndex, GridColumn column) async {
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
  Widget? buildEditWidget(DataGridRow dataGridRow, RowColumnIndex rowColumnIndex, GridColumn column, CellSubmit submitCell) {
    final dynamic cellValue = dataGridRow.getCells()[rowColumnIndex.columnIndex].value;
    final columnName = column.columnName;

    // Get schema for this column
    final columnSchema = _schema[columnName] as Map<String, dynamic>?;
    if (columnSchema == null) {
      // Fallback to text field if no schema
      return _buildTextField(dataGridRow, rowColumnIndex, column, submitCell, cellValue);
    }

    // Get type
    final typeValue = columnSchema['type'];
    String? type;
    if (typeValue is String) {
      type = typeValue;
    } else if (typeValue is List) {
      type = typeValue.firstWhere((t) => t != 'null' && t != null, orElse: () => null) as String?;
    }

    // Check if it has enum (dropdown)
    if (columnSchema.containsKey('enum')) {
      return _buildDropdown(dataGridRow, rowColumnIndex, column, submitCell, cellValue, columnSchema);
    }

    // Check if it's boolean (switch)
    if (type == 'boolean') {
      return _buildSwitch(dataGridRow, rowColumnIndex, column, submitCell, cellValue);
    }

    // Default to text field
    return _buildTextField(dataGridRow, rowColumnIndex, column, submitCell, cellValue);
  }

  Widget _buildTextField(DataGridRow dataGridRow, RowColumnIndex rowColumnIndex, GridColumn column, CellSubmit submitCell, dynamic cellValue) {
    final TextEditingController editingController = TextEditingController(text: cellValue?.toString() ?? '');

    // Get column schema to determine field type
    final columnSchema = _schema[column.columnName] as Map<String, dynamic>?;
    final typeValue = columnSchema?['type'];
    String? fieldType;
    if (typeValue is String) {
      fieldType = typeValue;
    } else if (typeValue is List) {
      fieldType = typeValue.firstWhere((t) => t != 'null' && t != null, orElse: () => null) as String?;
    }

    return Container(
      padding: const EdgeInsets.all(8.0),
      alignment: Alignment.centerLeft,
      child: TextField(
        autofocus: true,
        controller: editingController,
        textAlign: TextAlign.left,
        decoration: InputDecoration(
          border: InputBorder.none,
          contentPadding: EdgeInsets.zero,
          suffixIcon: SpeechToTextButton(
            controller: editingController,
            fieldType: fieldType,
            onTextChanged: () {
              final int dataRowIndex = _dataGridRows.indexOf(dataGridRow);
              if (dataRowIndex != -1) {
                dynamic value = editingController.text;
                // Convert to appropriate type
                if (fieldType == 'integer') {
                  value = int.tryParse(editingController.text) ?? editingController.text;
                } else if (fieldType == 'number') {
                  value = double.tryParse(editingController.text) ?? editingController.text;
                }
                _rows[dataRowIndex][column.columnName] = value;
                _buildDataGridRows();
                onCellUpdate(dataRowIndex, column.columnName, value);
              }
            },
          ),
        ),
        onSubmitted: (String value) {
          final int dataRowIndex = _dataGridRows.indexOf(dataGridRow);
          if (dataRowIndex != -1) {
            _rows[dataRowIndex][column.columnName] = value;
            _buildDataGridRows();
            onCellUpdate(dataRowIndex, column.columnName, value);
          }
          submitCell();
        },
      ),
    );
  }

  Widget _buildDropdown(DataGridRow dataGridRow, RowColumnIndex rowColumnIndex, GridColumn column, CellSubmit submitCell, dynamic cellValue, Map<String, dynamic> schema) {
    final enumValues = schema['enum'] as List;
    final tfm = schema['\$tfm'] as Map<String, dynamic>?;
    final namesDe = tfm?['name_de'] as List?;

    // Remove duplicate values while preserving order
    final uniqueValues = <dynamic>[];
    final seen = <dynamic>{};
    for (var value in enumValues) {
      if (!seen.contains(value)) {
        uniqueValues.add(value);
        seen.add(value);
      }
    }

    return Container(
      padding: const EdgeInsets.all(4.0),
      alignment: Alignment.centerLeft,
      child: ConstrainedBox(
        constraints: const BoxConstraints(minWidth: 200),
        child: DropdownButton<dynamic>(
          value: cellValue,
          isExpanded: true,
          underline: const SizedBox(),
          items:
              uniqueValues.map<DropdownMenuItem<dynamic>>((value) {
                final index = enumValues.indexOf(value);
                final label = namesDe != null && index < namesDe.length ? namesDe[index]?.toString() ?? value?.toString() ?? 'null' : value?.toString() ?? 'null';

                return DropdownMenuItem<dynamic>(value: value, child: Text(label, overflow: TextOverflow.ellipsis));
              }).toList(),
          onChanged: (newValue) {
            final int dataRowIndex = _dataGridRows.indexOf(dataGridRow);
            if (dataRowIndex != -1) {
              _rows[dataRowIndex][column.columnName] = newValue;
              _buildDataGridRows();
              onCellUpdate(dataRowIndex, column.columnName, newValue);
            }
            submitCell();
          },
        ),
      ),
    );
  }

  Widget _buildSwitch(DataGridRow dataGridRow, RowColumnIndex rowColumnIndex, GridColumn column, CellSubmit submitCell, dynamic cellValue) {
    final boolValue = cellValue == true || cellValue == 1 || cellValue == 'true';

    return Container(
      padding: const EdgeInsets.all(4.0),
      alignment: Alignment.center,
      child: Switch(
        value: boolValue,
        onChanged: (newValue) {
          final int dataRowIndex = _dataGridRows.indexOf(dataGridRow);
          if (dataRowIndex != -1) {
            _rows[dataRowIndex][column.columnName] = newValue;
            _buildDataGridRows();
            onCellUpdate(dataRowIndex, column.columnName, newValue);
          }
          submitCell();
        },
      ),
    );
  }
}
