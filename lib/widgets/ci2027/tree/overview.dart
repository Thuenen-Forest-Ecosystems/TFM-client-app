import 'package:flutter/material.dart';
import 'package:powersync/sqlite3.dart' as sqlite;
import 'package:terrestrial_forest_monitor/services/powersync.dart';

class TreeOverview extends StatefulWidget {
  final String plotId;
  const TreeOverview({super.key, required this.plotId});

  @override
  State<TreeOverview> createState() => _TreeOverviewState();
}

class _TreeOverviewState extends State<TreeOverview> {
  Future<sqlite.ResultSet> _getTrees() async {
    print('widget.plotId: ${widget.plotId}');
    sqlite.ResultSet trees = await db.getAll('SELECT * FROM tree WHERE plot_id = ?', [widget.plotId]);

    return trees;
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<sqlite.ResultSet>(
      future: _getTrees(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.done) {
          Widget dbResult;
          if (snapshot.hasData && snapshot.data != null) {
            dbResult = Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text('Trees'),
                Text('${snapshot.data!.length}'),
              ],
            );
          } else {
            dbResult = Text('data not found');
          }
          return Center(child: dbResult);
        } else {
          return SizedBox(
            width: 50,
            height: 50,
            child: CircularProgressIndicator(),
          );
        }
      },
    );
  }
}
