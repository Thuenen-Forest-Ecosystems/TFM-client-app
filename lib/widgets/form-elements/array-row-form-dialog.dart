import 'package:flutter/material.dart';
import 'package:terrestrial_forest_monitor/widgets/form-elements/array-grid-dialog.dart';
import 'package:terrestrial_forest_monitor/widgets/form-elements/generic-form.dart';
import 'package:terrestrial_forest_monitor/widgets/form-elements/generic-textfield.dart';

/// ArrayRowFormDialog - Reusable dialog for adding/editing array rows via form
///
/// Shows a form dialog with proper input fields for each property in the schema.
/// Returns the completed row data when confirmed, or null if cancelled.
///
/// Supports two layout modes:
/// - **columnItems** (new structure): Groups fields into collapsible sections
///   matching the datagrid column layout from style-map.json
/// - **columnConfig** (old structure): Flat list of fields with options
class ArrayRowFormDialog extends StatefulWidget {
  final Map<String, dynamic> itemSchema;
  final Map<String, dynamic>? initialData;
  final Map<String, dynamic>? columnConfig;
  final List<dynamic>? columnItems;
  final Map<String, dynamic>? layoutOptions;
  final String title;
  final bool readOnly;

  const ArrayRowFormDialog({
    super.key,
    required this.itemSchema,
    this.initialData,
    this.columnConfig,
    this.columnItems,
    this.layoutOptions,
    this.title = 'Neue Zeile hinzufügen',
    this.readOnly = false,
  });

  /// Show the dialog and return the result
  static Future<Map<String, dynamic>?> show({
    required BuildContext context,
    required Map<String, dynamic> itemSchema,
    Map<String, dynamic>? initialData,
    Map<String, dynamic>? columnConfig,
    List<dynamic>? columnItems,
    Map<String, dynamic>? layoutOptions,
    String? title,
    bool readOnly = false,
  }) async {
    return await showDialog<Map<String, dynamic>>(
      context: context,
      barrierDismissible: false,
      builder: (context) => ArrayRowFormDialog(
        itemSchema: itemSchema,
        initialData: initialData,
        columnConfig: columnConfig,
        columnItems: columnItems,
        layoutOptions: layoutOptions,
        title: title ?? 'Neue Zeile hinzufügen',
        readOnly: readOnly,
      ),
    );
  }

  @override
  State<ArrayRowFormDialog> createState() => _ArrayRowFormDialogState();
}

class _ArrayRowFormDialogState extends State<ArrayRowFormDialog> {
  late Map<String, dynamic> _formData;
  late Map<String, dynamic> _effectiveSchema;
  List<String>? _includeProperties;
  Map<String, Map<String, dynamic>>? _fieldOptions;

  /// Parsed grouped layout from columnItems: list of { label, fields }
  List<_FieldGroup>? _fieldGroups;

  /// Array-type fields with their schema and column config
  final Map<String, _ArrayFieldInfo> _arrayFields = {};

  @override
  void initState() {
    super.initState();
    _formData = Map<String, dynamic>.from(widget.initialData ?? {});
    _prepareSchemaAndLayout();
  }

  void _prepareSchemaAndLayout() {
    final properties = widget.itemSchema['properties'] as Map<String, dynamic>? ?? {};

    // NEW STRUCTURE: Use columnItems if provided (groups + ordered fields)
    if (widget.columnItems != null && widget.columnItems!.isNotEmpty) {
      _prepareGroupedLayout(properties);
      return;
    }

    // OLD STRUCTURE: Flat columnConfig approach
    _prepareFlatLayout(properties);
  }

