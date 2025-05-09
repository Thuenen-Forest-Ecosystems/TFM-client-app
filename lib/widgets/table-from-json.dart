import 'package:flutter/material.dart';
import 'package:beamer/beamer.dart';
import 'package:terrestrial_forest_monitor/widgets/schema-valid_deprecated.dart';

// https://pub.dev/packages/data_table_2

class TableFromJson extends StatefulWidget {
  final List data;
  const TableFromJson({super.key, required this.data});

  @override
  State<TableFromJson> createState() => _TableFromJsonState();
}

class _TableFromJsonState extends State<TableFromJson> {
  List _data = [];

  bool _sortIdAsc = true;

  @override
  initState() {
    super.initState();
    _data = widget.data;
  }

  @override
  didUpdateWidget(TableFromJson oldWidget) {
    super.didUpdateWidget(oldWidget);
    _data = widget.data;
  }

  @override
  Widget build(BuildContext context) {
    return DataTable(
      sortColumnIndex: 0,
      sortAscending: _sortIdAsc,
      showCheckboxColumn: false,
      columns: <DataColumn>[
        DataColumn(label: Text('Valid')),
        DataColumn(
          label: Text('Traktnummer'),
          onSort:
              (columnIndex, ascending) => {
                setState(() {
                  if (_sortIdAsc) {
                    _data.sort((a, b) => a['id'].compareTo(b['id']));
                  } else {
                    _data.sort((a, b) => b['id'].compareTo(a['id']));
                  }
                  _sortIdAsc = !_sortIdAsc;
                }),
              },
        ),
        DataColumn(label: Text('Erstellt am')),
        DataColumn(label: Text('select_access_by')),
        DataColumn(label: Text('update_access_by')),
        DataColumn(label: Text('supervisor_id')),
        DataColumn(label: Text('topographic_map_number')),
        DataColumn(label: Text('state_administration')),
      ],
      rows:
          _data.map((dat) {
            return DataRow(
              onSelectChanged: (val) {
                // TODO: implement navigation
                Beamer.of(context).beamToNamed('/schema/private_ci2027_001/${dat['id']}');
                //Beamer.of(context).beamToNamed('/monitor/private_ci2027_001/${dat['id']}');
                //context.beamToNamed('/monitor/private_ci2027_001/${dat['id']}');
                //Navigator.pushNamed(context, '/monitor/private_ci2027_001/${dat['id']}', arguments: dat['id']);
              },
              cells: <DataCell>[
                DataCell(SchemaValidBtn(values: dat)),
                DataCell(Text(dat['id'].toString())),
                DataCell(Text(dat['created_at'].toString())),
                DataCell(Text(dat['select_access_by'].toString())),
                DataCell(Text(dat['update_access_by'].toString())),
                DataCell(Text(dat['supervisor_id'].toString())),
                DataCell(Text(dat['topographic_map_number'].toString())),
                DataCell(Text(dat['state_administration'].toString())),
              ],
            );
          }).toList(),
    );
  }
}
