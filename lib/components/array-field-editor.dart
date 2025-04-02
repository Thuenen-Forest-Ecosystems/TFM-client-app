import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:json_schema/json_schema.dart';
import 'package:pluto_grid/pluto_grid.dart';
import 'dart:math' show min, max;

enum ArrayEditorType { form, grid }

class ArrayFieldEditor extends StatefulWidget {
  final String name;
  final String title;
  final String? description;
  final Map<String, dynamic> schema;
  final List<dynamic> value;
  final bool isRequired;
  final Function(List) onChanged;
  final String? errorText;
  final List<ValidationError> validationErrors;
  final Map<String, dynamic>? formData;

  const ArrayFieldEditor({
    Key? key,
    required this.name,
    this.formData,
    required this.validationErrors,
    required this.title,
    this.description,
    required this.schema,
    required this.value,
    required this.isRequired,
    required this.onChanged,
    this.errorText,
  }) : super(key: key);

  @override
  State<ArrayFieldEditor> createState() => _ArrayFieldEditorState();
}

class _ArrayFieldEditorState extends State<ArrayFieldEditor> {
  ArrayEditorType _editorType = ArrayEditorType.grid;

  @override
  Widget build(BuildContext context) {
    if (_editorType == ArrayEditorType.form) {
      return Expanded(child: Row(children: [Expanded(child: SingleChildScrollView(child: _buildFormEditor())), ConstrainedBox(constraints: BoxConstraints(maxWidth: 50), child: _configNavigation())]));
    } else {
      return Expanded(child: Row(children: [Expanded(child: _buildGridEditor()), ConstrainedBox(constraints: BoxConstraints(maxWidth: 50), child: _configNavigation())]));
    }
  }

  void _addRowToValues() {
    Map<String, dynamic> newRow = {};
    // Add default values based on schema if needed

    Map properties = widget.schema['items']['properties'];

    for (var key in properties.keys) {
      if (properties[key]['type'] == 'string') {
        newRow[key] = '';
      } else if (properties[key]['type'] == 'number') {
        newRow[key] = 0;
      } else if (properties[key]['type'] == 'boolean') {
        newRow[key] = false;
      } else {
        newRow[key] = null;
      }
    }
    widget.value.add(newRow);
    widget.onChanged(widget.value);
    /*if (this.mounted) {
      setState(() {});
    }*/
  }

  Widget _configNavigation() {
    return Column(
      mainAxisAlignment: MainAxisAlignment.end,
      children: [
        IconButton(
          icon: Icon(Icons.add),
          onPressed: () {
            _addRowToValues();
          },
        ),
        IconButton(
          icon: Icon(_editorType == ArrayEditorType.form ? Icons.view_list : Icons.grid_on),
          onPressed: () {
            setState(() {
              _editorType = _editorType == ArrayEditorType.form ? ArrayEditorType.grid : ArrayEditorType.form;
            });
          },
        ),
      ],
    );
  }

  void _onChanged(List newValue) {
    if (widget.formData != null && widget.formData!.containsKey(widget.name)) {
      widget.formData![widget.name] = newValue;
      widget.onChanged(newValue);
    }
  }

  Widget _buildFormEditor() {
    // Implementation of your existing form editor for arrays
    // This is similar to your _buildArrayField method
    return _ArrayFormEditor(name: widget.name, schema: widget.schema, value: widget.value, onChanged: _onChanged);
  }

  Widget _buildGridEditor() {
    // Grid implementation using PlutoGrid
    return _ArrayGridEditor(name: widget.name, schema: widget.schema, value: widget.value, onChanged: _onChanged, validationErrors: widget.validationErrors);
  }
}

class _ArrayFormEditor extends StatefulWidget {
  final String name;
  final Map<String, dynamic> schema;
  final List<dynamic> value;
  final Function(List<dynamic>) onChanged;

  const _ArrayFormEditor({Key? key, required this.name, required this.schema, required this.value, required this.onChanged}) : super(key: key);

  @override
  State<_ArrayFormEditor> createState() => _ArrayFormEditorState();
}

