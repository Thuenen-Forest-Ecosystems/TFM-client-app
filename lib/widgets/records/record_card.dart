import 'package:flutter/material.dart';
import 'package:beamer/beamer.dart';
import 'package:terrestrial_forest_monitor/repositories/records_repository.dart';
import 'package:terrestrial_forest_monitor/services/powersync.dart';
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
  String? _forestStatusLabel;

  @override
  void initState() {
    super.initState();
    _loadForestStatusLabel();
  }

  @override
  void didUpdateWidget(RecordCard oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.record.properties['forest_status'] != widget.record.properties['forest_status']) {
      _loadForestStatusLabel();
    }
  }

  Future<void> _loadForestStatusLabel() async {
    final forestStatus = widget.record.properties['forest_status'];
    if (forestStatus == null) {
      setState(() => _forestStatusLabel = null);
      return;
    }
    try {
      final result = await db.get('SELECT name_de FROM lookup_forest_status WHERE code = ?', [
        forestStatus,
      ]);
      if (mounted && result != null) {
        setState(() => _forestStatusLabel = result['name_de'] as String?);
      }
    } catch (e) {
      debugPrint('Error loading forest status label: $e');
    }
  }

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
    final properties = widget.record.properties;

    /*final isAccessible = properties['accessibility'] != null
        ? (properties['accessibility'] == 1)
        : true;*/
    final isForest = properties['forest_status'] != null
        ? (properties['forest_status'] == 5 ||
              properties['forest_status'] == 3 ||
              properties['forest_status'] == 4)
        : true;

    final note = widget.record.note;

    // Check synchronization status from real-time PowerSync data
    final isSynchronized = _isSynchronized();

    // Reduce opacity if not accessible or not forest
    final shouldReduceOpacity = !isForest;

    return Opacity(
      opacity: shouldReduceOpacity ? 0.5 : 1.0,
      child: Card(
        margin: const EdgeInsets.only(bottom: 12),
        elevation: 2,
        child: InkWell(
          onTap: () {
            Beamer.of(context).beamToNamed(
              '/properties-edit/${Uri.encodeComponent(widget.record.clusterName)}/${Uri.encodeComponent(widget.record.plotName)}',
            );
          },
          child: IntrinsicHeight(
            child: Row(
              children: [
                // Status indicator
                Container(
                  width: 10,
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
                        ListTile(
                          contentPadding: EdgeInsets.zero,
                          title: Text(
                            'Trakt: ${widget.record.clusterName} | Ecke: ${widget.record.plotName}',
                          ),
                          subtitle: widget.distanceText != null
                              ? Text(
                                  widget.distanceText!,
                                  style: TextStyle(fontSize: 14, color: Colors.grey[600]),
                                )
                              : null,
                          trailing: widget.onFocusOnMap != null
                              ? IconButton(
                                  icon: const Icon(Icons.map),
                                  tooltip: 'Focus on map',
                                  onPressed: widget.onFocusOnMap,
                                )
                              : null,
                        ),
                        if (note != null && note.isNotEmpty)
                          Row(
                            children: [
                              const Icon(Icons.chat, size: 16, color: Colors.blue),
                              const SizedBox(width: 4),
                              Expanded(child: Text(note, style: TextStyle(fontSize: 12))),
                            ],
                          ),
                        if (!isForest && _forestStatusLabel != null)
                          Row(
                            children: [
                              const Icon(Icons.warning, size: 16, color: Colors.orange),
                              const SizedBox(width: 4),
                              Text(_forestStatusLabel!, style: TextStyle(fontSize: 12)),
                            ],
                          ),
                        if (widget.record.previousProperties?['plot_support_points'].length > 0)
                          Row(children: [const Text('Mit Hilfspunkten')]),
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
        ),
      ),
    );
  }
}
