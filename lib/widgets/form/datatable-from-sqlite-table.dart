import 'package:flutter/material.dart';
import 'package:data_table_2/data_table_2.dart';
import 'package:terrestrial_forest_monitor/services/powersync.dart';

class DatatableFromSqliteTable extends StatefulWidget {
  final String tableName;
  final bool editable;
  DatatableFromSqliteTable({super.key, required this.tableName, this.editable = false});

  @override
  State<DatatableFromSqliteTable> createState() => _DatatableFromSqliteTableState();
}

class _DatatableFromSqliteTableState extends State<DatatableFromSqliteTable> {
  ScrollController _scrollController = ScrollController();

  @override
  Widget build(BuildContext context) {
    return FutureBuilder(
        future: db.getAll('SELECT * FROM ${widget.tableName}'),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.done) {
            if (snapshot.hasData) {
              return DataTable2(
                scrollController: _scrollController,
                isHorizontalScrollBarVisible: true,
                isVerticalScrollBarVisible: true,
                minWidth: 3000,
                columns: snapshot.data![0].keys
                    .map(
                      (key) => DataColumn2(
                        //size: ColumnSize.L,
                        //fixedWidth: 200,
                        numeric: false,
                        label: Text(
                          key,
                        ),
                      ),
                    )
                    .toList(),
                rows: snapshot.data!
                    .map(
                      (row) => DataRow(
                        cells: row.values
                            .map(
                              (cell) => DataCell(
                                Text(cell.toString(), overflow: TextOverflow.ellipsis),
                              ),
                            )
                            .toList(),
                      ),
                    )
                    .toList(),
              );
            } else {
              return Center(
                child: Text('No data found'),
              );
            }
          } else {
            return Center(
              child: CircularProgressIndicator(),
            );
          }
        });
  }
}
