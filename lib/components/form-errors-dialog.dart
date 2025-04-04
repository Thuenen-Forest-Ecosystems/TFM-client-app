import 'package:flutter/material.dart';
import 'package:json_schema/json_schema.dart';

class FormErrorsDialog extends StatefulWidget {
  final List<ValidationError> validationErrors;
  const FormErrorsDialog({super.key, required this.validationErrors});

  @override
  State<FormErrorsDialog> createState() => _FormErrorsDialogState();
}

class _FormErrorsDialogState extends State<FormErrorsDialog> {
  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Form Errors'),
      content: SingleChildScrollView(
        child: ListBody(
          children:
              widget.validationErrors.map((error) {
                return ListTile(
                  title: Text(error.message),
                  subtitle: Text('Path: ${error.instancePath}'),
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
