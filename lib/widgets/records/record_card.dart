import 'package:flutter/material.dart';
import 'package:beamer/beamer.dart';
import 'package:terrestrial_forest_monitor/repositories/records_repository.dart';
import 'package:url_launcher/url_launcher.dart';

class RecordCard extends StatelessWidget {
  final Record record;
  final String? distanceText;
  final VoidCallback? onFocusOnMap;

  const RecordCard({super.key, required this.record, this.distanceText, this.onFocusOnMap});

  void _openNativeNavigationForRecord(BuildContext context) {
    final coords = record.getCoordinates();
    if (coords == null) return;

    final latitude = coords['latitude'];
    final longitude = coords['longitude'];
    final recordName = '${record.clusterName} | ${record.plotName}';

    final uri = Uri.parse(
      'geo:$latitude,$longitude?q=$latitude,$longitude(${Uri.encodeComponent(recordName)})',
    );

    launchUrl(uri);
  }

  String _formatDate(dynamic date) {
    if (date == null) return 'Nie';
    try {
      final DateTime dt = DateTime.parse(date.toString());
      return '${dt.day.toString().padLeft(2, '0')}.${dt.month.toString().padLeft(2, '0')}.${dt.year}';
    } catch (e) {
      return 'Nie';
    }
  }

  bool _isSynchronized() {
    // Use local_updated_at to precisely determine sync status
    // - If local_updated_at is NULL: fully synchronized
    // - If local_updated_at exists: has pending local changes
    try {
      final localUpdatedAt = record.localUpdatedAt;

      // No local timestamp means no pending changes
      if (localUpdatedAt == null || localUpdatedAt.isEmpty) {
        return true;
      }

      // Has local_updated_at timestamp means pending changes
      return false;
    } catch (e) {
      return true; // Default to synchronized if we can't determine
    }
  }

  @override
  Widget build(BuildContext context) {
    // Check if record has completed_at_troop set
    final completedAtTroop = record.properties['completed_at_troop'];
    final isCompleted = completedAtTroop != null && completedAtTroop.toString().isNotEmpty;

    // Get last update date
    final updatedAt = record.properties['updated_at'];
    final lastUpdateText = _formatDate(updatedAt);

    // Check synchronization status
    final isSynchronized = _isSynchronized();

    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      elevation: 2,
      child: InkWell(
        onTap: () {
          Beamer.of(context).beamToNamed(
            '/properties-edit/${Uri.encodeComponent(record.clusterName)}/${Uri.encodeComponent(record.plotName)}',
          );
        },
        child: Row(
          children: [
            // Status indicator
            Container(
              width: 4,
              height: 100,
              decoration: BoxDecoration(
                color: isCompleted ? Colors.green : Colors.red,
                borderRadius: const BorderRadius.only(
                  topLeft: Radius.circular(4),
                  bottomLeft: Radius.circular(4),
                ),
              ),
            ),
            Expanded(
              child: Padding(
                padding: const EdgeInsets.all(12),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Record header
                    Row(
                      children: [
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                '${record.clusterName} | ${record.plotName}',
                                style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                              ),
                              if (distanceText != null)
                                Text(
                                  distanceText!,
                                  style: TextStyle(fontSize: 14, color: Colors.grey[600]),
                                ),
                            ],
                          ),
                        ),
                        if (onFocusOnMap != null)
                          IconButton(
                            icon: const Icon(Icons.map),
                            tooltip: 'Focus on map',
                            onPressed: onFocusOnMap,
                          ),
                        IconButton(
                          icon: const Icon(Icons.directions_car),
                          tooltip: 'Open native navigation',
                          onPressed: () => _openNativeNavigationForRecord(context),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    // Last update and sync status
                    Row(
                      children: [
                        Icon(Icons.update, size: 16, color: Colors.grey[600]),
                        const SizedBox(width: 4),
                        Text(
                          lastUpdateText,
                          style: TextStyle(fontSize: 12, color: Colors.grey[600]),
                        ),
                        const SizedBox(width: 16),
                        Icon(
                          isSynchronized ? Icons.cloud_done : Icons.cloud_off,
                          size: 16,
                          color: isSynchronized ? Colors.green : Colors.orange,
                        ),
                        const SizedBox(width: 4),
                        Text(
                          isSynchronized ? 'Synchronisiert' : 'Nicht synchronisiert',
                          style: TextStyle(
                            fontSize: 12,
                            color: isSynchronized ? Colors.green : Colors.orange,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
