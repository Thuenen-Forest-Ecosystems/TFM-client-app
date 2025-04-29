import 'package:flutter/material.dart';
import 'package:data_table_2/data_table_2.dart';
import 'package:terrestrial_forest_monitor/components/stt-button.dart';
import 'package:terrestrial_forest_monitor/services/utils.dart';

class EditableDatatableFromSqliteTable extends StatefulWidget {
  final List<Map<dynamic, dynamic>> data;
  Map tableSettings = {};
  final Function? onUpdate;
  EditableDatatableFromSqliteTable({super.key, required this.data, Map? tableSettings, this.onUpdate}) : tableSettings = tableSettings ?? {};

  @override
  State<EditableDatatableFromSqliteTable> createState() => _EditableDatatableFromSqliteTableState();
}

class _EditableDatatableFromSqliteTableState extends State<EditableDatatableFromSqliteTable> {
  ScrollController _scrollController = ScrollController();
  int _fixedCols = 1;
  int _fixedRows = 0;
  bool _sortAscending = true;
  int? _sortColumnIndex;

  @override
  void initState() {
    // TODO: implement initState
    super.initState();
  }

  void _sort(key, columnIndex, ascending) {
    _sortAscending = !_sortAscending;
    _sortColumnIndex = columnIndex;

    widget.data.sort((a, b) {
      if (isNumeric(a[key].toString())) {
        return _sortAscending ? a[key].compareTo(b[key]) : b[key].compareTo(a[key]);
      } else {
        return _sortAscending ? a[key].toString().compareTo(b[key].toString()) : b[key].toString().compareTo(a[key].toString());
      }
    });

    setState(() {});
  }

  List<DataColumn2> _columnsHeader() {
    List<DataColumn2> columns = [];
    for (var entry in widget.data[0].entries) {
      if (widget.tableSettings[entry.key] != null && widget.tableSettings[entry.key]['visible'] == false) {
        continue;
      }
      columns.add(
        DataColumn2(
          //size: ColumnSize.L,
          //fixedWidth: 200,
          numeric: isNumeric(entry.value.toString()),
          label: Text(entry.key),
          onSort: (columnIndex, ascending) => _sort(entry.key, columnIndex, ascending),
        ),
      );
    }
    return columns;
  }

  List<DataRow2> _rowsBody() {
    List<DataRow2> rows = [];
    for (var row in widget.data) {
      List<DataCell> cells = [];
      for (var cell in row.entries) {
        if (widget.tableSettings[cell.key] != null && widget.tableSettings[cell.key]['visible'] == false) {
          continue;
        }
        if (widget.tableSettings[cell.key] != null && widget.tableSettings[cell.key]['editable'] == false) {
          cells.add(DataCell(Row(children: [Text(cell.value.toString(), overflow: TextOverflow.ellipsis)])));
          continue;
        } else {
          cells.add(
            DataCell(
              Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Expanded(
                    child: TextField(
                      decoration: InputDecoration(isDense: true, filled: true, fillColor: const Color.fromARGB(109, 116, 116, 116)),
                      controller: TextEditingController(text: cell.value == null ? '' : cell.value.toString()),
                      onChanged: (value) {
                        row[cell.key] = value;
                        if (widget.onUpdate != null) {
                          widget.onUpdate!();
                        }
                      },
                    ),
                  ),
                  IconButton(onPressed: () {}, icon: Icon(Icons.mic)),
                  SpeechToTextButton(),
                ],
              ),
            ),
          );
        }
      }
      rows.add(DataRow2(cells: cells));
    }
    return rows;
  }

  @override
  Widget build(BuildContext context) {
    return DataTable2(
      scrollController: _scrollController,
      isHorizontalScrollBarVisible: true,
      border: TableBorder.all(width: 1.0, color: Colors.grey),
      isVerticalScrollBarVisible: true,
      fixedLeftColumns: _fixedCols,
      dividerThickness: 1,
      horizontalMargin: 0,
      columnSpacing: 2,
      headingRowColor: WidgetStateProperty.resolveWith((states) => _fixedRows > 0 ? Color.fromARGB(0, 0, 0, 116) : Colors.transparent),
      fixedColumnsColor: const Color.fromARGB(109, 116, 116, 116),
      sortColumnIndex: _sortColumnIndex,
      sortAscending: _sortAscending,
      minWidth: 3000,
      columns: _columnsHeader(),
      rows: _rowsBody(),
    );
  }
}
