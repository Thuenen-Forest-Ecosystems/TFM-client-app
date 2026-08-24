import 'package:flutter/material.dart';
import 'package:terrestrial_forest_monitor/services/validation_types.dart';
import 'package:terrestrial_forest_monitor/widgets/form-elements/layout-filter.dart';

/// Read-only list of the `plot_support_points` carried over from the previous
/// inventory. The `point_type` it shows is declared by the style as
/// `options.filterBy.point_type` and defaults to 1 (versetzte Markierung).
///
/// Activated via `"component": "plot_support_points"` in the layout style-map.
class PlotSupportPoints extends StatelessWidget {
  final Map<String, dynamic>? jsonSchema;
  final Map<String, dynamic>? data;
  final Map<String, dynamic>? previousProperties;
  final TFMValidationResult? validationResult;

  /// Layout options of the style item, read for `filterBy.point_type`.
  final Map<String, dynamic>? layoutOptions;

  final Function(Map<String, dynamic>)? onDataChanged;

  const PlotSupportPoints({
    super.key,
    this.jsonSchema,
    this.data,
    this.previousProperties,
    this.validationResult,
    this.layoutOptions,
    this.onDataChanged,
  });

  /// Used when the style declares no `filterBy.point_type`.
  static const int _defaultPointType = 1;

  List<Map<String, dynamic>> _getSupportPoints() {
    final raw = previousProperties?['plot_support_points'];
    if (raw is! List) return [];
    final pointType = LayoutFilter.pointType(layoutOptions) ?? _defaultPointType;
    return raw
        .whereType<Map<String, dynamic>>()
        .where((p) => p['point_type'] == pointType)
        .toList();
  }

  @override
  Widget build(BuildContext context) {
    final points = _getSupportPoints();

    if (points.isEmpty) return const SizedBox.shrink();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        /*Padding(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 4),
          child: Text('Hilfspunkte aus Voraufnahme'),
        ),*/
        ...points.map((point) {
          final note = point['note'] as String?;
          final azimuth = point['azimuth'];
          final distance = point['distance'];
          final isMarked = point['is_marked'] as bool? ?? false;

          final parts = <String>[
            if (azimuth != null) 'Azimut: $azimuth gon',
            if (distance != null) 'Distanz: $distance cm',
          ];

          return ListTile(
            dense: true,
            /*leading: Icon(
              isMarked ? Icons.push_pin : Icons.push_pin_outlined,
              size: 20,
              color: isMarked ? Colors.orange : Colors.grey,
            ),*/
            title: Text(note ?? '–'),
            subtitle: parts.isNotEmpty ? Text(parts.join(' | ')) : null,
          );
        }),
      ],
    );
  }
}
