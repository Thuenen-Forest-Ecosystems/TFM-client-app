import 'dart:async';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:terrestrial_forest_monitor/services/validation_service.dart';
import 'package:terrestrial_forest_monitor/providers/gps-position.dart';

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
  DateTime? _startMeasurement;
  DateTime? _stopMeasurement;
  bool showDetails = true;

  @override
  void initState() {
    if (widget.data != null &&
        widget.propertyName != null &&
        widget.data![widget.propertyName!] != null) {
      _aggregatedData = Map<String, dynamic>.from(widget.data![widget.propertyName!]);
    }
    super.initState();
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
      _aggregatedData = null;
      _startMeasurement = DateTime.now();
      _stopMeasurement = null;
    });

    try {
      final gpsProvider = context.read<GpsPositionProvider>();
      _gpsSubscription = gpsProvider.positionStreamController.listen((position) {
        // Check count before setState to prevent race conditions
        if (!isRecording || _recordedPositions.length >= _targetCount) {
          return;
        }

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
        _saveToForm();
      }
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
      //'recorded_positions': _recordedPositions,
    };
  }

  void _saveToForm() {
    if (_aggregatedData != null && widget.onDataChanged != null && widget.propertyName != null) {
      final newData = Map<String, dynamic>.from(widget.data ?? {});
      newData[widget.propertyName!] = _aggregatedData;
      widget.onDataChanged!(newData);
      debugPrint('Saved aggregated GPS data: ${_aggregatedData!['measurement_count']} positions');
    }
  }

  @override
  Widget build(BuildContext context) {
    final progress = _recordedPositions.length / _targetCount;
    final gpsProvider = context.watch<GpsPositionProvider>();
    final hasGpsDevice = gpsProvider.lastPosition != null;

    return Padding(
      padding: const EdgeInsets.all(16.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Progress indicator
          if (isRecording) ...[
            LinearProgressIndicator(value: progress),
            const SizedBox(height: 8),
            Text(
              'Recording: ${_recordedPositions.length} / $_targetCount positions',
              style: Theme.of(context).textTheme.bodySmall,
            ),
          ] else if (_aggregatedData != null) ...[
            LinearProgressIndicator(value: 1.0),
            const SizedBox(height: 8),
            Text(
              'Abgeschlossen: ${_aggregatedData!['measurement_count']} Positionen aufgezeichnet',
              style: Theme.of(
                context,
              ).textTheme.bodySmall?.copyWith(color: Colors.green, fontWeight: FontWeight.bold),
            ),
          ],

          const SizedBox(height: 12),

          Row(
            children: [
              TextButton.icon(
                onPressed: _aggregatedData != null
                    ? () => setState(() => showDetails = !showDetails)
                    : null,
                icon: Icon(showDetails ? Icons.expand_less : Icons.expand_more),
                label: Text('Details'),
              ),
              const Spacer(),
              // Control button
              ElevatedButton.icon(
                onPressed: (isRecording || hasGpsDevice) ? _toggleRecording : null,
                icon: Icon(isRecording ? Icons.stop : Icons.gps_fixed),
                label: Text(isRecording ? 'Einmessung beenden' : 'Einmessung starten'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: isRecording ? Colors.red : Colors.green,
                  foregroundColor: Colors.white,
                ),
              ),
            ],
          ),
          // Display aggregated data (always visible when data exists)
          if (_aggregatedData != null && showDetails) ...[
            const SizedBox(height: 16),
            const Divider(),
            const SizedBox(height: 8),
            Text('Aggregierte Daten', style: Theme.of(context).textTheme.titleSmall),
            const SizedBox(height: 8),
            _buildDataRow('Quality', _getQualityText((_aggregatedData!['quality'] as int?) ?? 0)),
            if (_aggregatedData!['position_mean'] != null)
              _buildDataRow(
                'mittlere Position',
                '${(_aggregatedData!['position_mean']['latitude'] as num?)?.toStringAsFixed(8) ?? "?"}, ${(_aggregatedData!['position_mean']['longitude'] as num?)?.toStringAsFixed(8) ?? "?"}',
              ),
            //_buildDataRow(
            //  'Median Position',
            //  '${_aggregatedData!['position_median']['latitude'].toStringAsFixed(6)}, ${_aggregatedData!['position_median']['longitude'].toStringAsFixed(6)}',
            //),
            if (_aggregatedData!['satellites_count_mean'] != null)
              _buildDataRow(
                'Satellites (avg)',
                '${_aggregatedData!['satellites_count_mean'].toStringAsFixed(1)}',
              ),
            if (_aggregatedData!['pdop_mean'] != null)
              _buildDataRow('PDOP (avg)', '${_aggregatedData!['pdop_mean'].toStringAsFixed(2)}'),
            if (_aggregatedData!['hdop_mean'] != null)
              _buildDataRow('HDOP (avg)', '${_aggregatedData!['hdop_mean'].toStringAsFixed(2)}'),
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
          ],

          // Current GPS Information - Always visible
          const SizedBox(height: 16),
          const Divider(),
          const SizedBox(height: 8),
          Text('Aktuelle GPS Information', style: Theme.of(context).textTheme.titleSmall),
          const SizedBox(height: 8),

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
          if (gpsProvider.lastPosition != null) ...[
            _buildDataRow(
              'Position',
              '${gpsProvider.lastPosition!.latitude.toStringAsFixed(8)}, ${gpsProvider.lastPosition!.longitude.toStringAsFixed(8)}',
            ),
            _buildDataRow(
              'Genauigkeit',
              '${gpsProvider.lastPosition!.accuracy.toStringAsFixed(2)} m',
            ),
          ],

          // NMEA data if available
          if (gpsProvider.currentNMEA != null) ...[
            if (gpsProvider.currentNMEA!.fixQuality != null)
              _buildDataRow('Quality', gpsProvider.currentNMEA!.fixQuality.toString()),
            if (gpsProvider.currentNMEA!.satellites != null)
              _buildDataRow('Satelliten', gpsProvider.currentNMEA!.satellites.toString()),
            if (gpsProvider.currentNMEA!.hdop != null)
              _buildDataRow('HDOP', gpsProvider.currentNMEA!.hdop!.toStringAsFixed(2)),
            if (gpsProvider.currentNMEA!.pdop != null)
              _buildDataRow('PDOP', gpsProvider.currentNMEA!.pdop!.toStringAsFixed(2)),
            if (gpsProvider.currentNMEA!.altitude != null)
              _buildDataRow('Höhe', '${gpsProvider.currentNMEA!.altitude!.toStringAsFixed(1)} m'),
          ],

          // Show message if no GPS data
          if (gpsProvider.lastPosition == null && !gpsProvider.isConnecting)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 8.0),
              child: Text(
                'Keine GPS-Daten verfügbar',
                style: Theme.of(
                  context,
                ).textTheme.bodySmall?.copyWith(color: Colors.orange, fontStyle: FontStyle.italic),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildDataRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 4.0),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 120,
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

  String _formatTimestamp(String isoString) {
    try {
      final dt = DateTime.parse(isoString);
      return '${dt.day.toString().padLeft(2, '0')}.${dt.month.toString().padLeft(2, '0')}.${dt.year} ${dt.hour.toString().padLeft(2, '0')}:${dt.minute.toString().padLeft(2, '0')}:${dt.second.toString().padLeft(2, '0')}';
    } catch (e) {
      return isoString;
    }
  }
}
