import 'package:flutter/material.dart';
import 'package:powersync/sqlite3_common.dart' as sqlite;
import 'package:terrestrial_forest_monitor/widgets/output/lookup.dart';
import 'package:terrestrial_forest_monitor/widgets/timestamp-to-timeago.dart';

class ClusterPreview extends StatefulWidget {
  final String clusterId;
  final sqlite.Row clusterRow;
  const ClusterPreview({super.key, required this.clusterId, required this.clusterRow});

  @override
  State<ClusterPreview> createState() => _ClusterPreviewState();
}

class _ClusterPreviewState extends State<ClusterPreview> {
  @override
  Widget build(BuildContext context) {
    return Card(
      child: Column(
        children: [
          ListTile(
            title: Text('${widget.clusterRow['cluster_name']}'),
            subtitle: Row(
              children: [
                Text('Erstellt: '),
                TimestampToTimeago(timestamp: widget.clusterRow['created_at']),
              ],
            ),
            /*trailing: IconButton(
                onPressed: () {
                  showDialog<String>(
                    context: context,
                    builder: (BuildContext context) => AlertDialog(
                      title: Text('Trakt: ${widget.clusterRow['cluster_name']}'),
                      content: Text('Cluster ID: ${widget.clusterId}'),
                    ),
                  );
                },
                icon: Icon(Icons.info),),*/
          ),
          Padding(
            padding: EdgeInsets.all(10),
            child: Row(
              children: [
                LookupOutput(
                  lookupTable: 'lookup_state',
                  value: widget.clusterRow['state_responsible'] ?? '',
                  comment: 'verantwortliches Bundesland',
                ),
                LookupOutput(
                  lookupTable: 'lookup_state',
                  value: widget.clusterRow['states_affected'] ?? '',
                  comment: 'Bundesländer',
                ),
              ],
            ),
          )
        ],
      ),
    );
  }
}
