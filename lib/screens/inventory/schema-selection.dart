import 'dart:async';
import 'dart:io' show Platform;
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:beamer/beamer.dart';
import 'package:powersync/powersync.dart' hide Column;
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:terrestrial_forest_monitor/repositories/schema_repository.dart';
import 'package:terrestrial_forest_monitor/screens/inventory/permissions-selection.dart';
import 'package:terrestrial_forest_monitor/services/powersync.dart';
import 'package:terrestrial_forest_monitor/services/proxy_service.dart';
import 'package:terrestrial_forest_monitor/providers/auth.dart';
import 'package:terrestrial_forest_monitor/widgets/auth/user-info-tile.dart';
import 'package:terrestrial_forest_monitor/widgets/map/map-tiles-download.dart';
import 'package:terrestrial_forest_monitor/widgets/map/map-tiles-download-windows.dart';
import 'package:terrestrial_forest_monitor/widgets/version-control.dart';

class SchemaSelection extends StatefulWidget {
  const SchemaSelection({super.key});

  @override
  State<SchemaSelection> createState() => _SchemaSelectionState();
}

class _SchemaSelectionState extends State<SchemaSelection> {
  bool _isDatabaseAdmin = false;

  @override
  void initState() {
    super.initState();
    _checkDatabaseAdminStatus();
  }

  Future<void> _checkDatabaseAdminStatus() async {
    try {
      final user = Supabase.instance.client.auth.currentUser;
      if (user == null) {
        setState(() => _isDatabaseAdmin = false);
        return;
      }

      final result = await db.getAll('SELECT is_database_admin FROM users_profile WHERE id = ?', [
        user.id,
      ]);

      if (mounted) {
        setState(() {
          _isDatabaseAdmin = result.isNotEmpty && result.first['is_database_admin'] == 1;
        });
      }
    } catch (e) {
      debugPrint('Error checking database admin status: $e');
      if (mounted) {
        setState(() => _isDatabaseAdmin = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final repository = context.read<SchemaRepository>();
    // Try to get ScrollController from Provider, but it's optional
    final scrollController = context.watch<ScrollController?>();

    return StreamBuilder<List<SchemaModel>>(
      stream: _isDatabaseAdmin
          ? repository.watchUniqueByIntervalAll()
          : repository.watchUniqueByInterval(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }

        if (snapshot.hasError) {
          return Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(Icons.error_outline, size: 64, color: Colors.red[300]),
                const SizedBox(height: 16),
                Text('Fehler: ${snapshot.error}', style: const TextStyle(fontSize: 16)),
              ],
            ),
          );
        }

        final schemas = snapshot.data ?? [];

        return Column(
          children: [
            const UserInfoTile(),

            if (schemas.isNotEmpty)
              Card(
                margin: const EdgeInsets.all(16),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    const MapTilesDownload(),
                    FutureBuilder<ProxyConfig>(
                      future: ProxyService().getProxyConfig(),
                      builder: (context, snapshot) {
                        final proxyEnabled = snapshot.data?.enabled ?? false;
                        if (!proxyEnabled) return const SizedBox.shrink();

                        return Container(
                          margin: const EdgeInsets.fromLTRB(16, 0, 16, 16),
                          padding: const EdgeInsets.all(12),
                          decoration: BoxDecoration(
                            color: Colors.orange.withOpacity(0.1),
                            borderRadius: BorderRadius.circular(8),
                            border: Border.all(color: Colors.orange),
                          ),
                          child: Row(
                            children: [
                              Icon(Icons.warning_amber, color: Colors.orange.shade700),
                              const SizedBox(width: 12),
                              if (Platform.isWindows)
                                const Expanded(
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        'Wenn ein Proxy aktiv ist, kann der Bulk-Download möglicherweise nicht durchgeführt werden.',
                                        style: TextStyle(fontWeight: FontWeight.bold),
                                      ),
                                      SizedBox(height: 4),
                                      Text(
                                        'Stellen Sie den Proxy temporär aus.',
                                        style: TextStyle(fontSize: 12),
                                      ),
                                    ],
                                  ),
                                ),
                            ],
                          ),
                        );
                      },
                    ),
                  ],
                ),
              ),
            Expanded(
              child: schemas.isEmpty
                  ? const _EmptyStateWithProgress()
                  : ListView.builder(
                      controller: scrollController,
                      padding: const EdgeInsets.all(16),
                      itemCount: schemas.length,
                      physics: const ClampingScrollPhysics(),
                      addAutomaticKeepAlives: false,
                      addRepaintBoundaries: true,
                      itemBuilder: (context, index) {
                        final schema = schemas[index];
                        return _SchemaCard(
                          schema: schema,
                          onTap: () => _handleSchemaSelection(context, schema),
                        );
                      },
                    ),
            ),

            const VersionControl(),
          ],
        );
      },
    );
  }

  void _handleSchemaSelection(BuildContext context, SchemaModel schema) {
    final encodedIntervalName = Uri.encodeComponent(schema.intervalName);
    Beamer.of(context).beamToNamed('/records-selection/$encodedIntervalName');
  }
}

