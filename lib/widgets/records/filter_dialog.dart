import 'package:flutter/material.dart';
import 'package:terrestrial_forest_monitor/widgets/cluster/order-cluster-by.dart';

class RecordsFilterDialog extends StatefulWidget {
  final ClusterOrderBy currentOrderBy;
  final Function(ClusterOrderBy) onOrderByChanged;
  final bool showCompleted;
  final Function(bool) onShowCompletedChanged;
  final bool filterByMapExtent;
  final Function(bool) onFilterByMapExtentChanged;

  const RecordsFilterDialog({
    super.key,
    required this.currentOrderBy,
    required this.onOrderByChanged,
    required this.showCompleted,
    required this.onShowCompletedChanged,
    required this.filterByMapExtent,
    required this.onFilterByMapExtentChanged,
  });

  @override
  State<RecordsFilterDialog> createState() => _RecordsFilterDialogState();
}

class _RecordsFilterDialogState extends State<RecordsFilterDialog> {
  late bool _showCompleted;
  late bool _filterByMapExtent;

  @override
  void initState() {
    super.initState();
    _showCompleted = widget.showCompleted;
    _filterByMapExtent = widget.filterByMapExtent;
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Filter & Sortierung'),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          SwitchListTile(
            title: const Text('Abgeschlossene Ecken anzeigen'),
            subtitle: const Text('Ecken mit completed_at_troop'),
            value: _showCompleted,
            onChanged: (value) {
              setState(() {
                _showCompleted = value;
              });
              widget.onShowCompletedChanged(value);
            },
          ),
          SwitchListTile(
            title: const Text('Nur Ecken im Kartenausschnitt'),
            subtitle: const Text('Filtert nach aktueller Kartenansicht'),
            value: _filterByMapExtent,
            onChanged: (value) {
              setState(() {
                _filterByMapExtent = value;
              });
              widget.onFilterByMapExtentChanged(value);
            },
          ),
          const Divider(),
          const Padding(
            padding: EdgeInsets.symmetric(vertical: 8.0),
            child: Text('Sortierung', style: TextStyle(fontWeight: FontWeight.bold)),
          ),
          RadioListTile<ClusterOrderBy>(
            title: const Text('Entfernung'),
            subtitle: const Text('Nächste Ecke zuerst'),
            value: ClusterOrderBy.distance,
            groupValue: widget.currentOrderBy,
            onChanged: (value) {
              if (value != null) {
                widget.onOrderByChanged(value);
                Navigator.of(context).pop();
              }
            },
          ),
          RadioListTile<ClusterOrderBy>(
            title: const Text('Name'),
            subtitle: const Text('Alphabetisch nach Traktnummer'),
            value: ClusterOrderBy.clusterName,
            groupValue: widget.currentOrderBy,
            onChanged: (value) {
              if (value != null) {
                widget.onOrderByChanged(value);
                Navigator.of(context).pop();
              }
            },
          ),
          RadioListTile<ClusterOrderBy>(
            title: const Text('Zuletzt bearbeitet'),
            subtitle: const Text('Neueste zuerst'),
            value: ClusterOrderBy.updatedAt,
            groupValue: widget.currentOrderBy,
            onChanged: (value) {
              if (value != null) {
                widget.onOrderByChanged(value);
                Navigator.of(context).pop();
              }
            },
          ),
        ],
      ),
      actions: [
        TextButton(onPressed: () => Navigator.of(context).pop(), child: const Text('Abbrechen')),
      ],
    );
  }
}
