import 'dart:async';

import 'package:flutter/material.dart';
import 'package:powersync/powersync.dart' hide Column;
import 'package:provider/provider.dart';
import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:terrestrial_forest_monitor/providers/auth.dart';
import 'package:terrestrial_forest_monitor/services/powersync.dart';
import 'package:terrestrial_forest_monitor/services/log_service.dart';
import 'package:flutter/services.dart';
import 'package:terrestrial_forest_monitor/widgets/auth/if-database-admin.dart';
import 'package:terrestrial_forest_monitor/widgets/diagnostic-export-button.dart';
import 'package:terrestrial_forest_monitor/widgets/records-export-button.dart';

class SyncStatusButton extends StatefulWidget {
  const SyncStatusButton({super.key});

  @override
  State<SyncStatusButton> createState() => _SyncStatusButtonState();
}

class _SyncStatusButtonState extends State<SyncStatusButton> {
  // https://docs.powersync.com/client-sdk-references/flutter/usage-examples

  late SyncStatus _connectionState;
  StreamSubscription<SyncStatus>? _syncStatusSubscription;
  StreamSubscription<List<ConnectivityResult>>? _connectivitySubscription;
  bool _isNetworkAvailable = true;
  int _unsyncedCount = 0;
  StreamSubscription<dynamic>? _unsyncedSub;
  StreamSubscription<void>? _dbSwitchSub;

  static const _unsyncedSql = '''
    SELECT COUNT(*) AS n FROM records
    WHERE local_updated_at IS NOT NULL
      AND (
        updated_at IS NULL
        OR local_updated_at > datetime(updated_at, \'+10 minutes\')
      )
  ''';

  @override
  void initState() {
    super.initState();
    _subscribeToDb();

    // Listen to network connectivity changes
    _connectivitySubscription = Connectivity().onConnectivityChanged.listen((results) {
      if (mounted) {
        setState(() {
          _isNetworkAvailable = results.any((result) => result != ConnectivityResult.none);
        });
      }
    });

    // Check initial connectivity
    _checkInitialConnectivity();

    // Re-subscribe whenever switchUserDatabase swaps the global db.
    _dbSwitchSub = dbSwitchEvents.listen((_) => _resubscribeDb());
  }

  /// Subscribe to the current [db] instance's streams.
  void _subscribeToDb() {
    _connectionState = db.currentStatus;
    _syncStatusSubscription = db.statusStream.listen((event) {
      if (mounted) {
        setState(() {
          _connectionState = db.currentStatus;
        });

        // Log any sync errors
        if (event.anyError != null) {
          final logger = LogService();

          // Check for certificate error
          if (event.anyError.toString().contains('CERTIFICATE_VERIFY_FAILED')) {
            logger.log('', level: LogLevel.error);
            logger.log('🚨 CERTIFICATE ERROR DETECTED', level: LogLevel.error);
            logger.log(
              'PowerSync WebSocket bypasses Flutter certificate handling on Windows.',
              level: LogLevel.error,
            );
            logger.log('', level: LogLevel.error);
            logger.log('MANUAL FIX REQUIRED:', level: LogLevel.error);
            logger.log('1. Download: assets/certs/ca-bundle.pem', level: LogLevel.error);
            logger.log('2. Open certificate file', level: LogLevel.error);
            logger.log(
              '3. Install certificates to "Trusted Root Certification Authorities"',
              level: LogLevel.error,
            );
            logger.log('4. Restart app', level: LogLevel.error);
          }
        }
      }
    });

    _unsyncedSub = db.watch(_unsyncedSql).listen((rows) {
      if (mounted) {
        setState(() {
          _unsyncedCount = rows.isNotEmpty ? (rows.first['n'] as int? ?? 0) : 0;
        });
      }
    });
  }

  /// Cancel current db subscriptions and resubscribe to the (new) [db].
  void _resubscribeDb() {
    _syncStatusSubscription?.cancel();
    _unsyncedSub?.cancel();
    if (mounted) _subscribeToDb();
  }

  Future<void> _checkInitialConnectivity() async {
    final results = await Connectivity().checkConnectivity();
    if (mounted) {
      setState(() {
        _isNetworkAvailable = results.any((result) => result != ConnectivityResult.none);
      });
    }
  }

  @override
  void dispose() {
    super.dispose();
    _syncStatusSubscription?.cancel();
    _connectivitySubscription?.cancel();
    _unsyncedSub?.cancel();
    _dbSwitchSub?.cancel();
  }