class _ArrayFormEditorState extends State<_ArrayFormEditor> {
  @override
  Widget build(BuildContext context) {
    // Check if array items are objects
    final bool itemsAreObjects = widget.schema['items'] != null && widget.schema['items']['type'] == 'object';

    // Get the item schema for object items
    final Map<String, dynamic>? itemSchema = itemsAreObjects ? _typeSafeMap<String, dynamic>(widget.schema['items']) : null;

    return Column(
      children: [
        // Replace ListView.builder with Column + List generation
        Column(
          children: [
            // Add button
            ElevatedButton.icon(
              icon: const Icon(Icons.add),
              label: const Text('Add Item'),
              onPressed: () {
                final updatedValues = List<dynamic>.from(widget.value);

                // Add empty object for object items or empty string for simple items
                if (itemsAreObjects) {
                  updatedValues.add({});
                } else {
                  updatedValues.add('');
                }

                widget.onChanged(updatedValues);
              },
            ),
            // Build all existing items
            ...List.generate(widget.value.length, (index) {
              // Render existing item - either an object or a simple value
              final itemValue = widget.value[index];

              return Card(
                key: ValueKey('array-item-$index'), // Add key for stable identity
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
                              final updatedValues = List<dynamic>.from(widget.value);
                              updatedValues.removeAt(index);
                              widget.onChanged(updatedValues);
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
            }),
          ],
        ),
      ],
    );
  }

  Widget _buildSimpleItem(int index, dynamic itemValue) {
    return TextFormField(
      initialValue: itemValue?.toString() ?? '',
      decoration: const InputDecoration(border: OutlineInputBorder(), labelText: 'Value'),
      onChanged: (newValue) {
        final updatedValues = List<dynamic>.from(widget.value);
        updatedValues[index] = newValue;
        widget.onChanged(updatedValues);
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
            final propertyType = _getEffectiveType(propertySchema['type']);
            final propertyTitle = propertySchema['title'] as String? ?? propertyName;

            // Get the current property value
            final propertyValue = objectValue[propertyName];

            return Padding(padding: const EdgeInsets.only(bottom: 12.0), child: _buildObjectProperty(index, propertyName, propertyTitle, propertySchema, propertyType, propertyValue, isPropertyRequired));
          }).toList(),
    );
  }

