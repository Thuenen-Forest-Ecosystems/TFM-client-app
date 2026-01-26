import 'package:flutter/material.dart';
import 'package:terrestrial_forest_monitor/repositories/schema_repository.dart';

class NewRecordDialog extends StatefulWidget {
  const NewRecordDialog({super.key});

  @override
  State<NewRecordDialog> createState() => _NewRecordDialogState();
}

class _NewRecordDialogState extends State<NewRecordDialog> {
  final _formKey = GlobalKey<FormState>();
  final _clusterNameController = TextEditingController();
  final _plotNameController = TextEditingController();

  List<SchemaModel> _schemas = [];
  SchemaModel? _selectedSchema;
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadSchemas();
  }

  Future<void> _loadSchemas() async {
    try {
      final schemaRepo = SchemaRepository();
      final schemas = await schemaRepo.getAllVisibleSchemas();

      if (mounted) {
        setState(() {
          _schemas = schemas;
          _selectedSchema = schemas.isNotEmpty ? schemas.first : null;
          _isLoading = false;
        });
      }
    } catch (e) {
      debugPrint('Error loading schemas: $e');
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  @override
  void dispose() {
    _clusterNameController.dispose();
    _plotNameController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Neue Ecke erstellen'),
      content: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : Form(
              key: _formKey,
              child: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    if (_schemas.isEmpty)
                      const Padding(
                        padding: EdgeInsets.all(16.0),
                        child: Text('Keine Schemas verfügbar', style: TextStyle(color: Colors.red)),
                      )
                    else ...[
                      DropdownButtonFormField<SchemaModel>(
                        value: _selectedSchema,
                        decoration: const InputDecoration(
                          labelText: 'Schema / Intervall',
                          border: OutlineInputBorder(),
                        ),
                        items: _schemas.map((schema) {
                          return DropdownMenuItem(
                            value: schema,
                            child: Text(schema.title ?? schema.intervalName),
                          );
                        }).toList(),
                        onChanged: (value) {
                          setState(() {
                            _selectedSchema = value;
                          });
                        },
                        validator: (value) {
                          if (value == null) {
                            return 'Bitte Schema auswählen';
                          }
                          return null;
                        },
                      ),
                      const SizedBox(height: 16),
                      TextFormField(
                        controller: _clusterNameController,
                        decoration: const InputDecoration(
                          labelText: 'Traktnummer',
                          border: OutlineInputBorder(),
                          hintText: 'z.B. 12345',
                        ),
                        keyboardType: TextInputType.number,
                        validator: (value) {
                          if (value == null || value.isEmpty) {
                            return 'Bitte Traktnummer eingeben';
                          }
                          return null;
                        },
                      ),
                      const SizedBox(height: 16),
                      TextFormField(
                        controller: _plotNameController,
                        decoration: const InputDecoration(
                          labelText: 'Eckennummer',
                          border: OutlineInputBorder(),
                          hintText: 'z.B. 1',
                        ),
                        keyboardType: TextInputType.number,
                        validator: (value) {
                          if (value == null || value.isEmpty) {
                            return 'Bitte Eckennummer eingeben';
                          }
                          return null;
                        },
                      ),
                    ],
                  ],
                ),
              ),
            ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(null),
          child: const Text('Abbrechen'),
        ),
        if (!_isLoading && _schemas.isNotEmpty)
          FilledButton(
            onPressed: () {
              if (_formKey.currentState!.validate()) {
                Navigator.of(context).pop({
                  'clusterName': _clusterNameController.text,
                  'plotName': _plotNameController.text,
                  'schemaName': _selectedSchema!.intervalName,
                });
              }
            },
            child: const Text('Erstellen'),
          ),
      ],
    );
  }
}
