import 'package:flutter/material.dart';

enum ClusterOrderBy { distance, updatedAt, clusterName }

class OrderClusterBy extends StatefulWidget {
  final ClusterOrderBy initialOrderBy;
  final Function(ClusterOrderBy) onOrderChanged;

  const OrderClusterBy({super.key, this.initialOrderBy = ClusterOrderBy.clusterName, required this.onOrderChanged});

  @override
  State<OrderClusterBy> createState() => _OrderClusterByState();
}

class _OrderClusterByState extends State<OrderClusterBy> {
  late ClusterOrderBy _currentOrder;

  @override
  void initState() {
    super.initState();
    _currentOrder = widget.initialOrderBy;
  }

  String _getOrderLabel(ClusterOrderBy order) {
    switch (order) {
      case ClusterOrderBy.distance:
        return 'Distanz (gps required)';
      case ClusterOrderBy.updatedAt:
        return 'Geändert am';
      case ClusterOrderBy.clusterName:
        return 'Trakt-Nummer';
    }
  }

  IconData _getOrderIcon(ClusterOrderBy order) {
    switch (order) {
      case ClusterOrderBy.distance:
        return Icons.near_me;
      case ClusterOrderBy.updatedAt:
        return Icons.access_time;
      case ClusterOrderBy.clusterName:
        return Icons.sort_by_alpha;
    }
  }

  @override
  Widget build(BuildContext context) {
    return PopupMenuButton<ClusterOrderBy>(
      icon: Icon(_getOrderIcon(_currentOrder), size: 20),
      tooltip: 'Order by: ${_getOrderLabel(_currentOrder)}',
      onSelected: (ClusterOrderBy order) {
        setState(() {
          _currentOrder = order;
        });
        widget.onOrderChanged(order);
      },
      itemBuilder:
          (BuildContext context) =>
              ClusterOrderBy.values.map((order) {
                return PopupMenuItem<ClusterOrderBy>(
                  value: order,
                  child: Row(
                    children: [
                      Icon(_getOrderIcon(order), size: 18),
                      const SizedBox(width: 8),
                      Text(_getOrderLabel(order)),
                      if (_currentOrder == order) ...[const Spacer(), const Icon(Icons.check, size: 18)],
                    ],
                  ),
                );
              }).toList(),
    );
  }
}
