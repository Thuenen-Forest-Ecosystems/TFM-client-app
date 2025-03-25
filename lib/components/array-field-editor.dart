import 'package:flutter/material.dart';
import 'package:pluto_grid/pluto_grid.dart';

enum ArrayEditorType { form, grid }

class ArrayFieldEditor extends StatefulWidget {
  final String name;
  final String title;
  final String? description;
  final Map<String, dynamic> schema;
  final List<dynamic> value;
  final bool isRequired;
  final Function(List<dynamic>) onChanged;
  final String? errorText;

  const ArrayFieldEditor({Key? key, required this.name, required this.title, this.description, required this.schema, required this.value, required this.isRequired, required this.onChanged, this.errorText}) : super(key: key);

  @override
  State<ArrayFieldEditor> createState() => _ArrayFieldEditorState();
}

class _ArrayFieldEditorState extends State<ArrayFieldEditor> {
  ArrayEditorType _editorType = ArrayEditorType.form;

  @override
  Widget build(BuildContext context) {
    // Check if array items are objects
    final bool itemsAreObjects = widget.schema['items'] != null && widget.schema['items']['type'] == 'object';

    // Only show toggle if items are objects (grid doesn't make sense for simple arrays)
    final bool showToggle = itemsAreObjects;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [Text('${widget.title}${widget.isRequired ? ' *' : ''}', style: Theme.of(context).textTheme.titleMedium), if (widget.description != null) Text(widget.description!, style: Theme.of(context).textTheme.bodySmall)],
              ),
            ),
            if (showToggle)
              SegmentedButton<ArrayEditorType>(
                segments: const [ButtonSegment(value: ArrayEditorType.form, icon: Icon(Icons.view_list), label: Text('Form')), ButtonSegment(value: ArrayEditorType.grid, icon: Icon(Icons.grid_on), label: Text('Grid'))],
                selected: {_editorType},
                onSelectionChanged: (Set<ArrayEditorType> selection) {
                  setState(() {
                    _editorType = selection.first;
                  });
                },
              ),
          ],
        ),
        const SizedBox(height: 8),
        if (widget.errorText != null) Padding(padding: const EdgeInsets.only(bottom: 8.0), child: Text(widget.errorText!, style: TextStyle(color: Theme.of(context).colorScheme.error))),

        // Show either form or grid based on selected type
        if (_editorType == ArrayEditorType.form || !showToggle) _buildFormEditor() else _buildGridEditor(),
      ],
    );
  }

  Widget _buildFormEditor() {
    // Implementation of your existing form editor for arrays
    // This is similar to your _buildArrayField method
    return _ArrayFormEditor(name: widget.name, schema: widget.schema, value: widget.value, onChanged: widget.onChanged);
  }

  Widget _buildGridEditor() {
    // Grid implementation using PlutoGrid
    return _ArrayGridEditor(name: widget.name, schema: widget.schema, value: widget.value, onChanged: widget.onChanged);
  }
}

class _ArrayFormEditor extends StatelessWidget {
  final String name;
  final Map<String, dynamic> schema;
  final List<dynamic> value;
  final Function(List<dynamic>) onChanged;

