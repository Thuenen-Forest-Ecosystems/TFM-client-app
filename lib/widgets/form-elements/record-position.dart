import 'dart:async';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:terrestrial_forest_monitor/services/validation_service.dart';
import 'package:terrestrial_forest_monitor/providers/gps-position.dart';
import 'package:terrestrial_forest_monitor/models/gps_quality_criteria.dart';

/**
 * Record Position Form Element Widget
 * This widget allows users to record their current GPS position
 * it Records 100 GPS positions
 * Each position includes 
 *  - rtcm_age
    - quality
    - satellites_count_mean
    - pdop_mean
    - hdop_mean
    - position_mean
    - position_median
    - measurement_count
 *  start_measurement, stop_measurement should be logged as well
 * Widget shows detailed quality information about the recorded positions
 */

class RecordPosition extends StatefulWidget {
  final Map<String, dynamic>? jsonSchema;
  final Map<String, dynamic>? data;
  final Map<String, dynamic>? previous_properties;
  final String? propertyName;
  final TFMValidationResult? validationResult;
  final void Function(Map<String, dynamic> newData)? onDataChanged;

  const RecordPosition({
    super.key,
    this.jsonSchema,
    this.data,
    this.previous_properties,
    this.propertyName,
    this.validationResult,
    this.onDataChanged,
  });
  @override
  State<RecordPosition> createState() => _RecordPositionState();
}

class _RecordPositionState extends State<RecordPosition> {
  bool isRecording = false;
  List<Map<String, dynamic>> _recordedPositions = [];
  StreamSubscription? _gpsSubscription;
  int _targetCount = 100;
  Map<String, dynamic>? _aggregatedData;
  Map<String, dynamic>? _savedAggregatedData; // Store previous data when recording
  Map<String, dynamic>?
  _initialSavedData; // Store initial data from form (for display in saved card)
  bool _isDataSaved = true; // Track if current aggregated data has been saved
  DateTime? _startMeasurement;
  DateTime? _stopMeasurement;
  DateTime? _lastRecordedTime; // For throttling to ~1 Hz

  // Quality criteria
  late GpsQualityCriteria _qualityCriteria;
  QualityLevel? _currentQualityLevel;
  Map<String, QualityLevel>? _currentDetailedQuality;

  @override
  void initState() {
    super.initState();
    _loadQualityCriteria();
    if (widget.data != null &&
        widget.propertyName != null &&
        widget.data![widget.propertyName!] != null) {
      // Only set _initialSavedData for Card 2 (Gespeicherte Messung)
      // Leave _aggregatedData as null so Card 3 shows "Einmessung starten" button
      _initialSavedData = Map<String, dynamic>.from(widget.data![widget.propertyName!]);
    }
  }

  Future<void> _loadQualityCriteria() async {
    // Try to load from JSON, fallback to default
    try {
      // TODO: Load from assets or local storage
      // final String jsonString = await rootBundle.loadString('assets/gps_quality_criteria.json');
      // _qualityCriteria = GpsQualityCriteria.fromJsonString(jsonString);
      _qualityCriteria = GpsQualityCriteria.defaultCriteria;
    } catch (e) {
      debugPrint('Failed to load quality criteria from JSON, using defaults: $e');
      _qualityCriteria = GpsQualityCriteria.defaultCriteria;
    }
  }

  @override
  void dispose() {
    _gpsSubscription?.cancel();
    super.dispose();
  }

  void _toggleRecording() {
    if (isRecording) {
      _stopRecording();
    } else {
      _startRecording();
    }
  }

