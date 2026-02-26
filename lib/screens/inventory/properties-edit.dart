import 'dart:convert';
import 'dart:async';
import 'package:universal_io/io.dart';
import 'package:latlong2/latlong.dart';
import 'package:path_provider/path_provider.dart';

import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';
import 'package:provider/provider.dart';
//import 'package:maplibre_gl/maplibre_gl.dart';
import 'package:terrestrial_forest_monitor/repositories/records_repository.dart' as repo;
import 'package:terrestrial_forest_monitor/repositories/schema_repository.dart';

import 'package:terrestrial_forest_monitor/widgets/form-elements/form-wrapper.dart';
import 'package:terrestrial_forest_monitor/widgets/validation_errors_dialog.dart';
import 'package:terrestrial_forest_monitor/models/acknowledged_error.dart';
import 'package:terrestrial_forest_monitor/widgets/auth/if-database-admin.dart';
import 'package:terrestrial_forest_monitor/services/validation_service.dart';
import 'package:terrestrial_forest_monitor/services/conditional_rules_service.dart';
import 'package:terrestrial_forest_monitor/services/powersync.dart';
import 'package:terrestrial_forest_monitor/services/utils.dart';
import 'package:terrestrial_forest_monitor/providers/map_controller_provider.dart';
import 'package:terrestrial_forest_monitor/providers/gps-position.dart';
import 'package:terrestrial_forest_monitor/providers/records_list_provider.dart';
import 'package:terrestrial_forest_monitor/widgets/cluster_info_dialog.dart';
import 'package:terrestrial_forest_monitor/widgets/new_record_dialog.dart';
import 'package:terrestrial_forest_monitor/widgets/submission_success_dialog.dart';

import 'package:beamer/beamer.dart';

class PropertiesEdit extends StatefulWidget {
  final String clusterName;
  final String plotName;

  const PropertiesEdit({super.key, required this.clusterName, required this.plotName});

  @override
  State<PropertiesEdit> createState() => _PropertiesEditState();
}

class _PropertiesEditState extends State<PropertiesEdit> {
  repo.Record? _record;
  bool _isLoading = true;
  String? _error;
  Map<String, dynamic>? _jsonSchema;
  Map<String, dynamic>? _originalJsonSchema; // Unmodified schema for applying conditional rules
  Map<String, dynamic>? _rootSchema; // Full root schema (not just plot items)
  Map<String, dynamic>? _formData;
  Map<String, dynamic>? _initialFormData;
  Map<String, dynamic>? _previousFormData;
  TFMValidationResult? _validationResult;
  bool _isValidating = false;
  bool _hasCompletedInitialValidation = false;
  bool _isSaving = false;
  late SchemaRepository schemaRepository;
  MapControllerProvider? _mapProvider;
  int? _loadedSchemaVersion;
  String? _schemaDirectory;
  Map<String, dynamic>? _styleData;
  late final GlobalKey<FormWrapperState> _formWrapperKey;
  List<ConditionalRule> _conditionalRules = [];
  Timer? _validationDebounceTimer;

  /// Whether the form data has been modified since last load/save.
  bool get _hasUnsavedChanges {
    if (_formData == null && _initialFormData == null) return false;
    if (_formData == null || _initialFormData == null) return true;
    return jsonEncode(_formData) != jsonEncode(_initialFormData);
  }

  @override
  void initState() {
    super.initState();

    _formWrapperKey = GlobalKey<FormWrapperState>();
    schemaRepository = SchemaRepository();

    _loadRecord().then((_) {
      // Load schema after record is loaded to get the interval name
      if (_record != null) {
        _loadSchema(_record!.schemaName, schemaIdValidatedBy: _record!.schemaIdValidatedBy).then((
          _,
        ) {
          // validate initial form data after schema is loaded
          if (_formData != null) {
            _onFormDataChanged(_formData!);
          }
        });
      }
    });
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();

    // Store map provider reference while context is valid
    if (_mapProvider == null) {
      try {
        _mapProvider = context.read<MapControllerProvider>();
      } catch (e) {
        debugPrint('MapControllerProvider not available: $e');
      }
    }
  }

  @override
  void dispose() {
    // Cancel any pending validation timer
    _validationDebounceTimer?.cancel();

    // Clear distance line and focused record immediately when leaving
    // Only clear if the focused record matches this page's record
    // This prevents clearing when navigating between different properties-edit pages
    if (_mapProvider != null && _record != null) {
      // Schedule cleanup after frame to avoid calling notifyListeners during dispose
      SchedulerBinding.instance.addPostFrameCallback((_) {
        try {
          _mapProvider!.clearDistanceLine();

          // Only clear focused record if it's the same as this page's record
          if (_mapProvider!.focusedRecord?.id == _record!.id) {
            _mapProvider!.clearFocusedRecord();
            debugPrint('Distance line and focused record cleared on dispose (record matched)');
          } else {
            debugPrint('Distance line cleared but focused record preserved (different record)');
          }
        } catch (e) {
          debugPrint('Error clearing map state on dispose: $e');
        }
      });
    }

    super.dispose();
  }

  /// Deep copy a map to avoid mutating the original
  Map<String, dynamic> _deepCopyMap(Map<String, dynamic> original) {
    final copy = <String, dynamic>{};
    original.forEach((key, value) {
      if (value is Map<String, dynamic>) {
        copy[key] = _deepCopyMap(value);
      } else if (value is List) {
        copy[key] = _deepCopyList(value);
      } else {
        copy[key] = value;
      }
    });
    return copy;
  }

  /// Deep copy a list to avoid mutating the original
  List<dynamic> _deepCopyList(List<dynamic> original) {
    return original.map((item) {
      if (item is Map<String, dynamic>) {
        return _deepCopyMap(item);
      } else if (item is List) {
        return _deepCopyList(item);
      } else {
        return item;
      }
    }).toList();
  }

