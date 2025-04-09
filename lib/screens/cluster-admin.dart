import 'package:beamer/beamer.dart';
import 'package:flutter/material.dart';
import 'package:pluto_grid/pluto_grid.dart';
import 'package:terrestrial_forest_monitor/widgets/form/datagrid-from-sqlite-table.dart';

class ClusterAdmin extends StatefulWidget {
  const ClusterAdmin({super.key});

  @override
  State<ClusterAdmin> createState() => _ClusterAdminState();
}

class _ClusterAdminState extends State<ClusterAdmin> {
  final GlobalKey<DataGridFromSqlTableState> _dataGridKey = GlobalKey<DataGridFromSqlTableState>();

  _onRowsSelected(List<PlutoRow>? rows) {
    print('Selected rows count: ${rows?.length}');
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        leading: IconButton(icon: Icon(Icons.arrow_back), onPressed: () => Beamer.of(context).beamToNamed('/')),
        title: const Text('Cluster Admin'),
        backgroundColor: Colors.transparent,
        actions: [
          ElevatedButton(
            onPressed: () {
              _dataGridKey.currentState?.selectAll();
            },
            child: Text('Select All'),
          ),
        ],
      ),
      body: DataGridFromSqlTable(key: _dataGridKey, tableName: 'ps_data__cluster', multiSelect: true, onRowsSelected: _onRowsSelected),
    );
  }
}