  @override
  Widget build(BuildContext context) {
    final authProvider = context.watch<AuthProvider>();

    // Show sync status if user is authenticated (either online or offline)
    if (!authProvider.isAuthenticated) {
      return const SizedBox();
    }

    // If offline mode, show offline status with network info
    /*if (authProvider.isOfflineMode) {
      return Badge(
        isLabelVisible: _unsyncedCount > 0,
        backgroundColor: Colors.orange,
        label: Text('$_unsyncedCount'),
        child: _buildOfflineStatusChip(context, _isNetworkAvailable),
      );
    }*/

    // For online mode — authProvider.isAuthenticated already confirmed above,
    // so always show the chip regardless of stream state.
    return Badge(
      isLabelVisible: _unsyncedCount > 0,
      backgroundColor: Colors.orange,
      label: Text('$_unsyncedCount'),
      child: _buildStatusChip(context, _connectionState),
    );
  }
}

Widget _buildStatusChip(BuildContext context, SyncStatus status) {
  final iconData = _getStatusIconData(status);
  final statusText = _getStatusText(status);
  //final statusColor = _getStatusColor(status);

  return ConstrainedBox(
    constraints: const BoxConstraints(maxWidth: 150),
    child: InputChip(
      avatar: Icon(iconData, size: 18),
      label: Text(statusText, overflow: TextOverflow.ellipsis, maxLines: 1),
      shape: const StadiumBorder(),
      onPressed: () => _SyncStatusDialog.show(context, status),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
    ),
  );
}

Widget _buildOfflineStatusChip(BuildContext context, bool networkAvailable) {
  final icon = networkAvailable ? Icons.cloud_sync_outlined : Icons.cloud_off;
  final text = networkAvailable ? 'Upgrading...' : 'Offline';

  return ConstrainedBox(
    constraints: const BoxConstraints(maxWidth: 170),
    child: InputChip(
      avatar: Icon(icon, size: 18),
      label: Text(text, overflow: TextOverflow.ellipsis, maxLines: 1),
      shape: const StadiumBorder(),
      onPressed: () => _showOfflineDialog(context, networkAvailable),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
    ),
  );
}

IconData _getStatusIconData(SyncStatus status) {
  if (status.anyError != null) {
    if (!status.connected) {
      return Icons.cloud_off;
    } else {
      return Icons.sync_problem;
    }
  } else if (status.connecting) {
    return Icons.cloud_sync_outlined;
  } else if (!status.connected) {
    return Icons.cloud_off;
  } else if (status.uploading && status.downloading) {
    return Icons.cloud_sync_outlined;
  } else if (status.uploading) {
    return Icons.cloud_sync_outlined;
  } else if (status.downloading) {
    return Icons.cloud_sync_outlined;
  } else {
    return Icons.cloud_done;
  }
}

String _getStatusText(SyncStatus status) {
  if (!status.connected) {
    return 'Offline';
  } else if (status.anyError != null) {
    return 'Error';
  } else if (status.connecting) {
    return 'Connecting';
  } else if (status.uploading && status.downloading) {
    return 'Syncing...';
  } else if (status.uploading) {
    return 'Uploading';
  } else if (status.downloading) {
    return 'Downloading';
  } else {
    return 'Connected';
  }
}

// (replaced by _SyncStatusDialog below)
// ignore: unused_element
void _showStatusDialog(BuildContext context, SyncStatus status) {}

class _SyncStatusDialog extends StatefulWidget {
  final SyncStatus status;
  const _SyncStatusDialog({required this.status});

  static Future<void> show(BuildContext context, SyncStatus status) {
    return showDialog(
      context: context,
      builder: (_) => _SyncStatusDialog(status: status),
    );
  }

  @override
  State<_SyncStatusDialog> createState() => _SyncStatusDialogState();
}

