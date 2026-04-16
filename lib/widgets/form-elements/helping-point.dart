import 'dart:async';
import 'package:flutter/material.dart';
import 'package:latlong2/latlong.dart';
import 'package:provider/provider.dart';
import 'package:terrestrial_forest_monitor/providers/gps-position.dart';
import 'package:terrestrial_forest_monitor/models/gps_quality_criteria.dart';
import 'package:terrestrial_forest_monitor/widgets/form-elements/manual-navigation-steps.dart';

/// HelpingPoint – widget rendered inside each cardlist row
/// for the `plot_support_points_grid` array.
///
/// Allows the user to:
/// 1. Record GPS position (10 measurements, aggregated with quality info).
/// 2. Add multiple navigation steps (azimuth + distance) via [ManualNavigationSteps].
/// 3. The resulting total azimuth/distance from GPS start to calculated end is
///    written back into the row via [onDataChanged].
///
/// Activated via `"component": "helping_point"` in the layout style-map.
class HelpingPoint extends StatefulWidget {
  final Map<String, dynamic>? rowData;
  final int? index;
  final ValueChanged<Map<String, dynamic>>? onDataChanged;

  const HelpingPoint({super.key, this.rowData, this.index, this.onDataChanged});

  @override
  State<HelpingPoint> createState() => _HelpingPointState();
}

class _HelpingPointState extends State<HelpingPoint> {
  static const int _targetCount = 10;

  LatLng? _capturedPosition;

  // Result state
  int? _resultAzimuthGon;
  int? _resultDistanceCm;

  // GPS recording state
  bool _isRecording = false;
  bool _isGpsExpanded = false;
  List<Map<String, dynamic>> _recordedPositions = [];
  StreamSubscription? _gpsSubscription;
  DateTime? _lastRecordedTime;
  late GpsQualityCriteria _qualityCriteria;

  @override
  void initState() {
    super.initState();
    _qualityCriteria = GpsQualityCriteria.defaultCriteria;
    _restoreFromRowData();
  }

  @override
  void dispose() {
    _gpsSubscription?.cancel();
    super.dispose();
  }

  void _restoreFromRowData() {
    final measurement = widget.rowData?['gps_measurement'] as Map<String, dynamic>?;
    if (measurement != null) {
      final mean = measurement['position_mean'] as Map<String, dynamic>?;
      if (mean != null && mean['latitude'] != null && mean['longitude'] != null) {
        _capturedPosition = LatLng(
          (mean['latitude'] as num).toDouble(),
          (mean['longitude'] as num).toDouble(),
        );
      }
    } else {
      // Fallback: restore from simple lat/lon fields
      final lat = widget.rowData?['latitude'];
      final lon = widget.rowData?['longitude'];
      if (lat != null && lon != null) {
        _capturedPosition = LatLng(
          (lat is num) ? lat.toDouble() : double.tryParse(lat.toString()) ?? 0,
          (lon is num) ? lon.toDouble() : double.tryParse(lon.toString()) ?? 0,
        );
      }
    }
  }

  // ── GPS Recording ───────────────────────────────────────────────────────

  void _startRecording() {
    setState(() {
      _isRecording = true;
      _recordedPositions.clear();
      _lastRecordedTime = null;
    });

    final gpsProvider = context.read<GpsPositionProvider>();
    _gpsSubscription = gpsProvider.positionStreamController.listen((position) {
      if (!_isRecording || _recordedPositions.length >= _targetCount) return;

      // Throttle to ~1 Hz
      final now = DateTime.now();
      if (_lastRecordedTime != null && now.difference(_lastRecordedTime!).inMilliseconds < 1000) {
        return;
      }
      _lastRecordedTime = now;

      final nmea = gpsProvider.currentNMEA;

      setState(() {
        _recordedPositions.add({
          'latitude': position.latitude,
          'longitude': position.longitude,
          'accuracy': position.accuracy,
          'timestamp': now.toIso8601String(),
          'quality': nmea?.fixQuality,
          'satellites_count': nmea?.satellites,
          'pdop': nmea?.pdop,
          'hdop': nmea?.hdop,
          'vdop': nmea?.vdop,
          'altitude': nmea?.altitude,
        });
      });

      if (_recordedPositions.length >= _targetCount) {
        _stopRecording();
      }
    });
  }

  void _stopRecording() {
    _gpsSubscription?.cancel();
    _gpsSubscription = null;

    if (_recordedPositions.isEmpty) {
      setState(() => _isRecording = false);
      return;
    }

    final aggregated = _calculateAggregatedData();
    final mean = aggregated['position_mean'] as Map<String, dynamic>?;

    setState(() {
      _isRecording = false;
      if (mean != null) {
        _capturedPosition = LatLng(
          (mean['latitude'] as num).toDouble(),
          (mean['longitude'] as num).toDouble(),
        );
      }
    });

    // Save aggregated measurement + simple lat/lon
    widget.onDataChanged?.call({
      'latitude': mean?['latitude'],
      'longitude': mean?['longitude'],
      'gps_measurement': aggregated,
    });
  }

