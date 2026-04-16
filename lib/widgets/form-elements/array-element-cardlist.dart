import 'package:flutter/material.dart';
import 'package:terrestrial_forest_monitor/services/validation_service.dart';
import 'package:terrestrial_forest_monitor/widgets/form-elements/array-element-trina.dart';
import 'package:terrestrial_forest_monitor/widgets/form-elements/generic-form.dart';
import 'package:terrestrial_forest_monitor/widgets/form-elements/helping-point.dart';

/// ArrayElementCardList – renders an array as a vertical list of Cards.
/// Each card contains a [GenericForm] for one row's editable fields.
///
/// Use `"component": "cardlist"` in the layout style-map to activate this widget.
///
/// Supports the same `columnItems` / `options` (incl. `maxRows`) format as ArrayElementTrina.
/// Fields with `"display": false` are hidden from the card UI but their `"default"` values
/// are still seeded when a new row is added.
class ArrayElementCardList extends StatefulWidget {
  final Map<String, dynamic> jsonSchema;
  final List<dynamic>? data;
  final String? propertyName;

  /// Column items array (same format as datagrid `items`) – drives visible fields + defaults.
  final List<dynamic>? columnItems;

  /// Layout options: `maxRows`, etc.
  final Map<String, dynamic>? layoutOptions;

  /// Optional label shown in each card header (e.g. "Hilfspunkt").
  final String? label;

  final TFMValidationResult? validationResult;
  final Function(List<dynamic>?)? onDataChanged;

  const ArrayElementCardList({
    super.key,
    required this.jsonSchema,
    required this.data,
    this.propertyName,
    this.columnItems,
    this.layoutOptions,
    this.label,
    this.validationResult,
    this.onDataChanged,
  });

  @override
  State<ArrayElementCardList> createState() => ArrayElementCardListState();
}

class ArrayElementCardListState extends State<ArrayElementCardList> {
  late List<Map<String, dynamic>> _rows;

  @override
  void initState() {
    super.initState();
    _rows = _buildRows();
  }