  void _startRecording() {
    setState(() {
      isRecording = true;
      _recordedPositions.clear();
      _savedAggregatedData = _aggregatedData; // Save previous measurement
      _aggregatedData = null;
      _isDataSaved = true;
      _startMeasurement = DateTime.now();
      _stopMeasurement = null;
      _lastRecordedTime = null; // Reset throttle timer
    });

    try {
      final gpsProvider = context.read<GpsPositionProvider>();
      _gpsSubscription = gpsProvider.positionStreamController.listen((position) {
        // Check count before setState to prevent race conditions
        if (!isRecording || _recordedPositions.length >= _targetCount) {
          return;
        }

        // Throttle to approximately 1 Hz (1 position per second)
        final now = DateTime.now();
        if (_lastRecordedTime != null) {
          final timeSinceLastRecord = now.difference(_lastRecordedTime!);
          if (timeSinceLastRecord.inMilliseconds < 1000) {
            // Less than 1 second since last recording, skip this position
            return;
          }
        }
        _lastRecordedTime = now;

        final nmea = gpsProvider.currentNMEA;

        setState(() {
          _recordedPositions.add({
            'latitude': position.latitude,
            'longitude': position.longitude,
            'accuracy': position.accuracy,
            'timestamp': DateTime.now().toIso8601String(),
            'rtcm_age': null, // RTCM age not available in current NMEA
            'quality': nmea?.fixQuality,
            'satellites_count': nmea?.satellites,
            'pdop': nmea?.pdop,
            'hdop': nmea?.hdop,
            'vdop': nmea?.vdop,
            'altitude': nmea?.altitude,
            'heading': nmea?.heading,
            'speed_knots': nmea?.speedKnots,
          });

          // Update aggregated data on every new position
          _aggregatedData = _calculateAggregatedData();

          // Update current quality state
          final quality = _getCurrentQuality(gpsProvider);
          _currentQualityLevel = quality['level'];
          _currentDetailedQuality = quality['detailed'];
        });

        // Auto-stop when target reached - stop immediately, not after frame
        if (_recordedPositions.length >= _targetCount) {
          _stopRecording();
        }
      });
    } catch (e) {
      debugPrint('Error starting GPS recording: $e');
      setState(() {
        isRecording = false;
      });
    }
  }

  void _stopRecording() {
    _gpsSubscription?.cancel();
    setState(() {
      isRecording = false;
      _stopMeasurement = DateTime.now();
      if (_recordedPositions.isNotEmpty) {
        _aggregatedData = _calculateAggregatedData();
        _isDataSaved = false; // Mark as unsaved
      }
      _savedAggregatedData = null; // Clear saved data after stopping
    });
  }

  void _cancelRecording() {
    _gpsSubscription?.cancel();
    setState(() {
      isRecording = false;
      _recordedPositions.clear();
      _currentQualityLevel = null;
      _currentDetailedQuality = null;
      _startMeasurement = null;
      _stopMeasurement = null;
      _lastRecordedTime = null;
      _aggregatedData = _savedAggregatedData; // Restore previous measurement
      _savedAggregatedData = null;
      _isDataSaved = true; // Restored data is already saved
    });
  }