  /// Prepare grouped layout from columnItems (new style-map.json structure)
  void _prepareGroupedLayout(Map<String, dynamic> properties) {
    final groups = <_FieldGroup>[];
    final modifiedProperties = <String, dynamic>{};
    final allIncludeProps = <String>[];

    // Ungrouped items go into a default group (no label)
    var ungroupedFields = <String>[];

    for (final item in widget.columnItems!) {
      if (item is! Map<String, dynamic>) continue;

      if (item['type'] == 'group') {
        // Group with sub-items
        final groupLabel = item['label'] as String? ?? '';
        final groupItems = item['items'] as List<dynamic>? ?? [];
        final groupFields = <String>[];

        for (final subItem in groupItems) {
          if (subItem is! Map<String, dynamic>) continue;
          final fieldName = subItem['name'] as String?;
          if (fieldName == null) continue;
          if (!properties.containsKey(fieldName)) continue;

          // Skip calculated/display-only fields
          if (subItem['type'] == 'calculated') continue;
          if (subItem['display'] == false) continue;

          // Track array-type fields
          final propSchema = properties[fieldName] as Map<String, dynamic>;
          final schemaType = propSchema['type'];
          final isArray =
              schemaType == 'array' ||
              (schemaType is List && schemaType.contains('array')) ||
              subItem['type'] == 'array';
          if (isArray) {
            _arrayFields[fieldName] = _ArrayFieldInfo(
              fieldName: fieldName,
              propertySchema: propSchema,
              nestedColumns: subItem['columns'] as Map<String, dynamic>?,
              nestedOptions: subItem['options'] as Map<String, dynamic>?,
              isReadOnly:
                  widget.readOnly ||
                  subItem['readonly'] == true ||
                  propSchema['readOnly'] == true ||
                  propSchema['readonly'] == true,
            );
          }

          _applyFieldConfig(fieldName, subItem, properties, modifiedProperties);
          groupFields.add(fieldName);
          allIncludeProps.add(fieldName);
        }

        if (groupFields.isNotEmpty) {
          // Flush any pending ungrouped fields first
          if (ungroupedFields.isNotEmpty) {
            groups.add(_FieldGroup(label: null, fields: ungroupedFields));
            ungroupedFields = [];
          }
          groups.add(_FieldGroup(label: groupLabel, fields: groupFields));
        }
      } else {
        // Top-level item (not in a group)
        final fieldName = item['name'] as String?;
        if (fieldName == null) continue;
        if (!properties.containsKey(fieldName)) continue;
        if (item['type'] == 'calculated') continue;
        if (item['display'] == false) continue;

        // Track array-type fields
        final propSchema = properties[fieldName] as Map<String, dynamic>;
        final schemaType = propSchema['type'];
        final isArray =
            schemaType == 'array' ||
            (schemaType is List && schemaType.contains('array')) ||
            item['type'] == 'array';
        if (isArray) {
          _arrayFields[fieldName] = _ArrayFieldInfo(
            fieldName: fieldName,
            propertySchema: propSchema,
            nestedColumns: item['columns'] as Map<String, dynamic>?,
            nestedOptions: item['options'] as Map<String, dynamic>?,
            isReadOnly:
                widget.readOnly ||
                item['readonly'] == true ||
                propSchema['readOnly'] == true ||
                propSchema['readonly'] == true,
          );
        }

        _applyFieldConfig(fieldName, item, properties, modifiedProperties);
        ungroupedFields.add(fieldName);
        allIncludeProps.add(fieldName);
      }
    }

    // Flush remaining ungrouped fields
    if (ungroupedFields.isNotEmpty) {
      groups.add(_FieldGroup(label: null, fields: ungroupedFields));
    }

    _effectiveSchema = {...widget.itemSchema, 'properties': modifiedProperties};
    _includeProperties = allIncludeProps.isNotEmpty ? allIncludeProps : null;
    _fieldGroups = groups;
  }

  /// Apply column item config to a property schema entry
  void _applyFieldConfig(
    String fieldName,
    Map<String, dynamic> itemConfig,
    Map<String, dynamic> properties,
    Map<String, dynamic> modifiedProperties,
  ) {
    final propertySchema = Map<String, dynamic>.from(properties[fieldName] as Map<String, dynamic>);

    // Apply readonly
    if (widget.readOnly ||
        itemConfig['readonly'] == true ||
        propertySchema['readOnly'] == true ||
        propertySchema['readonly'] == true) {
      propertySchema['readonly'] = true;
    }

    // Override title if provided
    if (itemConfig['title'] != null) {
      propertySchema['title'] = itemConfig['title'];
    }

    modifiedProperties[fieldName] = propertySchema;
  }

