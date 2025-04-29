import 'package:flutter/material.dart';
import 'package:json_schema/json_schema.dart';

class FormErrorsDialog extends StatefulWidget {
  final List<ValidationError> validationErrors;
  final Map<String, dynamic> schema;
  const FormErrorsDialog({super.key, required this.validationErrors, required this.schema});

  @override
  State<FormErrorsDialog> createState() => _FormErrorsDialogState();
}

class _FormErrorsDialogState extends State<FormErrorsDialog> {
  String _schemaTitleBySchemaPath(ValidationError error) {
    // Remove leading slash and split the path
    final parts = error.schemaPath.split('/').where((p) => p.isNotEmpty).toList();
    dynamic current = widget.schema;

    for (final part in parts) {
      if (part == 'required') {
        continue;
      }
      if (current is Map<String, dynamic> && current.containsKey(part)) {
        current = current[part];
      } else if (current is List && int.tryParse(part) != null) {
        int idx = int.parse(part);
        if (idx >= 0 && idx < current.length) {
          current = current[idx];
        } else {
          return 'Not found in schema';
        }
      } else {
        return 'Not found in schema';
      }
    }

    return (current is Map && current.containsKey('title')) ? current['title'].toString() : 'Not found in schema';
  }

  String _getSchemaTitleFromInstancePath(ValidationError error) {
    // Remove leading slash and split the path
    final parts = error.instancePath.split('/').where((p) => p.isNotEmpty).toList();
    dynamic current = widget.schema;

    for (final part in parts) {
      if (current is Map<String, dynamic> && current.containsKey(part)) {
        current = current[part];
      } else if (current is List && int.tryParse(part) != null) {
        int idx = int.parse(part);
        if (idx >= 0 && idx < current.length) {
          current = current[idx];
        } else {
          return 'Not found in schema';
        }
      } else {
        return 'Not found in schema';
      }
    }

    return current?['title']?.toString() ?? 'Not found in schema';
  }

  String _parseErrorMessage(ValidationError error) {
    // Check if the error message is a list
    if (error.message.startsWith('required prop missing')) {
      return 'Required "something" in "${_schemaTitleBySchemaPath(error)}".';
    }

    return error.message.toString();
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Form Errors'),
      content: SingleChildScrollView(
        child: ListBody(
          children:
              widget.validationErrors.map((error) {
                return ListTile(
                  title: Text(_parseErrorMessage(error)),
                  subtitle: Text('${error.schemaPath} ${error.instancePath}'),
                  trailing: IconButton(
                    icon: const Icon(Icons.remove_red_eye),
                    onPressed: () {
                      // pop and return the error
                      Navigator.of(context).pop(error);
                    },
                  ),
                );
              }).toList(),
        ),
      ),
      actions: <Widget>[
        TextButton(
          child: const Text('OK'),
          onPressed: () {
            Navigator.of(context).pop();
          },
        ),
      ],
    );
  }
}
