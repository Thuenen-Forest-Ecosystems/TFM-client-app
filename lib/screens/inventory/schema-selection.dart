import 'dart:async';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:beamer/beamer.dart';
import 'package:powersync/powersync.dart' hide Column;
import 'package:terrestrial_forest_monitor/repositories/schema_repository.dart';
import 'package:terrestrial_forest_monitor/screens/inventory/permissions-selection.dart';
import 'package:terrestrial_forest_monitor/services/powersync.dart';

class SchemaSelection extends StatefulWidget {
  const SchemaSelection({super.key});

  @override
  State<SchemaSelection> createState() => _SchemaSelectionState();
}

class _SchemaSelectionState extends State<SchemaSelection> {
  @override
  Widget build(BuildContext context) {
    final repository = context.read<SchemaRepository>();
    // Try to get ScrollController from Provider, but it's optional
    final scrollController = context.watch<ScrollController?>();

    return StreamBuilder<List<SchemaModel>>(
      stream: repository.watchUniqueByInterval(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }

        if (snapshot.hasError) {
          return Center(
            child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [Icon(Icons.error_outline, size: 64, color: Colors.red[300]), const SizedBox(height: 16), Text('Fehler: ${snapshot.error}', style: const TextStyle(fontSize: 16))]),
          );
        }

        final schemas = snapshot.data ?? [];

        if (schemas.isEmpty) {
          return const _EmptyStateWithProgress();
        }

        return ListView.builder(
          controller: scrollController,
          padding: const EdgeInsets.all(16),
          itemCount: schemas.length,
          physics: const ClampingScrollPhysics(),
          addAutomaticKeepAlives: false,
          addRepaintBoundaries: true,
          itemBuilder: (context, index) {
            final schema = schemas[index];
            return _SchemaCard(schema: schema, onTap: () => _handleSchemaSelection(context, schema));
          },
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

class _EmptyStateWithProgressState extends State<_EmptyStateWithProgress> with SingleTickerProviderStateMixin {
  // add funny loading messages
  List<String> loopLoadingMessage = ["Bitte warten...", "Es kann einen Moment dauern...", "... es dauert nicht mehr lange...", "Fast geschafft...", "Noch ein bisschen Geduld...", "Daten werden synchronisiert...", "Fast fertig..."];

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
                        SizedBox(width: 80, height: 80, child: CircularProgressIndicator(value: downloadProgress > 0 ? downloadProgress / 100 : null, strokeWidth: 6)),
                        if (downloadProgress > 0) Text('${downloadProgress.toStringAsFixed(0)}%', style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                      ],
                    ),
                  ),
                  const SizedBox(height: 16),
                  Text(loopLoadingMessage[_currentMessageIndex], style: const TextStyle(fontSize: 18)),
                ] else ...[
                  Icon(Icons.folder_open, size: 64, color: Colors.grey[400]),
                  const SizedBox(height: 16),
                  const Text('Keine Schemas verfügbar', style: TextStyle(fontSize: 18)),
                  const SizedBox(height: 8),
                  Text('Bitte synchronisieren Sie die Daten', style: TextStyle(color: Colors.grey[600])),
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
    // Get the current user ID from Supabase
    final userId = getUserId();

    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      elevation: 2,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(padding: EdgeInsets.all(20.0), child: Text(schema.title, style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold))),
          Divider(height: 1),

          // Show permissions only if user is logged in
          if (userId != null) PermissionsSelection(userId: userId, schemaId: schema.id),
        ],
      ),
    );
  }
}
