import 'package:flutter/material.dart';
import 'package:beamer/beamer.dart';
import 'package:terrestrial_forest_monitor/repositories/records_repository.dart';
import 'package:url_launcher/url_launcher.dart';

class RecordCard extends StatefulWidget {
  final Record record;
  final String? distanceText;
  final VoidCallback? onFocusOnMap;

  const RecordCard({super.key, required this.record, this.distanceText, this.onFocusOnMap});

  @override
  State<RecordCard> createState() => _RecordCardState();
}

class _RecordCardState extends State<RecordCard> {
  // No need for local state - use widget.record directly for real-time data

  void _openNativeNavigationForRecord(BuildContext context) {
    final coords = widget.record.getCoordinates();
    if (coords == null) return;

    final latitude = coords['latitude'];
    final longitude = coords['longitude'];
    final recordName = '${widget.record.clusterName} | ${widget.record.plotName}';

    final uri = Uri.parse(
      'geo:$latitude,$longitude?q=$latitude,$longitude(${Uri.encodeComponent(recordName)})',
    );

    launchUrl(uri);
  }

  String _formatDate(dynamic date) {
    if (date == null) return 'Nie';
    try {
      // Parse as UTC then convert to local time for display
      final DateTime dt = DateTime.parse(date.toString()).toLocal();
      return '${dt.day.toString().padLeft(2, '0')}.${dt.month.toString().padLeft(2, '0')}.${dt.year} ${dt.hour.toString().padLeft(2, '0')}:${dt.minute.toString().padLeft(2, '0')}';
    } catch (e) {
      return 'Nie';
    }
  }

  bool _isSynchronized() {
    // Simple approach: A record is synchronized if it has an updated_at from the server
    // If it was modified locally and uploaded, the server will set updated_at
    // and PowerSync will sync it back down
    final updatedAt = widget.record.updatedAt;
    final localUpdatedAt = widget.record.localUpdatedAt;

    // If we have a local change timestamp
    if (localUpdatedAt != null) {
      // Not synced if no server timestamp yet
      if (updatedAt == null) return false;

      try {
        final serverTime = DateTime.parse(updatedAt);
        final localTime = DateTime.parse(localUpdatedAt);
        // Server time should be >= local time (within tolerance)
        return serverTime.millisecondsSinceEpoch >= localTime.millisecondsSinceEpoch - 1000;
      } catch (e) {
        return false;
      }
    }

    // No local timestamp means either:
    // 1. Never modified locally (has server updated_at = synced)
    // 2. Old record without timestamps (assume synced)
    return true;
  }

  @override
  Widget build(BuildContext context) {
    // Check if record has completed_at_troop set
    final completedAtTroop = widget.record.completedAtTroop;
    final isCompleted = completedAtTroop != null && completedAtTroop.toString().isNotEmpty;

    // Get last update date
    final updatedAt = widget.record.updatedAt;
    final lastUpdateText = _formatDate(updatedAt);
    final localUpdatedAt = widget.record.localUpdatedAt;
    final lastLocalUpdateText = _formatDate(localUpdatedAt);

    // Check synchronization status from real-time PowerSync data
    final isSynchronized = _isSynchronized();

    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      elevation: 2,
      child: InkWell(
        onTap: () {
          Beamer.of(context).beamToNamed(
            '/properties-edit/${Uri.encodeComponent(widget.record.clusterName)}/${Uri.encodeComponent(widget.record.plotName)}',
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
                                '${widget.record.clusterName} | ${widget.record.plotName}',
                                style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                              ),
                              if (widget.distanceText != null)
                                Text(
                                  widget.distanceText!,
                                  style: TextStyle(fontSize: 14, color: Colors.grey[600]),
                                ),
                            ],
                          ),
                        ),
                        if (widget.onFocusOnMap != null)
                          IconButton(
                            icon: const Icon(Icons.map),
                            tooltip: 'Focus on map',
                            onPressed: widget.onFocusOnMap,
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
                          lastLocalUpdateText,
                          style: TextStyle(fontSize: 12, color: Colors.grey[600]),
                        ),
                        const Spacer(),
                        Icon(
                          isSynchronized ? Icons.done_all : Icons.done_all,
                          size: 16,
                          color: isSynchronized ? Colors.green : Colors.grey,
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