  Map<String, dynamic> _calculateAggregatedData() {
    if (_recordedPositions.isEmpty) return {};

    // Filter to use only best quality positions for aggregation
    var positionsToUse = _recordedPositions;

    // Helper function to safely convert quality to int
    int? _parseQuality(dynamic value) {
      if (value == null) return null;
      if (value is int) return value;
      if (value is String) return int.tryParse(value);
      if (value is num) return value.toInt();
      return null;
    }

    // NMEA Quality codes priorities:
    // 4: RTK Fixed (Best)
    // 5: RTK Float
    // 2: DGPS
    // 1: GPS
    // Only accept valid quality codes, ignore: 0 (no fix), 6 (estimated), 7 (manual), 8 (simulation), etc.
    const validQualities = {1, 2, 4, 5};

    final existingQualities = _recordedPositions
        .map((p) => _parseQuality(p['quality']))
        .where((q) => q != null && validQualities.contains(q))
        .cast<int>()
        .toSet();

    if (existingQualities.isNotEmpty) {
      int bestQuality;
      if (existingQualities.contains(4)) {
        bestQuality = 4;
      } else if (existingQualities.contains(5)) {
        bestQuality = 5;
      } else if (existingQualities.contains(2)) {
        bestQuality = 2;
      } else {
        bestQuality = 1;
      }

      positionsToUse = _recordedPositions
          .where((p) => _parseQuality(p['quality']) == bestQuality)
          .toList();
    }

    // Calculate mean position and quality metrics
    double sumLat = 0, sumLng = 0, sumAccuracy = 0;
    double sumSatellites = 0, sumPdop = 0, sumHdop = 0;
    int satellitesCount = 0, pdopCount = 0, hdopCount = 0;
    List<double> latitudes = [], longitudes = [];

    // Helper to safely convert to double
    double? _toDouble(dynamic value) {
      if (value == null) return null;
      if (value is double) return value;
      if (value is int) return value.toDouble();
      if (value is String) return double.tryParse(value);
      if (value is num) return value.toDouble();
      return null;
    }

    for (var pos in positionsToUse) {
      sumLat += pos['latitude'];
      sumLng += pos['longitude'];
      sumAccuracy += pos['accuracy'];

      latitudes.add(pos['latitude']);
      longitudes.add(pos['longitude']);

      final satCount = _toDouble(pos['satellites_count']);
      if (satCount != null) {
        sumSatellites += satCount;
        satellitesCount++;
      }
      final pdop = _toDouble(pos['pdop']);
      if (pdop != null) {
        sumPdop += pdop;
        pdopCount++;
      }
      final hdop = _toDouble(pos['hdop']);
      if (hdop != null) {
        sumHdop += hdop;
        hdopCount++;
      }
    }

    final meanLat = sumLat / positionsToUse.length;
    final meanLng = sumLng / positionsToUse.length;
    final meanAccuracy = sumAccuracy / positionsToUse.length;

    // Calculate median position
    latitudes.sort();
    longitudes.sort();
    final medianLat = latitudes[latitudes.length ~/ 2];
    final medianLng = longitudes[longitudes.length ~/ 2];

    // Quality indicator (simplified): 1=excellent, 2=good, 3=fair, 4=poor
    int quality = 4;
    // We can be stricter with quality assessment since we filtered for best fix
    if (meanAccuracy < 2.0 && hdopCount > 0 && (sumHdop / hdopCount) < 1.5) {
      quality = 1;
    } else if (meanAccuracy < 5.0 && hdopCount > 0 && (sumHdop / hdopCount) < 3.0) {
      quality = 2;
    } else if (meanAccuracy < 10.0) {
      quality = 3;
    }

    // Evaluate overall quality using criteria
    final overallQuality = _qualityCriteria.evaluateQuality(
      hdopValue: hdopCount > 0 ? sumHdop / hdopCount : null,
      pdopValue: pdopCount > 0 ? sumPdop / pdopCount : null,
      satellitesValue: satellitesCount > 0 ? (sumSatellites / satellitesCount).round() : null,
      measurementCountValue: positionsToUse.length,
    );

    final detailedQuality = _qualityCriteria.evaluateDetailed(
      hdopValue: hdopCount > 0 ? sumHdop / hdopCount : null,
      pdopValue: pdopCount > 0 ? sumPdop / pdopCount : null,
      satellitesValue: satellitesCount > 0 ? (sumSatellites / satellitesCount).round() : null,
      measurementCountValue: positionsToUse.length,
    );

    return {
      'rtcm_age': null, // Not available in current implementation
      'quality': quality,
      'satellites_count_mean': satellitesCount > 0 ? sumSatellites / satellitesCount : null,
      'pdop_mean': pdopCount > 0 ? sumPdop / pdopCount : null,
      'hdop_mean': hdopCount > 0 ? sumHdop / hdopCount : null,
      'position_mean': {'latitude': meanLat, 'longitude': meanLng},
      'position_median': {'latitude': medianLat, 'longitude': medianLng},
      'measurement_count': positionsToUse.length,
      // Keep track of total recorded for reference if needed, but measurement_count usually implies used for calc
      'total_recorded_count': _recordedPositions.length,
      'start_measurement': _startMeasurement?.toIso8601String(),
      'stop_measurement': _stopMeasurement?.toIso8601String(),
      'mean_accuracy': meanAccuracy,
      // Store the quality code used for aggregation
      'aggregation_quality_code': existingQualities.isNotEmpty
          ? _parseQuality(positionsToUse.first['quality'])
          : null,
      // Quality assessment based on criteria
      'overall_quality': overallQuality.toString().split('.').last,
      'detailed_quality': detailedQuality.map(
        (key, value) => MapEntry(key, value.toString().split('.').last),
      ),
      //'recorded_positions': _recordedPositions,
    };
  }

  void _updateCurrentQualityState(GpsPositionProvider gpsProvider) {
    final nmea = gpsProvider.currentNMEA;
    final position = gpsProvider.lastPosition;

    if (position != null) {
      final hdop = nmea?.hdop;
      final pdop = nmea?.pdop;
      final satellites = nmea?.satellites;

      setState(() {
        _currentQualityLevel = _qualityCriteria.evaluateQuality(
          hdopValue: hdop,
          pdopValue: pdop,
          satellitesValue: satellites,
        );

        _currentDetailedQuality = _qualityCriteria.evaluateDetailed(
          hdopValue: hdop,
          pdopValue: pdop,
          satellitesValue: satellites,
        );
      });
    }
  }

  Map<String, dynamic> _getCurrentQuality(GpsPositionProvider gpsProvider) {
    final nmea = gpsProvider.currentNMEA;
    final position = gpsProvider.lastPosition;

    if (position == null) {
      return {'level': null, 'detailed': null};
    }

    final hdop = nmea?.hdop;
    final pdop = nmea?.pdop;
    final satellites = nmea?.satellites;

    final level = _qualityCriteria.evaluateQuality(
      hdopValue: hdop,
      pdopValue: pdop,
      satellitesValue: satellites,
    );

    final detailed = _qualityCriteria.evaluateDetailed(
      hdopValue: hdop,
      pdopValue: pdop,
      satellitesValue: satellites,
    );

    return {'level': level, 'detailed': detailed};
  }

