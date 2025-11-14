import 'dart:async';

import 'package:flutter/material.dart';
import 'package:powersync/powersync.dart' hide Column;
import 'package:supabase_flutter/supabase_flutter.dart';
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

  @override
  void initState() {
    super.initState();
    _connectionState = db.currentStatus;
    _syncStatusSubscription = db.statusStream.listen((event) {
      setState(() {
        _connectionState = db.currentStatus;
        print('SyncStatus: ${event}');
      });
    });
  }

  @override
  void dispose() {
    super.dispose();
    _syncStatusSubscription?.cancel();
  }

  @override
  Widget build(BuildContext context) {
    return StreamBuilder(
      stream: Supabase.instance.client.auth.onAuthStateChange,
      builder: (context, snapshot) {
        if (snapshot.hasData) {
          User? user = getCurrentUser();

          if (user == null) {
            return SizedBox();
          }
          return _makeIconButton(context, _connectionState);
        } else {
          return SizedBox();
        }
      },
    );
  }
}

Widget _makeIconButton(BuildContext context, SyncStatus status) {
  final iconData = _getStatusIconData(status);
  final statusText = _getStatusText(status);

  return IconButton(onPressed: () => _showStatusDialog(context, status), tooltip: statusText, icon: Icon(iconData));
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
  if (status.anyError != null) {
    return status.anyError!.toString();
  } else if (status.connecting) {
    return 'Connecting';
  } else if (!status.connected) {
    return 'Not connected';
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
                const Text('Error:', style: TextStyle(fontWeight: FontWeight.bold, color: Colors.red)),
                const SizedBox(height: 4),
                Text(status.anyError.toString(), style: const TextStyle(fontSize: 12)),
              ],
            ],
          ),
        ),
        actions: [TextButton(onPressed: () => Navigator.of(context).pop(), child: const Text('Close'))],
      );
    },
  );
}

Widget _buildStatusRow(String label, String value) {
  return Padding(
    padding: const EdgeInsets.symmetric(vertical: 4),
    child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [SizedBox(width: 120, child: Text('$label:', style: const TextStyle(fontWeight: FontWeight.w500))), Expanded(child: Text(value))]),
  );
}
