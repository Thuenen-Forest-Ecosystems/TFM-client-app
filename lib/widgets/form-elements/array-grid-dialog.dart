import 'package:flutter/material.dart';
import 'package:terrestrial_forest_monitor/l10n/app_localizations.dart';
import 'package:terrestrial_forest_monitor/services/validation_types.dart';
import 'package:terrestrial_forest_monitor/widgets/form-elements/array-element-trina.dart';

/// ArrayGridDialog - Dialog for editing nested arrays within datagrids
///
/// Features:
/// - Adaptive dialog size based on content
/// - Full ArrayElementTrina functionality (add/delete, validation, etc.)
/// - Respects parent readonly state
/// - Schema-driven layout from columnConfig
class ArrayGridDialog extends StatefulWidget {
  final Map<String, dynamic> nestedArraySchema;
  final List<dynamic>? data;
  final String? title;
  final TFMValidationResult? validationResult;
  final String? propertyPath;
  final Map<String, dynamic>? columnConfig;
  final Map<String, dynamic>? layoutOptions;
  final bool parentReadOnly;

  /// Previous-survey data for this nested array, used to surface previous
  /// values in the cell info dialog (matched per-row by [identifierField]).
  final List<dynamic>? previousData;

  /// Field name used to match current rows with previous-survey rows.
  final String? identifierField;

  const ArrayGridDialog({
    super.key,
    required this.nestedArraySchema,
    required this.data,
    this.title,
    this.validationResult,
    this.propertyPath,
    this.columnConfig,
    this.layoutOptions,
    this.parentReadOnly = false,
    this.previousData,
    this.identifierField,
  });

  /// Show dialog and return updated data (or null if cancelled)
  static Future<List<dynamic>?> show({
    required BuildContext context,
    required Map<String, dynamic> nestedArraySchema,
    required List<dynamic>? data,
    String? title,
    TFMValidationResult? validationResult,
    String? propertyPath,
    Map<String, dynamic>? columnConfig,
    Map<String, dynamic>? layoutOptions,
    bool parentReadOnly = false,
    List<dynamic>? previousData,
    String? identifierField,
  }) async {
    return showDialog<List<dynamic>?>(
      context: context,
      barrierDismissible: false,
      builder: (context) => ArrayGridDialog(
        nestedArraySchema: nestedArraySchema,
        data: data,
        title: title,
        validationResult: validationResult,
        propertyPath: propertyPath,
        columnConfig: columnConfig,
        layoutOptions: layoutOptions,
        parentReadOnly: parentReadOnly,
        previousData: previousData,
        identifierField: identifierField,
      ),
    );
  }

  @override
  State<ArrayGridDialog> createState() => _ArrayGridDialogState();
}

class _ArrayGridDialogState extends State<ArrayGridDialog> {
  late List<dynamic>? _currentData;

  @override
  void initState() {
    super.initState();
    // Deep copy data to avoid modifying original until Save is clicked
    _currentData = widget.data != null
        ? List<dynamic>.from(widget.data!.map((item) => Map<String, dynamic>.from(item)))
        : null;
  }

  void _handleDataChanged(List<dynamic>? newData) {
    setState(() {
      _currentData = newData;
    });
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final screenSize = MediaQuery.of(context).size;

    // Adaptive dialog size: 90% of screen width/height, but constrain for very large screens
    final dialogWidth = (screenSize.width * 0.9).clamp(400.0, 1400.0);
    final dialogHeight = (screenSize.height * 0.9).clamp(400.0, 900.0);

    // Create effective schema with parent readonly if applicable
    final effectiveSchema = Map<String, dynamic>.from(widget.nestedArraySchema);
    if (widget.parentReadOnly) {
      effectiveSchema['readonly'] = true;
    }

    return Dialog(
      child: Container(
        width: dialogWidth,
        height: dialogHeight,
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Header
            Row(
              children: [
                Expanded(
                  child: Text(widget.title ?? 'Nested Array', style: theme.textTheme.titleLarge),
                ),
                IconButton(
                  icon: const Icon(Icons.close),
                  onPressed: () => Navigator.of(context).pop(null),
                  tooltip: AppLocalizations.of(context)!.gridCancel,
                ),
              ],
            ),

            // Array Grid
            Expanded(
              child: ArrayElementTrina(
                jsonSchema: effectiveSchema,
                data: _currentData,
                propertyName: widget.propertyPath,
                validationResult: widget.validationResult,
                onDataChanged: _handleDataChanged,
                columnConfig: widget.columnConfig,
                layoutOptions: widget.layoutOptions,
                autoHeight: widget.layoutOptions?['isScrollable'] == false,
                previousData: widget.previousData,
                identifierField: widget.identifierField,
              ),
            ),

            // Footer buttons
            Row(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                /*TextButton(
                  onPressed: () => Navigator.of(context).pop(null),
                  child: Text(AppLocalizations.of(context)!.gridCancel),
                ),*/
                const SizedBox(width: 8),
                ElevatedButton(
                  onPressed: widget.parentReadOnly
                      ? null
                      : () => Navigator.of(context).pop(_currentData),
                  child: Text(AppLocalizations.of(context)!.gridSave),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