  void _saveToForm() {
    if (_aggregatedData != null && widget.onDataChanged != null && widget.propertyName != null) {
      final newData = Map<String, dynamic>.from(widget.data ?? {});
      newData[widget.propertyName!] = _aggregatedData;
      widget.onDataChanged!(newData);
      setState(() {
        // Update saved data reference for Card 2
        _initialSavedData = Map<String, dynamic>.from(_aggregatedData!);
        // Clear recording state for Card 3
        _aggregatedData = null;
        _recordedPositions.clear();
        _isDataSaved = true;
        _startMeasurement = null;
        _stopMeasurement = null;
        _currentQualityLevel = null;
        _currentDetailedQuality = null;
      });
      debugPrint('Saved aggregated GPS data: ${_initialSavedData!['measurement_count']} positions');
    }
  }

  Color _getQualityColor(QualityLevel level) {
    switch (level) {
      case QualityLevel.good:
        return Colors.green;
      case QualityLevel.ok:
        return Colors.orange;
      case QualityLevel.notAcceptable:
        return Colors.red;
    }
  }

  String _getQualityLabel(QualityLevel level) {
    switch (level) {
      case QualityLevel.good:
        return 'gut';
      case QualityLevel.ok:
        return 'geeignet';
      case QualityLevel.notAcceptable:
        return 'nicht geeignet';
    }
  }

  IconData _getQualityIcon(QualityLevel level) {
    switch (level) {
      case QualityLevel.good:
        return Icons.check_circle;
      case QualityLevel.ok:
        return Icons.warning;
      case QualityLevel.notAcceptable:
        return Icons.error;
    }
  }

