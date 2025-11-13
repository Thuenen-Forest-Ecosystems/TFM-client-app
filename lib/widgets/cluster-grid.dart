import 'package:flutter/material.dart';
import 'package:pluto_grid/pluto_grid.dart';

class ClusterGrid extends StatefulWidget {
  final List<Map<String, dynamic>> data;
  const ClusterGrid({super.key, required this.data});

  @override
  State<ClusterGrid> createState() => _ClusterGridState();
}

class _ClusterGridState extends State<ClusterGrid> {
  late List<PlutoColumn> columns;
  late List<PlutoRow> rows;

  @override
  void initState() {
    super.initState();
    _initializeGrid();
  }

  void _initializeGrid() {
    // Generate columns based on the keys of the first map in the data list
    columns =
        widget.data.isNotEmpty
            ? widget.data.first.keys.map((key) {
              return PlutoColumn(title: key, field: key, type: PlutoColumnType.text());
            }).toList()
            : [];

    // Generate rows based on the data list
    rows =
        widget.data.map((item) {
          return PlutoRow(
            cells: item.map((key, value) {
              return MapEntry(key, PlutoCell(value: value));
            }),
          );
        }).toList();
  }

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: double.infinity, // Ensures the grid takes up the full width
      child: PlutoGrid(
        columns: columns,
        rows: rows,
        onLoaded: (PlutoGridOnLoadedEvent event) {
          // Handle grid loaded event if needed
        },
        onChanged: (PlutoGridOnChangedEvent event) {
          // Handle cell value changes if needed
        },
      ),
    );
  }
}
