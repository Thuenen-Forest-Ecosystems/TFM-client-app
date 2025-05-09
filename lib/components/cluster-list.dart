import 'package:flutter/material.dart';
import 'package:terrestrial_forest_monitor/services/powersync.dart';

class ClusterList extends StatefulWidget {
  const ClusterList({super.key});

  @override
  State<ClusterList> createState() => _ClusterListState();
}

class _ClusterListState extends State<ClusterList> {
  List checked = [];

  @override
  void initState() {
    super.initState();
  }

  Future<List<Widget>> _getLookups() async {
    return [];
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder(
      future: db.getAll('SELECT * FROM cluster LIMIT 10'),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return CircularProgressIndicator();
        } else if (snapshot.hasData) {
          return Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text('Filter by Cluster'),
              ...snapshot.data!.map<Widget>((dynamic cluster) {
                return CheckboxListTile(
                  title: Text(cluster['cluster_name'].toString()),
                  subtitle: Text(checked.contains(cluster['id']) ? 'Checked' : 'Unchecked'),
                  value: checked.contains(cluster['id']),
                  onChanged: (bool? value) {
                    if (value == true) {
                      checked.add(cluster['id']);
                    } else {
                      checked.remove(cluster['id']);
                    }
                    setState(() {});
                  },
                );
              }),
            ],
          );
        } else {
          return Text('Loading...');
        }
      },
    );
  }
}