  /// Prepare flat layout from columnConfig (old structure)
  void _prepareFlatLayout(Map<String, dynamic> properties) {
    final modifiedProperties = <String, dynamic>{};
    final includeProps = <String>[];
    final fieldOpts = <String, Map<String, dynamic>>{};

    // Use columnConfig key order (style-map.json position) when available,
    // otherwise fall back to schema property order.
    final fieldsToProcess = widget.columnConfig != null
        ? widget.columnConfig!.keys
        : properties.keys;

    for (final key in fieldsToProcess) {
      if (!properties.containsKey(key)) continue;
      final propertySchema = Map<String, dynamic>.from(properties[key] as Map<String, dynamic>);

      // Get column configuration
      final columnConfig = widget.columnConfig?[key] as Map<String, dynamic>?;
      final display = columnConfig?['display'] ?? true;

      // Skip if display is false
      if (display == false) continue;

      // Detect array-type fields (from schema type or column config type)
      final schemaType = propertySchema['type'];
      final isArray =
          schemaType == 'array' ||
          (schemaType is List && schemaType.contains('array')) ||
          columnConfig?['type'] == 'array';

      if (isArray) {
        final isReadOnly =
            widget.readOnly ||
            columnConfig?['readonly'] == true ||
            propertySchema['readOnly'] == true ||
            propertySchema['readonly'] == true;
        _arrayFields[key] = _ArrayFieldInfo(
          fieldName: key,
          propertySchema: propertySchema,
          nestedColumns: columnConfig?['columns'] as Map<String, dynamic>?,
          nestedOptions: columnConfig?['options'] as Map<String, dynamic>?,
          isReadOnly: isReadOnly,
        );
        includeProps.add(key);
        modifiedProperties[key] = propertySchema;
        continue;
      }

      includeProps.add(key);

      // Make field readonly if dialog is in readOnly mode or field is marked readonly
      if (widget.readOnly ||
          columnConfig?['readonly'] == true ||
          propertySchema['readOnly'] == true ||
          propertySchema['readonly'] == true) {
        propertySchema['readonly'] = true;
      }

      // Extract field options (width, title, etc.)
      if (columnConfig != null) {
        final opts = <String, dynamic>{};
        if (columnConfig['width'] != null) opts['width'] = columnConfig['width'];
        if (columnConfig['minWidth'] != null) opts['minWidth'] = columnConfig['minWidth'];
        if (columnConfig['maxWidth'] != null) opts['maxWidth'] = columnConfig['maxWidth'];

        // Override title if provided in layout
        if (columnConfig['title'] != null) {
          propertySchema['title'] = columnConfig['title'];
        }

        if (opts.isNotEmpty) fieldOpts[key] = opts;
      }

      modifiedProperties[key] = propertySchema;
    }

    _effectiveSchema = {...widget.itemSchema, 'properties': modifiedProperties};

    _includeProperties = includeProps.isNotEmpty ? includeProps : null;
    _fieldOptions = fieldOpts.isNotEmpty ? fieldOpts : null;
  }

  void _handleSave() {
    Navigator.of(context).pop(_formData);
  }

  void _handleCancel() {
    Navigator.of(context).pop();
  }

  void _updateField(String key, dynamic value) {
    setState(() {
      _formData[key] = value;
    });
  }

