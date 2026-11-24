import 'dart:convert';
import 'dart:io';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:terrestrial_forest_monitor/l10n/app_localizations.dart';
import 'package:terrestrial_forest_monitor/services/powersync.dart';
import 'package:terrestrial_forest_monitor/widgets/auth/if-database-admin.dart';

/// Admin-only button that exports all local records to a user-selected JSON file.
class RecordsExportButton extends StatefulWidget {
  const RecordsExportButton({super.key});

  @override
  State<RecordsExportButton> createState() => _RecordsExportButtonState();
}

class _RecordsExportButtonState extends State<RecordsExportButton> {
  bool _exporting = false;

  Future<void> _export() async {
    final l10n = AppLocalizations.of(context)!;
    setState(() => _exporting = true);
    try {
      final rows = await db.execute('SELECT * FROM records ORDER BY cluster_name, plot_name');
      final records = rows.map((r) => Map<String, dynamic>.from(r)).toList();

      final payload = {
        'exported_at': DateTime.now().toIso8601String(),
        'count': records.length,
        'records': records,
      };

      final jsonString = const JsonEncoder.withIndent('  ').convert(payload);
      final timestamp = DateTime.now().toIso8601String().replaceAll(':', '-').substring(0, 19);
      final fileName = 'tfm-records-$timestamp.json';

      final path = await FilePicker.saveFile(
        dialogTitle: l10n.recordsExportDialogTitle,
        fileName: fileName,
        type: FileType.custom,
        allowedExtensions: ['json'],
        // Web has no file system: the bytes are handed to the browser as a
        // download and saveFile returns null.
        bytes: kIsWeb ? utf8.encode(jsonString) : null,
      );

      if (!kIsWeb) {
        if (path == null) return; // user cancelled
        await File(path).writeAsString(jsonString, encoding: utf8);
      }

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(l10n.recordsExportSaved(records.length, path ?? fileName)),
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(l10n.recordsExportError(e.toString())),
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _exporting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return IfDatabaseAdmin(
      child: _exporting
          ? const Padding(
              padding: EdgeInsets.symmetric(horizontal: 12),
              child: SizedBox(
                width: 20,
                height: 20,
                child: CircularProgressIndicator(strokeWidth: 2),
              ),
            )
          : IconButton(
              icon: const Icon(Icons.download_outlined),
              tooltip: AppLocalizations.of(context)!.recordsExportTooltip,
              onPressed: _export,
            ),
    );
  }
}
