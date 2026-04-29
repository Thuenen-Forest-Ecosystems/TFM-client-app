import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:terrestrial_forest_monitor/services/powersync.dart';
import 'package:terrestrial_forest_monitor/widgets/auth/if-database-admin.dart';

class DiagnosticButton extends StatefulWidget {
  const DiagnosticButton({super.key});

  @override
  State<DiagnosticButton> createState() => _DiagnosticButtonState();
}

class _DiagnosticButtonState extends State<DiagnosticButton> {
  StreamSubscription<dynamic>? _sub;
  int _unsyncedCount = 0;

  static const _sql = '''
    SELECT COUNT(*) AS n FROM records
    WHERE local_updated_at IS NOT NULL
      AND (
        updated_at IS NULL
        OR local_updated_at > datetime(updated_at, \'+60 seconds\')
      )
  ''';

  @override
  void initState() {
    super.initState();
    _sub = db.watch(_sql).listen((rows) {
      if (mounted) {
        setState(() {
          _unsyncedCount = rows.isNotEmpty ? (rows.first['n'] as int? ?? 0) : 0;
        });
      }
    });
  }

  @override
  void dispose() {
    _sub?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Badge(
      //isLabelVisible: _unsyncedCount > 0,
      backgroundColor: Colors.orange,
      label: Text('$_unsyncedCount'),
      child: Ink(
        width: 32,
        height: 32,
        decoration: ShapeDecoration(
          color: _unsyncedCount > 0 ? Colors.orange : Colors.green,
          shape: const CircleBorder(),
        ),
        child: IconButton(
          icon: const Icon(Icons.warning_amber_rounded),
          padding: EdgeInsets.zero,
          constraints: const BoxConstraints.tightFor(width: 32, height: 32),
          tooltip: 'Übertragungsdiagnose',
          onPressed: () => _DiagnosticDialog.show(context),
        ),
      ),
    );
  }
}

class _DiagnosticDialog extends StatefulWidget {
  const _DiagnosticDialog();

  static Future<void> show(BuildContext context) {
    return showDialog(context: context, builder: (_) => const _DiagnosticDialog());
  }

  @override
  State<_DiagnosticDialog> createState() => _DiagnosticDialogState();
}

class _DiagnosticDialogState extends State<_DiagnosticDialog> {
  bool _loading = true;
  String? _error;

  int _pendingCrudCount = 0;
  List<Map<String, dynamic>> _crudBreakdown = [];
  List<Map<String, dynamic>> _unsyncedRecords = [];

  static const String _serverQuery =
      '''-- Run on Supabase to find records not uploaded from devices:
SELECT id, cluster_name, plot_name,
       local_updated_at, updated_at,
       (local_updated_at::timestamptz - updated_at::timestamptz) AS lag
FROM public.records
WHERE local_updated_at IS NOT NULL
  AND updated_at IS NOT NULL
  AND local_updated_at > updated_at + interval \'10 minutes\'
ORDER BY lag DESC;

-- Records that were never uploaded (no server timestamp):
SELECT id, cluster_name, plot_name, local_updated_at
FROM public.records
WHERE local_updated_at IS NOT NULL
  AND updated_at IS NULL
ORDER BY local_updated_at DESC;''';

  @override
  void initState() {
    super.initState();
    _runDiagnostics();
  }

