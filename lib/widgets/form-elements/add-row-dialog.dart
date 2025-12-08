import 'package:flutter/material.dart';
import 'package:terrestrial_forest_monitor/widgets/form-elements/generic-form.dart';

class AddRowDialog extends StatefulWidget {
  final Map<String, dynamic> jsonSchema;
  final String propertyName;
  final Function(Map<String, dynamic>) onRowAdded;

  const AddRowDialog({super.key, required this.jsonSchema, required this.propertyName, required this.onRowAdded});

  @override
  State<AddRowDialog> createState() => _AddRowDialogState();

  static Future<void> show({required BuildContext context, required Map<String, dynamic> jsonSchema, required String propertyName, required Function(Map<String, dynamic>) onRowAdded}) async {
    await showDialog(
      context: context,
      barrierDismissible: false,
      useSafeArea: true,
      builder: (BuildContext context) {
        return AddRowDialog(jsonSchema: jsonSchema, propertyName: propertyName, onRowAdded: onRowAdded);
      },
    );
  }
}

class _AddRowDialogState extends State<AddRowDialog> {
  late Map<String, dynamic> _formData;
  late Map<String, dynamic> _itemSchema;
  final GlobalKey<FormState> _formKey = GlobalKey<FormState>();

  @override
  void initState() {
    super.initState();
    _initializeFormData();
  }

  void _initializeFormData() {
    // Get the item schema from the array schema
    _itemSchema = widget.jsonSchema['items'] as Map<String, dynamic>? ?? {};
    final properties = _itemSchema['properties'] as Map<String, dynamic>? ?? {};

    _formData = <String, dynamic>{};

    // Initialize form data with default values
    properties.forEach((key, value) {
      final propertySchema = value as Map<String, dynamic>;
      final typeValue = propertySchema['type'];

      String? type;
      if (typeValue is String) {
        type = typeValue;
      } else if (typeValue is List) {
        type = typeValue.firstWhere((t) => t != 'null' && t != null, orElse: () => null) as String?;
      }

      // Check for default values or set initial values based on type
      if (propertySchema.containsKey('default')) {
        _formData[key] = propertySchema['default'];
      } else {
        // Check if field has autoIncrement enabled
        final tfm = propertySchema['\$tfm'] as Map<String, dynamic>?;
        final form = tfm?['form'] as Map<String, dynamic>?;
        final autoIncrement = form?['autoIncrement'] as bool? ?? false;

        if (autoIncrement && (type == 'integer' || type == 'number')) {
          // Auto-increment will be handled when the row is actually added
          final defaultValue = propertySchema['default'] as int? ?? 1;
          _formData[key] = defaultValue;
        } else {
          // Set appropriate initial values based on type
          switch (type) {
            case 'string':
              _formData[key] = null;
            case 'number':
            case 'integer':
              _formData[key] = null;
            case 'boolean':
              _formData[key] = false;
            case 'array':
              _formData[key] = [];
            case 'object':
              _formData[key] = {};
            default:
              _formData[key] = null;
          }
        }
      }
    });
  }

  void _handleFormDataChanged(Map<String, dynamic> updatedData) {
    setState(() {
      _formData.addAll(updatedData);
    });
  }

  void _handleSave() {
    // Clean up null values and empty strings
    final cleanedData = <String, dynamic>{};
    _formData.forEach((key, value) {
      if (value != null && value != '') {
        cleanedData[key] = value;
      }
    });

    widget.onRowAdded(cleanedData);
    Navigator.of(context).pop();
  }

  void _handleCancel() {
    Navigator.of(context).pop();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final screenSize = MediaQuery.of(context).size;
    final isTablet = screenSize.width >= 600;

    return Dialog.fullscreen(
      child: Scaffold(
        appBar: AppBar(
          title: Text('Neuen ${_getDisplayName()} hinzufügen', style: TextStyle(fontSize: isTablet ? 20 : 18)),
          leading: IconButton(icon: const Icon(Icons.close), onPressed: _handleCancel),
          actions: [
            if (isTablet) ...[
              TextButton(onPressed: _handleCancel, child: const Text('Abbrechen')),
              ElevatedButton(
                onPressed: _handleSave,
                style: ElevatedButton.styleFrom(backgroundColor: theme.colorScheme.primary, foregroundColor: theme.colorScheme.onPrimary),
                child: const Text('Hinzufügen'),
              ),
              const SizedBox(width: 16),
            ],
          ],
        ),
        body: SingleChildScrollView(
          padding: EdgeInsets.all(isTablet ? 24 : 16),
          child: Container(
            width: double.infinity,
            constraints: BoxConstraints(maxWidth: isTablet ? 800 : double.infinity),
            child: Padding(
              padding: EdgeInsets.all(isTablet ? 24 : 16),
              child: Form(
                key: _formKey,
                child: GenericForm(jsonSchema: _itemSchema['properties'], data: _formData, propertyName: null, validationResult: null, onDataChanged: _handleFormDataChanged),
              ),
            ),
          ),
        ),
        bottomNavigationBar: !isTablet
            ? Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: theme.scaffoldBackgroundColor,
                  border: Border(top: BorderSide(color: theme.dividerColor, width: 0.5)),
                ),
                child: Row(
                  children: [
                    Expanded(
                      child: OutlinedButton(
                        onPressed: _handleCancel,
                        style: OutlinedButton.styleFrom(padding: const EdgeInsets.symmetric(vertical: 16)),
                        child: const Text('Abbrechen'),
                      ),
                    ),
                    const SizedBox(width: 16),
                    Expanded(
                      child: ElevatedButton(
                        onPressed: _handleSave,
                        style: ElevatedButton.styleFrom(backgroundColor: theme.colorScheme.primary, foregroundColor: theme.colorScheme.onPrimary, padding: const EdgeInsets.symmetric(vertical: 16)),
                        child: const Text('Eintrag hinzufügen'),
                      ),
                    ),
                  ],
                ),
              )
            : null,
      ),
    );
  }

  String _getDisplayName() {
    final title = _itemSchema['title'] as String?;
    if (title != null) return title;

    // Convert property name to display name
    switch (widget.propertyName) {
      case 'tree':
        return 'WZP Eintrag';
      case 'edges':
        return 'Ecken Eintrag';
      case 'structure_lt4m':
        return 'Struktur <4m Eintrag';
      case 'structure_gt4m':
        return 'Struktur >4m Eintrag';
      case 'regeneration':
        return 'Verjüngung Eintrag';
      case 'deadwood':
        return 'Totholz Eintrag';
      default:
        return '${widget.propertyName} Eintrag';
    }
  }
}
