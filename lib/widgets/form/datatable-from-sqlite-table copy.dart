import 'package:flutter/material.dart';
import 'package:data_table_2/data_table_2.dart';
import 'package:terrestrial_forest_monitor/services/powersync.dart';

class DatatableFromSqliteTable extends StatefulWidget {
  final String tableName;
  final bool editable;
  final String where;
  final List<String?> queryParameters;
  DatatableFromSqliteTable({super.key, required this.tableName, this.editable = false, this.where = '', this.queryParameters = const []});

  @override
  State<DatatableFromSqliteTable> createState() => _DatatableFromSqliteTableState();
}

class _DatatableFromSqliteTableState extends State<DatatableFromSqliteTable> {
  ScrollController _scrollController = ScrollController();

  @override
  Widget build(BuildContext context) {
    return FutureBuilder(
      future: db.getAll('SELECT * FROM ${widget.tableName} ${widget.where}', widget.queryParameters),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.done) {
          if (snapshot.hasData && snapshot.data!.isNotEmpty) {
            return DataTable2(
              scrollController: _scrollController,
              isHorizontalScrollBarVisible: true,
              isVerticalScrollBarVisible: true,
              minWidth: 3000,
              columns:
                  snapshot.data![0].keys
                      .map(
                        (key) => DataColumn2(
                          //size: ColumnSize.L,
                          //fixedWidth: 200,
                          numeric: false,
                          label: Text(key),
                        ),
                      )
                      .toList(),
              rows:
                  snapshot.data!
                      .map(
                        (row) => DataRow(
                          cells:
                              row.values
                                  .map(
                                    (cell) => DataCell(
                                      TextField(decoration: InputDecoration(border: InputBorder.none), controller: TextEditingController(text: cell.toString())),
                                      //Text(cell.toString(), overflow: TextOverflow.ellipsis),
                                    ),
                                  )
                                  .toList(),
                        ),
                      )
                      .toList(),
            );
          } else {
            return Center(child: Text('No data found'));
          }
        } else {
          return Center(child: CircularProgressIndicator());
        }
      },
    );
  }
}
