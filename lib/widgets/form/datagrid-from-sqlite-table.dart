import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:pluto_grid/pluto_grid.dart';
import 'package:terrestrial_forest_monitor/services/powersync.dart';

class DataGridFromSqlTable extends StatefulWidget {
  final String tableName;
  final bool editable;
  final String where;
  final List<String?> queryParameters;
  final bool multiSelect;
  final Function(List<PlutoRow>?)? onRowsSelected;
  const DataGridFromSqlTable({super.key, required this.tableName, this.editable = false, this.where = '', this.queryParameters = const [], this.multiSelect = false, this.onRowsSelected});

  @override
  State<DataGridFromSqlTable> createState() => DataGridFromSqlTableState();
}

class DataGridFromSqlTableState extends State<DataGridFromSqlTable> {
  final PlutoGridConfiguration configurationLight = PlutoGridConfiguration();
  final PlutoGridConfiguration configurationDark = PlutoGridConfiguration.dark();

  List<PlutoRow>? selectedRows;
  List<PlutoRow> filteredRows = [];

  late final PlutoGridStateManager stateManager;
  final int rowsPerPage = 50;

  List hideColumns = ['intkey'];
  List frozenColumns = ['cluster_name'];

  void selectAll() {
    stateManager.setAllCurrentSelecting(); // Select all rows
  }

  bool _ishidden(key) {
    return hideColumns.contains(key);
  }

  PlutoColumnFrozen _isFrozen(key) {
    return frozenColumns.contains(key) ? PlutoColumnFrozen.start : PlutoColumnFrozen.none;
  }

  List<PlutoColumn> _getColumns(List<Map<String, dynamic>> values) {
    List<PlutoColumn> columns = [];

    if (values.isNotEmpty) {
      Map<String, dynamic> firstValue = jsonDecode(values[0]['data']);

      for (var key in firstValue.keys) {
        columns.add(
          PlutoColumn(
            title: key,
            field: key,
            type: PlutoColumnType.text(),
            //width: 200,
            enableEditingMode: false,
            hide: _ishidden(key),
            frozen: _isFrozen(key),
            enableContextMenu: false,
          ),
        );
      }
    }
    return columns;
  }

  List<PlutoRow> _getRows(List<Map<String, dynamic>> values) {
    List<PlutoRow> rows = [];

    for (var value in values) {
      Map<String, dynamic> data = jsonDecode(value['data']);

      rows.add(PlutoRow(cells: data.map((key, value) => MapEntry(key, PlutoCell(value: value)))));
    }
    return rows;
  }

  List<PlutoRow> getFilteredRows() {
    // Return the current filtered rows from the state manager
    return stateManager.refRows.filteredList;
  }

  @override
  Widget build(BuildContext context) {
    final brightness = PlatformDispatcher.instance.platformBrightness;
    bool isDarkMode = brightness == Brightness.dark;

    return FutureBuilder(
      future: db.getAll('SELECT * FROM ${widget.tableName} ${widget.where}', widget.queryParameters),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.done) {
          return PlutoGrid(
            mode: PlutoGridMode.multiSelect,
            onChanged: (event) => print(event),
            onSorted: (event) => print(event),
            onRowChecked: (event) => {print('Row checked: ${event.row}')},
            onSelected: (event) {
              selectedRows = event.selectedRows;
              /*if (widget.onRowsSelected != null) {
                widget.onRowsSelected!(selectedRows);
              }*/
            },

            onLoaded: (PlutoGridOnLoadedEvent event) {
              stateManager = event.stateManager;
              // Enable filtering functionality
              stateManager.setShowColumnFilter(true);
              stateManager.setSelectingMode(PlutoGridSelectingMode.row);
              stateManager.setPageSize(rowsPerPage);
              stateManager.eventManager!.listener((event) {
                if (event is PlutoGridChangeColumnFilterEvent) {
                  widget.onRowsSelected!(stateManager.refRows.filteredList);
                }
              });
            },
            configuration: isDarkMode ? configurationDark : configurationLight,
            createFooter: (stateManager) {
              //stateManager.setPageSize(rowsPerPage, notify: false);
              return PlutoPagination(stateManager);
            },
            columns: _getColumns(snapshot.data!),
            rows: _getRows(snapshot.data!),
          );
        }
        return CircularProgressIndicator();
      },
    );
  }
}