  Future<void> _runDiagnostics() async {
    setState(() {
      _loading = true;
      _error = null;
    });

    try {
      // 1. Count pending PowerSync CRUD operations
      final crudCountResult = await db.execute('SELECT COUNT(*) as n FROM ps_crud');
      final pending = crudCountResult.isNotEmpty ? (crudCountResult.first['n'] as int? ?? 0) : 0;

      // 2. Breakdown by table + operation
      final breakdownResult = await db.execute('''
        SELECT
          json_extract(data, '\$.type') AS table_name,
          json_extract(data, '\$.op')   AS operation,
          COUNT(*)                       AS cnt
        FROM ps_crud
        GROUP BY table_name, operation
        ORDER BY cnt DESC
      ''');
      final breakdown = breakdownResult
          .map(
            (r) => {
              'table': r['table_name']?.toString() ?? '?',
              'op': r['operation']?.toString() ?? '?',
              'cnt': r['cnt'],
            },
          )
          .toList();

      // 3. Records with local changes not yet reflected on the server.
      //    local_updated_at > updated_at + 60 s  OR  updated_at IS NULL
      final unsyncedResult = await db.execute('''
        SELECT id, cluster_name, plot_name, local_updated_at, updated_at
        FROM records
        WHERE local_updated_at IS NOT NULL
          AND (
            updated_at IS NULL
            OR local_updated_at > datetime(updated_at, \'+60 seconds\')
          )
        ORDER BY local_updated_at DESC
        LIMIT 50
      ''');
      final unsynced = unsyncedResult
          .map(
            (r) => {
              'id': r['id']?.toString(),
              'cluster_name': r['cluster_name']?.toString(),
              'plot_name': r['plot_name']?.toString(),
              'local_updated_at': r['local_updated_at']?.toString(),
              'updated_at': r['updated_at']?.toString(),
            },
          )
          .toList();

      if (mounted) {
        setState(() {
          _pendingCrudCount = pending;
          _crudBreakdown = breakdown;
          _unsyncedRecords = unsynced;
          _loading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _error = e.toString();
          _loading = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Row(children: [Text('Übertragungsdiagnose')]),
      content: SizedBox(
        width: double.maxFinite,
        child: _loading
            ? const SizedBox(height: 80, child: Center(child: CircularProgressIndicator()))
            : _error != null
            ? Text('Fehler: $_error', style: TextStyle(color: Theme.of(context).colorScheme.error))
            : _buildContent(context),
      ),
      actions: [
        // TextButton(onPressed: _runDiagnostics, child: const Text('Aktualisieren')),
        TextButton(onPressed: () => Navigator.of(context).pop(), child: const Text('Schließen')),
      ],
    );
  }

  Widget _buildContent(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return SingleChildScrollView(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          // ── Summary card ──────────────────────────────────────────
          Container(
            padding: const EdgeInsets.all(12),
            child: Column(
              children: [
                _buildSummaryRow(
                  Icons.upload_outlined,
                  'Warteschlange',
                  '$_pendingCrudCount ausstehend',
                ),
                if (_crudBreakdown.isNotEmpty) ...[
                  const SizedBox(height: 4),
                  ..._crudBreakdown.map(
                    (b) => Padding(
                      padding: const EdgeInsets.only(left: 26, top: 2),
                      child: Row(
                        children: [
                          Expanded(
                            child: Text(
                              '${b['table']} · ${b['op']}',
                              style: const TextStyle(fontSize: 12),
                            ),
                          ),
                          Text('${b['cnt']}×', style: const TextStyle(fontSize: 12)),
                        ],
                      ),
                    ),
                  ),
                ],
                const SizedBox(height: 8),
                _buildSummaryRow(
                  Icons.sync_problem_outlined,
                  'Nicht synchronisiert',
                  '${_unsyncedRecords.length} Datensatz/Datensätze',
                ),
              ],
            ),
          ),

          // ── Unsynced record list ───────────────────────────────────
          if (_unsyncedRecords.isNotEmpty) ...[
            const SizedBox(height: 14),
            Text(
              'Betroffene Datensätze (max. 50):',
              style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
            ),
            const SizedBox(height: 6),
            ..._unsyncedRecords.map(_buildRecordRow),
          ],

          // ── Server-side SQL ────────────────────────────────────────
          IfDatabaseAdmin(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                const SizedBox(height: 14),
                Row(
                  children: [
                    const Expanded(
                      child: Text(
                        'Server-Diagnose SQL:',
                        style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12),
                      ),
                    ),
                    IconButton(
                      icon: const Icon(Icons.copy, size: 16),
                      tooltip: 'SQL kopieren',
                      onPressed: () {
                        Clipboard.setData(const ClipboardData(text: _serverQuery));
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(
                            content: Text('SQL in die Zwischenablage kopiert'),
                            behavior: SnackBarBehavior.floating,
                          ),
                        );
                      },
                    ),
                  ],
                ),
                Builder(
                  builder: (context) {
                    final scheme = Theme.of(context).colorScheme;
                    return Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: scheme.surfaceContainerHighest,
                        borderRadius: BorderRadius.circular(4),
                        border: Border.all(color: scheme.outlineVariant),
                      ),
                      child: SelectableText(
                        _serverQuery,
                        style: const TextStyle(fontSize: 11, fontFamily: 'monospace'),
                      ),
                    );
                  },
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSummaryRow(IconData icon, String label, String value) {
    return Row(
      children: [
        Expanded(child: Text(label, style: const TextStyle(fontSize: 13))),
        Text(value, style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w500)),
      ],
    );
  }

  Widget _buildRecordRow(Map<String, dynamic> row) {
    final cluster = row['cluster_name'] ?? '?';
    final plot = row['plot_name'] ?? '?';
    final localTs = _formatTs(row['local_updated_at']);
    final serverTs = _formatTs(row['updated_at']);
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 3),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Padding(padding: EdgeInsets.only(top: 5), child: Icon(Icons.circle, size: 6)),
          const SizedBox(width: 6),
          Expanded(
            child: Text(
              '$cluster / $plot\nLokal: $localTs  •  Server: ${serverTs ?? '–'}',
              style: const TextStyle(fontSize: 12),
            ),
          ),
        ],
      ),
    );
  }

  String? _formatTs(String? ts) {
    if (ts == null) return null;
    try {
      final dt = DateTime.parse(ts).toLocal();
      return '${dt.day.toString().padLeft(2, '0')}.${dt.month.toString().padLeft(2, '0')}.${dt.year} '
          '${dt.hour.toString().padLeft(2, '0')}:${dt.minute.toString().padLeft(2, '0')}';
    } catch (_) {
      return ts;
    }
  }
}
