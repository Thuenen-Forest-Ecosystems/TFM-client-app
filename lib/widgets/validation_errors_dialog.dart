import 'package:flutter/material.dart';
import 'package:terrestrial_forest_monitor/services/validation_service.dart';
import 'package:terrestrial_forest_monitor/repositories/records_repository.dart';
import 'package:terrestrial_forest_monitor/services/powersync.dart';
import 'package:terrestrial_forest_monitor/models/acknowledged_error.dart';

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
  final Map<String, bool> _acknowledgedIssues = {};
  final Map<String, TextEditingController> _issueNoteControllers = {};

  @override
  void initState() {
    super.initState();
    _noteController = TextEditingController(text: widget.record?.note ?? '');

    // Initialize controllers for each issue
    _initializeIssueControllers();
  }

  void _initializeIssueControllers() {
    for (var i = 0; i < widget.validationResult.allIssues.length; i++) {
      final issue = widget.validationResult.allIssues[i];
      final issueKey = _getIssueKey(issue, i);
      _issueNoteControllers[issueKey] = TextEditingController();
    }
  }

  String _getIssueKey(dynamic issue, int index) {
    final instancePath = issue is ValidationError
        ? issue.instancePath
        : (issue as TFMValidationError).instancePath;
    final message = issue is ValidationError
        ? issue.message
        : (issue as TFMValidationError).message;
    return '$index-$instancePath-$message';
  }

  @override
  void dispose() {
    _noteController.dispose();
    for (var controller in _issueNoteControllers.values) {
      controller.dispose();
    }
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

  Future<Map<String, List<AcknowledgedError>>> _collectAcknowledgedErrors() async {
    final validationErrors = <AcknowledgedError>[];
    final plausibilityErrors = <AcknowledgedError>[];

    for (var i = 0; i < widget.validationResult.allIssues.length; i++) {
      final issue = widget.validationResult.allIssues[i];
      final issueKey = _getIssueKey(issue, i);

      // Only include acknowledged issues
      if (_acknowledgedIssues[issueKey] != true) continue;

      final isAJVError = issue is ValidationError;
      final isTFMError = issue is TFMValidationError;
      final isWarning = isTFMError && issue.isWarning;
      final isError = !isWarning;

      final instancePath = issue is ValidationError
          ? issue.instancePath
          : (issue as TFMValidationError).instancePath;
      final message = issue is ValidationError
          ? issue.message
          : (issue as TFMValidationError).message;
      final note = _issueNoteControllers[issueKey]?.text.trim();

      // For errors, note is mandatory
      if (isError && (note == null || note.isEmpty)) {
        continue; // Skip errors without notes
      }

      final acknowledgedError = AcknowledgedError(
        message: message,
        instancePath: instancePath,
        schemaPath: isAJVError ? issue.schemaPath : null,
        type: isWarning ? 'warning' : 'error',
        source: isAJVError ? 'ajv' : 'tfm',
        note: note,
        rawError: isAJVError ? issue.rawError : (issue as TFMValidationError).error ?? {},
      );

      if (isAJVError) {
        validationErrors.add(acknowledgedError);
      } else {
        plausibilityErrors.add(acknowledgedError);
      }
    }

    return {'validation_errors': validationErrors, 'plausibility_errors': plausibilityErrors};
  }

  Future<bool> _saveAcknowledgedErrors() async {
    if (widget.record == null) return false;

    final acknowledged = await _collectAcknowledgedErrors();
    final validationErrors = acknowledged['validation_errors']!;
    final plausibilityErrors = acknowledged['plausibility_errors']!;

    // Check if all errors (not warnings) have been acknowledged with notes
    final unacknowledgedErrors = widget.validationResult.allErrors.where((issue) {
      for (var i = 0; i < widget.validationResult.allIssues.length; i++) {
        if (widget.validationResult.allIssues[i] == issue) {
          final issueKey = _getIssueKey(issue, i);
          final isAcknowledged = _acknowledgedIssues[issueKey] == true;
          final hasNote = _issueNoteControllers[issueKey]?.text.trim().isNotEmpty ?? false;
          if (!isAcknowledged || !hasNote) return true;
        }
      }
      return false;
    }).toList();

    if (unacknowledgedErrors.isNotEmpty) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              'Alle Fehler müssen mit einer Notiz bestätigt werden (${unacknowledgedErrors.length} verbleibend)',
            ),
            duration: const Duration(seconds: 3),
          ),
        );
      }
      return false;
    }

    try {
      final validationErrorsJson = validationErrors.isNotEmpty
          ? AcknowledgedError.encodeList(validationErrors)
          : null;
      final plausibilityErrorsJson = plausibilityErrors.isNotEmpty
          ? AcknowledgedError.encodeList(plausibilityErrors)
          : null;

      await db.execute(
        'UPDATE records SET validation_errors = ?, plausibility_errors = ? WHERE id = ?',
        [validationErrorsJson, plausibilityErrorsJson, widget.record!.id],
      );

      return true;
    } catch (e) {
      debugPrint('Error saving acknowledged errors: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Fehler beim Speichern: $e'),
            backgroundColor: Colors.red,
            duration: const Duration(seconds: 3),
          ),
        );
      }
      return false;
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
        'position': 'position_column',
        'edges': 'edges',
        'structure_lt4m': 'stocking',
        'structure_gt4m': 'stocking',
        'regeneration': 'regeneration_grid',
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
    if (parts.isEmpty) return 'habitat_and_stocking';

    // First part is the tab id (tree, position, edges, etc.)
    final firstPart = parts[0];

    // Map known field names to tab IDs from style-map.json
    final tabMapping = {
      'tree': 'tree',
      'position': 'position_column',
      'edges': 'edges',
      'structure_lt4m': 'stocking',
      'structure_gt4m': 'stocking',
      'regeneration': 'regeneration_grid',
      'deadwood': 'deadwood',
    };

    // Default to first tab "Ecke" if no match found
    return tabMapping[firstPart] ?? 'habitat_and_stocking';
  }

  String _getGroupName(String? instancePath) {
    if (instancePath == null || instancePath.isEmpty) return 'Ecke';

    final parts = instancePath.split('/').where((p) => p.isNotEmpty).toList();
    if (parts.isEmpty) return 'Ecke';

    final firstPart = parts[0];

    // Map field names to their tab labels from style-map.json
    final groupNames = {
      'tree': 'WZP',
      'position': 'Position',
      'edges': 'Ränder',
      'structure_lt4m': 'Struktur < 4m',
      'structure_gt4m': 'Struktur > 4m',
      'structure': 'Bestockung', // Normalized key for grouping
      'regeneration': 'Verjüngung',
      'deadwood': 'Totholz',
    };

    return groupNames[firstPart] ?? 'Ecke';
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
      String groupKey = instancePath != null && instancePath.isNotEmpty
          ? instancePath.split('/').firstWhere((p) => p.isNotEmpty, orElse: () => 'root')
          : 'root';

      // Normalize groupKey so structure_lt4m and structure_gt4m are grouped together
      if (groupKey == 'structure_lt4m' || groupKey == 'structure_gt4m') {
        groupKey = 'structure';
      }

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
                  title: Text(groupName, style: const TextStyle(fontWeight: FontWeight.bold)),
                  subtitle: Text(
                    '${errorCountInGroup > 0 ? '$errorCountInGroup Fehler' : ''}${errorCountInGroup > 0 && warningCountInGroup > 0 ? ', ' : ''}${warningCountInGroup > 0 ? '$warningCountInGroup Warnungen' : ''}',
                  ),
                  children: issues.asMap().entries.map((entry) {
                    final globalIndex = widget.validationResult.allIssues.indexOf(entry.value);
                    final issue = entry.value;
                    final isTFMError = issue is TFMValidationError;
                    final isWarning = isTFMError && issue.isWarning;
                    final isError = !isWarning;

                    final params = issue is ValidationError
                        ? issue.rawError['params'] as Map<String, dynamic>?
                        : null;
                    final instancePath = issue is ValidationError
                        ? issue.instancePath
                        : (issue as TFMValidationError).instancePath;
                    final schemaPath = issue is ValidationError ? issue.schemaPath : null;
                    final tabId = _getTabIdFromPath(instancePath, schemaPath, params);

                    final canNavigate = tabId != null && widget.onNavigateToTab != null;

                    final issueKey = _getIssueKey(issue, globalIndex);
                    final isAcknowledged = _acknowledgedIssues[issueKey] ?? false;

                    // Build subtitle with additional TFM information
                    Widget? subtitle;
                    if (isTFMError) {
                      final tfmError = issue as TFMValidationError;
                      final subtitleParts = <String>[];

                      if (tfmError.note != null && tfmError.note!.isNotEmpty) {
                        subtitleParts.add('Hinweis: ${tfmError.note}');
                      }
                      if (tfmError.error?['code'] != null) {
                        final code = tfmError.error!['code'];
                        // Show debugInfo for technical errors (code 1 or 2)
                        if ((code == 1 || code == 2) && tfmError.debugInfo != null) {
                          subtitleParts.add('Debug: ${tfmError.debugInfo}');
                        } else {
                          subtitleParts.add('Code: $code');
                        }
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

                    return Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        ListTile(
                          leading: widget.showActions
                              ? Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    Checkbox(
                                      value: isAcknowledged,
                                      onChanged: (value) {
                                        setState(() {
                                          _acknowledgedIssues[issueKey] = value ?? false;
                                        });
                                      },
                                    ),
                                    Icon(
                                      isWarning ? Icons.warning : Icons.error,
                                      color: isWarning ? Colors.orange : Colors.red,
                                      size: 20,
                                    ),
                                  ],
                                )
                              : Icon(
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
                          trailing: widget.showActions && canNavigate
                              ? IconButton(
                                  icon: const Icon(Icons.arrow_forward, size: 18),
                                  onPressed: () {
                                    debugPrint(
                                      'Navigating to tab: $tabId for issue: $instancePath',
                                    );
                                    widget.onNavigateToTab!(tabId);
                                    Navigator.of(context).pop<String?>(null);
                                  },
                                )
                              : null,
                          selected: isAcknowledged,
                          dense: true,
                          onTap: widget.showActions
                              ? () {
                                  setState(() {
                                    _acknowledgedIssues[issueKey] = !isAcknowledged;
                                  });
                                }
                              : null,
                        ),
                        if (isAcknowledged)
                          Padding(
                            padding: const EdgeInsets.only(left: 72.0, right: 16.0, bottom: 8.0),
                            child: TextField(
                              controller: _issueNoteControllers[issueKey],
                              decoration: InputDecoration(
                                hintText: isError
                                    ? 'Notiz hinzufügen (erforderlich für Fehler)*'
                                    : 'Notiz hinzufügen (optional)',
                                border: const OutlineInputBorder(),
                                isDense: true,
                                errorText:
                                    isError &&
                                        (_issueNoteControllers[issueKey]?.text.trim().isEmpty ??
                                            true)
                                    ? 'Notiz erforderlich'
                                    : null,
                              ),
                              maxLines: 2,
                              minLines: 1,
                              onChanged: (_) => setState(() {}),
                            ),
                          ),
                      ],
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
                        Expanded(
                          child: ElevatedButton(
                            onPressed: () async {
                              // Save acknowledged errors
                              final success = await _saveAcknowledgedErrors();
                              if (!success) return;

                              // Save general note
                              await _saveNote();

                              if (mounted) {
                                Navigator.of(context).pop(errorCount == 0 ? 'complete' : 'save');
                              }
                            },
                            style: ElevatedButton.styleFrom(
                              backgroundColor: errorCount == 0 ? Colors.green : null,
                            ),
                            child: Text(
                              errorCount == 0
                                  ? 'SPEICHERN UND ABSCHLIEßEN'
                                  : 'mindestens $errorCount Fehler behebenden oder kommentieren',
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
