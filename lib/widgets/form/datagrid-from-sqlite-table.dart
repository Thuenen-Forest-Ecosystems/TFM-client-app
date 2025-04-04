import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:pluto_grid/pluto_grid.dart';
import 'package:terrestrial_forest_monitor/services/powersync.dart';

class DataGridFromSqlTable extends StatefulWidget {
  final String tableName;
  final bool editable;
  final String where;
  final List<String?> queryParameters;
  const DataGridFromSqlTable({super.key, required this.tableName, this.editable = false, this.where = '', this.queryParameters = const []});

  @override
  State<DataGridFromSqlTable> createState() => _DataGridFromSqlTableState();
}

class _DataGridFromSqlTableState extends State<DataGridFromSqlTable> {
  late final PlutoGridStateManager stateManager;
  final int rowsPerPage = 50;

  List hideColumns = [
    'intkey',
  ];
  List frozenColumns = [
    'cluster_name',
  ];

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

      rows.add(
        PlutoRow(
          cells: data.map(
            (key, value) => MapEntry(
              key,
              PlutoCell(value: value),
            ),
          ),
        ),
      );
    }
    return rows;
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder(
      future: db.getAll('SELECT * FROM ${widget.tableName} ${widget.where}', widget.queryParameters),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.done) {
          return PlutoGrid(
              // Dark theme

              onLoaded: (PlutoGridOnLoadedEvent event) {
                final stateManager = event.stateManager;
                // Enable filtering functionality
                stateManager.setShowColumnFilter(true);
                stateManager.setSelectingMode(PlutoGridSelectingMode.row);
                stateManager.setPageSize(rowsPerPage);
              },
              configuration: PlutoGridConfiguration(
                style: PlutoGridStyleConfig(
                  gridBorderColor: Colors.grey[800]!,
                  rowHeight: 45,
                  columnHeight: 45,
                ),
              ),
              createFooter: (stateManager) {
                stateManager.setPageSize(100, notify: false); // default 40
                return PlutoPagination(stateManager);
              },
              columns: _getColumns(snapshot.data!),
              rows: _getRows(snapshot.data!));
        }
        return CircularProgressIndicator();
      },
    );
  }
  /* return PlutoGrid(
      columns: columnsProviders,
      rows: rowsProviders,
      onLoaded: (PlutoGridOnLoadedEvent event) {
        stateManagerProviders = event.stateManager;
        stateManagerSummary.setSelectingMode(PlutoGridSelectingMode.row);
      },
    );
  }*/
}
