import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:terrestrial_forest_monitor/services/validation_types.dart';

/// DisplacedMarker – widget for adding a single `plot_support_points` entry
/// with `point_type = 1` ("versetzte Markierung") to the current record.
///
/// Only visible when a point_type = 1 entry already exists OR
/// marker_status is 2, 3 or 4; hidden entirely otherwise.
/// Shows an add button as long as the record has no point_type = 1 entry.
/// Once added (max 1), azimuth [gon], distance [cm], note and is_marked are
/// editable. All other entries in `plot_support_points` (e.g. the GNSS
/// helping point with point_type = 5) are preserved on every write.
///
/// Activated via `"component": "displaced_marker"` in the layout style-map.
class DisplacedMarker extends StatefulWidget {
  final Map<String, dynamic>? jsonSchema;
  final Map<String, dynamic>? data;
  final Map<String, dynamic>? previousProperties;
  final TFMValidationResult? validationResult;
  final Function(Map<String, dynamic>)? onDataChanged;

  const DisplacedMarker({
    super.key,
    this.jsonSchema,
    this.data,
    this.previousProperties,
    this.validationResult,
    this.onDataChanged,
  });

  @override
  State<DisplacedMarker> createState() => _DisplacedMarkerState();
}

class _DisplacedMarkerState extends State<DisplacedMarker> {
  static const int _pointType = 1;
  static const Set<String> _relevantMarkerStatuses = {'2', '3', '4'};

  final _azimuthController = TextEditingController();
  final _distanceController = TextEditingController();
  final _noteController = TextEditingController();

  @override
  void initState() {
    super.initState();
    _syncControllersFromData();
  }

  @override
  void didUpdateWidget(DisplacedMarker oldWidget) {
    super.didUpdateWidget(oldWidget);
    _syncControllersFromData();
  }

  @override
  void dispose() {
    _azimuthController.dispose();
    _distanceController.dispose();
    _noteController.dispose();
    super.dispose();
  }

  // ── Data helpers ────────────────────────────────────────────────────────

  List<Map<String, dynamic>> _currentPoints() {
    final raw = widget.data?['plot_support_points'];
    if (raw is! List) return [];
    return raw.map((p) => Map<String, dynamic>.from(p as Map)).toList();
  }

  int _markerIndex(List<Map<String, dynamic>> points) {
    return points.indexWhere((p) => p['point_type'] == _pointType);
  }

  Map<String, dynamic>? get _marker {
    final points = _currentPoints();
    final index = _markerIndex(points);
    return index >= 0 ? points[index] : null;
  }

  void _writePoints(List<Map<String, dynamic>> points) {
    widget.onDataChanged?.call({'plot_support_points': points});
  }

  bool get _isMarkerStatusRelevant {
    final status = widget.data?['marker_status'];
    return status != null && _relevantMarkerStatuses.contains(status.toString());
  }

  /// Only overwrite controller text if the underlying value actually differs,
  /// so typing (and the cursor position) is not disturbed by rebuilds.
  void _syncControllersFromData() {
    final marker = _marker;
    final azimuth = marker?['azimuth']?.toString() ?? '';
    final distance = marker?['distance']?.toString() ?? '';
    final note = marker?['note']?.toString() ?? '';

    if (_azimuthController.text != azimuth &&
        int.tryParse(_azimuthController.text) != marker?['azimuth']) {
      _azimuthController.text = azimuth;
    }
    if (_distanceController.text != distance &&
        int.tryParse(_distanceController.text) != marker?['distance']) {
      _distanceController.text = distance;
    }
    if (_noteController.text != note && marker != null && _noteController.text != marker['note']) {
      _noteController.text = note;
    }
  }

  // ── Actions ─────────────────────────────────────────────────────────────

  void _addMarker() {
    final points = _currentPoints();
    if (_markerIndex(points) >= 0) return;
    points.add({'point_type': _pointType, 'is_marked': false});
    _writePoints(points);
  }

  void _removeMarker() {
    final points = _currentPoints();
    final index = _markerIndex(points);
    if (index < 0) return;
    points.removeAt(index);
    _azimuthController.clear();
    _distanceController.clear();
    _noteController.clear();
    _writePoints(points);
  }

  void _updateMarker(String key, dynamic value) {
    final points = _currentPoints();
    final index = _markerIndex(points);
    if (index < 0) return;
    points[index] = {...points[index], key: value};
    _writePoints(points);
  }

  // ── Validation helpers ──────────────────────────────────────────────────

  String? get _azimuthError {
    final text = _azimuthController.text;
    if (text.isEmpty) return null;
    final value = int.tryParse(text);
    if (value == null || value < 0 || value > 399) return '0–399 Gon';
    return null;
  }

  String? get _distanceError {
    final text = _distanceController.text;
    if (text.isEmpty) return null;
    final value = int.tryParse(text);
    if (value == null || value < 1) return 'mind. 1 cm';
    return null;
  }

  // ── UI ──────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    final marker = _marker;

    if (marker == null && !_isMarkerStatusRelevant) {
      return const SizedBox.shrink();
    }

    if (marker == null) {
      return Padding(
        padding: const EdgeInsets.symmetric(vertical: 4),
        child: Center(
          child: TextButton.icon(
            onPressed: _addMarker,
            label: const Text('Versetzte Markierung anlegen'),
          ),
        ),
      );
    }

    return Card(
      margin: const EdgeInsets.symmetric(vertical: 8),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(
                    'Versetzte Markierung',
                    style: Theme.of(context).textTheme.titleSmall,
                  ),
                ),
                IconButton(
                  onPressed: _removeMarker,
                  icon: const Icon(Icons.delete_outline, size: 20),
                  tooltip: 'Versetzte Markierung entfernen',
                  color: Colors.red,
                ),
              ],
            ),
            const SizedBox(height: 8),
            Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _distanceController,
                    keyboardType: TextInputType.number,
                    textAlign: TextAlign.right,
                    inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                    decoration: InputDecoration(
                      isDense: true,
                      labelText: 'Horizontalentfernung',
                      suffix: const Text(' cm'),
                      errorText: _distanceError,
                      border: const OutlineInputBorder(
                        borderRadius: BorderRadius.all(Radius.circular(40)),
                      ),
                    ),
                    onChanged: (value) {
                      setState(() {});
                      _updateMarker('distance', int.tryParse(value));
                    },
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: TextField(
                    controller: _azimuthController,
                    keyboardType: TextInputType.number,
                    textAlign: TextAlign.right,
                    inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                    decoration: InputDecoration(
                      isDense: true,
                      labelText: 'Azimut',
                      suffix: const Text(' Gon'),
                      errorText: _azimuthError,
                      border: const OutlineInputBorder(
                        borderRadius: BorderRadius.all(Radius.circular(40)),
                      ),
                    ),
                    onChanged: (value) {
                      setState(() {});
                      _updateMarker('azimuth', int.tryParse(value));
                    },
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _noteController,
              decoration: const InputDecoration(
                isDense: true,
                labelText: 'Beschreibung',
                border: OutlineInputBorder(borderRadius: BorderRadius.all(Radius.circular(40))),
              ),
              onChanged: (value) => _updateMarker('note', value.isEmpty ? null : value),
            ),
            SwitchListTile(
              dense: true,
              contentPadding: EdgeInsets.zero,
              title: const Text('Ist markiert'),
              value: marker['is_marked'] == true,
              onChanged: (value) => _updateMarker('is_marked', value),
            ),
          ],
        ),
      ),
    );
  }
}
