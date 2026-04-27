import 'package:flutter/material.dart';
import 'package:terrestrial_forest_monitor/services/powersync.dart';

class SyncedTablesScreen extends StatefulWidget {
  const SyncedTablesScreen({super.key});

  @override
  State<SyncedTablesScreen> createState() => _SyncedTablesScreenState();
}

class _SyncedTablesScreenState extends State<SyncedTablesScreen> {
  bool _isLoading = true;
  String? _error;
  List<_TableInfo> _tables = [];

  @override
  void initState() {
    super.initState();
    _loadTables();
  }

  Future<void> _loadTables() async {
    setState(() {
      _isLoading = true;
      _error = null;
    });

    try {
      final tableRows = await db.getAll(
        "SELECT name FROM sqlite_master WHERE type='table' AND name LIKE 'ps_data__%' ORDER BY name",
      );

      final tables = <_TableInfo>[];
      for (final row in tableRows) {
        final name = row['name'] as String;
        try {
          final countResult = await db.getAll('SELECT COUNT(*) as count FROM "$name"');
          final count = countResult.first['count'] as int? ?? 0;
          tables.add(_TableInfo(name: name, rowCount: count));
        } catch (_) {
          tables.add(_TableInfo(name: name, rowCount: -1));
        }
      }

      setState(() {
        _tables = tables;
        _isLoading = false;
      });
    } catch (e) {
      setState(() {
        _error = 'Fehler: $e';
        _isLoading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Synced Tables'),
        actions: [
          IconButton(icon: const Icon(Icons.refresh), tooltip: 'Neu laden', onPressed: _loadTables),
        ],
      ),
      body: _buildBody(),
    );
  }

  Widget _buildBody() {
    if (_isLoading) {
      return const Center(child: CircularProgressIndicator());
    }

    if (_error != null) {
      return Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(_error!, style: const TextStyle(color: Colors.red)),
            const SizedBox(height: 12),
            ElevatedButton(onPressed: _loadTables, child: const Text('Wiederholen')),
          ],
        ),
      );
    }

    if (_tables.isEmpty) {
      return const Center(child: Text('Keine Tabellen gefunden.'));
    }

    return ListView.separated(
      itemCount: _tables.length,
      separatorBuilder: (_, __) => const Divider(height: 1),
      itemBuilder: (context, index) {
        final table = _tables[index];
        return ListTile(
          dense: true,
          title: Text(table.name, style: const TextStyle(fontFamily: 'monospace')),
          trailing: table.rowCount < 0
              ? const Text('–', style: TextStyle(color: Colors.red))
              : Text('${table.rowCount}', style: const TextStyle(fontWeight: FontWeight.bold)),
        );
      },
    );
  }
}

class _TableInfo {
  final String name;
  final int rowCount;
  const _TableInfo({required this.name, required this.rowCount});
}