class _SyncStatusDialogState extends State<_SyncStatusDialog> {
  late SyncStatus _status;
  StreamSubscription<SyncStatus>? _statusSub;
  StreamSubscription<void>? _dbSwitchSub;
  bool _diagLoading = true;
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
    _status = widget.status;
    _loadDiagnostics();
    _statusSub = db.statusStream.listen((s) {
      if (mounted) {
        setState(() => _status = s);
        _loadDiagnostics();
      }
    });
    _dbSwitchSub = dbSwitchEvents.listen((_) {
      _statusSub?.cancel();
      _statusSub = db.statusStream.listen((s) {
        if (mounted) {
          setState(() => _status = s);
          _loadDiagnostics();
        }
      });
      if (mounted) setState(() => _status = db.currentStatus);
      _loadDiagnostics();
    });
  }

  @override
  void dispose() {
    _statusSub?.cancel();
    _dbSwitchSub?.cancel();
    super.dispose();
  }

  Future<void> _loadDiagnostics() async {
    try {
      final crudCountResult = await db.execute('SELECT COUNT(*) as n FROM ps_crud');
      final pending = crudCountResult.isNotEmpty ? (crudCountResult.first['n'] as int? ?? 0) : 0;

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

      final unsyncedResult = await db.execute('''
        SELECT id, cluster_name, plot_name, local_updated_at, updated_at
        FROM records
        WHERE local_updated_at IS NOT NULL
          AND (
            updated_at IS NULL
            OR local_updated_at > datetime(updated_at, \'+10 minutes\')
          )
        ORDER BY local_updated_at DESC
        LIMIT 50
      ''');
      final unsynced = unsyncedResult
          .map(
            (r) => {
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
          _diagLoading = false;
        });
      }
    } catch (_) {
      if (mounted) setState(() => _diagLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final status = _status;
    // SocketException / Failed host lookup = plain offline, not actionable
    final isNetworkDownError =
        !status.connected &&
        (status.anyError?.toString().contains('SocketException') == true ||
            status.anyError?.toString().contains('Failed host lookup') == true);
    return AlertDialog(
      title: const Text('Sync Status'),
      content: SingleChildScrollView(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            _buildStatusRow('Connected', status.connected ? 'Yes' : 'No'),
            _buildStatusRow('Connecting', status.connecting ? 'Yes' : 'No'),
            _buildStatusRow('Downloading', status.downloading ? 'Yes' : 'No'),
            _buildStatusRow('Uploading', status.uploading ? 'Yes' : 'No'),
            const Divider(),
            _buildStatusRow(
              'Letzte Synchronisierung',
              status.lastSyncedAt?.toLocal().toString() ?? 'Nie',
            ),
            //_buildStatusRow('Hat synchronisiert', (status.hasSynced ?? false) ? 'Ja' : 'Nein'),
            // ── Diagnostic ─────────────────────────────────────────
            const Divider(),
            if (_diagLoading)
              const Padding(
                padding: EdgeInsets.symmetric(vertical: 8),
                child: Center(
                  child: SizedBox(
                    width: 16,
                    height: 16,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  ),
                ),
              )
            else
              _buildDiagnosticSection(context),
            if (status.anyError != null && !isNetworkDownError) ...[
              const Divider(),
              const Text(
                'Error:',
                style: TextStyle(fontWeight: FontWeight.bold, color: Colors.red),
              ),
              const SizedBox(height: 4),
              Text(status.anyError.toString(), style: const TextStyle(fontSize: 12)),
              if (status.anyError.toString().contains('Handshake') ||
                  status.anyError.toString().contains('CERTIFICATE_VERIFY_FAILED')) ...[
                const SizedBox(height: 12),
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: Colors.orange.shade50,
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: Colors.orange.shade200),
                  ),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Icon(Icons.lightbulb_outline, size: 20, color: Colors.orange.shade700),
                      const SizedBox(width: 8),
                      const Expanded(
                        child: Text(
                          'Haben Sie bereits die Anwendung "Install SSL Certificates" ausgeführt? '
                          'Wenn nicht, bitte suchen Sie die Anwendung und führen Diese aus.',
                          style: TextStyle(fontSize: 13),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ],
          ],
        ),
      ),
      actionsAlignment: MainAxisAlignment.spaceBetween,
      actions: [
        Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            const RecordsExportButton(),
            DiagnosticExportButton(
              pendingCrudCount: _pendingCrudCount,
              crudBreakdown: _crudBreakdown,
              unsyncedRecords: _unsyncedRecords,
              lastSyncedAt: _status.lastSyncedAt?.toLocal().toIso8601String(),
            ),
          ],
        ),
        Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextButton(
              onPressed: () async {
                Navigator.of(context).pop();
                await db.disconnect();
                final connector = SupabaseConnector();
                db.connect(connector: connector);
              },
              child: const Text('Reconnect'),
            ),
            TextButton(onPressed: () => Navigator.of(context).pop(), child: const Text('Close')),
          ],
        ),
      ],
    );
  }

  Widget _buildDiagnosticSection(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        _buildStatusRow('Warteschlange', '$_pendingCrudCount ausstehend'),
        if (_crudBreakdown.isNotEmpty) ...[
          const SizedBox(height: 4),
          ..._crudBreakdown.map(
            (b) => Padding(
              padding: const EdgeInsets.only(left: 12, top: 2),
              child: Row(
                children: [
                  Expanded(
                    child: Text('${b['table']} · ${b['op']}', style: const TextStyle(fontSize: 12)),
                  ),
                  Text('${b['cnt']}×', style: const TextStyle(fontSize: 12)),
                ],
              ),
            ),
          ),
        ],
        _buildStatusRow('Nicht synchronisiert', '${_unsyncedRecords.length} Datensätze'),
        if (_unsyncedRecords.isNotEmpty) ...[
          const SizedBox(height: 6),
          ..._unsyncedRecords.take(10).map(_buildRecordRow),
          if (_unsyncedRecords.length > 10)
            Padding(
              padding: const EdgeInsets.only(left: 12, top: 2),
              child: Text(
                '… und ${_unsyncedRecords.length - 10} weitere',
                style: const TextStyle(fontSize: 11),
              ),
            ),
        ],
        IfDatabaseAdmin(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              const SizedBox(height: 8),
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
                builder: (ctx) {
                  final scheme = Theme.of(ctx).colorScheme;
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
    );
  }

  Widget _buildRecordRow(Map<String, dynamic> row) {
    final cluster = row['cluster_name'] ?? '?';
    final plot = row['plot_name'] ?? '?';
    final localTs = _formatTs(row['local_updated_at']);
    final serverTs = _formatTs(row['updated_at']);
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 2),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Padding(padding: EdgeInsets.only(top: 5), child: Icon(Icons.circle, size: 5)),
          const SizedBox(width: 6),
          Expanded(
            child: Text(
              '$cluster / $plot\nLokal: $localTs  •  Server: ${serverTs ?? '–'}',
              style: const TextStyle(fontSize: 11),
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

void _showOfflineDialog(BuildContext context, bool networkAvailable) {
  showDialog(
    context: context,
    builder: (BuildContext context) {
      return AlertDialog(
        title: Row(children: [const Text('Offline-Modus')]),
        content: SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              if (networkAvailable) ...[
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(borderRadius: BorderRadius.circular(8)),
                  child: Row(
                    children: [
                      Icon(Icons.cloud_sync_outlined, size: 20),
                      const SizedBox(width: 8),
                      const Expanded(
                        child: Text(
                          'Verbindung wird wiederhergestellt...',
                          style: TextStyle(fontWeight: FontWeight.w500),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 16),
                const Text(
                  'Die App stellt automatisch die Verbindung zum Server wieder her. '
                  'PowerSync-Synchronisierung wird in Kürze fortgesetzt.',
                ),
              ] else ...[
                const Text(
                  'Die App funktioniert ohne Internetverbindung. '
                  'Alle Änderungen werden lokal gespeichert und automatisch '
                  'synchronisiert, sobald Sie wieder online sind.',
                ),
              ],
              const SizedBox(height: 16),
              const Divider(),
              const SizedBox(height: 8),
              Row(
                children: [
                  Icon(Icons.info_outline, size: 18, color: Colors.blue),
                  const SizedBox(width: 8),
                  const Expanded(
                    child: Text(
                      'Hintergrund-Synchronisierung',
                      style: TextStyle(fontWeight: FontWeight.w500),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              const Text(
                'Die Synchronisierung läuft auch weiter, wenn:\n'
                '• Die App im Hintergrund ist\n'
                '• Das Gerät schläft\n'
                '• Eine andere App im Fokus ist\n\n'
                'Die App muss nur geöffnet bleiben (nicht geschlossen werden).',
                style: TextStyle(fontSize: 12),
              ),
            ],
          ),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.of(context).pop(), child: const Text('OK')),
        ],
      );
    },
  );
}

Widget _buildStatusRow(String label, String value) {
  return Padding(
    padding: const EdgeInsets.symmetric(vertical: 4),
    child: Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SizedBox(
          width: 120,
          child: Text('$label:', style: const TextStyle(fontWeight: FontWeight.w500)),
        ),
        Expanded(child: Text(value)),
      ],
    ),
  );
}
