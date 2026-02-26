import 'package:flutter/material.dart';
import 'package:terrestrial_forest_monitor/services/validation_service.dart';
import 'package:terrestrial_forest_monitor/repositories/records_repository.dart';
import 'package:terrestrial_forest_monitor/services/powersync.dart';
import 'package:terrestrial_forest_monitor/models/acknowledged_error.dart';

/// Result returned from ValidationErrorsDialog
class ValidationDialogResult {
  final String action; // 'complete' or 'save'
  final Map<String, List<AcknowledgedError>> acknowledgedErrors;

  ValidationDialogResult({required this.action, required this.acknowledgedErrors});
}

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

  static Future<ValidationDialogResult?> show(
    BuildContext context,
    TFMValidationResult validationResult, {
    bool showActions = true,
    Function(String?)? onNavigateToTab,
    Record? record,
  }) {
    return Navigator.of(context, rootNavigator: true).push<ValidationDialogResult>(
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
  bool _hasSaved = false; // Guard against double saves
  bool _isPopping = false; // Guard against PopScope re-entry

  @override
  void initState() {
    super.initState();
    _noteController = TextEditingController(text: widget.record?.note ?? '');

    // Initialize controllers for each issue
    _initializeIssueControllers();
  }

  /// Normalize a path value: treat null and empty string as equivalent ('root')
  String _normalizePath(String? path) {
    if (path == null || path.isEmpty) return 'root';
    return path;
  }

  /// Build a stable key from an AcknowledgedError (saved data)
  String _savedErrorKey(AcknowledgedError error) {
    return '${_normalizePath(error.instancePath)}-${_normalizePath(error.schemaPath)}-${error.message}-${error.source}';
  }

  void _initializeIssueControllers() {
    // Load previously saved acknowledged errors if record exists
    Map<String, AcknowledgedError> savedErrors = {};
    if (widget.record != null) {
      debugPrint('🔑 Loading saved errors from record ${widget.record!.id}');
      debugPrint('🔑 validationErrors: ${widget.record!.validationErrors}');
      debugPrint('🔑 plausibilityErrors: ${widget.record!.plausibilityErrors}');

      // Load validation errors (AJV errors)
      debugPrint('🔑 Decoding validation errors...');
      final validationErrorsList = AcknowledgedError.decodeList(widget.record!.validationErrors);
      debugPrint('🔑 Decoded ${validationErrorsList.length} validation errors');
      for (var error in validationErrorsList) {
        final key = _savedErrorKey(error);
        savedErrors[key] = error;
        debugPrint('🔑 Saved AJV error key: $key');
      }

      // Load plausibility errors (TFM errors)
      debugPrint('🔑 Decoding plausibility errors...');
      final plausibilityErrorsList = AcknowledgedError.decodeList(
        widget.record!.plausibilityErrors,
      );
      debugPrint('🔑 Decoded ${plausibilityErrorsList.length} plausibility errors');
      for (var error in plausibilityErrorsList) {
        final key = _savedErrorKey(error);
        savedErrors[key] = error;
        debugPrint('🔑 Saved TFM error key: $key');
      }
    }

    debugPrint('🔑 Total saved errors loaded: ${savedErrors.length}');
    if (savedErrors.isNotEmpty) {
      debugPrint('🔑 All saved error keys:');
      for (var key in savedErrors.keys) {
        debugPrint('🔑   - "$key"');
      }
    }

    // Initialize controllers for each issue
    for (var i = 0; i < widget.validationResult.allIssues.length; i++) {
      final issue = widget.validationResult.allIssues[i];
      final issueKey = _getIssueKey(issue, i);

      debugPrint('🔑 Checking issue: $issueKey');

      // Check if this issue was previously acknowledged
      final savedError = savedErrors[issueKey];
      if (savedError != null) {
        // Pre-check the acknowledgment checkbox
        _acknowledgedIssues[issueKey] = true;
        // Pre-fill the note
        _issueNoteControllers[issueKey] = TextEditingController(text: savedError.note ?? '');
      } else {
        _issueNoteControllers[issueKey] = TextEditingController();
      }
    }
  }

  String _getIssueKey(dynamic issue, int index) {
    final instancePath = issue is ValidationError
        ? issue.instancePath
        : (issue as TFMValidationError).instancePath;
    final schemaPath = issue is ValidationError ? issue.schemaPath : null;
    final message = issue is ValidationError
        ? issue.message
        : (issue as TFMValidationError).message;
    final source = issue is ValidationError ? 'ajv' : 'tfm';
    // Use stable identifier based on path and message, not index
    // Normalize empty strings to 'root'/'none' to match saved error keys
    return '${_normalizePath(instancePath)}-${_normalizePath(schemaPath)}-$message-$source';
  }

  /// Close the dialog after saving acknowledged errors
  Future<void> _closeDialog() async {
    if (_isPopping) {
      debugPrint('🚪 _closeDialog: Already popping, ignoring');
      return;
    }

    _isPopping = true;
    debugPrint('🚪 _closeDialog: Saving before close...');
    await _saveAcknowledgedErrorsToDatabase();

    if (mounted) {
      Navigator.of(context).pop();
    }
  }

  @override
  void dispose() {
    // Save is handled explicitly in PopScope/X-button/submit before popping.
    // _hasSaved guard prevents any duplicate save attempts.
    _noteController.dispose();
    for (var controller in _issueNoteControllers.values) {
      controller.dispose();
    }
    super.dispose();
  }

  /// Save acknowledged errors to database
  /// Returns true if save was successful, false otherwise
  /// Uses _hasSaved guard to prevent double saves from racing
  Future<bool> _saveAcknowledgedErrorsToDatabase() async {
    if (widget.record == null || widget.record!.id == null) {
      debugPrint('💾 Skip save: no record or record ID');
      return false;
    }

    if (_hasSaved) {
      debugPrint('💾 Skip save: already saved this session');
      return true;
    }

    try {
      _hasSaved = true;

      // Don't require notes for auto-save (save work in progress)
      final acknowledged = _collectAcknowledgedErrors(requireNotes: false);
      final validationErrors = acknowledged['validation_errors'] ?? [];
      final plausibilityErrors = acknowledged['plausibility_errors'] ?? [];

      final validationErrorsJson = validationErrors.isNotEmpty
          ? AcknowledgedError.encodeList(validationErrors)
          : null;
      final plausibilityErrorsJson = plausibilityErrors.isNotEmpty
          ? AcknowledgedError.encodeList(plausibilityErrors)
          : null;

      debugPrint('💾 Saving acknowledged errors to DB for record ${widget.record!.id}');
      debugPrint('💾 validation_errors: ${validationErrors.length} items');
      debugPrint('💾 plausibility_errors: ${plausibilityErrors.length} items');
      debugPrint('💾 validationErrorsJson type: ${validationErrorsJson.runtimeType}');
      debugPrint(
        '💾 validationErrorsJson: ${validationErrorsJson?.substring(0, validationErrorsJson.length > 150 ? 150 : validationErrorsJson.length)}',
      );
      debugPrint('💾 plausibilityErrorsJson type: ${plausibilityErrorsJson.runtimeType}');
      debugPrint(
        '💾 plausibilityErrorsJson: ${plausibilityErrorsJson?.substring(0, plausibilityErrorsJson.length > 150 ? 150 : plausibilityErrorsJson.length)}',
      );

      // Debug: Print what we're saving
      if (validationErrors.isNotEmpty) {
        debugPrint('💾 Saving validation errors:');
        for (var err in validationErrors) {
          debugPrint('💾   Key would be: ${_savedErrorKey(err)}');
          debugPrint('💾   Note: ${err.note}');
        }
      }
      if (plausibilityErrors.isNotEmpty) {
        debugPrint('💾 Saving plausibility errors:');
        for (var err in plausibilityErrors) {
          debugPrint('💾   Key would be: ${_savedErrorKey(err)}');
          debugPrint('💾   Note: ${err.note}');
        }
      }

      await db.execute(
        'UPDATE records SET validation_errors = ?, plausibility_errors = ? WHERE id = ?',
        [validationErrorsJson, plausibilityErrorsJson, widget.record!.id],
      );

      debugPrint('💾 ✅ Save successful');
      return true;
    } catch (e) {
      debugPrint('💾 ❌ Error saving acknowledged errors: $e');
      _hasSaved = false; // Allow retry on error
      return false;
    }
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
            content: Text('Trakt wurde gespeichert.'),
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

  Map<String, List<AcknowledgedError>> _collectAcknowledgedErrors({bool requireNotes = true}) {
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

      // For errors, note is mandatory (when requireNotes is true)
      if (requireNotes && isError && (note == null || note.isEmpty)) {
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

  bool _validateAcknowledgedErrors() {
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

    return true;
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

  int get _unacknowledgedErrorsCount {
    int count = 0;
    for (var i = 0; i < widget.validationResult.allErrors.length; i++) {
      final issue = widget.validationResult.allErrors[i];
      final issueKey = _getIssueKey(issue, widget.validationResult.allIssues.indexOf(issue));
      final isAcknowledged = _acknowledgedIssues[issueKey] == true;
      final hasNote = _issueNoteControllers[issueKey]?.text.trim().isNotEmpty ?? false;

      if (!isAcknowledged || !hasNote) {
        count++;
      }
    }
    return count;
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

    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (bool didPop, dynamic result) async {
        // This callback handles system back button and gestures
        if (didPop || _isPopping) {
          debugPrint('🚪 PopScope: Already popping, skipping');
          return;
        }

        // System back button was pressed - close the dialog
        await _closeDialog();
      },
      child: Scaffold(
        appBar: AppBar(
          leading: IconButton(icon: const Icon(Icons.close), onPressed: _closeDialog),
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
                      /*if (errorCount == 0)
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
                    if (errorCount == 0) const SizedBox(height: 12),*/
                      Row(
                        children: [
                          Expanded(
                            child: ElevatedButton(
                              onPressed: _unacknowledgedErrorsCount > 0
                                  ? null
                                  : () async {
                                      // Validate acknowledged errors
                                      if (!_validateAcknowledgedErrors()) return;

                                      // Collect all acknowledged errors (including warnings without notes)
                                      // _validateAcknowledgedErrors already ensures errors have notes
                                      final acknowledged = _collectAcknowledgedErrors(
                                        requireNotes: false,
                                      );

                                      debugPrint('📋 === DIALOG SUBMIT ===');
                                      debugPrint(
                                        '📋 validation_errors collected: ${acknowledged['validation_errors']?.length ?? 0}',
                                      );
                                      debugPrint(
                                        '📋 plausibility_errors collected: ${acknowledged['plausibility_errors']?.length ?? 0}',
                                      );
                                      debugPrint(
                                        '📋 Action: ${errorCount == 0 ? 'complete' : 'save'}',
                                      );

                                      if (mounted) {
                                        // Mark as saved so PopScope's callback skips DB save
                                        // (the acknowledged errors are returned in the result
                                        // and will be written by save() in properties-edit)
                                        _hasSaved = true;

                                        final action = errorCount == 0 ? 'complete' : 'save';
                                        Navigator.of(context).pop(
                                          ValidationDialogResult(
                                            action: action,
                                            acknowledgedErrors: acknowledged,
                                          ),
                                        );
                                      }
                                    },
                              style: ElevatedButton.styleFrom(
                                backgroundColor: _unacknowledgedErrorsCount == 0
                                    ? Theme.of(context).colorScheme.primary
                                    : null,
                                foregroundColor: _unacknowledgedErrorsCount == 0
                                    ? Theme.of(context).colorScheme.onPrimary
                                    : null,
                              ),
                              child: Text(
                                _unacknowledgedErrorsCount == 0
                                    ? 'AN LANDESINVENTURLEITUNG ÜBERMITTELN'
                                    : '$_unacknowledgedErrorsCount Fehler beheben oder kommentieren',
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
      ), // Scaffold
    ); // PopScope
  }
}