  Future<void> _loadSchema(String intervalName, {String? schemaIdValidatedBy}) async {
    try {
      // Prefer validated schema if available, otherwise get latest
      SchemaModel? latestSchema;

      if (schemaIdValidatedBy != null) {
        debugPrint('Loading validated schema: $schemaIdValidatedBy');
        latestSchema = await schemaRepository.getById(schemaIdValidatedBy);

        if (latestSchema == null) {
          debugPrint('Validated schema not found, falling back to latest');
          latestSchema = await schemaRepository.getLatestForInterval(intervalName);
        }
      } else {
        debugPrint('No validated schema ID, loading latest for interval: $intervalName');
        latestSchema = await schemaRepository.getLatestForInterval(intervalName);
      }

      if (latestSchema == null) {
        debugPrint('No schema found for interval: $intervalName');
        setState(() {
          _error = 'Kein Schema gefunden für: $intervalName';
        });
        return;
      }

      debugPrint('Found schema: ${latestSchema.title} (version: ${latestSchema.version})');
      debugPrint('Schema directory: ${latestSchema.directory}');
      debugPrint('Schema has schemaData: ${latestSchema.schemaData != null}');
      debugPrint('Schema has styleDefault: ${latestSchema.styleDefault != null}');
      debugPrint('Schema has plausabilityScript: ${latestSchema.plausabilityScript != null}');

      // Store loaded schema version for display
      setState(() {
        _loadedSchemaVersion = latestSchema!.version;
        _schemaDirectory = latestSchema.directory;
      });

      // Determine which style to use based on control troop status
      final isControlTroop = await getCurrentIsControlTroop() ?? false;
      debugPrint('Using ${isControlTroop ? "CONTROL" : "DEFAULT"} style');

      final styleToUse = isControlTroop ? latestSchema.styleControl : latestSchema.styleDefault;

      // Validate that required style exists
      if (isControlTroop && latestSchema.styleControl == null) {
        debugPrint('❌ ERROR: Control troop requires style_control but it is NULL');
        if (mounted) {
          setState(() {
            _error = 'Kontroll-Trupp benötigt style_control Schema, aber es ist nicht verfügbar';
            _isLoading = false;
          });
        }
        return;
      }

      // Load conditional rules from schema table data first, with file fallback
      List<ConditionalRule> conditionalRules = [];
      try {
        conditionalRules = await ConditionalRulesService().loadRules(
          styleData: styleToUse,
          directory: latestSchema.directory,
        );
        debugPrint('📌 Loaded ${conditionalRules.length} conditional rules');
      } catch (rulesError) {
        debugPrint('❌ Error loading conditional rules: $rulesError');
      }

      debugPrint('Loading schema data (from database or files)');

      try {
        Map<String, dynamic>? validationSchema;
        String? tfmValidationCode;
        final directory = latestSchema.directory;

        // First try: Use data from schema table columns (regardless of directory)
        if (latestSchema.schemaData != null) {
          debugPrint('✅ Schema data found in database, attempting to extract validation schema');
          debugPrint('Schema data keys: ${latestSchema.schemaData!.keys.toList()}');

          // Safely navigate nested structure with debugging
          final schemaData = latestSchema.schemaData!;
          if (schemaData.containsKey('properties')) {
            final properties = schemaData['properties'] as Map<String, dynamic>?;
            debugPrint('Properties keys: ${properties?.keys.toList()}');

            if (properties != null && properties.containsKey('plot')) {
              final plot = properties['plot'] as Map<String, dynamic>?;
              debugPrint('Plot keys: ${plot?.keys.toList()}');

              if (plot != null && plot.containsKey('items')) {
                validationSchema = plot['items'] as Map<String, dynamic>?;
                debugPrint('✅ Successfully extracted validation schema from database');
              } else {
                debugPrint('❌ "items" key not found in plot object');
              }
            } else {
              debugPrint('❌ "plot" key not found in properties object');
            }
          } else {
            debugPrint('❌ "properties" key not found in schema data');
          }
        }

        if (latestSchema.plausabilityScript != null) {
          debugPrint('✅ Using plausability script from database');
          tfmValidationCode = latestSchema.plausabilityScript;
        }

        // Fallback: Load from downloaded files if not in database
        if (directory != null) {
          final appDirectory = await getApplicationDocumentsDirectory();

          if (validationSchema == null) {
            debugPrint('⚠️ Falling back to loading validation.json from file: $directory');
            final validationFilePath =
                '${appDirectory.path}/TFM/validation/$directory/validation.json';
            final validationFile = File(validationFilePath);

            if (await validationFile.exists()) {
              final validationContent = await validationFile.readAsString();
              final Map<String, dynamic> validationJson = jsonDecode(validationContent);
              debugPrint('Validation file keys: ${validationJson.keys.toList()}');

              // Safely navigate nested structure with debugging
              if (validationJson.containsKey('properties')) {
                final properties = validationJson['properties'] as Map<String, dynamic>?;
                debugPrint('Properties keys from file: ${properties?.keys.toList()}');

                if (properties != null && properties.containsKey('plot')) {
                  final plot = properties['plot'] as Map<String, dynamic>?;
                  debugPrint('Plot keys from file: ${plot?.keys.toList()}');

                  if (plot != null && plot.containsKey('items')) {
                    validationSchema = plot['items'] as Map<String, dynamic>?;
                    debugPrint('✅ Loaded validation schema from file');
                  } else {
                    debugPrint('❌ "items" key not found in plot object from file');
                  }
                } else {
                  debugPrint('❌ "plot" key not found in properties object from file');
                }
              } else {
                debugPrint('❌ "properties" key not found in validation file');
              }
            } else {
              debugPrint('❌ validation.json not found at: $validationFilePath');
            }
          }

          if (tfmValidationCode == null) {
            debugPrint('⚠️ Falling back to loading bundle.umd.js from file: $directory');
            final tfmFilePath = '${appDirectory.path}/TFM/validation/$directory/bundle.umd.js';
            final tfmFile = File(tfmFilePath);

            if (await tfmFile.exists()) {
              tfmValidationCode = await tfmFile.readAsString();
              debugPrint('✅ Loaded plausability script from file');
            } else {
              debugPrint('❌ bundle.umd.js not found at: $tfmFilePath');
            }
          }
        }

        // Check if we have the required validation schema
        if (validationSchema == null) {
          debugPrint('❌ No validation schema available');
          if (mounted) {
            setState(() {
              _error = 'Validation schema not available in database or files';
              _isLoading = false;
            });
          }
          return;
        }

        // Set the schema with conditional rules
        final originalSchema = _deepCopyMap(validationSchema);
        setState(() {
          _jsonSchema = validationSchema;
          _originalJsonSchema = originalSchema;
          _rootSchema = latestSchema?.schemaData;
          _conditionalRules = conditionalRules;
          _styleData = styleToUse; // Use the determined style (control or default)
          _isLoading = false;
        });
        debugPrint('✅ Schema and rules set in state (${conditionalRules.length} rules)');

        // Initialize TFM validation code if available
        if (tfmValidationCode != null) {
          try {
            debugPrint('Reinitializing ValidationService with TFM validation code');
            await ValidationService.instance.initialize(tfmValidationCode: tfmValidationCode);
            debugPrint('ValidationService reinitialized with TFM validation');

            // Small delay to ensure WebView is fully ready
            await Future.delayed(Duration(milliseconds: 200));
            debugPrint('Waited for ValidationService to be fully ready');
          } catch (tfmError) {
            debugPrint('Error initializing TFM validation code: $tfmError');
          }
        }

        // Trigger initial validation
        if (_formData != null && _originalJsonSchema != null) {
          debugPrint('Triggering initial validation...');
          await _onFormDataChanged(_formData!);
        }
      } catch (e) {
        debugPrint('Error loading schema: $e');
        if (mounted) {
          setState(() {
            _error = 'Error loading schema: $e';
            _isLoading = false;
          });
        }
      }
    } catch (e) {
      debugPrint('Error loading schema: $e');
      setState(() {
        _error = 'Fehler beim Laden des Schemas: $e';
      });
    }
  }

