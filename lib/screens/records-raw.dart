import 'package:flutter/material.dart';
import 'package:trina_grid/trina_grid.dart';
import 'package:terrestrial_forest_monitor/repositories/records_repository.dart' as repo;

class RecordsRawScreen extends StatefulWidget {
  const RecordsRawScreen({super.key});

  @override
  State<RecordsRawScreen> createState() => _RecordsRawScreenState();
}

class _RecordsRawScreenState extends State<RecordsRawScreen> {
  final repo.RecordsRepository _repository = repo.RecordsRepository();
  final int _pageSize = 50;
  int _currentPage = 0;
  int _totalRecords = 0;
  bool _isLoading = true;
  String? _error;
  List<repo.Record> _records = [];

  @override
  void initState() {
    super.initState();
    _loadRecords();
  }

  Future<void> _loadRecords() async {
    setState(() {
      _isLoading = true;
      _error = null;
    });

    try {
      final offset = _currentPage * _pageSize;
      final records = await _repository.getRecords(offset: offset, limit: _pageSize);

      // Get total count (we'll fetch all and count for simplicity)
      final allRecords = await _repository.getAllRecords();

      setState(() {
        _records = records;
        _totalRecords = allRecords.length;
        _isLoading = false;
      });
    } catch (e) {
      setState(() {
        _error = 'Fehler beim Laden der Datensätze: $e';
        _isLoading = false;
      });
    }
  }

  void _nextPage() {
    final maxPage = (_totalRecords / _pageSize).ceil() - 1;
    if (_currentPage < maxPage) {
      setState(() {
        _currentPage++;
      });
      _loadRecords();
    }
  }

  void _previousPage() {
    if (_currentPage > 0) {
      setState(() {
        _currentPage--;
      });
      _loadRecords();
    }
  }

  void _goToPage(int page) {
    setState(() {
      _currentPage = page;
    });
    _loadRecords();
  }

  List<TrinaColumn> _buildColumns() {
    if (_records.isEmpty) {
      return [];
    }

    // Get the first record to determine available fields
    final sampleMap = _records.first.toMap();

    // Define column metadata for better display
    final columnConfig = {
      'id': {'title': 'ID', 'width': 280.0, 'frozen': false},
      'cluster_name': {'title': 'Trakt', 'width': 120.0, 'frozen': true},
      'plot_name': {'title': 'Ecke', 'width': 100.0, 'frozen': true},
      'schema_name': {'title': 'Schema', 'width': 150.0, 'frozen': false},
      'schema_id': {'title': 'Schema ID', 'width': 280.0, 'frozen': false},
      'schema_id_validated_by': {'title': 'Validiert mit Schema', 'width': 280.0, 'frozen': false},
      'is_valid': {'title': 'Gültig', 'width': 80.0, 'frozen': false},
      'plot_id': {'title': 'Ecke ID', 'width': 280.0, 'frozen': false},
      'cluster_id': {'title': 'Trakt ID', 'width': 280.0, 'frozen': false},
      'responsible_administration': {'title': 'Verwaltung', 'width': 200.0, 'frozen': false},
      'responsible_provider': {'title': 'Anbieter', 'width': 200.0, 'frozen': false},
      'responsible_state': {'title': 'Bundesland', 'width': 200.0, 'frozen': false},
      'responsible_troop': {'title': 'Trupp', 'width': 200.0, 'frozen': false},
      'updated_at': {'title': 'Aktualisiert', 'width': 180.0, 'frozen': false},
      'local_updated_at': {'title': 'Lokal aktualisiert', 'width': 180.0, 'frozen': false},
      'completed_at_state': {
        'title': 'Abgeschlossen (Bundesland)',
        'width': 180.0,
        'frozen': false,
      },
      'completed_at_troop': {'title': 'Abgeschlossen (Trupp)', 'width': 180.0, 'frozen': false},
      'completed_at_administration': {
        'title': 'Abgeschlossen (Verwaltung)',
        'width': 180.0,
        'frozen': false,
      },
      'is_to_be_recorded': {'title': 'Aufzuzeichnen', 'width': 120.0, 'frozen': false},
      'note': {'title': 'Notiz', 'width': 300.0, 'frozen': false},
      'properties': {'title': 'Eigenschaften (JSON)', 'width': 400.0, 'frozen': false},
      'previous_properties': {
        'title': 'Vorherige Eigenschaften (JSON)',
        'width': 400.0,
        'frozen': false,
      },
      'previous_position_data': {
        'title': 'Vorherige Position (JSON)',
        'width': 400.0,
        'frozen': false,
      },
    };

    return sampleMap.keys.map((field) {
      final config =
          columnConfig[field] ??
          {'title': field.replaceAll('_', ' ').toUpperCase(), 'width': 150.0, 'frozen': false};

      return TrinaColumn(
        field: field,
        title: config['title'] as String,
        width: config['width'] as double,
        frozen: (config['frozen'] as bool) ? TrinaColumnFrozen.start : TrinaColumnFrozen.none,
        type: TrinaColumnTypeText(),
        renderer: field == 'is_valid'
            ? (rendererContext) {
                final isValid = rendererContext.cell.value;
                return Container(
                  alignment: Alignment.center,
                  child: isValid == 1
                      ? const Icon(Icons.check_circle, color: Colors.green, size: 20)
                      : isValid == 0
                      ? const Icon(Icons.cancel, color: Colors.red, size: 20)
                      : const Icon(Icons.help_outline, color: Colors.grey, size: 20),
                );
              }
            : null,
      );
    }).toList();
  }