  const _ArrayFormEditor({Key? key, required this.name, required this.schema, required this.value, required this.onChanged}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    // Check if array items are objects
    final bool itemsAreObjects = schema['items'] != null && schema['items']['type'] == 'object';

    // Get the item schema for object items
    final Map<String, dynamic>? itemSchema = itemsAreObjects ? _typeSafeMap<String, dynamic>(schema['items']) : null;

    return Column(
      children: [
        ListView.builder(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          itemCount: value.length + 1,
          itemBuilder: (context, index) {
            // Add button at the end of the list
            if (index == value.length) {
              return ElevatedButton.icon(
                icon: const Icon(Icons.add),
                label: const Text('Add Item'),
                onPressed: () {
                  final updatedValues = List<dynamic>.from(value);

                  // Add empty object for object items or empty string for simple items
                  if (itemsAreObjects) {
                    updatedValues.add({});
                  } else {
                    updatedValues.add('');
                  }

                  onChanged(updatedValues);
                },
              );
            }

            // Render existing item - either an object or a simple value
            final itemValue = value[index];

            return Card(
              margin: const EdgeInsets.symmetric(vertical: 8.0),
              child: Padding(
                padding: const EdgeInsets.all(12.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Header row with title and delete button
                    Row(
                      children: [
                        Expanded(child: Text('Item ${index + 1}', style: Theme.of(context).textTheme.titleMedium)),
                        IconButton(
                          icon: const Icon(Icons.delete_outline, color: Colors.red),
                          onPressed: () {
                            final updatedValues = List<dynamic>.from(value);
                            updatedValues.removeAt(index);
                            onChanged(updatedValues);
                          },
                        ),
                      ],
                    ),
                    const Divider(),

                    // Different rendering based on item type
                    if (itemsAreObjects && itemSchema != null) _buildObjectItem(index, itemValue, itemSchema) else _buildSimpleItem(index, itemValue),
                  ],
                ),
              ),
            );
          },
        ),
      ],
    );
  }

  Widget _buildSimpleItem(int index, dynamic itemValue) {
    return TextFormField(
      initialValue: itemValue?.toString() ?? '',
      decoration: const InputDecoration(border: OutlineInputBorder(), labelText: 'Value'),
      onChanged: (newValue) {
        final updatedValues = List<dynamic>.from(value);
        updatedValues[index] = newValue;
        onChanged(updatedValues);
      },
    );
  }

  Widget _buildObjectItem(int index, dynamic itemValue, Map<String, dynamic> itemSchema) {
    // Ensure itemValue is a map
    Map<String, dynamic> objectValue = _typeSafeMap<String, dynamic>(itemValue);

    // Get object properties and requirements
    final properties = _typeSafeMap<String, dynamic>(itemSchema['properties']);
    final required = List<String>.from(itemSchema['required'] ?? []);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children:
          properties.entries.map<Widget>((entry) {
            final propertyName = entry.key;
            final propertySchema = _typeSafeMap<String, dynamic>(entry.value);
            final isPropertyRequired = required.contains(propertyName);
            final propertyType = propertySchema['type'] as String? ?? 'string';
            final propertyTitle = propertySchema['title'] as String? ?? propertyName;

            // Get the current property value
            final propertyValue = objectValue[propertyName];

            return Padding(padding: const EdgeInsets.only(bottom: 12.0), child: _buildObjectProperty(index, propertyName, propertyTitle, propertySchema, propertyType, propertyValue, isPropertyRequired));
          }).toList(),
    );
  }

  Widget _buildObjectProperty(int index, String propertyName, String propertyTitle, Map<String, dynamic> propertySchema, String propertyType, dynamic propertyValue, bool isRequired) {
    // Create appropriate field based on property type
    switch (propertyType) {
      case 'string':
        return TextFormField(
          initialValue: propertyValue?.toString() ?? '',
          decoration: InputDecoration(labelText: '$propertyTitle${isRequired ? ' *' : ''}', border: const OutlineInputBorder()),
          onChanged: (newValue) {
            _updateObjectProperty(index, propertyName, newValue);
          },
        );

      case 'number':
      case 'integer':
        return TextFormField(
          initialValue: propertyValue?.toString() ?? '',
          keyboardType: TextInputType.number,
          decoration: InputDecoration(labelText: '$propertyTitle${isRequired ? ' *' : ''}', border: const OutlineInputBorder()),
          onChanged: (newValue) {
            if (newValue.isNotEmpty) {
              if (propertyType == 'integer') {
                _updateObjectProperty(index, propertyName, int.tryParse(newValue) ?? 0);
              } else {
                _updateObjectProperty(index, propertyName, double.tryParse(newValue) ?? 0.0);
              }
            } else {
              _updateObjectProperty(index, propertyName, null);
            }
          },
        );

      case 'boolean':
        return Row(
          children: [
            Checkbox(
              value: propertyValue == true,
              onChanged: (newValue) {
                _updateObjectProperty(index, propertyName, newValue ?? false);
              },
            ),
            Expanded(child: Text(propertyTitle)),
          ],
        );

      default:
        return Text('Unsupported type: $propertyType');
    }
  }

  void _updateObjectProperty(int index, String propertyName, dynamic propertyValue) {
    // Get the current array
    final updatedValues = List<dynamic>.from(value);

    if (index < updatedValues.length) {
      // Get the object at the specified index
      Map<String, dynamic> itemMap = _typeSafeMap<String, dynamic>(updatedValues[index]);

      // Update the property
      itemMap[propertyName] = propertyValue;

      // Update the array item
      updatedValues[index] = itemMap;

      // Update the entire array
      onChanged(updatedValues);
    }
  }

  Map<K, V> _typeSafeMap<K, V>(dynamic map) {
    if (map == null) return <K, V>{};
    if (map is Map<K, V>) return map;

    final result = <K, V>{};
    if (map is Map) {
      map.forEach((key, value) {
        if (key is K && (value is V || value == null)) {
          result[key] = value;
        }
      });
    }
    return result;
  }
}

class _ArrayGridEditor extends StatefulWidget {
  final String name;
  final Map<String, dynamic> schema;
  final List<dynamic> value;
  final Function(List<dynamic>) onChanged;

  const _ArrayGridEditor({Key? key, required this.name, required this.schema, required this.value, required this.onChanged}) : super(key: key);

  @override
  State<_ArrayGridEditor> createState() => _ArrayGridEditorState();
}