  Widget _buildObjectProperty(int index, String propertyName, String propertyTitle, Map<String, dynamic> propertySchema, String propertyType, dynamic propertyValue, bool isRequired) {
    // Create appropriate field based on property type
    final effectiveType = _getEffectiveType(propertyType);

    switch (effectiveType) {
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
    final updatedValues = List<dynamic>.from(widget.value);

    if (index < updatedValues.length) {
      // Get the object at the specified index
      Map<String, dynamic> itemMap = _typeSafeMap<String, dynamic>(updatedValues[index]);

      // Update the property
      itemMap[propertyName] = propertyValue;

      // Update the array item
      updatedValues[index] = itemMap;

      // Update the entire array
      widget.onChanged(updatedValues);
    }
  }

  void _addItem() {
    final updatedValues = List<dynamic>.from(widget.value);

    // Add empty object for object items or empty string for simple items
    final bool itemsAreObjects = widget.schema['items'] != null && widget.schema['items']['type'] == 'object';
    if (itemsAreObjects) {
      updatedValues.add({});
    } else {
      updatedValues.add('');
    }

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

  String _getEffectiveType(dynamic type) {
    if (type == null) return 'string';
    if (type is String) return type;
    if (type is List && type.isNotEmpty) return type[0].toString();
    return 'string';
  }
}

class _ArrayGridEditor extends StatefulWidget {
  final String name;
  final Map<String, dynamic> schema;
  final List<dynamic> value;
  final Function(List<dynamic>) onChanged;
  final List<ValidationError> validationErrors;

  const _ArrayGridEditor({Key? key, required this.name, required this.schema, required this.value, required this.onChanged, required this.validationErrors}) : super(key: key);

  @override
  State<_ArrayGridEditor> createState() => _ArrayGridEditorState();
}

class _ArrayGridEditorState extends State<_ArrayGridEditor> {
  late List<PlutoColumn> columns;
  late List<PlutoRow> rows;
  late PlutoGridStateManager stateManager;
  final PlutoGridConfiguration configurationLight = PlutoGridConfiguration();
  final PlutoGridConfiguration configurationDark = PlutoGridConfiguration.dark();

  @override
  void initState() {
    super.initState();
    _setupGridData();
  }

  @override
  void didUpdateWidget(_ArrayGridEditor oldWidget) {
    super.didUpdateWidget(oldWidget);

    //if (oldWidget.value != widget.value || oldWidget.schema != widget.schema) {

    _setupGridData();
    stateManager.removeAllRows();
    stateManager.appendRows(rows);
    //stateManager.notifyListeners();

    if (this.mounted) {
      setState(() {});
    }
    //}
  }

  void _setupGridData() {
    // Get the item schema for objects
    final itemSchema = _typeSafeMap<String, dynamic>(widget.schema['items']);
    final properties = _typeSafeMap<String, dynamic>(itemSchema['properties']);

    // Safety check - ensure we have properties before proceeding
    if (properties.isEmpty) {
      columns = [];
      rows = [];
      return;
    }

    // Create columns based on object properties
    columns =
        properties.entries.map<PlutoColumn>((entry) {
          final key = entry.key;
          final propSchema = _typeSafeMap<String, dynamic>(entry.value);
          final title = propSchema['title'] as String? ?? key;
          final type = _getEffectiveType(propSchema['type']);

          if (propSchema['enum'] != null) {
            List enumColumns = [];
            for (var i = 0; i < propSchema['enum'].length; i++) {
              String enumKey = propSchema['enum'][i].toString();
              if (propSchema['\$tfm'] != null && propSchema['\$tfm']['name_de'] != null && propSchema['\$tfm']['name_de'][i] != null) {
                // Handle translation if available
                String translatedValue = propSchema['\$tfm']['name_de'][i];
                enumKey += '- $translatedValue';
              }
              enumColumns.add(enumKey);
            }
            print('ENUM: $key');
            // Handle enum type
            final List<dynamic> enumValues = List<dynamic>.from(enumColumns);
            return PlutoColumn(
              title: title,
              field: key,
              type: PlutoColumnType.select(enumValues, enableColumnFilter: true),
              width: 150,
              minWidth: 80,
              enableEditingMode: true,
              enableSorting: true,
              enableDropToResize: true,
              enableFilterMenuItem: false,
              enableContextMenu: false,
            );
          }

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

          // Ensure column field is not null or empty
          // PlutoGrid requires unique, non-empty field identifiers
          final String safeKey = key.isNotEmpty ? key : 'column_$title';
          if (key.isEmpty) {
            print('!!!!Column key is empty, using default: $safeKey');
          }

          // https://pluto.weblaze.dev/columns
          PlutoColumn column = PlutoColumn(title: title, field: safeKey, type: columnType, width: 150, minWidth: 80, enableEditingMode: true, enableSorting: true, enableDropToResize: true, enableFilterMenuItem: false, enableContextMenu: false);

          if (key == 'tree_number') {
            //column.enableEditingMode = false; // Disable editing for ID column
            column.frozen = PlutoColumnFrozen.start; // Freeze ID column
          }

          // Add custom renderer to show validation errors
          column.renderer = (rendererContext) {
            // Check if there's an error for this field
            bool hasError = false;
            String? errorMessage;

            // Process validation errors for this cell
            if (widget.validationErrors.isNotEmpty) {
              // Look for errors related to this array item
              final String instancePath = "/${widget.name}/${rendererContext.rowIdx}/${key}";
              for (final error in widget.validationErrors) {
                // Match errors by instance path
                /*print('---');
                print(error.instancePath);
                print(instancePath);*/
                if (error.instancePath == instancePath) {
                  hasError = true;
                  errorMessage = error.message;
                  break;
                }
              }
            }

            return Container(
              decoration: BoxDecoration(border: hasError ? Border.all(color: Colors.red, width: 2) : null),
              child: Row(
                children: [
                  Expanded(child: Text(rendererContext.cell.value?.toString() ?? '', style: TextStyle(color: hasError ? Colors.red : null))),
                  if (type != 'boolean')
                    IconButton(
                      onPressed: () {
                        // Microphone functionality could be added here
                      },
                      icon: Icon(Icons.mic),
                    ),
                  if (hasError) Tooltip(message: errorMessage ?? 'Invalid value', child: Icon(Icons.error_outline, color: Colors.red, size: 16)),
                ],
              ),
            );
          };

          return column;
        }).toList();

    // Safety check - ensure we have generated columns
    if (columns.isEmpty) {
      columns = [PlutoColumn(title: 'No Fields', field: 'placeholder', type: PlutoColumnType.text())];
    }

    // Create rows from existing data
    rows = [];
    // Safety check for valid data
    if (widget.value.isNotEmpty) {
      for (var item in widget.value) {
        final Map<String, dynamic> rowItem = _typeSafeMap<String, dynamic>(item);
        final Map<String, PlutoCell> cells = {};

        // Create cells for each property, ensuring each column has a cell
        for (var column in columns) {
          final String field = column.field;
          final value = rowItem[field];
          cells[field] = PlutoCell(value: value);
        }

        rows.add(PlutoRow(cells: cells));
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final brightness = PlatformDispatcher.instance.platformBrightness;
    bool isDarkMode = brightness == Brightness.dark;

    // Safety check - handle empty columns case
    if (columns.isEmpty) {
      return Card(child: Padding(padding: const EdgeInsets.all(16.0), child: Center(child: Text('No fields defined for array items'))));
    }

    print('BUILD GRID ${rows.length}');

    // Rest of the build method...
    return PlutoGrid(
      columns: columns,
      rows: rows,
      configuration: isDarkMode ? configurationDark : configurationLight,
      onChanged: (PlutoGridOnChangedEvent event) {
        widget.value[event.rowIdx][event.column.field] = event.value;
        widget.onChanged(widget.value);
      },
      onLoaded: (PlutoGridOnLoadedEvent event) {
        // Avoid setting state during build
        WidgetsBinding.instance.addPostFrameCallback((_) {
          stateManager = event.stateManager;

          stateManager.setSelectingMode(PlutoGridSelectingMode.row);

          print('StateManager initialized');

          // Wait until grid is actually ready before configuring
          Future.delayed(Duration(milliseconds: 100), () {
            if (!mounted) return;

            stateManager.setShowLoading(true);

            // Resize columns with a try-catch to prevent uncaught errors
            try {
              final double availableWidth = context.size?.width ?? 0;
              if (availableWidth > 0 && stateManager.columns.isNotEmpty) {
                // Simple even width distribution
                final double colWidth = (availableWidth / stateManager.columns.length) - 10;
                for (final column in stateManager.columns) {
                  stateManager.resizeColumn(column, colWidth);
                }
              }
            } catch (e) {
              print('Error adjusting column widths: $e');
            }

            stateManager.setShowLoading(false);
          });
        });
      },
    );
    // Action buttons...
  }

  void _addRow() {
    // Create empty cells for the new row
    final Map<String, PlutoCell> newCells = {};

    for (var column in columns) {
      newCells[column.field] = PlutoCell(value: null);
    }

    // Create a new row with the empty cells
    final newRow = PlutoRow(cells: newCells);

    // Add the new row to the grid
    stateManager.appendRows([newRow]);

    // Update data source
    _updateDataFromGrid();
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

  // Add the _getEffectiveType helper method to _ArrayGridEditorState class:
  String _getEffectiveType(dynamic typeValue) {
    if (typeValue == null) return 'string';

    if (typeValue is List) {
      // Find first non-null type in the array
      for (final type in typeValue) {
        if (type != null && type != 'null') {
          return type.toString();
        }
      }
      return 'string'; // Default if all null or only "null" type
    }

    return typeValue.toString();
  }
}
