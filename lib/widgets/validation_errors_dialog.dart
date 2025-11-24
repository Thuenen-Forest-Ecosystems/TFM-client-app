import 'package:flutter/material.dart';
import 'package:terrestrial_forest_monitor/services/validation_service.dart';

class ValidationErrorsDialog extends StatelessWidget {
  final ValidationResult validationResult;
  final bool showActions;

  const ValidationErrorsDialog({
    super.key,
    required this.validationResult,
    this.showActions = true,
  });

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        leading: IconButton(
          icon: const Icon(Icons.close),
          onPressed: () => Navigator.of(context).pop(),
        ),
        title: Row(children: [const SizedBox(width: 8), const Text('Ergebnis der Prüfung')]),
      ),
      body: ListView.separated(
        padding: const EdgeInsets.all(16),
        itemCount: validationResult.errors.length,
        separatorBuilder: (context, index) => const Divider(),
        itemBuilder: (context, index) {
          final error = validationResult.errors[index];
          return ListTile(
            leading: CircleAvatar(child: Text('${index + 1}')),
            title: Text(error.message, style: const TextStyle(fontWeight: FontWeight.w500)),
            subtitle:
                error.schemaPath != null && error.schemaPath!.isNotEmpty
                    ? Padding(
                      padding: const EdgeInsets.only(top: 4.0),
                      child: Text('Pfad: ${error.schemaPath}'),
                    )
                    : null,
          );
        },
      ),
      bottomNavigationBar:
          showActions
              ? SafeArea(
                child: Padding(
                  padding: const EdgeInsets.all(16.0),
                  child: ElevatedButton(
                    onPressed: () => Navigator.of(context).pop(true),
                    style: ElevatedButton.styleFrom(minimumSize: const Size.fromHeight(48)),
                    child: const Text('SPEICHERN'),
                  ),
                ),
              )
              : null,
    );
  }

  static Future<bool?> show(
    BuildContext context,
    ValidationResult validationResult, {
    bool showActions = true,
  }) {
    return Navigator.of(context, rootNavigator: true).push<bool>(
      MaterialPageRoute(
        fullscreenDialog: true,
        builder:
            (context) => ValidationErrorsDialog(
              validationResult: validationResult,
              showActions: showActions,
            ),
      ),
    );
  }
}
