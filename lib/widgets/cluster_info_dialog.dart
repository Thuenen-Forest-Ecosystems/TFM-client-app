import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:terrestrial_forest_monitor/repositories/records_repository.dart';
import 'package:terrestrial_forest_monitor/widgets/form-elements/generic-form.dart';
//import 'package:terrestrial_forest_monitor/services/utils.dart';

/// ClusterInfoButton - Shows an info icon that opens a dialog with cluster JSON data
///
/// Displays the cluster field from the record in a formatted list view
class ClusterInfoButton extends StatelessWidget {
  final Record? record;
  final Color? iconColor;
  final double? iconSize;
  final String? tooltip;
  final Map<String, dynamic>? rootSchema;

  const ClusterInfoButton({
    super.key,
    required this.record,
    this.iconColor,
    this.iconSize,
    this.tooltip,
    this.rootSchema,
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
      builder: (context) => ClusterInfoDialog(
        clusterData: clusterMap,
        clusterName: record!.clusterName,
        rootSchema: rootSchema,
      ),
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

/// Dialog that displays cluster information using FormWrapper
class ClusterInfoDialog extends StatefulWidget {
  final Map<String, dynamic> clusterData;
  final String clusterName;
  final Map<String, dynamic>? rootSchema;

  const ClusterInfoDialog({
    super.key,
    required this.clusterData,
    required this.clusterName,
    this.rootSchema,
  });

  @override
  State<ClusterInfoDialog> createState() => _ClusterInfoDialogState();
}

class _ClusterInfoDialogState extends State<ClusterInfoDialog> {
  Map<String, dynamic>? _clusterStyleData;
  bool _isLoading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _loadClusterStyle();
  }

  Future<void> _loadClusterStyle() async {
    try {
      // Load cluster style from assets
      final styleString = await rootBundle.loadString('assets/schema/cluster_style.json');
      final styleJson = jsonDecode(styleString) as Map<String, dynamic>;

      setState(() {
        _clusterStyleData = styleJson;
        _isLoading = false;
      });
    } catch (e) {
      debugPrint('Error loading cluster style: $e');
      setState(() {
        _error = e.toString();
        _isLoading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

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
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('Informationen', style: theme.textTheme.titleLarge),
                        const SizedBox(height: 4),
                        Text('Trakt: ${widget.clusterName}', style: theme.textTheme.bodyMedium),
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

            // Content
            Expanded(
              child: _isLoading
                  ? const Center(child: CircularProgressIndicator())
                  : _error != null || widget.rootSchema == null || _clusterStyleData == null
                  ? _buildFallbackList()
                  : SingleChildScrollView(
                      child: Column(
                        children: [
                          Padding(padding: const EdgeInsets.all(16.0), child: _buildFormWrapper()),
                        ],
                      ),
                    ),
            ),
          ],
        ),
      ),
    );
  }

  /// Build GenericForm for cluster data
  Widget _buildFormWrapper() {
    // Extract layout configuration from cluster style
    final layoutConfig = _clusterStyleData!['layout'] as Map<String, dynamic>?;
    final typeProperties = layoutConfig?['typeProperties'] as Map<String, dynamic>?;
    final properties = layoutConfig?['properties'] as List<dynamic>?;

    // Determine layout mode
    final responsive = typeProperties?['responsive'] as bool? ?? false;
    final layoutMode = responsive ? 'responsive-wrap' : null;

    // Extract property names from layout config
    final includeProperties = properties
        ?.map((p) {
          if (p is String) return p;
          if (p is Map) return p['name'] as String?;
          return null;
        })
        .whereType<String>()
        .toList();

    return GenericForm(
      jsonSchema: widget.rootSchema,
      data: widget.clusterData,
      layout: layoutMode,
      includeProperties: includeProperties,
    );
  }

  /// Fallback to simple list view
  Widget _buildFallbackList() {
    final sortedKeys = widget.clusterData.keys.toList()..sort();

    return ListView.separated(
      padding: const EdgeInsets.symmetric(vertical: 8),
      itemCount: sortedKeys.length,
      separatorBuilder: (context, index) =>
          Divider(height: 1, indent: 16, endIndent: 16, color: Colors.grey[300]),
      itemBuilder: (context, index) {
        final key = sortedKeys[index];
        final value = widget.clusterData[key];
        return _buildFieldTile(key, value);
      },
    );
  }

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

  /// Build a list tile for a cluster field (fallback)
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
}
