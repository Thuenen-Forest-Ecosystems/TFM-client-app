
import 'package:flutter/material.dart';
import 'package:pluto_grid/pluto_grid.dart';
import 'package:powersync/sqlite3_common.dart' show ResultSet;
import 'package:terrestrial_forest_monitor/services/powersync.dart';

class DataGridFormInventory extends StatefulWidget {
  final List<Map<String, dynamic>> rows;
  final Map<String, dynamic> columns;
  final Function(List<Map<String, dynamic>>) onChanged; // Add this line
  DataGridFormInventory({super.key, required this.rows, required this.columns, required this.onChanged});

  @override
  State<DataGridFormInventory> createState() => _DataGridFormInventoryState();
}

class _DataGridFormInventoryState extends State<DataGridFormInventory> {
  late final PlutoGridStateManager stateManager;

  final int rowsPerPage = 50;

  List<Map<String, dynamic>> rows = [];
  Map<String, dynamic> columns = {};
  List<PlutoColumn> _plutoColumns = [];
  List hideColumns = ['intkey'];
  List frozenColumns = ['cluster_name'];

  @override
  void initState() {
    // TODO: implement initState
    super.initState();
    rows = List<Map<String, dynamic>>.from(widget.rows); // Create a copy
    columns = Map<String, dynamic>.from(widget.columns); // Create a copy
    //_getColumns(columns);
  }

  bool _ishidden(key) {
    return hideColumns.contains(key);
  }

  void _notifyChanges() {
    widget.onChanged(rows); // Notify the parent widget
  }

  PlutoColumnFrozen _isFrozen(key) {
    return frozenColumns.contains(key) ? PlutoColumnFrozen.start : PlutoColumnFrozen.none;
  }

  Future<List<PlutoColumn>> _getColumns(Map<String, dynamic> values) async {
    List<PlutoColumn> columns = [];

    for (var entry in values.entries) {
      var key = entry.key;
      var value = entry.value;

      List<String> lookupNames = [];
      // Map to store name_de -> code mapping
      Map<String, dynamic> nameToCodeMap = {};

      PlutoColumn plutoColumn = PlutoColumn(
        title: values[key]['title'] ?? key,
        field: key,
        type: PlutoColumnType.text(),
        enableEditingMode: true,
        hide: _ishidden(key),
        frozen: _isFrozen(key),
        enableContextMenu: false,
        //type: PlutoColumnType.select(lookupName, enableColumnFilter: true),
      );

      if (value['\$migration']['nfi2022']['lookup'] != null) {
        String table = value['\$migration']['nfi2022']['lookup']; // lookup.lookup_vogel_schutzgebiet.code
        String tableName = table.split('.')[1];
        try {
          ResultSet lookupResult = await db.getAll('SELECT code, name_de FROM $tableName');

          // Erstelle eine Map von code -> name_de für das Rendering
          Map<String, String> codeToNameMap = {};
          // Erstelle eine List von Strings im Format "code|name_de" für das Dropdown
          List<String> codeNamePairs = [];

          for (var row in lookupResult) {
            String code = row['code'].toString();
            String name = row['name_de'].toString();
            codeToNameMap[code] = name;
            codeNamePairs.add("$code | $name"); // Format: "code|name_de"
          }

          plutoColumn.type = PlutoColumnType.select(codeNamePairs, enableColumnFilter: true);

          // Custom renderer to show only the name part
          plutoColumn.renderer = (rendererContext) {
            // If cell is in editing state, return custom editing widget

            // Otherwise show display view
            String value = rendererContext.cell.value?.toString() ?? '';
            // Wenn der Wert nur der Code ist (gespeicherter Wert)
            if (codeToNameMap.containsKey(value)) {
              return Text(codeToNameMap[value]!);
            }
            // Wenn der Wert im Format "code|name_de" ist (während der Auswahl)
            /*if (value.contains('|')) {
              String code = value.split('|')[0];
              rows[rendererContext.rowIdx][rendererContext.column.field] = code; // Speichere nur den Code
              return Text(value.split('|')[1]); // Zeige nur den Namen an
            }*/
            return Text(value);
          };
        } catch (e) {
          print(e);
          print(tableName);
        }
      } else {
        if (value['type'] == 'integer') {
          plutoColumn.type = PlutoColumnType.number();
        } else if (value['type'] == 'number') {
          plutoColumn.type = PlutoColumnType.number();
        } else {
          plutoColumn.type = PlutoColumnType.text();
        }
      }

      columns.add(plutoColumn);
    }

    return columns;
  }

