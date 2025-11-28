import 'package:flutter/material.dart';
import 'package:trina_grid/trina_grid.dart';

/// Simple test widget to debug TrinaGrid row adding behavior
class TestTrinaGrid extends StatefulWidget {
  const TestTrinaGrid({super.key});

  @override
  State<TestTrinaGrid> createState() => _TestTrinaGridState();
}

class _TestTrinaGridState extends State<TestTrinaGrid> {
  List<Map<String, dynamic>> _data = [];
  int _nextId = 1;

  List<TrinaColumn> _buildColumns() {
    return [
      TrinaColumn(
        title: 'ID',
        field: 'id',
        type: TrinaColumnTypeNumber(
          negative: false,
          format: '#',
          applyFormatOnInit: true,
          allowFirstDot: false,
          locale: 'de_DE',
        ),
        width: 100,
      ),
      TrinaColumn(title: 'Name', field: 'name', type: TrinaColumnTypeText(), width: 200),
      TrinaColumn(
        title: 'Value',
        field: 'value',
        type: TrinaColumnTypeNumber(
          negative: false,
          format: '#,###',
          applyFormatOnInit: true,
          allowFirstDot: false,
          locale: 'de_DE',
        ),
        width: 150,
      ),
    ];
  }

  List<TrinaRow> _buildRows() {
    return _data.map((item) {
      return TrinaRow(
        cells: {
          'id': TrinaCell(value: item['id']),
          'name': TrinaCell(value: item['name']),
          'value': TrinaCell(value: item['value']),
        },
      );
    }).toList();
  }

  void _addRow() {
    setState(() {
      _data.add({'id': _nextId, 'name': 'Item $_nextId', 'value': _nextId * 10});
      _nextId++;
    });
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      body: MediaQuery.removePadding(
        context: context,
        removeTop: true,
        child: _data.isEmpty
            ? Center(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const Text('No data'),
                    const SizedBox(height: 16),
                    ElevatedButton(onPressed: _addRow, child: const Text('Add First Row')),
                  ],
                ),
              )
            : TrinaGrid(
                key: ValueKey('test_grid_${_data.length}'),
                columns: _buildColumns(),
                rows: _buildRows(),
                configuration: TrinaGridConfiguration(
                  style: TrinaGridStyleConfig(
                    gridBackgroundColor: isDark ? const Color(0xFF1E1E1E) : Colors.white,
                    rowColor: isDark ? const Color(0xFF252526) : Colors.white,
                    cellTextStyle: TextStyle(
                      color: isDark ? Colors.white : Colors.black87,
                      fontSize: 14,
                    ),
                    columnTextStyle: TextStyle(
                      color: isDark ? Colors.white : Colors.black87,
                      fontSize: 14,
                      fontWeight: FontWeight.bold,
                    ),
                    gridBorderColor: isDark ? const Color(0xFF3E3E42) : Colors.grey.shade300,
                    borderColor: isDark ? const Color(0xFF3E3E42) : Colors.grey.shade300,
                  ),
                ),
              ),
      ),
      floatingActionButton: FloatingActionButton(onPressed: _addRow, child: const Icon(Icons.add)),
    );
  }
}