  @override
  Widget build(BuildContext context) {
    final progress = _recordedPositions.length / _targetCount;
    final gpsProvider = context.watch<GpsPositionProvider>();
    final hasGpsDevice = gpsProvider.lastPosition != null;

    // Get current quality for display (computed during build, no state mutation)
    final currentQuality = hasGpsDevice && !isRecording ? _getCurrentQuality(gpsProvider) : null;
    final displayQualityLevel = isRecording
        ? _currentQualityLevel
        : currentQuality?['level'] as QualityLevel?;
    final displayDetailedQuality = isRecording
        ? _currentDetailedQuality
        : currentQuality?['detailed'] as Map<String, QualityLevel>?;

    return Padding(
      padding: const EdgeInsets.all(16.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Display aggregated data and current GPS info in responsive card layout
          LayoutBuilder(
            builder: (context, constraints) {
              final isWideScreen = constraints.maxWidth > 800;
              return Wrap(
                spacing: 16.0,
                runSpacing: 16.0,
                children: [
                  // Card 1: Current GPS Information
                  if (gpsProvider.lastPosition != null || gpsProvider.isConnecting)
                    Container(
                      width: isWideScreen ? (constraints.maxWidth - 16) / 2 : constraints.maxWidth,
                      child: Card(
                        elevation: 2,
                        child: Padding(
                          padding: const EdgeInsets.all(16.0),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                children: [
                                  if (displayQualityLevel != null) ...[
                                    _buildQualityCircle(displayQualityLevel),
                                    const SizedBox(width: 8),
                                  ],
                                  Text(
                                    'Aktuelle GPS Information',
                                    style: Theme.of(context).textTheme.titleSmall,
                                  ),
                                ],
                              ),
                              const SizedBox(height: 12),

                              // Connection status
                              _buildDataRow(
                                'Verbindung',
                                gpsProvider.connectedDevice != null
                                    ? 'Bluetooth: ${gpsProvider.connectedDevice!.platformName}'
                                    : gpsProvider.connectedClassicDevice != null
                                    ? 'Bluetooth Classic: ${gpsProvider.connectedClassicDevice!.name ?? "Unbekannt"}'
                                    : gpsProvider.listeningPosition
                                    ? 'Internes GPS'
                                    : 'Keine Verbindung',
                              ),

                              // Current position
                              if (gpsProvider.lastPosition != null)
                                _buildDataRow(
                                  'Position',
                                  '${gpsProvider.lastPosition!.latitude.toStringAsFixed(8)}, ${gpsProvider.lastPosition!.longitude.toStringAsFixed(8)}',
                                ),

                              // NMEA data if available
                              if (gpsProvider.currentNMEA != null) ...[
                                if (gpsProvider.currentNMEA!.fixQuality != null)
                                  _buildDataRow(
                                    'Quality',
                                    gpsProvider.currentNMEA!.fixQuality.toString(),
                                    qualityLevel: GpsQualityCriteria.evaluateCorrectionSignal(
                                      gpsProvider.currentNMEA!.fixQuality,
                                    ),
                                  ),
                                if (gpsProvider.currentNMEA!.satellites != null)
                                  _buildDataRow(
                                    'Satelliten',
                                    gpsProvider.currentNMEA!.satellites.toString(),
                                    qualityLevel: _qualityCriteria.satellites.evaluate(
                                      gpsProvider.currentNMEA!.satellites!,
                                    ),
                                  ),
                                if (gpsProvider.currentNMEA!.hdop != null)
                                  _buildDataRow(
                                    'HDOP',
                                    gpsProvider.currentNMEA!.hdop!.toStringAsFixed(2),
                                    qualityLevel: _qualityCriteria.hdop.evaluate(
                                      gpsProvider.currentNMEA!.hdop!,
                                    ),
                                  ),
                                if (gpsProvider.currentNMEA!.pdop != null)
                                  _buildDataRow(
                                    'PDOP',
                                    gpsProvider.currentNMEA!.pdop!.toStringAsFixed(2),
                                    qualityLevel: _qualityCriteria.pdop.evaluate(
                                      gpsProvider.currentNMEA!.pdop!,
                                    ),
                                  ),
                                if (gpsProvider.currentNMEA!.altitude != null)
                                  _buildDataRow(
                                    'Höhe',
                                    '${gpsProvider.currentNMEA!.altitude!.toStringAsFixed(1)} m',
                                  ),
                              ],

                              // Show message if no GPS data
                              if (gpsProvider.lastPosition == null && !gpsProvider.isConnecting)
                                Padding(
                                  padding: const EdgeInsets.only(top: 8.0),
                                  child: Text(
                                    'Keine GPS-Daten verfügbar',
                                    style: Theme.of(context).textTheme.bodySmall?.copyWith(
                                      color: Colors.orange,
                                      fontStyle: FontStyle.italic,
                                    ),
                                  ),
                                ),
                            ],
                          ),
                        ),
                      ),
                    ),

                  // Card 2: Saved Measurements from form
                  if (_initialSavedData != null)
                    Container(
                      width: isWideScreen ? (constraints.maxWidth - 16) / 2 : constraints.maxWidth,
                      child: Card(
                        elevation: 2,
                        child: Padding(
                          padding: const EdgeInsets.all(16.0),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                children: [
                                  if (_initialSavedData!['overall_quality'] != null) ...[
                                    _buildQualityCircle(
                                      QualityLevel.values.firstWhere(
                                        (e) =>
                                            e.toString().split('.').last ==
                                            _initialSavedData!['overall_quality'],
                                      ),
                                    ),
                                    const SizedBox(width: 8),
                                  ],
                                  Text(
                                    'Gespeicherte Messung',
                                    style: Theme.of(context).textTheme.titleSmall,
                                  ),
                                  const SizedBox(width: 8),
                                  if (_initialSavedData!['overall_quality'] != null)
                                    Chip(
                                      label: Text(
                                        _getQualityLabel(
                                          QualityLevel.values.firstWhere(
                                            (e) =>
                                                e.toString().split('.').last ==
                                                _initialSavedData!['overall_quality'],
                                          ),
                                        ),
                                        style: const TextStyle(fontSize: 11),
                                      ),
                                      backgroundColor: _getQualityColor(
                                        QualityLevel.values.firstWhere(
                                          (e) =>
                                              e.toString().split('.').last ==
                                              _initialSavedData!['overall_quality'],
                                        ),
                                      ).withOpacity(0.2),
                                      visualDensity: VisualDensity.compact,
                                    ),
                                ],
                              ),
                              const SizedBox(height: 12),
                              _buildDataRow(
                                'Quality',
                                _getQualityText((_initialSavedData!['quality'] as int?) ?? 0),
                                qualityLevel: _initialSavedData!['aggregation_quality_code'] != null
                                    ? GpsQualityCriteria.evaluateCorrectionSignal(
                                        _initialSavedData!['aggregation_quality_code'],
                                      )
                                    : null,
                              ),
                              if (_initialSavedData!['position_mean'] != null)
                                _buildDataRow(
                                  'mittlere Position',
                                  '${(_initialSavedData!['position_mean']['latitude'] as num?)?.toStringAsFixed(8) ?? "?"}, ${(_initialSavedData!['position_mean']['longitude'] as num?)?.toStringAsFixed(8) ?? "?"}',
                                ),
                              if (_initialSavedData!['measurement_count'] != null)
                                _buildDataRow(
                                  'Messungen',
                                  '${_initialSavedData!['measurement_count']}',
                                  qualityLevel: _qualityCriteria.measurementCount.evaluate(
                                    _initialSavedData!['measurement_count'] as int,
                                  ),
                                ),
                              if (_initialSavedData!['satellites_count_mean'] != null)
                                _buildDataRow(
                                  'Satellites (avg)',
                                  '${_initialSavedData!['satellites_count_mean'].toStringAsFixed(1)}',
                                  qualityLevel: _qualityCriteria.satellites.evaluate(
                                    (_initialSavedData!['satellites_count_mean'] as num).round(),
                                  ),
                                ),
                              if (_initialSavedData!['pdop_mean'] != null)
                                _buildDataRow(
                                  'PDOP (avg)',
                                  '${_initialSavedData!['pdop_mean'].toStringAsFixed(2)}',
                                  qualityLevel: _qualityCriteria.pdop.evaluate(
                                    (_initialSavedData!['pdop_mean'] as num).toDouble(),
                                  ),
                                ),
                              if (_initialSavedData!['hdop_mean'] != null)
                                _buildDataRow(
                                  'HDOP (avg)',
                                  '${_initialSavedData!['hdop_mean'].toStringAsFixed(2)}',
                                  qualityLevel: _qualityCriteria.hdop.evaluate(
                                    (_initialSavedData!['hdop_mean'] as num).toDouble(),
                                  ),
                                ),
                              if (_initialSavedData!['start_measurement'] != null)
                                _buildDataRow(
                                  'Start Time',
                                  _formatTimestamp(
                                    _initialSavedData!['start_measurement'] as String,
                                  ),
                                ),
                              if (_initialSavedData!['stop_measurement'] != null)
                                _buildDataRow(
                                  'End Time',
                                  _formatTimestamp(
                                    _initialSavedData!['stop_measurement'] as String,
                                  ),
                                ),
                            ],
                          ),
                        ),
                      ),
                    ),

                  // Card 3: New Measurement (Aggregierte Daten) - Always visible
                  Container(
                    width: isWideScreen ? (constraints.maxWidth - 16) / 2 : constraints.maxWidth,
                    child: Card(
                      elevation: 2,
                      child: Padding(
                        padding: const EdgeInsets.all(16.0),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            // Header row with title and quality
                            Row(
                              children: [
                                if (_aggregatedData != null &&
                                    _aggregatedData!['overall_quality'] != null) ...[
                                  _buildQualityCircle(
                                    QualityLevel.values.firstWhere(
                                      (e) =>
                                          e.toString().split('.').last ==
                                          _aggregatedData!['overall_quality'],
                                    ),
                                  ),
                                  const SizedBox(width: 8),
                                  Text(
                                    'Aktuelle Messung',
                                    style: Theme.of(context).textTheme.titleSmall,
                                  ),
                                  const SizedBox(width: 8),
                                ],
                                if (_aggregatedData != null &&
                                    _aggregatedData!['overall_quality'] != null)
                                  Chip(
                                    label: Text(
                                      _getQualityLabel(
                                        QualityLevel.values.firstWhere(
                                          (e) =>
                                              e.toString().split('.').last ==
                                              _aggregatedData!['overall_quality'],
                                        ),
                                      ),
                                      style: const TextStyle(fontSize: 11),
                                    ),
                                    backgroundColor: _getQualityColor(
                                      QualityLevel.values.firstWhere(
                                        (e) =>
                                            e.toString().split('.').last ==
                                            _aggregatedData!['overall_quality'],
                                      ),
                                    ).withOpacity(0.2),
                                    visualDensity: VisualDensity.compact,
                                  ),
                              ],
                            ),
                            const SizedBox(height: 12),

                            // Recording progress indicator
                            if (isRecording) ...[
                              LinearProgressIndicator(value: progress),
                              const SizedBox(height: 8),
                              Row(
                                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                children: [
                                  Text(
                                    'Recording: ${_recordedPositions.length} / $_targetCount positions',
                                    style: Theme.of(context).textTheme.bodySmall,
                                  ),
                                  IconButton(
                                    onPressed: _toggleRecording,
                                    icon: const Icon(Icons.stop),
                                    tooltip: 'Einmessung beenden',
                                    color: Colors.red,
                                  ),
                                ],
                              ),
                              const SizedBox(height: 12),
                            ]
                            // Completion indicator (only when NOT recording)
                            else if (_aggregatedData != null && _isDataSaved) ...[
                              LinearProgressIndicator(value: 1.0),
                              const SizedBox(height: 8),
                              Text(
                                'Abgeschlossen: ${_aggregatedData!['measurement_count']} Positionen aufgezeichnet',
                                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                                  color: Colors.green,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                              const SizedBox(height: 12),
                              // Button to start new measurement after completion
                              Center(
                                child: ElevatedButton(
                                  onPressed: hasGpsDevice
                                      ? () {
                                          setState(() {
                                            _aggregatedData = null;
                                            _recordedPositions.clear();
                                            _isDataSaved = true;
                                            _startMeasurement = null;
                                            _stopMeasurement = null;
                                            _currentQualityLevel = null;
                                            _currentDetailedQuality = null;
                                          });
                                        }
                                      : null,
                                  child: const Text('Neue Messung starten'),
                                ),
                              ),
                              const SizedBox(height: 12),
                            ],

                            // Show start button when no data and not recording
                            if (_aggregatedData == null && !isRecording) ...[
                              Center(
                                child: ElevatedButton.icon(
                                  onPressed: hasGpsDevice ? _toggleRecording : null,
                                  icon: const Icon(Icons.gps_fixed),
                                  label: const Text('Einmessung starten'),
                                  style: ElevatedButton.styleFrom(
                                    backgroundColor: Colors.green,
                                    foregroundColor: Colors.white,
                                  ),
                                ),
                              ),
                            ],

                            // Show data when available
                            if (_aggregatedData != null) ...[
                              _buildDataRow(
                                'Quality',
                                _getQualityText((_aggregatedData!['quality'] as int?) ?? 0),
                                qualityLevel: _aggregatedData!['aggregation_quality_code'] != null
                                    ? GpsQualityCriteria.evaluateCorrectionSignal(
                                        _aggregatedData!['aggregation_quality_code'],
                                      )
                                    : null,
                              ),
                              if (_aggregatedData!['position_mean'] != null)
                                _buildDataRow(
                                  'mittlere Position',
                                  '${(_aggregatedData!['position_mean']['latitude'] as num?)?.toStringAsFixed(8) ?? "?"}, ${(_aggregatedData!['position_mean']['longitude'] as num?)?.toStringAsFixed(8) ?? "?"}',
                                ),
                              if (_aggregatedData!['measurement_count'] != null)
                                _buildDataRow(
                                  'Messungen',
                                  '${_aggregatedData!['measurement_count']}',
                                  qualityLevel: _qualityCriteria.measurementCount.evaluate(
                                    _aggregatedData!['measurement_count'] as int,
                                  ),
                                ),
                              if (_aggregatedData!['satellites_count_mean'] != null)
                                _buildDataRow(
                                  'Satellites (avg)',
                                  '${_aggregatedData!['satellites_count_mean'].toStringAsFixed(1)}',
                                  qualityLevel: _qualityCriteria.satellites.evaluate(
                                    (_aggregatedData!['satellites_count_mean'] as num).round(),
                                  ),
                                ),
                              if (_aggregatedData!['pdop_mean'] != null)
                                _buildDataRow(
                                  'PDOP (avg)',
                                  '${_aggregatedData!['pdop_mean'].toStringAsFixed(2)}',
                                  qualityLevel: _qualityCriteria.pdop.evaluate(
                                    (_aggregatedData!['pdop_mean'] as num).toDouble(),
                                  ),
                                ),
                              if (_aggregatedData!['hdop_mean'] != null)
                                _buildDataRow(
                                  'HDOP (avg)',
                                  '${_aggregatedData!['hdop_mean'].toStringAsFixed(2)}',
                                  qualityLevel: _qualityCriteria.hdop.evaluate(
                                    (_aggregatedData!['hdop_mean'] as num).toDouble(),
                                  ),
                                ),
                              if (_aggregatedData!['start_measurement'] != null)
                                _buildDataRow(
                                  'Start Time',
                                  _formatTimestamp(_aggregatedData!['start_measurement'] as String),
                                ),
                              if (_aggregatedData!['stop_measurement'] != null)
                                _buildDataRow(
                                  'End Time',
                                  _formatTimestamp(_aggregatedData!['stop_measurement'] as String),
                                ),
                              // Save button - only visible if quality is ok or good and data not saved yet
                              if (!_isDataSaved && _aggregatedData!['overall_quality'] != null)
                                Builder(
                                  builder: (context) {
                                    final overallQuality = QualityLevel.values.firstWhere(
                                      (e) =>
                                          e.toString().split('.').last ==
                                          _aggregatedData!['overall_quality'],
                                    );
                                    final canSave =
                                        overallQuality == QualityLevel.good ||
                                        overallQuality == QualityLevel.ok;
                                    final isOverwriting = _initialSavedData != null;
                                    return Padding(
                                      padding: const EdgeInsets.only(top: 16.0),
                                      child: Column(
                                        children: [
                                          if (isOverwriting)
                                            Padding(
                                              padding: const EdgeInsets.only(bottom: 8.0),
                                              child: Text(
                                                'Vorhandene Messung wird überschrieben',
                                                style: Theme.of(context).textTheme.bodySmall
                                                    ?.copyWith(color: Colors.orange),
                                              ),
                                            ),
                                          Row(
                                            mainAxisAlignment: MainAxisAlignment.center,
                                            children: [
                                              TextButton(
                                                onPressed: () {
                                                  setState(() {
                                                    _aggregatedData = null;
                                                    _recordedPositions.clear();
                                                    _isDataSaved = true;
                                                    _startMeasurement = null;
                                                    _stopMeasurement = null;
                                                    _currentQualityLevel = null;
                                                    _currentDetailedQuality = null;
                                                  });
                                                },
                                                child: const Text('Messung verwerfen'),
                                              ),
                                              const SizedBox(width: 12),
                                              ElevatedButton.icon(
                                                onPressed: canSave ? _saveToForm : null,
                                                icon: Icon(
                                                  isOverwriting ? Icons.warning : Icons.save,
                                                ),
                                                label: Text(
                                                  isOverwriting
                                                      ? 'Messung ersetzen'
                                                      : 'Messung übernehmen',
                                                ),
                                                style: ElevatedButton.styleFrom(
                                                  backgroundColor: isOverwriting
                                                      ? Colors.orange
                                                      : Colors.green,
                                                  foregroundColor: Colors.white,
                                                ),
                                              ),
                                            ],
                                          ),
                                        ],
                                      ),
                                    );
                                  },
                                ),
                            ],
                          ],
                        ),
                      ),
                    ),
                  ),
                ],
              );
            },
          ),
        ],
      ),
    );
  }

  Widget _buildQualityCircle(QualityLevel level, {double size = 16.0}) {
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(shape: BoxShape.circle, color: _getQualityColor(level)),
    );
  }

  Widget _buildDataRow(String label, String value, {QualityLevel? qualityLevel}) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 4.0),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (qualityLevel != null) ...[
            _buildQualityCircle(qualityLevel, size: 12.0),
            const SizedBox(width: 6),
          ],
          SizedBox(
            width: qualityLevel != null ? 102 : 120,
            child: Text('$label:', style: const TextStyle(fontWeight: FontWeight.w500)),
          ),
          Expanded(child: Text(value)),
        ],
      ),
    );
  }

  String _getQualityText(int quality) {
    switch (quality) {
      case 1:
        return '1 - Excellent';
      case 2:
        return '2 - Good';
      case 3:
        return '3 - Fair';
      case 4:
        return '4 - Poor';
      default:
        return 'Unknown';
    }
  }

  String _getCorrectionSignalText(dynamic fixQuality) {
    int? quality;
    if (fixQuality is int) {
      quality = fixQuality;
    } else if (fixQuality is String) {
      quality = int.tryParse(fixQuality);
    }

    // Valid NMEA quality codes: 1, 2, 4, 5
    if (quality == null) {
      return 'Nicht geeignet';
    } else if (quality == 1) {
      return 'Standard GPS';
    } else if (quality == 2) {
      return 'DGPS verfügbar';
    } else if (quality == 4) {
      return 'RTK Fixed verfügbar';
    } else if (quality == 5) {
      return 'RTK Float verfügbar';
    } else {
      return 'Nicht geeignet';
    }
  }

  String _formatTimestamp(String isoString) {
    try {
      final dt = DateTime.parse(isoString);
      return '${dt.day.toString().padLeft(2, '0')}.${dt.month.toString().padLeft(2, '0')}.${dt.year} ${dt.hour.toString().padLeft(2, '0')}:${dt.minute.toString().padLeft(2, '0')}:${dt.second.toString().padLeft(2, '0')}';
    } catch (e) {
      return isoString;
    }
  }
}