class _ArrayGridEditorState extends State<_ArrayGridEditor> {
  late List<PlutoColumn> columns;
  late List<PlutoRow> rows;
  late PlutoGridStateManager stateManager;

  @override
  void initState() {
    super.initState();
    _setupGridData();
  }

  @override
  void didUpdateWidget(_ArrayGridEditor oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.value != widget.value || oldWidget.schema != widget.schema) {
      _setupGridData();
      if (this.mounted) {
        setState(() {});
      }
    }
  }

  void _setupGridData() {
    // Get the item schema for objects
    final itemSchema = _typeSafeMap<String, dynamic>(widget.schema['items']);
    final properties = _typeSafeMap<String, dynamic>(itemSchema['properties']);

    // Create columns based on object properties
    columns =
        properties.entries.map<PlutoColumn>((entry) {
          final key = entry.key;
          final propSchema = _typeSafeMap<String, dynamic>(entry.value);
          final title = propSchema['title'] as String? ?? key;
          final type = propSchema['type'] as String? ?? 'string';

          // Determine column type based on property type
          PlutoColumnType columnType;
          switch (type) {
            case 'number':
              columnType = PlutoColumnType.number();
              break;
            case 'integer':
              columnType = PlutoColumnType.number(format: '#,###');
              break;
            case 'boolean':
              columnType = PlutoColumnType.select([true, false]);
              break;
            default:
              columnType = PlutoColumnType.text();
          }

          return PlutoColumn(title: title, field: key, type: columnType, enableEditingMode: true);
        }).toList();

    // Create rows from existing data
    rows = [];
    for (var item in widget.value) {
      final Map<String, dynamic> rowItem = _typeSafeMap<String, dynamic>(item);
      final Map<String, PlutoCell> cells = {};

      // Create cells for each property
      for (var prop in properties.keys) {
        final value = rowItem[prop];
        cells[prop] = PlutoCell(value: value);
      }

      rows.add(PlutoRow(cells: cells));
    }
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 400, // Set appropriate height
      decoration: BoxDecoration(border: Border.all(color: Colors.grey.shade300), borderRadius: BorderRadius.circular(4)),
      child: Column(
        children: [
          Expanded(
            child: PlutoGrid(
              columns: columns,
              rows: rows,
              onLoaded: (PlutoGridOnLoadedEvent event) {
                stateManager = event.stateManager;
              },
              onChanged: (PlutoGridOnChangedEvent event) {
                // Update data when grid changes
                _updateDataFromGrid();
              },
              configuration: const PlutoGridConfiguration(columnSize: PlutoGridColumnSizeConfig(autoSizeMode: PlutoAutoSizeMode.scale)),
            ),
          ),
          Padding(
            padding: const EdgeInsets.all(8.0),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                ElevatedButton.icon(
                  icon: const Icon(Icons.add),
                  label: const Text('Add Row'),
                  onPressed: () {
                    final Map<String, PlutoCell> cells = {};
                    for (var column in columns) {
                      cells[column.field] = PlutoCell(value: null);
                    }
                    stateManager.appendRows([PlutoRow(cells: cells)]);
                    _updateDataFromGrid();
                  },
                ),
                const SizedBox(width: 8),
                ElevatedButton.icon(
                  icon: const Icon(Icons.delete),
                  style: ElevatedButton.styleFrom(backgroundColor: Colors.red, foregroundColor: Colors.white),
                  label: const Text('Delete Selected'),
                  onPressed: () {
                    if (stateManager.currentSelectingRows.isNotEmpty) {
                      stateManager.removeRows(stateManager.currentSelectingRows);
                      _updateDataFromGrid();
                    }
                  },
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  void _updateDataFromGrid() {
    final List<dynamic> updatedValues = [];

    // Convert PlutoRows back to object maps
    for (var row in stateManager.rows) {
      final Map<String, dynamic> item = {};

      // Extract cell values
      row.cells.forEach((key, cell) {
        final columnIndex = columns.indexWhere((col) => col.field == key);
        if (columnIndex >= 0) {
          final columnType = columns[columnIndex].type;

          // Convert value based on column type
          if (columnType is PlutoColumnTypeNumber) {
            item[key] =
                cell.value is num
                    ? cell.value
                    : cell.value is String && (cell.value as String).isNotEmpty
                    ? num.tryParse(cell.value.toString()) ?? 0
                    : 0;
          } else {
            item[key] = cell.value;
          }
        }
      });

      updatedValues.add(item);
    }

    // Update parent
    widget.onChanged(updatedValues);
  }

  Map<K, V> _typeSafeMap<K, V>(dynamic map) {
    if (map == null) return <K, V>{};
    if (map is Map<K, V>) return map;

    final result = <K, V>{};
    if (map is Map) {
      map.forEach((key, value) {
        if (key is K && (value is V || value == null)) {
          result[key] = value;
        }
      });
    }
    return result;
  }
}
