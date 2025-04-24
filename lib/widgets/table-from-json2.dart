import 'package:beamer/beamer.dart';
import 'package:flutter/material.dart';
// https://pub.dev/packages/data_table_2
import 'package:data_table_2/data_table_2.dart';

class TableFromJson2 extends StatefulWidget {
  final List data;
  final String parentPath;
  const TableFromJson2({super.key, required this.data, required this.parentPath});

  @override
  State<TableFromJson2> createState() => _TableFromJsonState();
}

class _TableFromJsonState extends State<TableFromJson2> {
  List _data = [];
  String _parentPath = '';
  bool _sortIdAsc = true;

  @override
  initState() {
    super.initState();
    _data = widget.data;
    _parentPath = widget.parentPath;
  }

  @override
  didUpdateWidget(TableFromJson2 oldWidget) {
    super.didUpdateWidget(oldWidget);
    _data = widget.data;
    print('didUpdateWidget');
  }

  @override
  Widget build(BuildContext context) {
    return DataTable2(
      //sortColumnIndex: 0,
      //sortAscending: _sortIdAsc,
      //showCheckboxColumn: false,
      fixedLeftColumns: 1,
      minWidth: 1000,
      fixedTopRows: 1,
      isVerticalScrollBarVisible: true,
      isHorizontalScrollBarVisible: true,
      columns: [DataColumn2(label: Text('ID'), size: ColumnSize.S), DataColumn2(label: Text('Plot-Nummer'), size: ColumnSize.S)],
      rows:
          _data.map((dat) {
            return DataRow(
              onSelectChanged: (val) {
                Beamer.of(context).beamToNamed('$_parentPath/${dat['id']}');
              },
              cells: [DataCell(Text(dat['id'].toString())), DataCell(Text(dat['plot_name'].toString()))],
            );
          }).toList(),
      /*rows: List<DataRow>.generate(
        100,
        (index) => DataRow(
          cells: [
            DataCell(Text('A' * (10 - index % 10))),
            DataCell(Text('B' * (10 - (index + 5) % 10))),
            DataCell(Text('C' * (15 - (index + 5) % 10))),
            DataCell(Text('D' * (15 - (index + 10) % 10))),
            DataCell(Text(((index + 0.1) * 25.4).toString())),
            DataCell(Text('A' * (10 - index % 10))),
            DataCell(Text('B' * (10 - (index + 5) % 10))),
            DataCell(Text('C' * (15 - (index + 5) % 10))),
            DataCell(Text('D' * (15 - (index + 10) % 10))),
            DataCell(Text(((index + 0.1) * 25.4).toString()))
          ],
        ),
      ),*/
    );
  }
}
