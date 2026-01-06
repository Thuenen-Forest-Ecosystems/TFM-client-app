import 'package:flutter/material.dart';
import 'package:terrestrial_forest_monitor/services/validation_service.dart';
import 'package:terrestrial_forest_monitor/repositories/records_repository.dart';
import 'package:terrestrial_forest_monitor/services/powersync.dart';

class ValidationErrorsDialog extends StatefulWidget {
  final TFMValidationResult validationResult;
  final bool showActions;
  final Function(String?)? onNavigateToTab;
  final Record? record;

  const ValidationErrorsDialog({
    super.key,
    required this.validationResult,
    this.showActions = true,
    this.onNavigateToTab,
    this.record,
  });

  @override
  State<ValidationErrorsDialog> createState() => _ValidationErrorsDialogState();

  static Future<String?> show(
    BuildContext context,
    TFMValidationResult validationResult, {
    bool showActions = true,
    Function(String?)? onNavigateToTab,
    Record? record,
  }) {
    return Navigator.of(context, rootNavigator: true).push<String>(
      MaterialPageRoute(
        fullscreenDialog: true,
        builder: (context) => ValidationErrorsDialog(
          validationResult: validationResult,
          showActions: showActions,
          onNavigateToTab: onNavigateToTab,
          record: record,
        ),
      ),
    );
  }
}

class _ValidationErrorsDialogState extends State<ValidationErrorsDialog> {
  late final TextEditingController _noteController;

  @override
  void initState() {
    super.initState();
    _noteController = TextEditingController(text: widget.record?.note ?? '');
  }

  @override
  void dispose() {
    _noteController.dispose();
    super.dispose();
  }