  @override
  void didUpdateWidget(ArrayElementCardList oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.data != oldWidget.data) {
      setState(() {
        _rows = _buildRows();
      });
    }
  }

  List<Map<String, dynamic>> _buildRows() {
    if (widget.data == null) return [];
    return widget.data!
        .map((e) => Map<String, dynamic>.from((e as Map?)?.cast<String, dynamic>() ?? {}))
        .toList();
  }

  void _notifyDataChanged() {
    widget.onDataChanged?.call(List<dynamic>.from(_rows));
  }

  // ── Defaults ──────────────────────────────────────────────────────────────

  /// Collect `"default"` values from columnItems (including nested groups).
  Map<String, dynamic> _getColumnItemDefaults() {
    final defaults = <String, dynamic>{};
    if (widget.columnItems == null) return defaults;
    void processItem(Map<String, dynamic> item) {
      final name = item['name'] as String?;
      if (name != null && item.containsKey('default')) defaults[name] = item['default'];
      final children = item['items'] as List?;
      if (children != null) {
        for (final child in children) {
          if (child is Map<String, dynamic>) processItem(child);
        }
      }
    }

    for (final item in widget.columnItems!) {
      if (item is Map<String, dynamic>) processItem(item);
    }
    return defaults;
  }

  /// Collect field names with `"autoIncrement": true` from columnItems.
  Set<String> _getAutoIncrementFields() {
    final fields = <String>{};
    if (widget.columnItems == null) return fields;
    for (final item in widget.columnItems!) {
      if (item is Map<String, dynamic>) {
        if (item['type'] == 'group') {
          for (final sub in (item['items'] as List?) ?? []) {
            if (sub is Map<String, dynamic> &&
                sub['name'] != null &&
                sub['autoIncrement'] == true) {
              fields.add(sub['name'] as String);
            }
          }
        } else if (item['name'] != null && item['autoIncrement'] == true) {
          fields.add(item['name'] as String);
        }
      }
    }
    return fields;
  }

  int _computeNextAutoIncrementValue(String key, Map<String, dynamic>? propertySchema) {
    final existingValues = _rows
        .map((row) => row[key])
        .where((v) => v != null && v is num)
        .map((v) => (v as num).toInt())
        .toList();
    final defaultValue = (propertySchema?['default'] as int?) ?? 1;
    return existingValues.isEmpty
        ? defaultValue
        : (existingValues.reduce((a, b) => a > b ? a : b) + 1);
  }

  Map<String, dynamic> _buildNewRow() {
    final itemSchema = widget.jsonSchema['items'] as Map<String, dynamic>?;
    final properties = itemSchema?['properties'] as Map<String, dynamic>?;
    final newRow = <String, dynamic>{};

    // 1. Seed from columnItems defaults (highest priority)
    newRow.addAll(_getColumnItemDefaults());

    // 2. Fill remaining fields from schema defaults / type defaults
    if (properties != null) {
      properties.forEach((key, value) {
        if (newRow.containsKey(key)) return; // already seeded above
        final schema = value as Map<String, dynamic>;
        final typeValue = schema['type'];
        String? type;
        if (typeValue is String) {
          type = typeValue;
        } else if (typeValue is List) {
          type =
              typeValue.firstWhere((t) => t != 'null' && t != null, orElse: () => null) as String?;
        }
        if (schema.containsKey('default')) {
          newRow[key] = schema['default'];
        } else {
          switch (type) {
            case 'string':
              newRow[key] = '';
            case 'integer':
            case 'number':
              newRow[key] = null;
            case 'boolean':
              newRow[key] = false;
            case 'array':
              newRow[key] = [];
            case 'object':
              newRow[key] = {};
            default:
              newRow[key] = null;
          }
        }
      });
    }

    // 3. Auto-increment fields
    final autoFields = _getAutoIncrementFields();
    for (final key in autoFields) {
      newRow[key] = _computeNextAutoIncrementValue(key, properties?[key] as Map<String, dynamic>?);
    }

    return newRow;
  }

  // ── Mutations ─────────────────────────────────────────────────────────────

  void _addRow() {
    setState(() {
      _rows.add(_buildNewRow());
    });
    _notifyDataChanged();
  }

  void _deleteRow(int index) {
    setState(() {
      _rows.removeAt(index);
    });
    _notifyDataChanged();
  }

  void _updateRow(int index, Map<String, dynamic> updatedFields) {
    setState(() {
      _rows[index].addAll(updatedFields);
    });
    _notifyDataChanged();
  }

  // ── Field helpers ─────────────────────────────────────────────────────────

  /// Build per-field options (width, upDownBtn, etc.) for [GenericForm].
  Map<String, Map<String, dynamic>> _getFieldOptions() {
    if (widget.columnItems == null) return {};
    final opts = <String, Map<String, dynamic>>{};
    void collect(Map<String, dynamic> item) {
      if (item['type'] == 'group') {
        final children = item['items'] as List?;
        if (children != null) {
          for (final child in children) {
            if (child is Map<String, dynamic>) collect(child);
          }
        }
      } else {
        final name = item['name'] as String?;
        if (name != null && item['display'] != false) {
          final o = <String, dynamic>{};
          if (item['width'] != null) o['width'] = item['width'];
          if (item['upDownBtn'] != null) o['upDownBtn'] = item['upDownBtn'];
          if (o.isNotEmpty) opts[name] = o;
        }
      }
    }

    for (final item in widget.columnItems!) {
      if (item is Map<String, dynamic>) collect(item);
    }
    return opts;
  }

  /// Build the card body widgets in style-map order by iterating columnItems.
  /// Groups consecutive primitive fields into a single [GenericForm], and
  /// renders component objects and nested arrays inline at their position.
  List<Widget> _buildCardBody(int index, Map<String, dynamic> rowData) {
    if (widget.columnItems == null) {
      // Fallback: render all schema properties as a single form
      final itemSchema = widget.jsonSchema['items'] as Map<String, dynamic>?;
      final schemaForForm = itemSchema != null ? {'properties': itemSchema['properties']} : null;
      return [
        Padding(
          padding: const EdgeInsets.all(8),
          child: GenericForm(
            key: ValueKey('row_fallback_$index'),
            jsonSchema: schemaForForm,
            data: rowData,
            propertyName: widget.propertyName != null ? '${widget.propertyName}/$index' : null,
            validationResult: widget.validationResult,
            onDataChanged: (updatedData) => _updateRow(index, updatedData),
          ),
        ),
      ];
    }

    final itemSchema = widget.jsonSchema['items'] as Map<String, dynamic>?;
    final properties = itemSchema?['properties'] as Map<String, dynamic>?;
    final schemaForForm = itemSchema != null ? {'properties': itemSchema['properties']} : null;
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final fieldOptions = _getFieldOptions();

    final result = <Widget>[];
    // Accumulate consecutive primitive field names, flush as GenericForm
    var pendingFields = <String>[];

    void flushFields() {
      if (pendingFields.isEmpty) return;
      final fields = List<String>.from(pendingFields);
      result.add(
        Padding(
          padding: const EdgeInsets.all(8),
          child: GenericForm(
            key: ValueKey('row_${index}_fields_${fields.first}'),
            jsonSchema: schemaForForm,
            data: rowData,
            propertyName: widget.propertyName != null ? '${widget.propertyName}/$index' : null,
            validationResult: widget.validationResult,
            includeProperties: fields,
            fieldOptions: fieldOptions.isNotEmpty ? fieldOptions : null,
            onDataChanged: (updatedData) => _updateRow(index, updatedData),
          ),
        ),
      );
      pendingFields = [];
    }

    for (final item in widget.columnItems!) {
      if (item is! Map<String, dynamic>) continue;

      // Component object (e.g. helping_point)
      if (item['type'] == 'object' && item['component'] != null) {
        flushFields();
        final component = item['component'] as String;
        if (component == 'helping_point') {
          result.add(
            HelpingPoint(
              rowData: rowData,
              index: index,
              onDataChanged: (updatedFields) => _updateRow(index, updatedFields),
            ),
          );
        }
        continue;
      }

      // Nested array (e.g. edges datagrid)
      if (item['type'] == 'array' && item['name'] != null) {
        flushFields();
        final fieldName = item['name'] as String;
        final nestedData = rowData[fieldName] as List<dynamic>?;
        final nestedPropertySchema = properties?[fieldName] as Map<String, dynamic>?;
        final title = nestedPropertySchema?['title'] as String? ?? fieldName;
        final nestedColumns = item['columns'] as Map<String, dynamic>?;
        final nestedOptions = item['options'] as Map<String, dynamic>?;

        result.add(
          Padding(
            padding: const EdgeInsets.all(8),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Text(
                  title,
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w500,
                    color: isDark ? Colors.white70 : Colors.black54,
                  ),
                ),
                const SizedBox(height: 4),
                SizedBox(
                  height: 250,
                  child: ArrayElementTrina(
                    key: ValueKey('nested_${index}_$fieldName'),
                    jsonSchema: nestedPropertySchema ?? {},
                    data: nestedData,
                    propertyName: widget.propertyName != null
                        ? '${widget.propertyName}/$index/$fieldName'
                        : null,
                    columnConfig: nestedColumns,
                    layoutOptions: nestedOptions,
                    validationResult: widget.validationResult,
                    onDataChanged: (updatedData) {
                      _updateRow(index, {fieldName: updatedData});
                    },
                  ),
                ),
              ],
            ),
          ),
        );
        continue;
      }

      // Primitive field
      final name = item['name'] as String?;
      if (name != null && item['display'] != false) {
        pendingFields.add(name);
      }
    }

    flushFields();
    return result;
  }

  // ── Build ─────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    // Null data means the array has never been initialised yet
    if (widget.data == null) {
      return Center(
        child: ElevatedButton(
          onPressed: () {
            widget.onDataChanged?.call([]);
            setState(() {
              _rows = [];
            });
          },
          child: const Text('Kein Eintrag erforderlich'),
        ),
      );
    }

    final maxRows = (widget.layoutOptions?['maxRows'] as num?)?.toInt();
    final atMax = maxRows != null && _rows.length >= maxRows;
    final margin = (widget.layoutOptions?['margin'] as num?)?.toDouble() ?? 0.0;
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return SingleChildScrollView(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        mainAxisSize: MainAxisSize.min,
        children: [
          // ── Cards ──────────────────────────────────────────────────────────
          ..._rows.asMap().entries.map((entry) {
            final index = entry.key;
            final rowData = entry.value;

            return Padding(
              padding: EdgeInsets.only(left: margin, right: margin, top: margin, bottom: margin),
              child: Card.outlined(
                margin: EdgeInsets.zero,
                elevation: 1,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    // Header row: index + delete button
                    Container(
                      decoration: BoxDecoration(
                        color: isDark ? const Color(0xFF2D2D30) : Colors.grey.shade100,
                        borderRadius: const BorderRadius.vertical(top: Radius.circular(4)),
                      ),
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                      child: Row(
                        children: [
                          Expanded(
                            child: Text(
                              widget.label != null
                                  ? '${widget.label} (${index + 1})'
                                  : '${index + 1}',
                              style: TextStyle(
                                fontWeight: FontWeight.bold,
                                fontSize: 13,
                                color: isDark ? Colors.white70 : Colors.black54,
                              ),
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                          IconButton(
                            icon: const Icon(Icons.delete_outline, size: 18),
                            onPressed: () => _deleteRow(index),
                            tooltip: 'Eintrag löschen',
                            padding: const EdgeInsets.all(4),
                            constraints: const BoxConstraints(),
                          ),
                        ],
                      ),
                    ),
                    // Card body – rendered in style-map order
                    ..._buildCardBody(index, rowData),
                  ],
                ),
              ),
            );
          }),

          // ── Add button ─────────────────────────────────────────────────────
          Padding(
            padding: EdgeInsets.only(top: 4, left: margin, right: margin, bottom: margin),
            child: TextButton.icon(
              onPressed: atMax ? null : _addRow,
              icon: const Icon(Icons.add, size: 18),
              label: Text(
                atMax ? 'Maximal $maxRows Einträge' : '${widget.label ?? 'Eintrag'} hinzufügen',
              ),
            ),
          ),
        ],
      ),
    );
  }
}
