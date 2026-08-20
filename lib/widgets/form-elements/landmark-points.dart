import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:terrestrial_forest_monitor/services/validation_types.dart';

/// LandmarkPoints – widget for adding `plot_support_points` entries with
/// `point_type = 2` ("markanter Geländepunkt") to the current record.
///
/// A landmark is a conspicuous – usually distant – terrain feature that helps
/// to find the plot corner again. Per entry the crew records azimuth [gon] and
/// horizontal distance [cm] measured from the corner to the landmark, plus a
/// short description. Unlike the displaced marker, any number of landmarks may
/// be recorded. All other entries in `plot_support_points` (GNSS helping point
/// with point_type = 5, versetzte Markierung with point_type = 1) are
/// preserved on every write.
///
/// Activated via `"component": "landmark_points"` in the layout style-map.
class LandmarkPoints extends StatefulWidget {
  final Map<String, dynamic>? jsonSchema;
  final Map<String, dynamic>? data;
  final Map<String, dynamic>? previousProperties;
  final TFMValidationResult? validationResult;
  final Function(Map<String, dynamic>)? onDataChanged;

  const LandmarkPoints({
    super.key,
    this.jsonSchema,
    this.data,
    this.previousProperties,
    this.validationResult,
    this.onDataChanged,
  });

  @override
  State<LandmarkPoints> createState() => _LandmarkPointsState();
}

class _LandmarkPointsState extends State<LandmarkPoints> {
  static const int _pointType = 2;

  /// One controller trio per landmark, in the order the landmarks appear in
  /// `plot_support_points`.
  final List<_LandmarkControllers> _controllers = [];

  @override
  void initState() {
    super.initState();
    _syncControllersFromData();
  }

  @override
  void didUpdateWidget(LandmarkPoints oldWidget) {
    super.didUpdateWidget(oldWidget);
    _syncControllersFromData();
  }

  @override
  void dispose() {
    for (final controllers in _controllers) {
      controllers.dispose();
    }
    super.dispose();
  }

  // ── Data helpers ────────────────────────────────────────────────────────

  List<Map<String, dynamic>> _currentPoints() {
    final raw = widget.data?['plot_support_points'];
    if (raw is! List) return [];
    return raw.map((p) => Map<String, dynamic>.from(p as Map)).toList();
  }

  /// Positions of the landmark entries inside the full `plot_support_points`
  /// list, so edits address the right element without touching the others.
  List<int> _landmarkIndices(List<Map<String, dynamic>> points) {
    final indices = <int>[];
    for (var i = 0; i < points.length; i++) {
      if (points[i]['point_type'] == _pointType) indices.add(i);
    }
    return indices;
  }

  List<Map<String, dynamic>> get _landmarks {
    final points = _currentPoints();
    return _landmarkIndices(points).map((i) => points[i]).toList();
  }

  void _writePoints(List<Map<String, dynamic>> points) {
    widget.onDataChanged?.call({'plot_support_points': points});
  }

  void _syncControllersFromData() {
    final landmarks = _landmarks;

    while (_controllers.length < landmarks.length) {
      _controllers.add(_LandmarkControllers());
    }
    while (_controllers.length > landmarks.length) {
      _controllers.removeLast().dispose();
    }
    for (var i = 0; i < landmarks.length; i++) {
      _controllers[i].syncFrom(landmarks[i]);
    }
  }

  // ── Actions ─────────────────────────────────────────────────────────────

  void _addLandmark() {
    final points = _currentPoints();
    points.add({'point_type': _pointType, 'is_marked': false});
    setState(() {
      _controllers.add(_LandmarkControllers());
    });
    _writePoints(points);
  }

  void _removeLandmark(int landmarkIndex) {
    final points = _currentPoints();
    final indices = _landmarkIndices(points);
    if (landmarkIndex < 0 || landmarkIndex >= indices.length) return;
    points.removeAt(indices[landmarkIndex]);
    setState(() {
      if (landmarkIndex < _controllers.length) {
        _controllers.removeAt(landmarkIndex).dispose();
      }
    });
    _writePoints(points);
  }

  void _updateLandmark(int landmarkIndex, String key, dynamic value) {
    final points = _currentPoints();
    final indices = _landmarkIndices(points);
    if (landmarkIndex < 0 || landmarkIndex >= indices.length) return;
    final pointIndex = indices[landmarkIndex];
    points[pointIndex] = {...points[pointIndex], key: value};
    _writePoints(points);
  }

  // ── Validation helpers ──────────────────────────────────────────────────

  String? _azimuthError(String text) {
    if (text.isEmpty) return null;
    final value = int.tryParse(text);
    if (value == null || value < 0 || value > 399) return '0–399 Gon';
    return null;
  }

