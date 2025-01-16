import 'package:flutter/material.dart';
import 'package:terrestrial_forest_monitor/services/powersync.dart';
import 'package:terrestrial_forest_monitor/widgets/form/ediable-datatable-from-sqlite-table.dart';
import 'package:powersync/sqlite3_common.dart' as sqlite;

class TIWzp extends StatefulWidget {
  final String plotId;
  final List<Map<dynamic, dynamic>> data;
  final Function? onUpdate;
  const TIWzp({super.key, required this.plotId, required this.data, this.onUpdate});

  @override
  State<TIWzp> createState() => _TIWzpState();
}

class _TIWzpState extends State<TIWzp> {
  Future<sqlite.ResultSet> _loadData() async {
    sqlite.ResultSet trees = await db.getAll('SELECT * FROM tree WHERE plotid = ?', [widget.plotId]);

    // trees to json array

    return trees;
  }

  Map _filterData() {
    Map tableSettings = {
      'id': {
        "visible": false,
      },
      'intkey': {
        "visible": false,
      },
      'plot_id': {
        "visible": false,
        "editable": false,
      },
      'tree_number': {
        "editable": false,
      },
    };

    return tableSettings;
  }

  @override
  Widget build(BuildContext context) {
    return Card(
      child: EditableDatatableFromSqliteTable(
        data: widget.data,
        tableSettings: _filterData(),
        onUpdate: () {
          if (widget.onUpdate != null) {
            widget.onUpdate!();
          }
        },
      ),
    );
  }
}