  void _cancelRecording() {
    _gpsSubscription?.cancel();
    _gpsSubscription = null;
    setState(() {
      _isRecording = false;
      _recordedPositions.clear();
    });
  }

  Map<String, dynamic> _calculateAggregatedData() {
    if (_recordedPositions.isEmpty) return {};

    var positionsToUse = _recordedPositions;

    int? _parseQuality(dynamic value) {
      if (value == null) return null;
      if (value is int) return value;
      if (value is String) return int.tryParse(value);
      if (value is num) return value.toInt();
      return null;
    }

    double? _toDouble(dynamic value) {
      if (value == null) return null;
      if (value is double) return value;
      if (value is int) return value.toDouble();
      if (value is String) return double.tryParse(value);
      if (value is num) return value.toDouble();
      return null;
    }

    // Filter to best available quality
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

    double sumLat = 0, sumLng = 0, sumAccuracy = 0;
    double sumSatellites = 0, sumPdop = 0, sumHdop = 0;
    int satellitesCount = 0, pdopCount = 0, hdopCount = 0;
    List<double> latitudes = [], longitudes = [];

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

    final n = positionsToUse.length;
    final meanLat = sumLat / n;
    final meanLng = sumLng / n;

    latitudes.sort();
    longitudes.sort();
    final medianLat = latitudes[latitudes.length ~/ 2];
    final medianLng = longitudes[longitudes.length ~/ 2];

    final overallQuality = _qualityCriteria.evaluateQuality(
      hdopValue: hdopCount > 0 ? sumHdop / hdopCount : null,
      pdopValue: pdopCount > 0 ? sumPdop / pdopCount : null,
      satellitesValue: satellitesCount > 0 ? (sumSatellites / satellitesCount).round() : null,
      measurementCountValue: n,
    );

    return {
      'quality': existingQualities.isNotEmpty
          ? _parseQuality(positionsToUse.first['quality'])
          : null,
      'satellites_count_mean': satellitesCount > 0 ? sumSatellites / satellitesCount : null,
      'pdop_mean': pdopCount > 0 ? sumPdop / pdopCount : null,
      'hdop_mean': hdopCount > 0 ? sumHdop / hdopCount : null,
      'position_mean': {'latitude': meanLat, 'longitude': meanLng},
      'position_median': {'latitude': medianLat, 'longitude': medianLng},
      'measurement_count': n,
      'total_recorded_count': _recordedPositions.length,
      'mean_accuracy': sumAccuracy / n,
      'aggregation_quality_code': existingQualities.isNotEmpty
          ? _parseQuality(positionsToUse.first['quality'])
          : null,
      'overall_quality': overallQuality.toString().split('.').last,
      'timestamp': DateTime.now().toIso8601String(),
    };
  }

  // ── Navigation result callback ──────────────────────────────────────────

  void _onCalculatedPositionChanged(Map<String, double>? result) {
    if (result == null) return;
    final azimuthGon = result['azimuth']!.round();
    final distanceCm = (result['distance']! * 100).round();
    setState(() {
      _resultAzimuthGon = azimuthGon;
      _resultDistanceCm = distanceCm;
    });
    widget.onDataChanged?.call({'azimuth': azimuthGon, 'distance': distanceCm});
  }

  // ── UI helpers ──────────────────────────────────────────────────────────

  Color _qualityColor(String? quality) {
    switch (quality) {
      case 'good':
        return Colors.green;
      case 'ok':
        return Colors.orange;
      default:
        return Colors.red;
    }
  }