  String? _distanceError(String text) {
    if (text.isEmpty) return null;
    final value = int.tryParse(text);
    if (value == null || value < 1) return 'mind. 1 cm';
    return null;
  }

  // ── UI ──────────────────────────────────────────────────────────────────

  Widget _buildLandmarkCard(int index) {
    final controllers = _controllers[index];

    return Card.outlined(
      margin: const EdgeInsets.only(bottom: 8),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(12, 4, 12, 12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(
                    'Geländepunkt ${index + 1}',
                    style: Theme.of(context).textTheme.labelLarge,
                  ),
                ),
                IconButton(
                  onPressed: () => _removeLandmark(index),
                  icon: const Icon(Icons.delete_outline, size: 20),
                  tooltip: 'Geländepunkt entfernen',
                  color: Colors.red,
                ),
              ],
            ),
            const SizedBox(height: 4),
            Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: controllers.distance,
                    keyboardType: TextInputType.number,
                    textAlign: TextAlign.right,
                    inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                    decoration: InputDecoration(
                      isDense: true,
                      labelText: 'Horizontalentfernung',
                      suffix: const Text(' cm'),
                      errorText: _distanceError(controllers.distance.text),
                      border: const OutlineInputBorder(
                        borderRadius: BorderRadius.all(Radius.circular(40)),
                      ),
                    ),
                    onChanged: (value) {
                      setState(() {});
                      _updateLandmark(index, 'distance', int.tryParse(value));
                    },
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: TextField(
                    controller: controllers.azimuth,
                    keyboardType: TextInputType.number,
                    textAlign: TextAlign.right,
                    inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                    decoration: InputDecoration(
                      isDense: true,
                      labelText: 'Azimut',
                      suffix: const Text(' Gon'),
                      errorText: _azimuthError(controllers.azimuth.text),
                      border: const OutlineInputBorder(
                        borderRadius: BorderRadius.all(Radius.circular(40)),
                      ),
                    ),
                    onChanged: (value) {
                      setState(() {});
                      _updateLandmark(index, 'azimuth', int.tryParse(value));
                    },
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            TextField(
              controller: controllers.note,
              decoration: const InputDecoration(
                isDense: true,
                labelText: 'Beschreibung',
                border: OutlineInputBorder(borderRadius: BorderRadius.all(Radius.circular(40))),
              ),
              onChanged: (value) => _updateLandmark(index, 'note', value.isEmpty ? null : value),
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final landmarks = _landmarks;

    // Defensive: keep the controllers aligned with the data even when the
    // parent rebuilt this widget without going through didUpdateWidget.
    while (_controllers.length < landmarks.length) {
      _controllers.add(_LandmarkControllers());
    }

    // The surrounding `card` layout item supplies the frame and the
    // "Markante Geländepunkte" heading, so only the entries are built here.
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      mainAxisSize: MainAxisSize.min,
      children: [
        Padding(
          padding: const EdgeInsets.only(bottom: 8),
          child: Text(
            'Azimut und Entfernung von der Ecke zum Geländepunkt',
            style: Theme.of(context).textTheme.bodySmall?.copyWith(
              color: Theme.of(context).colorScheme.onSurfaceVariant,
            ),
          ),
        ),
        for (var i = 0; i < landmarks.length; i++) _buildLandmarkCard(i),
        Center(
          child: TextButton.icon(
            onPressed: _addLandmark,
            icon: const Icon(Icons.add, size: 18),
            label: const Text('Geländepunkt hinzufügen'),
          ),
        ),
      ],
    );
  }
}

class _LandmarkControllers {
  final TextEditingController azimuth = TextEditingController();
  final TextEditingController distance = TextEditingController();
  final TextEditingController note = TextEditingController();

  /// Only overwrite a controller when the underlying value actually differs,
  /// so typing (and the cursor position) is not disturbed by rebuilds.
  void syncFrom(Map<String, dynamic> point) {
    _apply(azimuth, point['azimuth']?.toString() ?? '', numeric: true);
    _apply(distance, point['distance']?.toString() ?? '', numeric: true);
    _apply(note, point['note']?.toString() ?? '');
  }

  void _apply(TextEditingController controller, String value, {bool numeric = false}) {
    if (controller.text == value) return;
    // "007" parses to the stored 7 – leave the raw input alone while typing.
    if (numeric && int.tryParse(controller.text)?.toString() == value) return;
    controller.value = TextEditingValue(
      text: value,
      selection: TextSelection.collapsed(offset: value.length),
    );
  }

  void dispose() {
    azimuth.dispose();
    distance.dispose();
    note.dispose();
  }
}
