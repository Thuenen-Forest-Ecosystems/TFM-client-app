import 'dart:convert';
import 'dart:io';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:terrestrial_forest_monitor/widgets/auth/if-database-admin.dart';

/// Download button (DB-admin only) — exports diagnostic data as a JSON file
/// to a user-selected location on the device.
class DiagnosticExportButton extends StatelessWidget {
  final int pendingCrudCount;
  final List<Map<String, dynamic>> crudBreakdown;
  final List<Map<String, dynamic>> unsyncedRecords;
  final String? lastSyncedAt;

  const DiagnosticExportButton({
    super.key,
    required this.pendingCrudCount,
    required this.crudBreakdown,
    required this.unsyncedRecords,
    this.lastSyncedAt,
  });

  Future<void> _export(BuildContext context) async {
    final payload = {
      'exported_at': DateTime.now().toIso8601String(),
      'last_synced_at': lastSyncedAt,
      'pending_crud_count': pendingCrudCount,
      'crud_breakdown': crudBreakdown,
      'unsynced_records': unsyncedRecords,
    };

    final jsonString = const JsonEncoder.withIndent('  ').convert(payload);
    final timestamp = DateTime.now().toIso8601String().replaceAll(':', '-').substring(0, 19);
    final fileName = 'tfm-diagnostic-$timestamp.json';

    final path = await FilePicker.saveFile(
      dialogTitle: 'Diagnosedaten speichern',
      fileName: fileName,
      type: FileType.custom,
      allowedExtensions: ['json'],
    );

    if (path == null) return; // user cancelled

    try {
      await File(path).writeAsString(jsonString, encoding: utf8);
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Gespeichert: $path'), behavior: SnackBarBehavior.floating),
        );
      }
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Fehler beim Speichern: $e'), behavior: SnackBarBehavior.floating),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return IfDatabaseAdmin(
      child: IconButton(
        icon: const Icon(Icons.download_outlined),
        tooltip: 'Diagnosedaten als JSON speichern',
        onPressed: () => _export(context),
      ),
    );
  }
}
