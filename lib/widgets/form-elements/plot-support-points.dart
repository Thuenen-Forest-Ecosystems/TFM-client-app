import 'package:flutter/material.dart';
import 'package:terrestrial_forest_monitor/services/validation_service.dart';

/// Widget for manual entry of plot support points
class PlotSupportPoints extends StatelessWidget {
  final Map<String, dynamic>? jsonSchema;
  final Map<String, dynamic>? data;
  final Map<String, dynamic>? previousProperties;
  final TFMValidationResult? validationResult;
  final Function(Map<String, dynamic>)? onDataChanged;

  const PlotSupportPoints({
    super.key,
    this.jsonSchema,
    this.data,
    this.previousProperties,
    this.validationResult,
    this.onDataChanged,
  });

  List<Map<String, dynamic>> _getSupportPoints() {
    final raw = previousProperties?['plot_support_points'];
    if (raw is! List) return [];
    return raw.whereType<Map<String, dynamic>>().where((p) => p['point_type'] == 1).toList();
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
