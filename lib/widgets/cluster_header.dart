import 'package:flutter/material.dart';
import 'package:terrestrial_forest_monitor/services/api.dart';

class ClusterHeader extends StatefulWidget {
  final String clusterId;
  const ClusterHeader({super.key, required this.clusterId});

  @override
  State<ClusterHeader> createState() => _ClusterHeaderState();
}

class _ClusterHeaderState extends State<ClusterHeader> {
  //String _clusterId;
  List<String> _displayKeys = [
    'id',
    'state_administration',
    'modified_at',
    'created_at',
    'state_location',
  ];

  @override
  initState() {
    super.initState();
    //_clusterId = widget.clusterId;
  }

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: double.infinity,
      child: Card(
        child: Padding(
          padding: EdgeInsets.all(20),
          child: FutureBuilder(
            future: ApiService().getCluster(widget.clusterId),
            builder: (context, snapshot) {
              if (snapshot.connectionState == ConnectionState.waiting) {
                return CircularProgressIndicator();
              } else {
                return Wrap(
                  spacing: 20,
                  runSpacing: 20,
                  children: _displayKeys.map((String key) {
                    if (snapshot.data![key] == null) return SizedBox();

                    return Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          snapshot.data![key].toString(),
                          style: TextStyle(fontWeight: FontWeight.bold),
                        ),
                        Text(
                          key,
                          style: Theme.of(context).textTheme.bodySmall,
                        ),
                      ],
                    );
                  }).toList(),
                );
              }
            },
          ),
        ),
      ),
    );
  }
}
