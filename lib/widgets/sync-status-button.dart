import 'dart:async';

import 'package:flutter/material.dart';
import 'package:powersync/powersync.dart' hide Column;
import 'package:provider/provider.dart';
import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:terrestrial_forest_monitor/providers/auth.dart';
import 'package:terrestrial_forest_monitor/services/powersync.dart';

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

  @override
  void initState() {
    super.initState();
    _connectionState = db.currentStatus;
    _syncStatusSubscription = db.statusStream.listen((event) {
      setState(() {
        _connectionState = db.currentStatus;
      });
    });

    // Listen to network connectivity changes
    _connectivitySubscription = Connectivity().onConnectivityChanged.listen((results) {
      setState(() {
        _isNetworkAvailable = results.any((result) => result != ConnectivityResult.none);
      });
    });

    // Check initial connectivity
    _checkInitialConnectivity();
  }

  Future<void> _checkInitialConnectivity() async {
    final results = await Connectivity().checkConnectivity();
    setState(() {
      _isNetworkAvailable = results.any((result) => result != ConnectivityResult.none);
    });
  }

  @override
  void dispose() {
    super.dispose();
    _syncStatusSubscription?.cancel();
    _connectivitySubscription?.cancel();
  }

  @override
  Widget build(BuildContext context) {
    final authProvider = context.watch<AuthProvider>();

    // Show sync status if user is authenticated (either online or offline)
    if (!authProvider.isAuthenticated) {
      return const SizedBox();
    }

    // If offline mode, show offline status with network info
    if (authProvider.isOfflineMode) {
      return _buildOfflineStatusChip(context, _isNetworkAvailable);
    }

    // For online mode, check Supabase auth
    return StreamBuilder(
      stream: Supabase.instance.client.auth.onAuthStateChange,
      builder: (context, snapshot) {
        if (snapshot.hasData) {
          User? user = getCurrentUser();

          if (user == null) {
            return const SizedBox();
          }
          return _buildStatusChip(context, _connectionState);
        } else {
          return const SizedBox();
        }
      },
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
      onPressed: () => _showStatusDialog(context, status),
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

Color _getStatusColor(SyncStatus status) {
  if (status.anyError != null) {
    return Colors.red.shade600;
  } else if (!status.connected) {
    return Colors.orange.shade700;
  } else if (status.connecting || status.uploading || status.downloading) {
    return Colors.blue.shade600;
  } else {
    return Colors.green.shade600;
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
    return 'Uploading and downloading';
  } else if (status.uploading) {
    return 'Uploading';
  } else if (status.downloading) {
    return 'Downloading';
  } else {
    return 'Connected';
  }
}

void _showStatusDialog(BuildContext context, SyncStatus status) {
  showDialog(
    context: context,
    builder: (BuildContext context) {
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
              _buildStatusRow('Last Synced At', status.lastSyncedAt?.toString() ?? 'Never'),
              if (status.anyError != null) ...[
                const Divider(),
                const Text(
                  'Error:',
                  style: TextStyle(fontWeight: FontWeight.bold, color: Colors.red),
                ),
                const SizedBox(height: 4),
                Text(status.anyError.toString(), style: const TextStyle(fontSize: 12)),
              ],
            ],
          ),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.of(context).pop(), child: const Text('Close')),
        ],
      );
    },
  );
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
