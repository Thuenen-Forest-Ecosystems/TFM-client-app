import 'dart:convert';
import 'dart:async';
import 'package:universal_io/io.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:latlong2/latlong.dart';
import 'package:path_provider/path_provider.dart';

import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';
import 'package:provider/provider.dart';
//import 'package:maplibre_gl/maplibre_gl.dart';
import 'package:terrestrial_forest_monitor/repositories/records_repository.dart';
import 'package:terrestrial_forest_monitor/repositories/schema_repository.dart';

import 'package:terrestrial_forest_monitor/widgets/form-elements/form-wrapper.dart';
import 'package:terrestrial_forest_monitor/widgets/validation_errors_dialog.dart';
import 'package:terrestrial_forest_monitor/services/validation_service.dart';
import 'package:terrestrial_forest_monitor/providers/map_controller_provider.dart';
import 'package:terrestrial_forest_monitor/providers/gps-position.dart';

class PropertiesEdit extends StatefulWidget {
  final String clusterName;
  final String plotName;

  const PropertiesEdit({super.key, required this.clusterName, required this.plotName});

  @override
  State<PropertiesEdit> createState() => _PropertiesEditState();
}

class _PropertiesEditState extends State<PropertiesEdit> {
  Record? _record;
  bool _isLoading = true;
  String? _error;
  Map<String, dynamic>? _jsonSchema;
  Map<String, dynamic>? _formData;
  Map<String, dynamic>? _previousFormData;
  ValidationResult? _validationResult;
  bool _isValidating = false;
  StreamSubscription? _gpsSubscription;
  late SchemaRepository schemaRepository;
  MapControllerProvider? _mapProvider;
  int? _loadedSchemaVersion;

  @override
  void initState() {
    super.initState();
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

    // Clear distance line and focused record when leaving the page
    // Schedule after frame to avoid calling notifyListeners during widget tree lock
    if (_mapProvider != null) {
      SchedulerBinding.instance.addPostFrameCallback((_) {
        _mapProvider?.clearDistanceLine();
        _mapProvider?.clearFocusedRecord();
        debugPrint('Distance line and focused record cleared on dispose');
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
      });

      // Check if schema has a directory for validation files
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

      // Load validation.json from downloaded directory
      final directory = latestSchema.directory!;
      debugPrint('Loading validation.json from directory: $directory');

      // On web, validation files aren't downloaded, so use embedded schema
      if (kIsWeb) {
        debugPrint('Web platform: using embedded schema instead of downloaded files');
        if (latestSchema.schemaData != null) {
          setState(() {
            _jsonSchema = latestSchema!.schemaData!['properties']['plot']['items'];
          });
        }
        return;
      }

      try {
        final appDirectory = await getApplicationDocumentsDirectory();
        final validationFilePath = '${appDirectory.path}/TFM/validation/$directory/validation.json';
        final validationFile = File(validationFilePath);

        if (!await validationFile.exists()) {
          debugPrint('validation.json not found at: $validationFilePath');
          debugPrint('Falling back to embedded schema');

          // Fallback to embedded schema
          if (latestSchema.schemaData != null) {
            setState(() {
              _jsonSchema = latestSchema!.schemaData!['properties']['plot']['items'];
            });
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
      final records = await RecordsRepository().getRecordsByClusterAndPlot(
        widget.clusterName,
        widget.plotName,
      );
      _formData = records.isNotEmpty ? records.first.properties : null;
      // print _formData.plot_coordinates to debug console
      debugPrint('Loaded form data: ${_formData?['plot_coordinates']}');
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
          _setFocusedRecord(context);
          _focusRecord(context);
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

  void saveRecord() async {
    await _onFormDataChanged(_formData ?? {});

    // Check validation before saving
    if (_validationResult != null && !_validationResult!.isValid) {
      // print validation errors
      debugPrint(
        'Cannot save, validation errors present: ${_validationResult!.errors.map((e) => e.message).join(", ")}',
      );
      final shouldSave = await ValidationErrorsDialog.show(context, _validationResult!);

      // If user didn't confirm save from dialog, return
      if (shouldSave != true) {
        return;
      }
    }

    // Implement save logic here
    debugPrint('Saving form data: $_formData');

    // Show success message
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Datensatz erfolgreich gespeichert'),
          backgroundColor: Colors.green,
          duration: Duration(seconds: 2),
        ),
      );
    }
  }

  Future<void> _onFormDataChanged(Map<String, dynamic> updatedData) async {
    if (_jsonSchema != null) {
      setState(() {
        _isValidating = true;
      });

      try {
        final result = await ValidationService.instance.validate(_jsonSchema!, updatedData);

        if (mounted) {
          setState(() {
            _validationResult = result;
            _isValidating = false;
            // Always update form data, regardless of validation result
            _formData = updatedData;
          });
        }

        if (result.isValid) {
          debugPrint('Form data is valid');
        } else {
          debugPrint('Form validation errors: ${result.errors.map((e) => e.message).join(", ")}');
        }
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
      debugPrint('Form data changed (no validation): $_formData');
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
        final latLng = LatLng(recordCoords['latitude']!, recordCoords['longitude']!);
        mapProvider.moveToLocation(latLng, zoom: 19.0);
      } else {
        debugPrint('Record has no coordinates to focus on');
      }
    } catch (e) {
      debugPrint('Error focusing on record: $e');
    }
  }

  void _showCurrentAsJson() {
    if (_formData == null) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('No data available')));
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
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('No schema available')));
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
                          'Trakt: ${widget.clusterName}, Ecke: ${widget.plotName}',
                          style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
                          overflow: TextOverflow.ellipsis,
                        ),
                        if (_loadedSchemaVersion != null)
                          Text(
                            'Schema Version: $_loadedSchemaVersion',
                            style: const TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.w400,
                              color: Colors.grey,
                            ),
                            overflow: TextOverflow.ellipsis,
                          ),
                      ],
                    ),
                  ),
                  Badge.count(
                    count: _validationResult?.errors.length ?? 0,
                    isLabelVisible: _validationResult != null && !_validationResult!.isValid,
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
                  IconButton(onPressed: _showCurrentAsJson, icon: Icon(Icons.javascript)),
                  IconButton(onPressed: _showCurrentSchema, icon: Icon(Icons.schema)),
                ],
              ),
            ),
            // Validation errors banner
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
                      jsonSchema: _jsonSchema,
                      formData: _formData,
                      previousFormData: _previousFormData,
                      onFormDataChanged: _onFormDataChanged,
                      validationResult: _validationResult,
                    ),
            ),
          ],
        ),
      ),
    );
  }
}
