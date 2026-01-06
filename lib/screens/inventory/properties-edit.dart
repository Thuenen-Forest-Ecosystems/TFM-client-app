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
import 'package:terrestrial_forest_monitor/widgets/auth/if-database-admin.dart';
import 'package:terrestrial_forest_monitor/services/validation_service.dart';
import 'package:terrestrial_forest_monitor/services/powersync.dart';
import 'package:terrestrial_forest_monitor/providers/map_controller_provider.dart';
import 'package:terrestrial_forest_monitor/providers/gps-position.dart';

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
  Map<String, dynamic>? _formData;
  Map<String, dynamic>? _previousFormData;
  TFMValidationResult? _validationResult;
  bool _isValidating = false;
  bool _isSaving = false;
  StreamSubscription? _gpsSubscription;
  late SchemaRepository schemaRepository;
  MapControllerProvider? _mapProvider;
  int? _loadedSchemaVersion;
  String? _schemaDirectory;
  late final GlobalKey<FormWrapperState> _formWrapperKey;

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

    // Schedule updates after frame to avoid calling notifyListeners during build
    SchedulerBinding.instance.addPostFrameCallback((_) {
      _updateDistanceLine();
    });
    _subscribeToGPS();
  }

  void _subscribeToGPS() {
    if (_gpsSubscription != null) return;

    try {
      final gpsProvider = context.read<GpsPositionProvider>();
      _gpsSubscription = gpsProvider.positionStreamController.listen((position) {
        _updateDistanceLine();
      });
    } catch (e) {
      debugPrint('Error subscribing to GPS: $e');
    }
  }

  void _updateDistanceLine() {
    if (_record == null) return;

    try {
      final mapProvider = context.read<MapControllerProvider>();
      final gpsProvider = context.read<GpsPositionProvider>();

      final recordCoords = _record!.getCoordinates();
      final userPosition = gpsProvider.lastPosition;

      if (recordCoords != null && userPosition != null) {
        final from = LatLng(userPosition.latitude, userPosition.longitude);
        final to = LatLng(recordCoords['latitude']!, recordCoords['longitude']!);

        mapProvider.showDistanceLine(from, to);
      }
    } catch (e) {
      debugPrint('Error updating distance line: $e');
    }
  }

  @override
  void dispose() {
    _gpsSubscription?.cancel();

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

      // Store loaded schema version for display
      setState(() {
        _loadedSchemaVersion = latestSchema!.version;
        _schemaDirectory = latestSchema.directory;
      });

      // Check if schema has a directory for validation and style files
      if (latestSchema.directory == null || latestSchema.directory!.isEmpty) {
        debugPrint('Schema has no directory, using embedded schema');
        // Use the embedded schema from the database
        if (latestSchema.schemaData != null) {
          setState(() {
            _jsonSchema = latestSchema!.schemaData!['properties']['plot']['items'];
          });
        }
        return;
      }

      // Load validation.json and style.json from downloaded directory
      final directory = latestSchema.directory!;
      debugPrint('Loading validation.json and style.json from directory: $directory');

      // On web, validation files aren't downloaded, so use embedded schema
      /*if (kIsWeb) {
        debugPrint('Web platform: using embedded schema instead of downloaded files');
        if (latestSchema.schemaData != null) {
          setState(() {
            _jsonSchema = latestSchema!.schemaData!['properties']['plot']['items'];
          });
        }
        return;
      }*/

      try {
        final appDirectory = await getApplicationDocumentsDirectory();
        final validationFilePath = '${appDirectory.path}/TFM/validation/$directory/validation.json';
        final validationFile = File(validationFilePath);

        // Check if directory exists and list files
        final validationDir = Directory('${appDirectory.path}/TFM/validation/$directory');
        if (await validationDir.exists()) {
          final files = await validationDir.list().toList();
          debugPrint(
            'Files in validation directory ($directory): ${files.map((f) => f.path.split('/').last).join(', ')}',
          );
        } else {
          debugPrint('Validation directory does not exist: ${validationDir.path}');
        }

        if (!await validationFile.exists()) {
          debugPrint('validation.json not found at: $validationFilePath');
          debugPrint('Attempting to download validation files for directory: $directory');

          // Try to download the validation files
          try {
            final result = await downloadValidationFiles(directory, force: true);
            debugPrint('Download result: $result');

            // Check again if file now exists
            if (await validationFile.exists()) {
              debugPrint('validation.json successfully downloaded');
              final validationContent = await validationFile.readAsString();
              final Map<String, dynamic> validationJson = jsonDecode(validationContent);
              setState(() {
                _jsonSchema = validationJson['properties']['plot']['items'];
              });
              return;
            }
          } catch (downloadError) {
            debugPrint('Error downloading validation files: $downloadError');
          }

          debugPrint('Falling back to embedded schema');

          // Fallback to embedded schema
          if (latestSchema.schemaData != null) {
            setState(() {
              _jsonSchema = latestSchema!.schemaData!['properties']['plot']['items'];
            });
          }

          // Try to load TFM validation code even when using fallback schema
          try {
            final appDirectory = await getApplicationDocumentsDirectory();
            final tfmFilePath = '${appDirectory.path}/TFM/validation/$directory/bundle.umd.js';
            final tfmFile = File(tfmFilePath);

            if (await tfmFile.exists()) {
              debugPrint('Loading TFM validation code from: $tfmFilePath');
              final tfmValidationCode = await tfmFile.readAsString();
              await ValidationService.instance.initialize(tfmValidationCode: tfmValidationCode);
              debugPrint('ValidationService reinitialized with TFM validation');

              // Small delay to ensure WebView is fully ready
              await Future.delayed(Duration(milliseconds: 200));
              debugPrint('Waited for ValidationService to be fully ready');
            }
          } catch (tfmError) {
            debugPrint('Error loading TFM validation code: $tfmError');
          }

          return;
        }

        // Read and parse validation.json
        final validationContent = await validationFile.readAsString();
        final Map<String, dynamic> validationJson = jsonDecode(validationContent);

        debugPrint('Successfully loaded validation.json from: $validationFilePath');

        setState(() {
          _jsonSchema = validationJson['properties']['plot']['items'];
        });

        // Try to load TFM validation code from the same directory
        try {
          final tfmFilePath = '${appDirectory.path}/TFM/validation/$directory/bundle.umd.js';
          final tfmFile = File(tfmFilePath);

          if (await tfmFile.exists()) {
            debugPrint('Loading TFM validation code from: $tfmFilePath');
            final tfmValidationCode = await tfmFile.readAsString();

            // Reinitialize ValidationService with TFM code
            debugPrint('Reinitializing ValidationService with TFM validation code');
            await ValidationService.instance.initialize(tfmValidationCode: tfmValidationCode);
            debugPrint('ValidationService reinitialized with TFM validation');

            // Small delay to ensure WebView is fully ready
            await Future.delayed(Duration(milliseconds: 200));
            debugPrint('Waited for ValidationService to be fully ready');
          } else {
            debugPrint('TFM validation file not found at: $tfmFilePath');
          }
        } catch (tfmError) {
          debugPrint('Error loading TFM validation code: $tfmError');
        }
      } catch (e) {
        debugPrint('Error loading validation.json file: $e');
        debugPrint('Falling back to embedded schema');

        // Fallback to embedded schema from database
        if (latestSchema.schemaData != null) {
          setState(() {
            _jsonSchema = latestSchema!.schemaData!['properties']['plot']['items'];
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

    try {
      final records = await repo.RecordsRepository().getRecordsByClusterAndPlot(
        widget.clusterName,
        widget.plotName,
      );
      _formData = records.isNotEmpty ? records.first.properties : null;
      // print _formData.plot_coordinates to debug console

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
          _updateDistanceLine();

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

  Future<void> save(String type) async {
    if (_record == null || _formData == null) {
      debugPrint('Cannot save: record or form data is null');
      return;
    }

    try {
      debugPrint('Saving form data: $_formData');

      // Get current timestamp for local_updated_at in UTC (to match server's updated_at timezone)
      final now = DateTime.now().toUtc().toIso8601String();

      // Update properties, schema_id_validated_by, and local_updated_at
      // PowerSync will track this change and sync to server
      setState(() {
        _isSaving = true;
      });
      if (type == 'save') {
        await db.execute(
          'UPDATE records SET properties = ?, schema_id_validated_by = ?, local_updated_at = ? WHERE id = ?',
          [jsonEncode(_formData), _record!.schemaIdValidatedBy, now, _record!.id],
        );
      } else if (type == 'complete') {
        await db.execute(
          'UPDATE records SET properties = ?, schema_id_validated_by = ?, local_updated_at = ?, completed_at_troop = ? WHERE id = ?',
          [jsonEncode(_formData), _record!.schemaIdValidatedBy, now, now, _record!.id],
        );
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
      );

      // Update local state
      setState(() {
        _record = updatedRecord;
        _isSaving = false;
      });

      // Show success message and navigate based on save action
      if (mounted) {
        // Find root scaffold messenger to show above bottom sheet
        final rootScaffoldMessenger = ScaffoldMessenger.of(context);
        rootScaffoldMessenger.showSnackBar(
          SnackBar(
            content: Text(
              type == 'complete'
                  ? 'Datensatz gespeichert und abgeschlossen'
                  : 'Datensatz erfolgreich gespeichert',
            ),
            backgroundColor: Colors.green,
            duration: Duration(seconds: 2),
            behavior: SnackBarBehavior.floating,
            margin: EdgeInsets.only(
              bottom: MediaQuery.of(context).size.height * 0.7,
              left: 16,
              right: 16,
            ),
          ),
        );

        // Only navigate away if "complete" was chosen
        if (type == 'complete') {
          Beamer.of(context).beamToNamed('/records-selection/${_record!.schemaId}');
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

    // Check validation before saving (show dialog for errors OR warnings)
    if (_validationResult != null && _validationResult!.allIssues.isNotEmpty) {
      // Show validation errors/warnings dialog
      saveAction = await ValidationErrorsDialog.show(
        context,
        _validationResult!,
        onNavigateToTab: _navigateToTabFromError,
        record: _record,
      );

      // If user didn't confirm save from dialog, return
      if (saveAction == null) {
        return;
      }
    } else {
      // No validation issues, default to 'complete'
      saveAction = 'complete';
    }

    // Call save with the determined action
    await save(saveAction);
  }

  Future<void> _onFormDataChanged(Map<String, dynamic> updatedData) async {
    if (_jsonSchema != null) {
      setState(() {
        _isValidating = true;
      });

      try {
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

        final result = await ValidationService.instance.validateWithTFM(
          schema: _jsonSchema!,
          data: currentDataWithMeta,
          previousData: previousDataWithMeta,
        );

        if (mounted) {
          setState(() {
            _validationResult = result;
            _isValidating = false;
            // Always update form data, regardless of validation result
            _formData = updatedData;
          });
        }

        debugPrint(
          'Form validation errors: ${result.allErrors.length} total (AJV: ${result.ajvErrors.length}, TFM: ${result.tfmOnlyErrors.length})',
        );
        debugPrint('tfmAvailable: ${result.tfmAvailable}, isValid: ${result.isValid}');
      } catch (e) {
        debugPrint('Validation error: $e');
        if (mounted) {
          setState(() {
            _isValidating = false;
          });
        }
      }
    } else {
      // No schema available, accept changes without validation
      setState(() {
        _formData = updatedData;
      });
    }
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
    if (_schemaDirectory == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('No style available'),
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

    try {
      final appDirectory = await getApplicationDocumentsDirectory();
      final stylePath = '${appDirectory.path}/TFM/validation/$_schemaDirectory/style.json';
      final styleFile = File(stylePath);

      if (!await styleFile.exists()) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Style file not found'),
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

      final styleContent = await styleFile.readAsString();
      final styleJson = jsonDecode(styleContent);
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

                  IconButton.outlined(
                    onPressed: _isSaving ? null : () => save('save'),
                    icon: _isSaving
                        ? const SizedBox(
                            width: 16,
                            height: 16,
                            child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                          )
                        : Icon(Icons.save),
                  ),
                  Badge.count(
                    count: _validationResult?.allIssues.length ?? 0,
                    isLabelVisible:
                        _validationResult != null && _validationResult!.allIssues.isNotEmpty,
                    textColor: Colors.white,
                    child: ElevatedButton(
                      onPressed: _jsonSchema != null ? saveRecord : null,
                      child: _isValidating
                          ? const SizedBox(
                              width: 16,
                              height: 16,
                              child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                            )
                          : const Text('FERTIG'),
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
                  : FormWrapper(
                      key: _formWrapperKey,
                      jsonSchema: _jsonSchema,
                      rawRecord: _record,
                      formData: _formData,
                      previousFormData: _previousFormData,
                      onFormDataChanged: _onFormDataChanged,
                      validationResult: _validationResult,
                      onNavigateToTab: _navigateToTabFromError,
                      layoutDirectory: _schemaDirectory, // Use schema directory for layout
                    ),
            ),
          ],
        ),
      ),
    );
  }
}