  List<TrinaRow> _buildRows() {
    return _records.map((record) {
      final recordMap = record.toMap();

      return TrinaRow(
        cells: Map.fromEntries(
          recordMap.entries.map((entry) {
            final value = entry.value ?? '—';
            return MapEntry(
              entry.key,
              TrinaCell(value: value is String ? value : value.toString()),
            );
          }),
        ),
      );
    }).toList();
  }

  @override
  Widget build(BuildContext context) {
    final totalPages = (_totalRecords / _pageSize).ceil();

    return Scaffold(
      appBar: AppBar(
        title: const Text('Rohdaten - Datensätze'),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: _loadRecords,
            tooltip: 'Aktualisieren',
          ),
        ],
      ),
      body: Column(
        children: [
          // Statistics bar
          Container(
            padding: const EdgeInsets.all(16),
            color: Theme.of(context).primaryColor.withOpacity(0.1),
            child: Row(
              children: [
                Expanded(
                  child: Text(
                    'Gesamt: $_totalRecords Datensätze',
                    style: const TextStyle(fontWeight: FontWeight.bold),
                  ),
                ),
                Text(
                  'Seite ${_currentPage + 1} von $totalPages',
                  style: const TextStyle(fontWeight: FontWeight.w500),
                ),
              ],
            ),
          ),

          // Grid
          Expanded(
            child: _isLoading
                ? const Center(child: CircularProgressIndicator())
                : _error != null
                ? Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        const Icon(Icons.error_outline, size: 48, color: Colors.red),
                        const SizedBox(height: 16),
                        Text(_error!, textAlign: TextAlign.center),
                        const SizedBox(height: 16),
                        ElevatedButton(
                          onPressed: _loadRecords,
                          child: const Text('Erneut versuchen'),
                        ),
                      ],
                    ),
                  )
                : _records.isEmpty
                ? const Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(Icons.inbox, size: 48, color: Colors.grey),
                        SizedBox(height: 16),
                        Text('Keine Datensätze gefunden'),
                      ],
                    ),
                  )
                : TrinaGrid(
                    columns: _buildColumns(),
                    rows: _buildRows(),
                    configuration: TrinaGridConfiguration(
                      style: TrinaGridStyleConfig(
                        rowHeight: 35,
                        columnHeight: 40,
                        enableRowColorAnimation: false,
                      ),
                    ),
                    mode: TrinaGridMode.readOnly,
                  ),
          ),

          // Pagination controls
          Container(
            padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 16),
            decoration: BoxDecoration(
              color: Theme.of(context).cardColor,
              border: Border(top: BorderSide(color: Theme.of(context).dividerColor)),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                IconButton(
                  icon: const Icon(Icons.first_page),
                  onPressed: _currentPage > 0 ? () => _goToPage(0) : null,
                  tooltip: 'Erste Seite',
                ),
                IconButton(
                  icon: const Icon(Icons.chevron_left),
                  onPressed: _currentPage > 0 ? _previousPage : null,
                  tooltip: 'Vorherige Seite',
                ),
                const SizedBox(width: 16),
                Text(
                  'Seite ${_currentPage + 1} von $totalPages',
                  style: const TextStyle(fontWeight: FontWeight.w500),
                ),
                const SizedBox(width: 16),
                IconButton(
                  icon: const Icon(Icons.chevron_right),
                  onPressed: _currentPage < totalPages - 1 ? _nextPage : null,
                  tooltip: 'Nächste Seite',
                ),
                IconButton(
                  icon: const Icon(Icons.last_page),
                  onPressed: _currentPage < totalPages - 1 ? () => _goToPage(totalPages - 1) : null,
                  tooltip: 'Letzte Seite',
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
