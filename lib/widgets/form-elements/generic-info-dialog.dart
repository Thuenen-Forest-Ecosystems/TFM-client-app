import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:terrestrial_forest_monitor/providers/language.dart';

/// A simple informational dialog that displays the schema metadata for a form
/// field: its title, description and type (plus unit when available), as well
/// as the current value and the value recorded in the previous survey cycle.
///
/// When a previous value exists the user can apply it to the field via the
/// "Set" action ([onApplyPrevious]).
///
/// Open it via [GenericInfoDialog.show], passing the same [fieldName] and
/// [fieldSchema] that the form element already has.
class _GenericInfoDialogWidget extends StatelessWidget {
  final String fieldName;
  final Map<String, dynamic> fieldSchema;
  final String? currentValueLabel;
  final String? previousValueLabel;
  final VoidCallback? onApplyPrevious;

  const _GenericInfoDialogWidget({
    required this.fieldName,
    required this.fieldSchema,
    this.currentValueLabel,
    this.previousValueLabel,
    this.onApplyPrevious,
  });

  String _getTitle(String langCode) {
    if (langCode != 'de') {
      final tfm = fieldSchema['\$tfm'] as Map<String, dynamic>?;
      final enTitle = tfm?['title_en'] as String?;
      if (enTitle != null) return enTitle;
    }
    return fieldSchema['title'] as String? ?? fieldName;
  }

  String? _getDescription(String langCode) {
    if (langCode != 'de') {
      final tfm = fieldSchema['\$tfm'] as Map<String, dynamic>?;
      final enDesc = tfm?['description_en'] as String?;
      if (enDesc != null) return enDesc;
    }
    return fieldSchema['description'] as String?;
  }

  String? _getType() {
    final typeValue = fieldSchema['type'];
    if (typeValue is String) return typeValue;
    if (typeValue is List) {
      return typeValue.firstWhere((t) => t != 'null' && t != null, orElse: () => null) as String?;
    }
    return null;
  }

  String? _getUnit() {
    final tfm = fieldSchema['\$tfm'] as Map<String, dynamic>?;
    return tfm?['unit_short'] as String? ?? fieldSchema['unit_short'] as String?;
  }

  @override
  Widget build(BuildContext context) {
    final langCode = context.select<Language, String>((l) => l.locale.languageCode);
    final isEn = langCode == 'en';

    final description = _getDescription(langCode);
    final type = _getType();
    final unit = _getUnit();

    final current = (currentValueLabel != null && currentValueLabel!.isNotEmpty)
        ? currentValueLabel!
        : '—';
    final hasPrevious = previousValueLabel != null && previousValueLabel!.isNotEmpty;
    // The current value already matches the previous survey, so applying it
    // would be a no-op — disable the "Set" action in that case.
    final isSameAsPrevious = hasPrevious && currentValueLabel == previousValueLabel;

    Widget row(String? label, String value) {
      return Padding(
        padding: const EdgeInsets.only(bottom: 12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (label != null)
              Text(
                label,
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                  color: Theme.of(context).colorScheme.primary,
                ),
              ),
            const SizedBox(height: 2),
            Text(value, style: const TextStyle(fontSize: 14)),
          ],
        ),
      );
    }

    return AlertDialog(
      title: Row(
        children: [
          //Icon(Icons.info_outline, color: Theme.of(context).colorScheme.primary),
          //const SizedBox(width: 8),
          Expanded(child: Text(_getTitle(langCode))),
          IconButton(
            icon: const Icon(Icons.close),
            tooltip: isEn ? 'Close' : 'Schließen',
            onPressed: () => Navigator.of(context).pop(),
          ),
        ],
      ),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            //row(isEn ? 'Field' : 'Feld', fieldName),
            if (description != null && description.isNotEmpty) row(null, description),
            //if (type != null) row(isEn ? 'Type' : 'Typ', type),
            //if (unit != null && unit.isNotEmpty) row(isEn ? 'Unit' : 'Einheit', unit),
            const Divider(height: 24),
            row(isEn ? 'Current value' : 'Aktueller Wert', current),
            if (hasPrevious)
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    isEn ? 'Previous survey' : 'Vorgängererhebung',
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                      color: Theme.of(context).colorScheme.primary,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Row(
                    children: [
                      Expanded(
                        child: Text(previousValueLabel!, style: const TextStyle(fontSize: 14)),
                      ),
                      const SizedBox(width: 8),
                      FilledButton.icon(
                        style: FilledButton.styleFrom(
                          backgroundColor: Theme.of(context).colorScheme.primaryContainer,
                          foregroundColor: Colors.black,
                        ),
                        label: const Icon(Icons.check, size: 18),
                        onPressed: (onApplyPrevious == null || isSameAsPrevious)
                            ? null
                            : () {
                                onApplyPrevious!();
                                Navigator.of(context).pop();
                              },
                        //label: Text(isEn ? 'Set' : 'Übernehmen'),
                      ),
                    ],
                  ),
                ],
              ),
          ],
        ),
      ),
      /*actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: Text(isEn ? 'Close' : 'Schließen'),
        ),
      ],*/
    );
  }
}

class GenericInfoDialog {
  static Future<void> show({
    required BuildContext context,
    required String fieldName,
    required Map<String, dynamic> fieldSchema,
    String? currentValueLabel,
    String? previousValueLabel,
    VoidCallback? onApplyPrevious,
  }) {
    return showDialog<void>(
      context: context,
      builder: (context) => _GenericInfoDialogWidget(
        fieldName: fieldName,
        fieldSchema: fieldSchema,
        currentValueLabel: currentValueLabel,
        previousValueLabel: previousValueLabel,
        onApplyPrevious: onApplyPrevious,
      ),
    );
  }
}
