import 'package:flutter/material.dart';
import 'package:powersync/sqlite3_common.dart' as sqlite3;
import 'package:terrestrial_forest_monitor/services/powersync.dart';
import 'package:terrestrial_forest_monitor/widgets/form/datagrid-from-sqlite-table.dart';
//import 'package:terrestrial_forest_monitor/widgets/form/datatable-from-sqlite-table%20copy.dart';
//import 'package:terrestrial_forest_monitor/widgets/form/ediable-datatable-from-sqlite-table.dart';

class DatabaseList extends StatefulWidget {
  const DatabaseList({super.key});

  @override
  State<DatabaseList> createState() => _DatabaseListState();
}

class _DatabaseListState extends State<DatabaseList> {
  Future<String> _getTableRowsCount(String tableName) async {
    sqlite3.ResultSet values = await db.getAll('SELECT * FROM $tableName');

    return values.length.toString();
  }

  Future<List<Widget>> _getLocalTables() async {
    List<Widget> tables = [];
    var value = await listTables();

    for (var table in value) {
      if (table['type'] != 'table' || !table['tbl_name'].startsWith('ps_data__')) {
        continue;
      }
      tables.add(
        ListTile(
          title: Text(table['tbl_name']),
          subtitle: Text(table['sql']),
          onTap: () {
            // Open Dialog
            showDialog(
              context: context,
              builder: (context) {
                return Dialog(child: DataGridFromSqlTable(tableName: table['tbl_name']));
              },
            );
          },
          trailing: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              /*IconButton(
                icon: Icon(Icons.delete),
                onPressed: () async {
                  await db.execute('DROP TABLE ${table['tbl_name']}');
                  setState(() {});
                },
              ),*/
              FutureBuilder(
                future: _getTableRowsCount(table['tbl_name']),
                builder: (context, snapshot) {
                  if (snapshot.connectionState == ConnectionState.done) {
                    return Text(snapshot.data.toString());
                  } else {
                    return SizedBox(height: 20, width: 20, child: CircularProgressIndicator());
                  }
                },
              ),
            ],
          ),
        ),
      );
    }
    return tables;
  }

  @override
  void initState() {
    super.initState();
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder(
      future: _getLocalTables(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.done) {
          if (snapshot.hasData) {
            return Column(children: snapshot.data as List<Widget>);
          } else {
            return Center(child: Text('No tables found'));
          }
        } else {
          return Center(child: SizedBox(height: 50, width: 50, child: CircularProgressIndicator()));
        }
      },
    );
  }
}
