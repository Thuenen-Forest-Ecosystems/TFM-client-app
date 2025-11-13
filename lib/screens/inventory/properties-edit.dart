import 'dart:convert';
import 'dart:async';

import 'package:flutter/material.dart';
import 'package:beamer/beamer.dart';
import 'package:provider/provider.dart';
import 'package:maplibre_gl/maplibre_gl.dart';
import 'package:terrestrial_forest_monitor/repositories/records_repository.dart';
import 'package:terrestrial_forest_monitor/widgets/form-elements/form-wrapper.dart';
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

  @override
  void initState() {
    super.initState();
    _loadSchema();
    _loadRecord();
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _updateDistanceLine();
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
        debugPrint('Distance line updated');
      }
    } catch (e) {
      debugPrint('Error updating distance line: $e');
    }
  }

  @override
  void dispose() {
    _gpsSubscription?.cancel();

    // Clear distance line when leaving the page
    try {
      final mapProvider = context.read<MapControllerProvider>();
      mapProvider.clearDistanceLine();
      debugPrint('Distance line cleared on dispose');
    } catch (e) {
      debugPrint('Error clearing distance line: $e');
    }

    super.dispose();
  }

  Future<void> _loadSchema() async {
    // load jsonschema from assets/schema/validation.json
    final schemaString = await DefaultAssetBundle.of(context).loadString('assets/schema/validation.json');
    // parse the schemaString if needed, e.g., using jsonDecode
    final Map<String, dynamic> schemaJson = jsonDecode(schemaString);
    setState(() {
      _jsonSchema = schemaJson['properties']['plot']['items']['properties'];
    });
  }

  Future<void> _loadRecord() async {
    setState(() {
      _isLoading = true;
      _error = null;
    });

    try {
      final records = await RecordsRepository().getRecordsByClusterAndPlot(widget.clusterName, widget.plotName);
      _formData = records.isNotEmpty ? records.first.properties : null;
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

  void saveRecord() {
    // Implement save logic here
    debugPrint('Saving form data: $_formData');
  }

  void _onFormDataChanged(Map<String, dynamic> updatedData) async {
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
            if (result.isValid) {
              _formData = updatedData;
            }
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

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Column(
        children: [
          // Custom AppBar
          Container(
            height: 40.0,
            padding: const EdgeInsets.symmetric(horizontal: 8),
            child: Row(
              children: [
                IconButton(icon: const Icon(Icons.arrow_back, size: 20), onPressed: () => Beamer.of(context).beamBack()),
                const SizedBox(width: 8),
                Expanded(child: Text('${widget.clusterName} - ${widget.plotName}', style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold), overflow: TextOverflow.ellipsis)),
                if (_isValidating) const Padding(padding: EdgeInsets.symmetric(horizontal: 8.0), child: SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2))),
                if (_validationResult != null && !_validationResult!.isValid) Padding(padding: const EdgeInsets.symmetric(horizontal: 8.0), child: Icon(Icons.error, color: Colors.red, size: 20)),
                if (_validationResult != null && _validationResult!.isValid) Padding(padding: const EdgeInsets.symmetric(horizontal: 8.0), child: Icon(Icons.check_circle, color: Colors.green, size: 20)),
                ElevatedButton(onPressed: (_validationResult?.isValid ?? false) ? saveRecord : null, child: const Text('Save')),
              ],
            ),
          ),
          // Validation errors banner
          Expanded(
            child:
                _isLoading
                    ? const Center(child: CircularProgressIndicator())
                    : _error != null
                    ? Center(
                      child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [Text(_error!, style: const TextStyle(color: Colors.red)), const SizedBox(height: 16), ElevatedButton(onPressed: _loadRecord, child: const Text('Retry'))]),
                    )
                    : _record == null
                    ? const Center(child: Text('No record found'))
                    : FormWrapper(jsonSchema: _jsonSchema, formData: _formData, previousFormData: _previousFormData, onFormDataChanged: _onFormDataChanged),
          ),
        ],
      ),
    );
  }
}