  Future<List<PlutoRow>> _getRows(List<Map<String, dynamic>> values) async {
    List<PlutoRow> rows = [];

    for (var value in values) {
      rows.add(PlutoRow(cells: value.map((key, value) => MapEntry(key, PlutoCell(value: value)))));
    }
    print(values);
    return rows;
  }

  Map<String, dynamic> _getEmptyRow() {
    Map<String, dynamic> emptyRow = {};
    for (var key in columns.keys) {
      emptyRow[key] = '';
    }
    return emptyRow;
  }

  void _addRow() {
    setState(() {
      // add row top
      rows.insert(0, _getEmptyRow());
      stateManager.insertRows(0, [PlutoRow(cells: _getEmptyRow().map((key, value) => MapEntry(key, PlutoCell(value: value))))]);
      _notifyChanges();
    });
  }

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Expanded(
          child: FutureBuilder(
            future: _getColumns(columns),
            builder: (context, snapshot) {
              if (snapshot.hasData) {
                return PlutoGrid(
                  // Dark theme
                  onLoaded: (PlutoGridOnLoadedEvent event) async {
                    stateManager = event.stateManager;
                    // Enable filtering functionality
                    stateManager.setShowColumnFilter(false);
                    stateManager.setSelectingMode(PlutoGridSelectingMode.row);
                    stateManager.insertRows(0, await _getRows(rows));
                    //stateManager.setPageSize(rowsPerPage);
                  },
                  onChanged: (event) {
                    // change the row data
                    final row = event.rowIdx;
                    final column = event.column;
                    final value = event.value;
                    // VALIDATE
                    // Update the row data
                    setState(() {
                      rows[row][column.field] = value;
                      _notifyChanges();
                    });
                  },
                  configuration: PlutoGridConfiguration(
                    style: PlutoGridStyleConfig.dark(
                      gridBorderColor: Colors.grey[800]!,
                      rowHeight: 45,
                      columnHeight: 45,
                      gridBackgroundColor: Color.fromARGB(0, 0, 0, 0),
                      cellColorInEditState: Colors.transparent,
                      cellColorInReadOnlyState: Colors.transparent,
                      //rowColor: Color.fromARGB(0, 231, 145, 15),
                    ),
                  ),
                  /*createFooter: (stateManager) {
              stateManager.setPageSize(100, notify: false); // default 40
              return PlutoPagination(stateManager);
            },*/
                  columns: snapshot.data as List<PlutoColumn>,
                  rows: [],
                );
              } else {
                return CircularProgressIndicator();
              }
            },
          ),
        ),
        IconButton(onPressed: _addRow, icon: Icon(Icons.add)),
      ],
    );
  }
}

class CustomSelectCell extends StatelessWidget {
  final PlutoGridStateManager stateManager;
  final int rowIdx;
  final PlutoColumn column;
  final dynamic value;
  final List<String> items;
  final Map<String, String> codeToNameMap;

  const CustomSelectCell({super.key, required this.stateManager, required this.rowIdx, required this.column, required this.value, required this.items, required this.codeToNameMap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: () {
        showDialog(
          context: context,
          builder: (context) {
            return AlertDialog(
              title: Text('Wählen Sie einen Wert'),
              content: SizedBox(
                width: MediaQuery.of(context).size.width * 0.8, // 80% der Bildschirmbreite
                height: MediaQuery.of(context).size.height * 0.6, // 60% der Bildschirmhöhe
                child: ListView.builder(
                  itemCount: items.length,
                  itemBuilder: (context, index) {
                    String item = items[index];
                    String displayName = item.contains('|') ? item.split('|')[1].trim() : item;
                    String code = item.contains('|') ? item.split('|')[0].trim() : item;

                    return ListTile(
                      title: Text(displayName),
                      onTap: () {
                        // Setze den Code-Wert in der Zelle
                        stateManager.changeCellValue(stateManager.rows[rowIdx].cells[column.field]!, code);
                        Navigator.pop(context);
                      },
                    );
                  },
                ),
              ),
              actions: [TextButton(onPressed: () => Navigator.pop(context), child: Text('Abbrechen'))],
            );
          },
        );
      },
      child: Container(
        padding: EdgeInsets.all(8.0),
        alignment: Alignment.centerLeft,
        child: Row(children: [Expanded(child: Text(value != null && value.toString().isNotEmpty ? codeToNameMap[value.toString()] ?? value.toString() : 'Auswählen...', maxLines: 1, overflow: TextOverflow.ellipsis)), Icon(Icons.arrow_drop_down)]),
      ),
    );
  }
}