  Future<void> _loadRecord() async {
    setState(() {
      _isLoading = true;
      _error = null;
    });

    // Check if this is a NEW record creation
    if (widget.clusterName == 'NEW' && widget.plotName == 'NEW') {
      await _createNewRecord();
      return;
    }

    try {
      final records = await repo.RecordsRepository().getRecordsByClusterAndPlot(
        widget.clusterName,
        widget.plotName,
      );
      _formData = records.isNotEmpty ? records.first.properties : null;
      _initialFormData = _formData != null ? _deepCopyMap(_formData!) : null;

      _previousFormData = records.isNotEmpty ? records.first.previousProperties : null;
      if (mounted) {
        setState(() {
          _record = records.isNotEmpty ? records.first : null;
          _isLoading = false;
          if (_record == null) {
            _error = 'Record not found';
          }
        });

        // Update distance line after record is loaded
        if (_record != null) {
          //_updateDistanceLine();

          // Schedule focus operations after frame to avoid race conditions with dispose
          SchedulerBinding.instance.addPostFrameCallback((_) {
            if (mounted && _record != null) {
              _setFocusedRecord(context);
              _focusRecord(context);
            }
          });

          // Validate initial form data
          if (_formData != null) {
            _onFormDataChanged(_formData!);
          }
        }
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _error = 'Error loading record: $e';
          _isLoading = false;
        });
      }
    }
  }

  Future<void> _createNewRecord() async {
    if (!mounted) return;

    // Defer dialog until after the widget tree is built
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      if (!mounted) return;

      // Show dialog to get cluster and plot names
      final result = await showDialog<Map<String, String>>(
        context: context,
        barrierDismissible: false,
        builder: (context) => const NewRecordDialog(),
      );

      if (result == null) {
        // User cancelled, set loading to false and go back
        if (mounted) {
          setState(() {
            _isLoading = false;
          });
          // Use a small delay to ensure state is updated before navigation
          await Future.delayed(const Duration(milliseconds: 100));
          if (mounted) {
            Beamer.of(context).beamBack();
          }
        }
        return;
      }

      final clusterName = result['clusterName']!;
      final plotName = result['plotName']!;
      final schemaName = result['schemaName']!;

      try {
        // Get the selected schema
        final schema = await schemaRepository.getLatestForInterval(schemaName);
        if (schema == null) {
          throw Exception('Schema nicht gefunden: $schemaName');
        }

        // Generate UUIDs for cluster_id and plot_id
        final clusterId = DateTime.now().millisecondsSinceEpoch.toString();
        final plotId = '${clusterId}_${plotName.replaceAll(' ', '_')}';

        // Create new record with minimal required fields
        final newRecord = repo.Record(
          id: null, // Will be auto-generated on insert
          properties: {}, // Empty properties to be filled in form
          schemaName: schemaName,
          schemaId: schema.id!,
          schemaIdValidatedBy: schema.id,
          schemaVersion: schema.version,
          plotId: plotId,
          clusterId: clusterId,
          plotName: plotName,
          clusterName: clusterName,
          previousProperties: null, // No previous data for new record
          previousPositionData: null,
          isValid: 0,
          responsibleAdministration: null,
          responsibleProvider: null,
          responsibleState: null,
          responsibleTroop: null,
          updatedAt: null,
          localUpdatedAt: DateTime.now().toUtc().toIso8601String(),
          completedAtState: null,
          completedAtTroop: null,
          completedAtAdministration: null,
          isToBeRecorded: 1,
          note: null,
          validationErrors: null,
          cluster: null,
        );

        if (mounted) {
          setState(() {
            _record = newRecord;
            _formData = {};
            _initialFormData = {};
            _previousFormData = null;
            _isLoading = false;
          });

          // Load schema after record is created
          await _loadSchema(
            newRecord.schemaName,
            schemaIdValidatedBy: newRecord.schemaIdValidatedBy,
          );
        }
      } catch (e) {
        debugPrint('Error creating new record: $e');
        if (mounted) {
          setState(() {
            _error = 'Fehler beim Erstellen: $e';
            _isLoading = false;
          });
          ScaffoldMessenger.of(
            context,
          ).showSnackBar(SnackBar(content: Text('Fehler beim Erstellen der neuen Ecke: $e')));
          await Future.delayed(const Duration(milliseconds: 100));
          if (mounted) {
            Beamer.of(context).beamBack();
          }
        }
      }
    });
  }

  Future<void> save(String type, {Map<String, List<AcknowledgedError>>? acknowledgedErrors}) async {
    if (_record == null || _formData == null) {
      debugPrint('Cannot save: record or form data is null');
      return;
    }

    try {
      debugPrint('Saving form data: $_formData');

      // Get current timestamp for local_updated_at in UTC (to match server's updated_at timezone)
      final now = DateTime.now().toUtc().toIso8601String();

      setState(() {
        _isSaving = true;
      });

      // Reload record from database first to get any auto-saved acknowledged errors
      // This ensures we don't overwrite errors that were auto-saved when closing the dialog
      if (_record!.id != null) {
        try {
          final freshRecord = await repo.RecordsRepository().getRecordById(_record!.id!);
          if (freshRecord != null) {
            _record = freshRecord;
          }
        } catch (e) {
          debugPrint('Warning: Could not reload record before save: $e');
        }
      }

      // Prepare acknowledged errors JSON
      // If no new acknowledged errors provided, preserve existing ones from record
      String? validationErrorsJson = _record!.validationErrors;
      String? plausibilityErrorsJson = _record!.plausibilityErrors;

      debugPrint('💾 === SAVE ERRORS DEBUG ===');
      debugPrint('💾 acknowledgedErrors provided: ${acknowledgedErrors != null}');
      debugPrint('💾 Existing validationErrors from record: $validationErrorsJson');
      debugPrint('💾 Existing plausibilityErrors from record: $plausibilityErrorsJson');

      if (acknowledgedErrors != null) {
        final validationErrors = acknowledgedErrors['validation_errors'] ?? [];
        final plausibilityErrors = acknowledgedErrors['plausibility_errors'] ?? [];

        debugPrint('💾 New validation errors count: ${validationErrors.length}');
        debugPrint('💾 New plausibility errors count: ${plausibilityErrors.length}');

        validationErrorsJson = validationErrors.isNotEmpty
            ? AcknowledgedError.encodeList(validationErrors)
            : null;
        plausibilityErrorsJson = plausibilityErrors.isNotEmpty
            ? AcknowledgedError.encodeList(plausibilityErrors)
            : null;

        debugPrint(
          '💾 PROPERTIES-EDIT validationErrorsJson type: ${validationErrorsJson.runtimeType}',
        );
        debugPrint(
          '💾 PROPERTIES-EDIT plausibilityErrorsJson type: ${plausibilityErrorsJson.runtimeType}',
        );
        debugPrint(
          '💾 Final validationErrorsJson: ${validationErrorsJson?.substring(0, validationErrorsJson.length > 100 ? 100 : validationErrorsJson.length)}...',
        );
        debugPrint(
          '💾 Final plausibilityErrorsJson: ${plausibilityErrorsJson?.substring(0, plausibilityErrorsJson.length > 100 ? 100 : plausibilityErrorsJson.length)}...',
        );
      } else {
        debugPrint('💾 No new errors provided, using existing from record');
      }

      // Check if this is a new record (no id yet)
      if (_record!.id == null) {
        // INSERT new record using repository
        final completedAt = type == 'complete' ? now : null;
        final recordToInsert = _record!.copyWith(
          properties: _formData,
          isValid: 0,
          localUpdatedAt: now,
          completedAtTroop: completedAt,
          isToBeRecorded: 1,
          isTraining: 1,
          validationErrors: validationErrorsJson,
          plausibilityErrors: plausibilityErrorsJson,
        );

        final newId = await repo.RecordsRepository().insertRecord(recordToInsert);

        // Get the inserted record to update state
        final insertedRecord = await repo.RecordsRepository().getRecordById(newId);

        if (insertedRecord != null) {
          setState(() {
            _record = insertedRecord;
            _isSaving = false;
          });
        }
      } else {
        // UPDATE existing record
        debugPrint('💾 === EXECUTING DATABASE UPDATE ===');
        debugPrint('💾 Type: $type');
        debugPrint('💾 Record ID: ${_record!.id}');
        debugPrint(
          '💾 Writing validationErrorsJson: ${validationErrorsJson != null ? "${validationErrorsJson.length} chars" : "NULL"}',
        );
        debugPrint(
          '💾 Writing plausibilityErrorsJson: ${plausibilityErrorsJson != null ? "${plausibilityErrorsJson.length} chars" : "NULL"}',
        );

        if (type == 'save') {
          await db.execute(
            'UPDATE records SET properties = ?, schema_id_validated_by = ?, local_updated_at = ?, validation_errors = ?, plausibility_errors = ? WHERE id = ?',
            [
              jsonEncode(_formData),
              _record!.schemaIdValidatedBy,
              now,
              validationErrorsJson,
              plausibilityErrorsJson,
              _record!.id,
            ],
          );
          debugPrint('💾 ✅ UPDATE (save) executed');
        } else if (type == 'complete') {
          await db.execute(
            'UPDATE records SET properties = ?, schema_id_validated_by = ?, local_updated_at = ?, completed_at_troop = ?, validation_errors = ?, plausibility_errors = ? WHERE id = ?',
            [
              jsonEncode(_formData),
              _record!.schemaIdValidatedBy,
              now,
              now,
              validationErrorsJson,
              plausibilityErrorsJson,
              _record!.id,
            ],
          );
          debugPrint('💾 ✅ UPDATE (complete) executed');
        }

        // Create updated record for local state
        final updatedRecord = repo.Record(
          id: _record!.id,
          properties: _formData!,
          schemaName: _record!.schemaName,
          schemaId: _record!.schemaId,
          schemaIdValidatedBy: _record!.schemaIdValidatedBy,
          schemaVersion: _record!.schemaVersion,
          plotId: _record!.plotId,
          clusterId: _record!.clusterId,
          plotName: _record!.plotName,
          clusterName: _record!.clusterName,
          previousProperties: _record!.previousProperties,
          isValid: _record!.isValid,
          responsibleAdministration: _record!.responsibleAdministration,
          responsibleProvider: _record!.responsibleProvider,
          responsibleState: _record!.responsibleState,
          responsibleTroop: _record!.responsibleTroop,
          updatedAt: _record!.updatedAt,
          localUpdatedAt: now,
          completedAtState: _record!.completedAtState,
          completedAtTroop: _record!.completedAtTroop,
          completedAtAdministration: _record!.completedAtAdministration,
          note: _record!.note,
          validationErrors: validationErrorsJson,
          plausibilityErrors: plausibilityErrorsJson,
        );

        // Update local state
        setState(() {
          _record = updatedRecord;
          _isSaving = false;
        });

        // Reload record from database to ensure we have the latest data
        try {
          final reloadedRecord = await repo.RecordsRepository().getRecordById(_record!.id!);
          if (reloadedRecord != null) {
            setState(() {
              _record = reloadedRecord;
            });
            debugPrint('✅ Reloaded record from database:');
            debugPrint('✅ validationErrors: ${_record!.validationErrors}');
            debugPrint('✅ plausibilityErrors: ${_record!.plausibilityErrors}');
          }
        } catch (e) {
          debugPrint('⚠️ Failed to reload record: $e');
        }
      }

      // Update initial form data snapshot so save button disables again
      if (_formData != null) {
        _initialFormData = _deepCopyMap(_formData!);
      }

      // Show submission success dialog with next-record options
      if (mounted) {
        final result = await SubmissionSuccessDialog.show(context, submittedRecord: _record!);

        if (mounted) {
          if (result != null && result.action == 'open' && result.selectedRecord != null) {
            // Navigate to the selected record
            final r = result.selectedRecord!;
            Beamer.of(context).beamToNamed(
              '/properties-edit/${Uri.encodeComponent(r.clusterName)}/${Uri.encodeComponent(r.plotName)}',
            );
          } else {
            // Default: go back to records-selection
            Beamer.of(context).beamToNamed('/records-selection/${_record!.schemaId}');
          }
        }
      }
    } catch (e) {
      debugPrint('Error saving record: $e');

      // Show error message
      if (mounted) {
        // Find root scaffold messenger to show above bottom sheet
        final rootScaffoldMessenger = ScaffoldMessenger.of(context);
        rootScaffoldMessenger.showSnackBar(
          SnackBar(
            content: Text('Fehler beim Speichern: $e'),
            backgroundColor: Colors.red,
            duration: const Duration(seconds: 3),
            behavior: SnackBarBehavior.floating,
            margin: EdgeInsets.only(
              bottom: MediaQuery.of(context).size.height * 0.7,
              left: 16,
              right: 16,
            ),
          ),
        );
      }
    }
  }

  void saveRecord() async {
    _onFormDataChanged(_formData ?? {});

    String? saveAction;
    Map<String, List<AcknowledgedError>>? acknowledgedErrors;

    // Check validation before saving (show dialog for errors OR warnings)
    if (_validationResult != null && _validationResult!.allIssues.isNotEmpty) {
      // Reload record from database BEFORE opening dialog to get any previously saved errors
      if (_record?.id != null) {
        try {
          final freshRecord = await repo.RecordsRepository().getRecordById(_record!.id!);
          if (freshRecord != null && mounted) {
            setState(() {
              _record = freshRecord;
            });
          }
        } catch (e) {
          debugPrint('Warning: Could not reload record before opening dialog: $e');
        }
      }

      debugPrint('📋 Opening validation dialog with record:');
      debugPrint('📋 Record ID: ${_record?.id}');
      // Show validation errors/warnings dialog
      final result = await ValidationErrorsDialog.show(
        context,
        _validationResult!,
        onNavigateToTab: _navigateToTabFromError,
        record: _record,
      );

      debugPrint('📋 === DIALOG RETURNED ===');
      debugPrint('📋 Result: ${result != null ? "provided" : "NULL (cancelled)"}');
      if (result != null) {
        debugPrint('📋 Action: ${result.action}');
        debugPrint(
          '📋 validation_errors: ${result.acknowledgedErrors['validation_errors']?.length ?? 0}',
        );
        debugPrint(
          '📋 plausibility_errors: ${result.acknowledgedErrors['plausibility_errors']?.length ?? 0}',
        );
      }

      // Reload record from database AFTER dialog closes to get any auto-saved acknowledged errors
      if (_record?.id != null) {
        try {
          final reloadedRecord = await repo.RecordsRepository().getRecordById(_record!.id!);
          if (reloadedRecord != null && mounted) {
            setState(() {
              _record = reloadedRecord;
            });
          }
        } catch (e) {
          debugPrint('Failed to reload record after dialog: $e');
        }
      }

      // If user didn't confirm save from dialog, return
      if (result == null) {
        return;
      }

      saveAction = result.action;
      acknowledgedErrors = result.acknowledgedErrors;
    } else {
      // No validation issues, default to 'complete'
      saveAction = 'complete';
    }

    // Call save with the determined action and acknowledged errors
    await save(saveAction, acknowledgedErrors: acknowledgedErrors);
  }

  Future<void> _onFormDataChanged(Map<String, dynamic> updatedData) async {
    // Always update form data immediately (UI-responsive)
    setState(() {
      _formData = updatedData;
    });

    // Cancel any pending validation
    _validationDebounceTimer?.cancel();

    // Debounce validation and updates
    _validationDebounceTimer = Timer(const Duration(milliseconds: 800), () async {
      // Update provider cache and focused record (map preview)
      if (mounted && _record != null) {
        try {
          // Create updated record (don't save to DB yet)
          final updatedRecord = _record!.copyWith(properties: updatedData);

          // 1. Update list/markers
          context.read<RecordsListProvider>().updateRecordInCache(updatedRecord);

          // 2. Update focused features (trees, etc.) if map provider is available
          // MapWidget listens to this to rebuild tree layers
          final mapProvider = context.read<MapControllerProvider>();
          if (mapProvider.focusedRecord?.id == _record!.id) {
            mapProvider.setFocusedRecord(updatedRecord);
          }
        } catch (e) {
          debugPrint('Error updating map preview: $e');
        }
      }

      if (_originalJsonSchema != null) {
        setState(() {
          _isValidating = true;
        });

        try {
          // Apply conditional rules to original schema
          // Deep copy is handled inside applyRules() to prevent mutation
          final modifiedSchema = _conditionalRules.isNotEmpty
              ? ConditionalRulesService().applyRules(
                  schema: _originalJsonSchema!,
                  formData: updatedData,
                  rules: _conditionalRules,
                )
              : _originalJsonSchema!;

          if (_conditionalRules.isEmpty) {
            debugPrint('⚠️ No conditional rules to apply');
          }
          ;

          // Merge properties with record metadata for TFM validation
          // TFM needs: id, intkey, cluster_id, plot_id, and all properties
          final currentDataWithMeta = {
            ...updatedData,
            if (_record?.id != null) 'id': _record!.id,
            if (_record?.plotId != null) 'plot_id': _record!.plotId,
            if (_record?.clusterId != null) 'cluster_id': _record!.clusterId,
          };

          // Generate intkey if we have the necessary data
          if (_record != null &&
              updatedData['cluster_name'] != null &&
              updatedData['plot_name'] != null) {
            currentDataWithMeta['intkey'] =
                '-${updatedData['cluster_name']}-${updatedData['plot_name']}-_${_record!.schemaName}';
          }

          final previousDataWithMeta = _previousFormData != null
              ? {
                  ..._previousFormData!,
                  if (_record?.id != null) 'id': _record!.id,
                  if (_record?.plotId != null) 'plot_id': _record!.plotId,
                  if (_record?.clusterId != null) 'cluster_id': _record!.clusterId,
                  if (_previousFormData!['cluster_name'] != null &&
                      _previousFormData!['plot_name'] != null)
                    'intkey':
                        '-${_previousFormData!['cluster_name']}-${_previousFormData!['plot_name']}-_${_record!.schemaName}',
                }
              : null;

          // Fetch tree species lookup table for TFM validation
          List<Map<String, dynamic>>? treeSpeciesLookup;
          try {
            final results = await db.getAll('SELECT * FROM lookup_tree_species');
            if (results.isNotEmpty) {
              treeSpeciesLookup = results.map((row) => Map<String, dynamic>.from(row)).toList();
              debugPrint('Loaded ${treeSpeciesLookup.length} tree species for validation');
            } else {
              debugPrint('No tree species found in lookup table');
            }
          } catch (e) {
            debugPrint('Warning: Could not load tree species lookup: $e');
          }

          final result = await ValidationService.instance.validateWithTFM(
            schema: modifiedSchema,
            data: currentDataWithMeta,
            previousData: previousDataWithMeta,
            treeSpeciesLookup: treeSpeciesLookup,
          );

          // Strip /plot/0 from paths if TFM validation was run
          TFMValidationResult processedResult = result;
          if (result.tfmAvailable) {
            // Strip /plot/0 from AJV error paths
            final processedAjvErrors = result.ajvErrors.map((error) {
              final path = error.instancePath;
              final strippedPath = path?.startsWith('/plot/0') == true
                  ? path!.substring(7) // Remove '/plot/0'
                  : path;
              return ValidationError(
                instancePath: strippedPath,
                schemaPath: error.schemaPath,
                keyword: error.keyword,
                message: error.message,
                params: error.params,
                rawError: {...error.rawError, 'instancePath': strippedPath},
              );
            }).toList();

            // Strip /plot/0 from TFM error paths
            final processedTfmErrors = result.tfmErrors.map((error) {
              final path = error.instancePath;
              final strippedPath = path?.startsWith('/plot/0') == true
                  ? path!.substring(7) // Remove '/plot/0'
                  : path;
              return TFMValidationError(
                instancePath: strippedPath,
                error: error.error,
                debugInfo: error.debugInfo,
              );
            }).toList();

            processedResult = TFMValidationResult(
              ajvValid: result.ajvValid,
              ajvErrors: processedAjvErrors,
              tfmAvailable: result.tfmAvailable,
              tfmErrors: processedTfmErrors,
            );
          }

          if (mounted) {
            setState(() {
              _validationResult = processedResult;
              _isValidating = false;
              _hasCompletedInitialValidation = true;
              // Update schema with conditional rules applied
              _jsonSchema = modifiedSchema;
            });
          }
        } catch (e) {
          debugPrint('Validation error: $e');
          if (mounted) {
            setState(() {
              _isValidating = false;
            });
          }
        }
      }
    });
  }

  void _setFocusedRecord(BuildContext context) {
    try {
      final mapProvider = context.read<MapControllerProvider>();
      mapProvider.setFocusedRecord(_record);
    } catch (e) {
      debugPrint('Error setting focused record: $e');
    }
  }

  void _focusRecord(BuildContext context) {
    try {
      final mapProvider = context.read<MapControllerProvider>();
      final recordCoords = _record?.getCoordinates();

      if (recordCoords != null) {
        // Mark as manual interaction before moving
        mapProvider.markManualInteraction();
        final latLng = LatLng(recordCoords['latitude']!, recordCoords['longitude']!);
        mapProvider.moveToLocation(latLng, zoom: 19.0);
      } else {
        debugPrint('Record has no coordinates to focus on');
      }
    } catch (e) {
      debugPrint('Error focusing on record: $e');
    }
  }

  void _navigateToTabFromError(String? tabId) {
    debugPrint('Navigate to tab requested: $tabId');
    // Use GlobalKey to access FormWrapper's state and call its navigation method
    _formWrapperKey.currentState?.navigateToTab(tabId);
  }

  void _showCurrentAsJson() {
    if (_formData == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('No data available'),
          behavior: SnackBarBehavior.floating,
          margin: EdgeInsets.only(
            bottom: MediaQuery.of(context).size.height * 0.7,
            left: 16,
            right: 16,
          ),
        ),
      );
      return;
    }

    final jsonString = const JsonEncoder.withIndent('  ').convert(_formData);

    showDialog(
      context: context,
      builder: (context) => Dialog(
        child: Column(
          children: [
            AppBar(
              title: const Text('Current Form Data (JSON)'),
              automaticallyImplyLeading: false,
              actions: [
                IconButton(
                  icon: const Icon(Icons.close),
                  onPressed: () => Navigator.of(context).pop(),
                ),
              ],
            ),
            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsets.all(16.0),
                child: SelectableText(
                  jsonString,
                  style: const TextStyle(fontFamily: 'monospace', fontSize: 12),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _showCurrentSchema() {
    if (_jsonSchema == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('No schema available'),
          behavior: SnackBarBehavior.floating,
          margin: EdgeInsets.only(
            bottom: MediaQuery.of(context).size.height * 0.7,
            left: 16,
            right: 16,
          ),
        ),
      );
      return;
    }

    final jsonString = const JsonEncoder.withIndent('  ').convert(_jsonSchema);

    showDialog(
      context: context,
      builder: (context) => Dialog(
        child: Column(
          children: [
            AppBar(
              title: const Text('Current Schema (JSON)'),
              automaticallyImplyLeading: false,
              actions: [
                IconButton(
                  icon: const Icon(Icons.close),
                  onPressed: () => Navigator.of(context).pop(),
                ),
              ],
            ),
            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsets.all(16.0),
                child: SelectableText(
                  jsonString,
                  style: const TextStyle(fontFamily: 'monospace', fontSize: 12),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _showCurrentStyle() async {
    try {
      Map<String, dynamic>? styleJson;

      // Determine which style to use based on control troop status
      final isControlTroop = await getCurrentIsControlTroop() ?? false;
      final styleColumn = isControlTroop ? 'style_control' : 'style_default';
      debugPrint(
        'Showing ${isControlTroop ? "CONTROL" : "DEFAULT"} style from column: $styleColumn',
      );

      // First try: Get style from current schema's style_control or style_default
      final results = await db.getAll('SELECT $styleColumn FROM schemas WHERE id = ?', [
        _record?.schemaIdValidatedBy ?? _record?.schemaId,
      ]);

      if (results.isNotEmpty && results.first[styleColumn] != null) {
        final styleData = results.first[styleColumn];
        if (styleData is String) {
          styleJson = jsonDecode(styleData);
        } else {
          styleJson = styleData as Map<String, dynamic>;
        }
        debugPrint('✅ Loaded $styleColumn from database');
      }
      // Fallback: Load from file
      else if (_schemaDirectory != null) {
        debugPrint('⚠️ Falling back to loading style from file');
        final appDirectory = await getApplicationDocumentsDirectory();
        final stylePath = '${appDirectory.path}/TFM/validation/$_schemaDirectory/style.json';
        final styleFile = File(stylePath);

        if (await styleFile.exists()) {
          final styleContent = await styleFile.readAsString();
          styleJson = jsonDecode(styleContent);
        }
      }

      if (styleJson == null) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Style schema not available'),
              behavior: SnackBarBehavior.floating,
              margin: EdgeInsets.only(
                bottom: MediaQuery.of(context).size.height * 0.7,
                left: 16,
                right: 16,
              ),
            ),
          );
        }
        return;
      }

      final jsonString = const JsonEncoder.withIndent('  ').convert(styleJson);

      if (mounted) {
        showDialog(
          context: context,
          builder: (context) => Dialog(
            child: Column(
              children: [
                AppBar(
                  title: const Text('Current Style (JSON)'),
                  automaticallyImplyLeading: false,
                  actions: [
                    IconButton(
                      icon: const Icon(Icons.close),
                      onPressed: () => Navigator.of(context).pop(),
                    ),
                  ],
                ),
                Expanded(
                  child: SingleChildScrollView(
                    padding: const EdgeInsets.all(16.0),
                    child: SelectableText(
                      jsonString,
                      style: const TextStyle(fontFamily: 'monospace', fontSize: 12),
                    ),
                  ),
                ),
              ],
            ),
          ),
        );
      }
    } catch (e) {
      debugPrint('Error loading style file: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error loading style: $e'),
            behavior: SnackBarBehavior.floating,
            margin: EdgeInsets.only(
              bottom: MediaQuery.of(context).size.height * 0.7,
              left: 16,
              right: 16,
            ),
          ),
        );
      }
    }
  }

  Future<void> _showSchemaSelector() async {
    if (_record == null) return;

    try {
      // Get all schemas for this interval
      final results = await db.getAll(
        'SELECT * FROM schemas WHERE interval_name = ? ORDER BY created_at DESC, version DESC',
        [_record!.schemaName],
      );

      if (results.isEmpty) {
        if (mounted) {
          ScaffoldMessenger.of(
            context,
          ).showSnackBar(const SnackBar(content: Text('No schemas found for this interval')));
        }
        return;
      }

      final schemas = results.map((row) => SchemaModel.fromJson(row)).toList();
      final currentSchemaId = _record!.schemaIdValidatedBy;

      if (!mounted) return;

      final selectedSchema = await showDialog<SchemaModel>(
        context: context,
        builder: (context) => AlertDialog(
          title: const Text('Select Schema Version'),
          content: SizedBox(
            width: double.maxFinite,
            child: ListView.builder(
              shrinkWrap: true,
              itemCount: schemas.length,
              itemBuilder: (context, index) {
                final schema = schemas[index];
                final isCurrentSchema = schema.id == currentSchemaId;
                final isVisible = schema.isVisible;

                return ListTile(
                  leading: Icon(
                    isCurrentSchema ? Icons.check_circle : Icons.circle_outlined,
                    color: isCurrentSchema ? Colors.green : null,
                  ),
                  title: Text(
                    'v${schema.version ?? "Unknown"} - ${schema.title}',
                    style: TextStyle(
                      fontWeight: isCurrentSchema ? FontWeight.bold : FontWeight.normal,
                    ),
                  ),
                  subtitle: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('Directory: ${schema.directory ?? "Embedded"}'),
                      Text(
                        'Created: ${schema.createdAt.toLocal().toString().split('.')[0]}',
                        style: const TextStyle(fontSize: 11),
                      ),
                      if (!isVisible)
                        const Text(
                          'Hidden (Admin only)',
                          style: TextStyle(fontSize: 11, color: Colors.orange),
                        ),
                    ],
                  ),
                  trailing: isCurrentSchema
                      ? const Text('Current', style: TextStyle(color: Colors.green))
                      : null,
                  onTap: () => Navigator.of(context).pop(schema),
                );
              },
            ),
          ),
          actions: [
            TextButton(onPressed: () => Navigator.of(context).pop(), child: const Text('Cancel')),
          ],
        ),
      );

      if (selectedSchema != null && selectedSchema.id != currentSchemaId) {
        // Update the record to use the selected schema
        await db.execute('UPDATE records SET schema_id_validated_by = ? WHERE id = ?', [
          selectedSchema.id,
          _record!.id,
        ]);

        // Update local record state
        setState(() {
          _record = _record!.copyWith(schemaIdValidatedBy: selectedSchema.id);
        });

        // Reload the schema with the selected one
        await _loadSchema(_record!.schemaName, schemaIdValidatedBy: selectedSchema.id);

        // Re-validate with new schema
        if (_formData != null) {
          await _onFormDataChanged(_formData!);
        }

        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Schema changed to v${selectedSchema.version}'),
              backgroundColor: Colors.green,
            ),
          );
        }
      }
    } catch (e) {
      debugPrint('Error showing schema selector: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error: $e')));
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: MediaQuery.removePadding(
        context: context,
        removeTop: true,
        child: Column(
          children: [
            // Custom AppBar
            Container(
              padding: const EdgeInsets.fromLTRB(8, 4, 8, 4),
              clipBehavior: Clip.none,
              child: Row(
                children: [
                  ClusterInfoButton(
                    record: _record,
                    rootSchema: _rootSchema,
                    tooltip: 'Informationen',
                  ),
                  IconButton(
                    icon: const Icon(Icons.map, size: 20),
                    onPressed: () => _focusRecord(context),
                  ),
                  //const SizedBox(width: 8),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Trakt: ${widget.clusterName}',
                          style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
                          overflow: TextOverflow.ellipsis,
                        ),
                        if (_loadedSchemaVersion != null)
                          Text(
                            'Ecke: ${widget.plotName}',
                            style: const TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.w400,
                              color: Colors.grey,
                            ),
                          ),
                      ],
                    ),
                  ),

                  Container(
                    margin: const EdgeInsets.only(right: 8),
                    padding: const EdgeInsets.symmetric(horizontal: 6),
                    decoration: BoxDecoration(
                      // card background color
                      color: Theme.of(context).colorScheme.surface,
                      borderRadius: BorderRadius.circular(50),
                    ),
                    child: Row(
                      children: [
                        IconButton(
                          onPressed:
                              (_isSaving || !_hasCompletedInitialValidation || !_hasUnsavedChanges)
                              ? null
                              : () => save('save'),
                          color: Theme.of(context).colorScheme.primary,
                          icon: _isSaving
                              ? const SizedBox(
                                  width: 16,
                                  height: 16,
                                  child: CircularProgressIndicator(
                                    strokeWidth: 2,
                                    color: Colors.white,
                                  ),
                                )
                              : Icon(Icons.save),
                        ),
                        //Vertical divider
                        Container(width: 1, height: 24, color: Colors.white54),
                        Badge.count(
                          count: _validationResult?.allIssues.length ?? 0,
                          isLabelVisible:
                              _validationResult != null && _validationResult!.allIssues.isNotEmpty,
                          textColor: Colors.white,
                          child: TextButton(
                            onPressed: (_jsonSchema != null && _hasCompletedInitialValidation)
                                ? saveRecord
                                : null,
                            child: const Text('FERTIG'),
                          ),
                        ),
                      ],
                    ),
                  ),

                  IfDatabaseAdmin(
                    child: IconButton(
                      icon: const Icon(Icons.more_vert),
                      onPressed: () {
                        showMenu<String>(
                          context: context,
                          position: RelativeRect.fromLTRB(
                            MediaQuery.of(context).size.width,
                            kToolbarHeight,
                            0,
                            0,
                          ),
                          items: <PopupMenuEntry<String>>[
                            const PopupMenuItem<String>(
                              value: 'json',
                              child: Row(
                                children: [Icon(Icons.code), SizedBox(width: 8), Text('Show JSON')],
                              ),
                            ),
                            PopupMenuItem<String>(
                              value: 'schema',
                              child: Row(
                                children: [
                                  Icon(Icons.schema),
                                  SizedBox(width: 8),
                                  Text('Schema: v${_loadedSchemaVersion ?? "Unknown"}'),
                                ],
                              ),
                            ),
                            const PopupMenuItem<String>(
                              value: 'style',
                              child: Row(
                                children: [
                                  Icon(Icons.palette),
                                  SizedBox(width: 8),
                                  Text('Show Style'),
                                ],
                              ),
                            ),
                            //Divider
                            const PopupMenuDivider(),
                            const PopupMenuItem<String>(
                              value: 'select_schema',
                              child: Row(
                                children: [
                                  Icon(Icons.admin_panel_settings),
                                  SizedBox(width: 8),
                                  Text('Select Schema Version'),
                                ],
                              ),
                            ),
                          ],
                        ).then((value) {
                          if (value == 'json') {
                            _showCurrentAsJson();
                          } else if (value == 'schema') {
                            _showCurrentSchema();
                          } else if (value == 'style') {
                            _showCurrentStyle();
                          } else if (value == 'select_schema') {
                            _showSchemaSelector();
                          }
                        });
                      },
                    ),
                  ),
                  /*IfDatabaseAdmin(
                    child: IconButton(
                      icon: const Icon(Icons.admin_panel_settings, size: 20),
                      onPressed: _showSchemaSelector,
                      tooltip: 'Select Schema Version',
                    ),
                  ),*/
                ],
              ),
            ),
            Expanded(
              child: _isLoading
                  ? const Center(child: CircularProgressIndicator())
                  : _error != null
                  ? Center(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Text(_error!, style: const TextStyle(color: Colors.red)),
                          const SizedBox(height: 16),
                          ElevatedButton(onPressed: _loadRecord, child: const Text('Retry')),
                        ],
                      ),
                    )
                  : _record == null
                  ? const Center(child: Text('No record found'))
                  : !_hasCompletedInitialValidation
                  ? Center(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: const [
                          CircularProgressIndicator(),
                          SizedBox(height: 16),
                          Text(
                            'Formular wird erstellt',
                            style: TextStyle(fontSize: 16, fontWeight: FontWeight.w500),
                          ),
                        ],
                      ),
                    )
                  : FormWrapper(
                      key: _formWrapperKey,
                      jsonSchema: _jsonSchema,
                      rawRecord: _record,
                      formData: _formData,
                      previousFormData: _previousFormData,
                      onFormDataChanged: _onFormDataChanged,
                      validationResult: _validationResult,
                      onNavigateToTab: _navigateToTabFromError,
                      layoutStyleData: _styleData,
                      layoutDirectory: _schemaDirectory, // Fallback for file loading
                    ),
            ),
          ],
        ),
      ),
    );
  }
}