  Widget _buildDetailRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 4),
      child: Row(
        children: [
          SizedBox(
            width: 120,
            child: Text(
              '$label:',
              style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w500),
            ),
          ),
          Expanded(child: Text(value, style: const TextStyle(fontSize: 12))),
        ],
      ),
    );
  }

  String _correctionSignalText(dynamic fixQuality) {
    int? quality;
    if (fixQuality is int) {
      quality = fixQuality;
    } else if (fixQuality is String) {
      quality = int.tryParse(fixQuality);
    }
    switch (quality) {
      case 1:
        return 'Standard GPS';
      case 2:
        return 'DGPS';
      case 4:
        return 'RTK Fixed';
      case 5:
        return 'RTK Float';
      default:
        return 'Unbekannt';
    }
  }

  String _formatTimestamp(String isoString) {
    try {
      final dt = DateTime.parse(isoString);
      return '${dt.day.toString().padLeft(2, '0')}.${dt.month.toString().padLeft(2, '0')}.${dt.year} '
          '${dt.hour.toString().padLeft(2, '0')}:${dt.minute.toString().padLeft(2, '0')}:${dt.second.toString().padLeft(2, '0')}';
    } catch (_) {
      return isoString;
    }
  }

  @override
  Widget build(BuildContext context) {
    final hasGps = _capturedPosition != null;
    final measurement = widget.rowData?['gps_measurement'] as Map<String, dynamic>?;
    final overallQuality = measurement?['overall_quality'] as String?;

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // ── GPS measurement card ─────────────────────────────────────────
          Card(
            margin: EdgeInsets.zero,
            child: Padding(
              padding: const EdgeInsets.all(12),
              child: _isRecording
                  ? Row(
                      children: [
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'Einmessung... ${_recordedPositions.length}/$_targetCount',
                                style: TextStyle(
                                  fontSize: 13,
                                  color: Theme.of(context).colorScheme.onSurfaceVariant,
                                ),
                              ),
                              const SizedBox(height: 4),
                              LinearProgressIndicator(
                                value: _recordedPositions.length / _targetCount,
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(width: 8),
                        TextButton.icon(
                          onPressed: _cancelRecording,
                          icon: const Icon(Icons.close, size: 18),
                          label: const Text('Abbrechen'),
                          style: TextButton.styleFrom(foregroundColor: Colors.red),
                        ),
                      ],
                    )
                  : hasGps
                  ? Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        InkWell(
                          onTap: measurement != null
                              ? () => setState(() => _isGpsExpanded = !_isGpsExpanded)
                              : null,
                          child: Row(
                            children: [
                              if (overallQuality != null) ...[
                                Container(
                                  width: 12,
                                  height: 12,
                                  decoration: BoxDecoration(
                                    shape: BoxShape.circle,
                                    color: _qualityColor(overallQuality),
                                  ),
                                ),
                                const SizedBox(width: 6),
                              ],
                              Expanded(
                                child: Text(
                                  'GPS: ${_capturedPosition!.latitude.toStringAsFixed(6)}, '
                                  '${_capturedPosition!.longitude.toStringAsFixed(6)}'
                                  '${measurement != null ? ' (${measurement['measurement_count']} Mess.)' : ''}',
                                  style: TextStyle(
                                    fontSize: 13,
                                    color: Theme.of(context).colorScheme.onSurfaceVariant,
                                  ),
                                ),
                              ),
                              if (measurement != null)
                                Icon(
                                  _isGpsExpanded ? Icons.expand_less : Icons.expand_more,
                                  size: 20,
                                  color: Theme.of(context).colorScheme.onSurfaceVariant,
                                ),
                              TextButton.icon(
                                onPressed: _startRecording,
                                icon: const Icon(Icons.gps_fixed, size: 18),
                                label: const Text('Einmessung starten'),
                              ),
                            ],
                          ),
                        ),
                        if (_isGpsExpanded && measurement != null) ...[
                          const Divider(height: 16),
                          _buildDetailRow('Messungen', '${measurement['measurement_count']}'),
                          if (measurement['mean_accuracy'] != null)
                            _buildDetailRow(
                              'Genauigkeit',
                              '${(measurement['mean_accuracy'] as num).toStringAsFixed(2)} m',
                            ),
                          if (measurement['hdop_mean'] != null)
                            _buildDetailRow(
                              'HDOP',
                              '${(measurement['hdop_mean'] as num).toStringAsFixed(2)}',
                            ),
                          if (measurement['pdop_mean'] != null)
                            _buildDetailRow(
                              'PDOP',
                              '${(measurement['pdop_mean'] as num).toStringAsFixed(2)}',
                            ),
                          if (measurement['satellites_count_mean'] != null)
                            _buildDetailRow(
                              'Satelliten',
                              '${(measurement['satellites_count_mean'] as num).toStringAsFixed(1)}',
                            ),
                          if (measurement['aggregation_quality_code'] != null)
                            _buildDetailRow(
                              'Korrektursignal',
                              _correctionSignalText(measurement['aggregation_quality_code']),
                            ),
                          if (measurement['timestamp'] != null)
                            _buildDetailRow(
                              'Zeitpunkt',
                              _formatTimestamp(measurement['timestamp'] as String),
                            ),
                        ],
                      ],
                    )
                  : Center(
                      child: TextButton.icon(
                        onPressed: _startRecording,
                        icon: const Icon(Icons.gps_not_fixed),
                        label: const Text('Einmessung starten'),
                      ),
                    ),
            ),
          ),

          // ── Navigation steps (only if GPS captured) ─────────────────────
          if (hasGps && !_isRecording) ...[
            ManualNavigationSteps(
              startPosition: _capturedPosition,
              onCalculatedPositionChanged: _onCalculatedPositionChanged,
            ),
            if (_resultAzimuthGon != null && _resultDistanceCm != null)
              Card(
                margin: const EdgeInsets.only(top: 8),
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                  child: Row(
                    children: [
                      Text(
                        '${_resultAzimuthGon} gon',
                        style: TextStyle(color: Theme.of(context).colorScheme.onPrimaryContainer),
                      ),
                      const SizedBox(width: 16),
                      Text(
                        '${(_resultDistanceCm! / 100).toStringAsFixed(2)} m',
                        style: TextStyle(color: Theme.of(context).colorScheme.onPrimaryContainer),
                      ),
                    ],
                  ),
                ),
              ),
          ],
        ],
      ),
    );
  }
}
