import 'package:flutter/material.dart';
import 'package:terrestrial_forest_monitor/services/validation_service.dart';
import 'package:terrestrial_forest_monitor/widgets/form-elements/generic-form.dart';
import 'package:terrestrial_forest_monitor/widgets/form-elements/generic-textfield.dart';

/// CardDialog - A card that displays readonly fields and opens a dialog for editing
class CardDialog extends StatelessWidget {
  final String? label;
  final Map<String, dynamic>? jsonSchema;
  final Map<String, dynamic> data;
  final TFMValidationResult? validationResult;
  final Function(Map<String, dynamic>)? onDataChanged;
  final List<String>? includeProperties;

  const CardDialog({
    super.key,
    this.label,
    this.jsonSchema,
    required this.data,
    this.validationResult,
    this.onDataChanged,
    this.includeProperties,
  });

  List<ValidationError> _getErrorsForField(String fieldName) {
    if (validationResult == null) return [];
    return validationResult!.ajvErrors.where((error) {
      final path = error.instancePath ?? '';
      return path == '/$fieldName' || path.startsWith('/$fieldName/');
    }).toList();
  }

  List<MapEntry<String, Map<String, dynamic>>> _getFieldsToShow() {
    if (jsonSchema == null) return [];

    final properties = jsonSchema!.containsKey('properties')
        ? jsonSchema!['properties'] as Map<String, dynamic>?
        : jsonSchema;

    if (properties == null || properties.isEmpty) return [];

    final fieldsToShow = <MapEntry<String, Map<String, dynamic>>>[];

    properties.forEach((key, value) {
      // Filter by includeProperties if specified
      if (includeProperties != null && !includeProperties!.contains(key)) {
        return;
      }

      if (value is Map<String, dynamic>) {
        final typeValue = value['type'];
        String? type;
        if (typeValue is String) {
          type = typeValue;
        } else if (typeValue is List) {
          type = typeValue.firstWhere((t) => t != 'null', orElse: () => null) as String?;
        }

        // Include only primitive types
        if (type == 'string' || type == 'number' || type == 'integer' || type == 'boolean') {
          fieldsToShow.add(MapEntry(key, value));
        }
      }
    });

    return fieldsToShow;
  }

  Future<void> _openEditDialog(BuildContext context) async {
    final updatedData = await showDialog<Map<String, dynamic>>(
      context: context,
      builder: (context) => _EditDialog(
        label: label,
        jsonSchema: jsonSchema,
        data: data,
        validationResult: validationResult,
        includeProperties: includeProperties,
      ),
    );

    if (updatedData != null) {
      onDataChanged?.call(updatedData);
    }
  }

  @override
  Widget build(BuildContext context) {
    final fieldsToShow = _getFieldsToShow();

    if (fieldsToShow.isEmpty) {
      return Card(
        margin: const EdgeInsets.symmetric(vertical: 8),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Text(label ?? 'Keine Felder verfügbar'),
        ),
      );
    }

    return Card(
      margin: const EdgeInsets.symmetric(vertical: 8),
      child: InkWell(
        onTap: () => _openEditDialog(context),
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Expanded(
                    child: Text(
                      label ?? '',
                      style: Theme.of(
                        context,
                      ).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold),
                    ),
                  ),
                  Icon(Icons.edit, size: 20, color: Theme.of(context).colorScheme.primary),
                ],
              ),
              const SizedBox(height: 12),
              SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                child: Row(
                  children: fieldsToShow.map((entry) {
                    final fieldName = entry.key;
                    final fieldSchema = entry.value;
                    final fieldErrors = _getErrorsForField(fieldName);

                    // Create a readonly version of the schema
                    final readonlySchema = Map<String, dynamic>.from(fieldSchema);
                    readonlySchema['readonly'] = true;

                    return Padding(
                      padding: const EdgeInsets.only(right: 16),
                      child: SizedBox(
                        width: 200,
                        child: GenericTextField(
                          fieldName: fieldName,
                          fieldSchema: readonlySchema,
                          value: data[fieldName],
                          errors: fieldErrors,
                          compact: false,
                        ),
                      ),
                    );
                  }).toList(),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _EditDialog extends StatefulWidget {
  final String? label;
  final Map<String, dynamic>? jsonSchema;
  final Map<String, dynamic> data;
  final TFMValidationResult? validationResult;
  final List<String>? includeProperties;

  const _EditDialog({
    this.label,
    this.jsonSchema,
    required this.data,
    this.validationResult,
    this.includeProperties,
  });

  @override
  State<_EditDialog> createState() => _EditDialogState();
}

class _EditDialogState extends State<_EditDialog> {
  late Map<String, dynamic> _localData;

  @override
  void initState() {
    super.initState();
    _localData = Map<String, dynamic>.from(widget.data);
  }

  void _handleDataChanged(Map<String, dynamic> newData) {
    setState(() {
      _localData = newData;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      child: Container(
        constraints: BoxConstraints(
          maxWidth: 800,
          maxHeight: MediaQuery.of(context).size.height * 0.8,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Header
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Theme.of(context).colorScheme.primary,
                borderRadius: const BorderRadius.vertical(top: Radius.circular(4)),
              ),
              child: Row(
                children: [
                  Expanded(
                    child: Text(
                      widget.label ?? 'Bearbeiten',
                      style: Theme.of(context).textTheme.titleLarge,
                    ),
                  ),
                  /*IconButton(
                    icon: const Icon(Icons.close),
                    onPressed: () => Navigator.of(context).pop(),
                  ),*/
                ],
              ),
            ),
            // Form content
            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsets.all(16),
                child: GenericForm(
                  jsonSchema: widget.jsonSchema,
                  data: _localData,
                  validationResult: widget.validationResult,
                  onDataChanged: _handleDataChanged,
                  includeProperties: widget.includeProperties,
                ),
              ),
            ),
            // Buttons
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                border: Border(top: BorderSide(color: Theme.of(context).dividerColor)),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  /*TextButton(
                    onPressed: () => Navigator.of(context).pop(),
                    child: const Text('Abbrechen'),
                  ),
                  const Spacer(),*/
                  ElevatedButton(
                    onPressed: () {
                      Navigator.of(context).pop(_localData);
                    },
                    child: const Text('Fertig'),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
