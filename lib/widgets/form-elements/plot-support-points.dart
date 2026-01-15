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

  @override
  Widget build(BuildContext context) {
    // Extract plot_support_points array from previous properties
    final supportPoints = previousProperties?['plot_support_points'] as List<dynamic>? ?? [];

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (supportPoints.isEmpty)
          const Center(
            child: Padding(
              padding: EdgeInsets.all(16.0),
              child: Text(
                'Keine Hilfspunkte aus Vorjahr vorhanden',
                style: TextStyle(color: Colors.grey),
              ),
            ),
          )
        else
          ListView.builder(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            itemCount: supportPoints.length,
            itemBuilder: (context, index) {
              final point = supportPoints[index] as Map<String, dynamic>;
              return _buildSupportPointCard(context, point, index);
            },
          ),
      ],
    );
  }

  Widget _buildSupportPointCard(BuildContext context, Map<String, dynamic> point, int index) {
    final pointType = _getPointTypeLabel(point['point_type'] as int?);
    final isMarked = point['is_marked'] as bool? ?? false;
    final note = point['note'] as String? ?? '';
    final azimuth = point['azimuth'] as num?;
    final distance = point['distance'] as num?;

    return Card(
      margin: const EdgeInsets.only(bottom: 8.0),
      elevation: 1,
      child: ListTile(
        leading: CircleAvatar(
          backgroundColor: isMarked ? Colors.green : Colors.grey,
          child: Text('${index + 1}'),
        ),
        title: Text(pointType, style: const TextStyle(fontWeight: FontWeight.bold)),
        subtitle: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (note.isNotEmpty)
              Padding(
                padding: const EdgeInsets.only(top: 4.0),
                child: Text(note, maxLines: 2, overflow: TextOverflow.ellipsis),
              ),
            Padding(
              padding: const EdgeInsets.only(top: 4.0),
              child: Row(
                children: [
                  if (azimuth != null) ...[
                    const Icon(Icons.explore, size: 16),
                    const SizedBox(width: 4),
                    Text('${azimuth}°'),
                    const SizedBox(width: 16),
                  ],
                  if (distance != null) ...[
                    const Icon(Icons.straighten, size: 16),
                    const SizedBox(width: 4),
                    Text('${(distance / 100).toStringAsFixed(2)} m'),
                  ],
                ],
              ),
            ),
          ],
        ),
        trailing: isMarked ? const Icon(Icons.check_circle, color: Colors.green) : null,
      ),
    );
  }

  String _getPointTypeLabel(int? pointType) {
    switch (pointType) {
      case 1:
        return 'Hilfspunkt 1';
      case 2:
        return 'Landmarke';
      case 3:
        return 'Startpunkt';
      case 4:
        return 'Hilfspunkt';
      default:
        return 'Unbekannter Punkttyp';
    }
  }
}