class _EmptyStateWithProgress extends StatefulWidget {
  const _EmptyStateWithProgress();

  @override
  State<_EmptyStateWithProgress> createState() => _EmptyStateWithProgressState();
}

class _EmptyStateWithProgressState extends State<_EmptyStateWithProgress>
    with SingleTickerProviderStateMixin {
  // add funny loading messages
  List<String> loopLoadingMessage = [
    "Bitte warten...",
    "Es kann einen Moment dauern...",
    "... es dauert nicht mehr lange...",
    "Fast geschafft...",
    "Noch ein bisschen Geduld...",
    "Daten werden synchronisiert...",
    "Fast fertig...",
  ];

  int _currentMessageIndex = 0;
  Timer? _messageTimer;

  @override
  void initState() {
    super.initState();
    _startMessageLoop();
  }

  @override
  void dispose() {
    _messageTimer?.cancel();
    super.dispose();
  }

  void _startMessageLoop() {
    _messageTimer = Timer.periodic(const Duration(seconds: 25), (timer) {
      if (mounted) {
        setState(() {
          _currentMessageIndex = (_currentMessageIndex + 1) % loopLoadingMessage.length;
        });
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<SyncStatus>(
      stream: db.statusStream,
      initialData: db.currentStatus,
      builder: (context, syncSnapshot) {
        final syncStatus = syncSnapshot.data ?? db.currentStatus;
        final isDownloading = syncStatus.downloading;
        final downloadProgress = _calculateDownloadProgress(syncStatus);

        // Stop timer when not downloading
        if (!isDownloading) {
          _messageTimer?.cancel();
          _messageTimer = null;
        } else if (_messageTimer == null || !_messageTimer!.isActive) {
          // Restart timer if downloading and timer is not active
          _startMessageLoop();
        }

        return Center(
          child: SingleChildScrollView(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              mainAxisSize: MainAxisSize.min,
              children: [
                if (isDownloading) ...[
                  SizedBox(
                    width: 80,
                    height: 80,
                    child: Stack(
                      alignment: Alignment.center,
                      children: [
                        SizedBox(
                          width: 80,
                          height: 80,
                          child: CircularProgressIndicator(
                            value: downloadProgress > 0 ? downloadProgress / 100 : null,
                            strokeWidth: 1,
                          ),
                        ),
                        if (downloadProgress > 0)
                          Text(
                            '${downloadProgress.toStringAsFixed(0)}%',
                            style: const TextStyle(fontSize: 25),
                          ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 16),
                  Text(
                    loopLoadingMessage[_currentMessageIndex],
                    style: const TextStyle(fontSize: 12),
                  ),
                ] else ...[
                  Icon(Icons.folder_open, size: 64, color: Colors.grey[400]),
                  const SizedBox(height: 16),
                  const Text('Keine Schemas verfügbar', style: TextStyle(fontSize: 12)),
                  const SizedBox(height: 8),
                  Text(
                    'Bitte synchronisieren Sie die Daten',
                    style: TextStyle(color: Colors.grey[600]),
                  ),
                ],
              ],
            ),
          ),
        );
      },
    );
  }

  double _calculateDownloadProgress(SyncStatus status) {
    if (!status.downloading) {
      return 0.0;
    }

    // Get download progress from status
    final downloadProgress = status.downloadProgress;

    if (downloadProgress == null) {
      return 0.0;
    }

    // downloadedFraction returns a value from 0.0 to 1.0
    // Convert to percentage (0-100)
    final progress = downloadProgress.downloadedFraction * 100;
    return progress.clamp(0.0, 100.0);
  }
}

class _SchemaCard extends StatelessWidget {
  final SchemaModel schema;
  final VoidCallback onTap;

  const _SchemaCard({required this.schema, required this.onTap});

  @override
  Widget build(BuildContext context) {
    // Get the current user ID from Supabase (online) or AuthProvider (offline)
    final authProvider = context.watch<AuthProvider>();
    final userId = authProvider.userId ?? getUserId();

    return Column(
      children: [
        Card(
          margin: const EdgeInsets.only(bottom: 12),
          elevation: 2,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              ListTile(title: Text(schema.title)),
              Divider(height: 1),

              // Show permissions only if user is logged in
              if (userId != null) PermissionsSelection(userId: userId, schemaId: schema.id),
            ],
          ),
        ),
      ],
    );
  }
}