  /// Build grouped form content from columnItems layout
  Widget _buildGroupedForm(Map<String, dynamic> properties) {
    final groups = _fieldGroups!;

    return LayoutBuilder(
      builder: (context, constraints) {
        final screenWidth = constraints.maxWidth;
        int columns;
        if (screenWidth >= 900) {
          columns = 3;
        } else if (screenWidth >= 500) {
          columns = 2;
        } else {
          columns = 1;
        }
        final fieldWidth = columns > 1 ? (screenWidth / columns - 12) : double.infinity;

        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: groups.map((group) {
            final fieldWidgets = group.fields
                .where((f) => properties.containsKey(f))
                .map((fieldName) {
                  final fieldSchema = properties[fieldName] as Map<String, dynamic>;

                  // Check if this is an array field
                  if (_arrayFields.containsKey(fieldName)) {
                    return Padding(
                      padding: const EdgeInsets.symmetric(vertical: 4, horizontal: 4),
                      child: SizedBox(
                        width: double.infinity,
                        child: _buildArrayFieldWidget(fieldName, _arrayFields[fieldName]!),
                      ),
                    );
                  }

                  // Only show primitive types for text fields
                  final typeValue = fieldSchema['type'];
                  String? type;
                  if (typeValue is String) {
                    type = typeValue;
                  } else if (typeValue is List) {
                    type = typeValue.firstWhere((t) => t != 'null', orElse: () => null) as String?;
                  }
                  if (type != 'string' &&
                      type != 'number' &&
                      type != 'integer' &&
                      type != 'boolean') {
                    return null;
                  }

                  return Padding(
                    padding: const EdgeInsets.symmetric(vertical: 4, horizontal: 4),
                    child: SizedBox(
                      width: fieldWidth,
                      child: GenericTextField(
                        fieldName: fieldName,
                        fieldSchema: fieldSchema,
                        value: _formData[fieldName],
                        errors: const [],
                        onChanged: (value) => _updateField(fieldName, value),
                        currentData: _formData,
                      ),
                    ),
                  );
                })
                .whereType<Widget>()
                .toList();

            if (fieldWidgets.isEmpty) return const SizedBox.shrink();

            final wrappedFields = Wrap(spacing: 4, runSpacing: 4, children: fieldWidgets);

            if (group.label != null && group.label!.isNotEmpty) {
              return ExpansionTile(
                title: Text(
                  group.label!,
                  style: Theme.of(
                    context,
                  ).textTheme.titleSmall?.copyWith(fontWeight: FontWeight.bold),
                ),
                initiallyExpanded: false,
                tilePadding: const EdgeInsets.symmetric(horizontal: 4),
                childrenPadding: const EdgeInsets.fromLTRB(4, 0, 4, 8),
                children: [wrappedFields],
              );
            } else {
              return Padding(padding: const EdgeInsets.only(bottom: 8), child: wrappedFields);
            }
          }).toList(),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final properties = _effectiveSchema['properties'] as Map<String, dynamic>? ?? {};
    final useGroupedLayout = _fieldGroups != null && _fieldGroups!.isNotEmpty;

    return Dialog(
      child: Container(
        constraints: BoxConstraints(
          maxWidth: 1000,
          maxHeight: MediaQuery.of(context).size.height * 0.8,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Form content
            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsets.all(16),
                child: useGroupedLayout
                    ? _buildGroupedForm(properties)
                    : Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          GenericForm(
                            jsonSchema: _effectiveSchema,
                            data: _formData,
                            layout: 'responsive-wrap',
                            includeProperties: _includeProperties,
                            fieldOptions: _fieldOptions,
                            layoutOptions: widget.layoutOptions,
                            onDataChanged: (updatedData) {
                              setState(() {
                                _formData = updatedData;
                              });
                            },
                          ),
                          // Render array fields below the primitive form fields
                          for (final entry in _arrayFields.entries)
                            Padding(
                              padding: const EdgeInsets.symmetric(vertical: 4),
                              child: _buildArrayFieldWidget(entry.key, entry.value),
                            ),
                        ],
                      ),
              ),
            ),
            // Buttons
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                border: Border(top: BorderSide(color: Theme.of(context).dividerColor)),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  TextButton(onPressed: _handleCancel, child: const Text('Abbrechen')),
                  Spacer(),
                  if (!widget.readOnly)
                    ElevatedButton(onPressed: _handleSave, child: const Text('Speichern')),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  /// Build a widget for a nested array field - shows item count and edit button
  Widget _buildArrayFieldWidget(String fieldName, _ArrayFieldInfo info) {
    final data = _formData[fieldName];
    final itemCount = data is List ? data.length : 0;
    final title = info.propertySchema['title'] as String? ?? fieldName;
    final theme = Theme.of(context);

    return Card(
      margin: EdgeInsets.zero,
      child: ListTile(
        title: Text(title),
        subtitle: Text(
          itemCount == 0 ? 'Leer' : '$itemCount Einträge',
          style: TextStyle(color: itemCount == 0 ? Colors.grey : null),
        ),
        trailing: IconButton(
          icon: Icon(info.isReadOnly ? Icons.visibility : Icons.edit),
          tooltip: info.isReadOnly ? 'Anzeigen' : 'Bearbeiten',
          onPressed: () => _openNestedArrayDialog(fieldName, info),
        ),
        dense: true,
        tileColor: theme.colorScheme.surfaceContainerHighest.withAlpha(80),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
      ),
    );
  }

  Future<void> _openNestedArrayDialog(String fieldName, _ArrayFieldInfo info) async {
    final currentData = _formData[fieldName] is List ? _formData[fieldName] as List<dynamic> : null;

    final result = await ArrayGridDialog.show(
      context: context,
      nestedArraySchema: info.propertySchema,
      data: currentData,
      title: info.propertySchema['title'] as String? ?? fieldName,
      columnConfig: info.nestedColumns,
      layoutOptions: info.nestedOptions,
      parentReadOnly: info.isReadOnly,
    );

    if (result != null) {
      setState(() {
        _formData[fieldName] = result;
      });
    }
  }
}

/// Internal model for a group of fields
class _FieldGroup {
  final String? label;
  final List<String> fields;

  _FieldGroup({this.label, required this.fields});
}

/// Internal model for array-type field info
class _ArrayFieldInfo {
  final String fieldName;
  final Map<String, dynamic> propertySchema;
  final Map<String, dynamic>? nestedColumns;
  final Map<String, dynamic>? nestedOptions;
  final bool isReadOnly;

  _ArrayFieldInfo({
    required this.fieldName,
    required this.propertySchema,
    this.nestedColumns,
    this.nestedOptions,
    this.isReadOnly = false,
  });
}
