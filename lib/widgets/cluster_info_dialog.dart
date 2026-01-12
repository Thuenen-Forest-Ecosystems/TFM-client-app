import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:terrestrial_forest_monitor/repositories/records_repository.dart';

/// ClusterInfoButton - Shows an info icon that opens a dialog with cluster JSON data
///
/// Displays the cluster field from the record in a formatted list view
class ClusterInfoButton extends StatelessWidget {
  final Record? record;
  final Color? iconColor;
  final double? iconSize;
  final String? tooltip;

  const ClusterInfoButton({
    super.key,
    required this.record,
    this.iconColor,
    this.iconSize,
    this.tooltip,
  });

  Future<void> _showClusterInfo(BuildContext context) async {
    
    if (record == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Kein Datensatz verfügbar'), duration: Duration(seconds: 2)),
      );
      return;
    }

    // Get cluster data using the getCluster() method
    final clusterMap = record!.getCluster();


    if (clusterMap == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Keine Cluster-Informationen verfügbar'),
          duration: Duration(seconds: 2),
        ),
      );
      return;
    }

    showDialog(
      context: context,
      builder: (context) =>
          ClusterInfoDialog(clusterData: clusterMap, clusterName: record!.clusterName),
    );
  }

  @override
  Widget build(BuildContext context) {
    // Hide button if record is null or has no cluster data
    if (record == null || record!.getCluster() == null) {
      return const SizedBox.shrink();
    }
    
    return IconButton(
      icon: Icon(Icons.info_outline, color: iconColor, size: iconSize),
      tooltip: tooltip ?? 'Cluster-Informationen anzeigen',
      onPressed: () => _showClusterInfo(context),
    );
  }
}

/// Dialog that displays cluster information in a formatted list
class ClusterInfoDialog extends StatelessWidget {
  final Map<String, dynamic> clusterData;
  final String clusterName;

  const ClusterInfoDialog({super.key, required this.clusterData, required this.clusterName});

  /// Format value for display
  String _formatValue(dynamic value) {
    if (value == null) return 'null';
    if (value is String) return value;
    if (value is num) return value.toString();
    if (value is bool) return value ? 'Ja' : 'Nein';
    if (value is List) return 'Liste (${value.length} Einträge)';
    if (value is Map) return 'Objekt (${value.length} Felder)';
    return value.toString();
  }

  /// Build a list tile for a cluster field
  Widget _buildFieldTile(String key, dynamic value) {
    return ListTile(
      dense: true,
      title: Text(key, style: const TextStyle(fontWeight: FontWeight.w500, fontSize: 14)),
      subtitle: Text(_formatValue(value), style: const TextStyle(fontSize: 13)),
      trailing: value != null && (value is Map || value is List)
          ? Icon(Icons.arrow_forward_ios, size: 14, color: Colors.grey[600])
          : null,
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final sortedKeys = clusterData.keys.toList()..sort();

    return Dialog(
      child: Container(
        constraints: const BoxConstraints(maxWidth: 600, maxHeight: 800),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Header
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: theme.primaryColor.withOpacity(0.1),
                border: Border(bottom: BorderSide(color: theme.dividerColor)),
              ),
              child: Row(
                children: [
                  Icon(Icons.info_outline, color: theme.primaryColor),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('Cluster-Informationen', style: theme.textTheme.titleLarge),
                        const SizedBox(height: 4),
                        Text(
                          'Trakt: $clusterName',
                          style: theme.textTheme.bodyMedium?.copyWith(color: Colors.grey[600]),
                        ),
                      ],
                    ),
                  ),
                  IconButton(
                    icon: const Icon(Icons.close),
                    onPressed: () => Navigator.of(context).pop(),
                    tooltip: 'Schließen',
                  ),
                ],
              ),
            ),

            // List of cluster fields
            Expanded(
              child: ListView.separated(
                padding: const EdgeInsets.symmetric(vertical: 8),
                itemCount: sortedKeys.length,
                separatorBuilder: (context, index) =>
                    Divider(height: 1, indent: 16, endIndent: 16, color: Colors.grey[300]),
                itemBuilder: (context, index) {
                  final key = sortedKeys[index];
                  final value = clusterData[key];
                  return _buildFieldTile(key, value);
                },
              ),
            ),

            // Footer with actions
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                border: Border(top: BorderSide(color: theme.dividerColor)),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  TextButton.icon(
                    onPressed: () {
                      final jsonString = const JsonEncoder.withIndent('  ').convert(clusterData);
                      Clipboard.setData(ClipboardData(text: jsonString));
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(
                          content: Text('JSON in Zwischenablage kopiert'),
                          duration: Duration(seconds: 2),
                        ),
                      );
                    },
                    icon: const Icon(Icons.copy, size: 18),
                    label: const Text('JSON kopieren'),
                  ),
                  const SizedBox(width: 8),
                  ElevatedButton(
                    onPressed: () => Navigator.of(context).pop(),
                    child: const Text('Schließen'),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