  Future<void> _saveNote() async {
    if (widget.record == null) return;

    final noteText = _noteController.text.trim();
    final note = noteText.isNotEmpty ? noteText : null;

    try {
      await db.execute('UPDATE records SET note = ? WHERE id = ?', [note, widget.record!.id]);

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Notiz gespeichert'),
            backgroundColor: Colors.green,
            duration: Duration(seconds: 2),
          ),
        );
      }
    } catch (e) {
      debugPrint('Error saving note: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Fehler beim Speichern der Notiz: $e'),
            backgroundColor: Colors.red,
            duration: const Duration(seconds: 3),
          ),
        );
      }
    }
  }

  String? _getTabIdFromPath(
    String? instancePath,
    String? schemaPath,
    Map<String, dynamic>? params,
  ) {
    // Try instancePath first, fall back to schemaPath if instancePath is null/empty
    final pathToUse = (instancePath != null && instancePath.isNotEmpty) ? instancePath : schemaPath;

    String? fieldName;

    // For required field errors, the missing field name is in params.missingProperty
    if (params != null && params.containsKey('missingProperty')) {
      fieldName = params['missingProperty'] as String?;
      debugPrint('Found missing property in params: $fieldName');
    }

    // If we have a fieldName from params, use it directly
    if (fieldName != null && fieldName.isNotEmpty) {
      final tabMapping = {
        'tree': 'tree',
        'position': 'position',
        'edges': 'edges',
        'structure_lt4m': 'structure_lt4m',
        'structure_gt4m': 'structure_gt4m',
        'regeneration': 'regeneration',
        'deadwood': 'deadwood',
      };

      final tabId = tabMapping[fieldName];
      if (tabId != null) return tabId;
    }

    // Otherwise, try to parse from path
    if (pathToUse == null || pathToUse.isEmpty) return null;

    // Parse path like "/tree/0/dbh" or "#/properties/position/properties/coordinates"
    // For schemaPath, we need to extract from "#/properties/tree/..." format
    String cleanPath = pathToUse;
    if (cleanPath.startsWith('#/properties/')) {
      cleanPath = cleanPath.substring('#/properties/'.length);
      // Remove everything after the first segment (the tab name)
      final firstSlash = cleanPath.indexOf('/');
      if (firstSlash > 0) {
        cleanPath = cleanPath.substring(0, firstSlash);
      }
    }

    final parts = cleanPath.split('/').where((p) => p.isNotEmpty).toList();
    if (parts.isEmpty) return null;

    // First part is the tab id (tree, position, edges, etc.)
    final firstPart = parts[0];

    // Map known field names to tab IDs
    final tabMapping = {
      'tree': 'tree',
      'position': 'position',
      'edges': 'edges',
      'structure_lt4m': 'structure_lt4m',
      'structure_gt4m': 'structure_gt4m',
      'regeneration': 'regeneration',
      'deadwood': 'deadwood',
    };

    return tabMapping[firstPart];
  }

  String _getGroupName(String? instancePath) {
    if (instancePath == null || instancePath.isEmpty) return 'Allgemein';

    final parts = instancePath.split('/').where((p) => p.isNotEmpty).toList();
    if (parts.isEmpty) return 'Allgemein';

    final groupNames = {
      'tree': 'Bäume',
      'position': 'Position',
      'edges': 'Ecken',
      'structure_lt4m': 'Struktur <4m',
      'structure_gt4m': 'Struktur >4m',
      'regeneration': 'Verjüngung',
      'deadwood': 'Totholz',
    };

    return groupNames[parts[0]] ?? parts[0];
  }

  @override
  Widget build(BuildContext context) {
    final errorCount = widget.validationResult.allErrors.length;

    // Group errors by instance path
    final groupedIssues = <String, List<dynamic>>{};
    for (final issue in widget.validationResult.allIssues) {
      final instancePath = issue is ValidationError
          ? issue.instancePath
          : (issue as TFMValidationError).instancePath;

      // Extract the top-level path segment for grouping
      final groupKey = instancePath != null && instancePath.isNotEmpty
          ? instancePath.split('/').firstWhere((p) => p.isNotEmpty, orElse: () => 'root')
          : 'root';

      groupedIssues.putIfAbsent(groupKey, () => []).add(issue);
    }

    return Scaffold(
      appBar: AppBar(
        leading: IconButton(
          icon: const Icon(Icons.close),
          onPressed: () => Navigator.of(context).pop(),
        ),
        title: Row(children: [const SizedBox(width: 8), const Text('Ergebnis der Prüfung')]),
      ),
      body: Column(
        children: [
          Expanded(
            child: ListView.builder(
              itemCount: groupedIssues.length,
              itemBuilder: (context, groupIndex) {
                final groupKey = groupedIssues.keys.elementAt(groupIndex);
                final issues = groupedIssues[groupKey]!;
                final groupName = _getGroupName(groupKey != 'root' ? '/$groupKey' : null);

                final errorCountInGroup = issues.where((issue) {
                  if (issue is TFMValidationError) return issue.isError;
                  return true; // AJV errors are always errors
                }).length;

                final warningCountInGroup = issues.where((issue) {
                  if (issue is TFMValidationError) return issue.isWarning;
                  return false;
                }).length;

                return ExpansionTile(
                  initiallyExpanded: true,
                  leading: Icon(
                    errorCountInGroup > 0 ? Icons.error : Icons.warning,
                    color: errorCountInGroup > 0 ? Colors.red : Colors.orange,
                  ),
                  title: Text(groupName, style: const TextStyle(fontWeight: FontWeight.bold)),
                  subtitle: Text(
                    '${errorCountInGroup > 0 ? '$errorCountInGroup Fehler' : ''}${errorCountInGroup > 0 && warningCountInGroup > 0 ? ', ' : ''}${warningCountInGroup > 0 ? '$warningCountInGroup Warnungen' : ''}',
                  ),
                  children: issues.map((issue) {
                    final isTFMError = issue is TFMValidationError;
                    final isWarning = isTFMError && issue.isWarning;

                    final params = issue is ValidationError
                        ? issue.rawError['params'] as Map<String, dynamic>?
                        : null;
                    final instancePath = issue is ValidationError
                        ? issue.instancePath
                        : (issue as TFMValidationError).instancePath;
                    final schemaPath = issue is ValidationError ? issue.schemaPath : null;
                    final tabId = _getTabIdFromPath(instancePath, schemaPath, params);

                    final canNavigate = tabId != null && widget.onNavigateToTab != null;

                    // Build subtitle with additional TFM information
                    Widget? subtitle;
                    if (isTFMError) {
                      final tfmError = issue as TFMValidationError;
                      final subtitleParts = <String>[];

                      if (tfmError.note != null && tfmError.note!.isNotEmpty) {
                        subtitleParts.add('Hinweis: ${tfmError.note}');
                      }
                      if (tfmError.error?['code'] != null) {
                        subtitleParts.add('Code: ${tfmError.error!['code']}');
                      }
                      if (instancePath != null && instancePath.isNotEmpty) {
                        subtitleParts.add('Pfad: $instancePath');
                      }

                      if (subtitleParts.isNotEmpty) {
                        subtitle = Text(subtitleParts.join('\n'));
                      }
                    } else if (instancePath != null && instancePath.isNotEmpty) {
                      subtitle = Padding(
                        padding: const EdgeInsets.only(top: 4.0),
                        child: Text('Pfad: $instancePath'),
                      );
                    }

                    return ListTile(
                      leading: Icon(
                        isWarning ? Icons.warning : Icons.error,
                        color: isWarning ? Colors.orange : Colors.red,
                        size: 20,
                      ),
                      title: Text(
                        issue is ValidationError
                            ? issue.message
                            : (issue as TFMValidationError).message,
                      ),
                      subtitle: subtitle,
                      trailing: canNavigate ? const Icon(Icons.arrow_forward, size: 18) : null,
                      enabled: canNavigate,
                      dense: true,
                      onTap: canNavigate
                          ? () {
                              debugPrint('Navigating to tab: $tabId for issue: $instancePath');
                              widget.onNavigateToTab!(tabId);
                              Navigator.of(context).pop<String?>(null);
                            }
                          : null,
                    );
                  }).toList(),
                );
              },
            ),
          ),
        ],
      ),
      bottomNavigationBar: widget.showActions
          ? SafeArea(
              child: Padding(
                padding: const EdgeInsets.all(16.0),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    if (errorCount == 0)
                      TextField(
                        controller: _noteController,
                        decoration: const InputDecoration(
                          hintText: 'Fügen Sie hier eine Notiz hinzu...',
                          border: OutlineInputBorder(),
                          isDense: true,
                        ),
                        maxLines: 3,
                        minLines: 2,
                      ),
                    if (errorCount == 0) const SizedBox(height: 12),
                    Row(
                      children: [
                        /*Expanded(
                          child: ElevatedButton(
                            onPressed: () async {
                              await _saveNote();
                              if (mounted) {
                                Navigator.of(context).pop('save');
                              }
                            },
                            style: ElevatedButton.styleFrom(minimumSize: const Size.fromHeight(48)),
                            child: const Text('SPEICHERN'),
                          ),
                        ),
                        const SizedBox(width: 12),*/
                        Expanded(
                          child: ElevatedButton(
                            onPressed: errorCount == 0
                                ? () async {
                                    await _saveNote();
                                    if (mounted) {
                                      Navigator.of(context).pop('complete');
                                    }
                                  }
                                : null,
                            style: ElevatedButton.styleFrom(
                              minimumSize: const Size.fromHeight(48),
                              backgroundColor: Colors.green,
                            ),
                            child: Text(
                              errorCount == 0
                                  ? 'SPEICHERN UND ABSCHLIEßEN'
                                  : 'mindestens $errorCount zu behebende Fehler',
                            ),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            )
          : null,
    );
  }
}
