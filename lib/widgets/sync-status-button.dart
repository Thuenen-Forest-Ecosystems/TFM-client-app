import 'dart:async';

import 'package:flutter/material.dart';
import 'package:powersync/powersync.dart';
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
    final statusIcon = _getStatusIcon(_connectionState);
    return StreamBuilder(
      stream: Supabase.instance.client.auth.onAuthStateChange,
      builder: (context, snapshot) {
        if (snapshot.hasData) {
          User? user = getCurrentUser();

          if (user == null) {
            return SizedBox();
          }
          return statusIcon;
        } else {
          return SizedBox();
        }
      },
    );
  }
}

Widget _makeIcon(String text, IconData icon) {
  return Tooltip(message: text, child: Icon(icon));
}

Widget _getStatusIcon(SyncStatus status) {
  if (status.anyError != null) {
    // The error message is verbose, could be replaced with something
    // more user-friendly
    if (!status.connected) {
      return _makeIcon(status.anyError!.toString(), Icons.cloud_off);
    } else {
      return _makeIcon(status.anyError!.toString(), Icons.sync_problem);
    }
  } else if (status.connecting) {
    return _makeIcon('Connecting', Icons.cloud_sync_outlined);
  } else if (!status.connected) {
    return _makeIcon('Not connected', Icons.cloud_off);
  } else if (status.uploading && status.downloading) {
    // The status changes often between downloading, uploading and both,
    // so we use the same icon for all three
    return _makeIcon('Uploading and downloading', Icons.cloud_sync_outlined);
  } else if (status.uploading) {
    return _makeIcon('Uploading', Icons.cloud_sync_outlined);
  } else if (status.downloading) {
    return _makeIcon('Downloading', Icons.cloud_sync_outlined);
  } else {
    return _makeIcon('Connected', Icons.cloud_queue);
  }
}
