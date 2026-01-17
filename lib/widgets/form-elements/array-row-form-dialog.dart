import 'package:flutter/material.dart';
import 'package:terrestrial_forest_monitor/widgets/form-elements/generic-form.dart';

/// ArrayRowFormDialog - Reusable dialog for adding/editing array rows via form
///
/// Shows a form dialog with proper input fields for each property in the schema.
/// Returns the completed row data when confirmed, or null if cancelled.
class ArrayRowFormDialog extends StatefulWidget {
  final Map<String, dynamic> itemSchema;
  final Map<String, dynamic>? initialData;
  final Map<String, dynamic>? columnConfig;
  final Map<String, dynamic>? layoutOptions;
  final String title;
  final bool readOnly;

  const ArrayRowFormDialog({
    super.key,
    required this.itemSchema,
    this.initialData,
    this.columnConfig,
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
    Map<String, dynamic>? layoutOptions,
    String? title,
    bool readOnly = false,
  }) async {
    return await showDialog<Map<String, dynamic>>(
      context: context,
      builder: (context) => ArrayRowFormDialog(
        itemSchema: itemSchema,
        initialData: initialData,
        columnConfig: columnConfig,
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

  @override
  void initState() {
    super.initState();
    _formData = Map<String, dynamic>.from(widget.initialData ?? {});
    _prepareSchemaAndLayout();
  }

  void _prepareSchemaAndLayout() {
    // Start with the original schema
    final properties = widget.itemSchema['properties'] as Map<String, dynamic>? ?? {};
    final modifiedProperties = <String, dynamic>{};
    final includeProps = <String>[];
    final fieldOpts = <String, Map<String, dynamic>>{};

    properties.forEach((key, value) {
      final propertySchema = Map<String, dynamic>.from(value as Map<String, dynamic>);

      // Get column configuration
      final columnConfig = widget.columnConfig?[key] as Map<String, dynamic>?;
      final display = columnConfig?['display'] ?? true;

      // Skip if display is false
      if (display == false) return;

      includeProps.add(key);

      // Make field readonly if dialog is in readOnly mode or field is marked readonly
      if (widget.readOnly ||
          columnConfig?['readonly'] == true ||
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
    });

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

  @override
  Widget build(BuildContext context) {
    return Dialog(
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
              child: Row(
                children: [
                  Expanded(
                    child: Text(widget.title, style: Theme.of(context).textTheme.titleLarge),
                  ),
                  IconButton(icon: const Icon(Icons.close), onPressed: _handleCancel),
                ],
              ),
            ),
            // Form content
            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsets.all(16),
                child: GenericForm(
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
}
