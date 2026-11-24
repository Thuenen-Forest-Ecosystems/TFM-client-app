import 'package:flutter/material.dart';
import 'package:terrestrial_forest_monitor/l10n/app_localizations.dart';
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
        _error = e.toString();
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
    final l10n = AppLocalizations.of(context)!;

    // Define column metadata for better display
    final columnConfig = {
      'id': {'title': 'ID', 'width': 280.0, 'frozen': false},
      'cluster_name': {'title': l10n.recordsRawColCluster, 'width': 120.0, 'frozen': true},
      'plot_name': {'title': l10n.recordsRawColPlot, 'width': 100.0, 'frozen': true},
      'schema_name': {'title': 'Schema', 'width': 150.0, 'frozen': false},
      'schema_id': {'title': 'Schema ID', 'width': 280.0, 'frozen': false},
      'schema_id_validated_by': {'title': l10n.recordsRawColValidatedBy, 'width': 280.0, 'frozen': false},
      'is_valid': {'title': l10n.recordsRawColValid, 'width': 80.0, 'frozen': false},
      'plot_id': {'title': l10n.recordsRawColPlotId, 'width': 280.0, 'frozen': false},
      'cluster_id': {'title': l10n.recordsRawColClusterId, 'width': 280.0, 'frozen': false},
      'responsible_administration': {'title': l10n.recordsRawColAdministration, 'width': 200.0, 'frozen': false},
      'responsible_provider': {'title': l10n.recordsRawColProvider, 'width': 200.0, 'frozen': false},
      'responsible_state': {'title': l10n.recordsRawColState, 'width': 200.0, 'frozen': false},
      'responsible_troop': {'title': l10n.recordsRawColTroop, 'width': 200.0, 'frozen': false},
      'updated_at': {'title': l10n.recordsRawColUpdatedAt, 'width': 180.0, 'frozen': false},
      'local_updated_at': {'title': l10n.recordsRawColLocalUpdatedAt, 'width': 180.0, 'frozen': false},
      'completed_at_state': {
        'title': l10n.recordsRawColCompletedState,
        'width': 180.0,
        'frozen': false,
      },
      'completed_at_troop': {'title': l10n.recordsRawColCompletedTroop, 'width': 180.0, 'frozen': false},
      'completed_at_administration': {
        'title': l10n.recordsRawColCompletedAdministration,
        'width': 180.0,
        'frozen': false,
      },
      'is_to_be_recorded': {'title': l10n.recordsRawColToBeRecorded, 'width': 120.0, 'frozen': false},
      'note': {'title': l10n.recordsRawColNote, 'width': 300.0, 'frozen': false},
      'properties': {'title': l10n.recordsRawColProperties, 'width': 400.0, 'frozen': false},
      'previous_properties': {
        'title': l10n.recordsRawColPreviousProperties,
        'width': 400.0,
        'frozen': false,
      },
      'previous_position_data': {
        'title': l10n.recordsRawColPreviousPosition,
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
    final l10n = AppLocalizations.of(context)!;

    return Scaffold(
      appBar: AppBar(
        title: Text(l10n.recordsRawTitle),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: _loadRecords,
            tooltip: l10n.recordsRawRefresh,
          ),
        ],
      ),
      body: Column(
        children: [
          // Statistics bar
          Container(
            padding: const EdgeInsets.all(16),
            color: Theme.of(context).primaryColor.withValues(alpha: 0.1),
            child: Row(
              children: [
                Expanded(
                  child: Text(
                    l10n.recordsRawTotal(_totalRecords),
                    style: const TextStyle(fontWeight: FontWeight.bold),
                  ),
                ),
                Text(
                  l10n.recordsRawPageOf(_currentPage + 1, totalPages),
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
                        Text(l10n.recordsRawLoadError(_error!), textAlign: TextAlign.center),
                        const SizedBox(height: 16),
                        ElevatedButton(
                          onPressed: _loadRecords,
                          child: Text(l10n.recordsRawRetry),
                        ),
                      ],
                    ),
                  )
                : _records.isEmpty
                ? Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        const Icon(Icons.inbox, size: 48, color: Colors.grey),
                        const SizedBox(height: 16),
                        Text(l10n.recordsRawEmpty),
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
                  tooltip: l10n.recordsRawFirstPage,
                ),
                IconButton(
                  icon: const Icon(Icons.chevron_left),
                  onPressed: _currentPage > 0 ? _previousPage : null,
                  tooltip: l10n.recordsRawPreviousPage,
                ),
                const SizedBox(width: 16),
                Text(
                  l10n.recordsRawPageOf(_currentPage + 1, totalPages),
                  style: const TextStyle(fontWeight: FontWeight.w500),
                ),
                const SizedBox(width: 16),
                IconButton(
                  icon: const Icon(Icons.chevron_right),
                  onPressed: _currentPage < totalPages - 1 ? _nextPage : null,
                  tooltip: l10n.recordsRawNextPage,
                ),
                IconButton(
                  icon: const Icon(Icons.last_page),
                  onPressed: _currentPage < totalPages - 1 ? () => _goToPage(totalPages - 1) : null,
                  tooltip: l10n.recordsRawLastPage,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
