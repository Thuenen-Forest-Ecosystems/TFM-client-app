import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:terrestrial_forest_monitor/services/powersync.dart';

class DownloadSchemasBtn extends StatefulWidget {
  const DownloadSchemasBtn({super.key});

  @override
  State<DownloadSchemasBtn> createState() => _DownloadSchemasBtnState();
}

class _DownloadSchemasBtnState extends State<DownloadSchemasBtn> {
  bool _isDownloading = false;
  String _statusMessage = '';
  double _progress = 0.0;
  int _currentDirectory = 0;
  int _totalDirectories = 0;

  Future<bool> _isDatabaseAdmin() async {
    try {
      final user = Supabase.instance.client.auth.currentUser;
      if (user == null) return false;

      final result = await db.getAll('SELECT is_database_admin FROM users_profile WHERE id = ?', [
        user.id,
      ]);

      return result.isNotEmpty && result.first['is_database_admin'] == 1;
    } catch (e) {
      debugPrint('Error checking database admin status: $e');
      return false;
    }
  }

  Future<void> _downloadSchemas({bool force = false}) async {
    setState(() {
      _isDownloading = true;
      _statusMessage = 'Starte Download...';
      _progress = 0.0;
      _currentDirectory = 0;
      _totalDirectories = 0;
    });

    try {
      // Check if user is database admin
      final isDatabaseAdmin = await _isDatabaseAdmin();
      debugPrint('Is database admin: $isDatabaseAdmin');

      // First, check what schemas we have in total
      final allSchemas = await db.getAll(
        'SELECT id, directory, is_visible, is_deprecated FROM schemas',
      );
      debugPrint('Total schemas in local DB: ${allSchemas.length}');
      for (var schema in allSchemas) {
        debugPrint(
          'Schema: ${schema['id']}, directory: ${schema['directory']}, visible: ${schema['is_visible']}, deprecated: ${schema['is_deprecated']}',
        );
      }

      // Get all schema directories - include hidden schemas if database admin
      final visibilityCondition = isDatabaseAdmin ? '' : 'AND is_visible = 1';
      final results = await db.getAll(
        "SELECT DISTINCT directory FROM schemas WHERE directory IS NOT NULL AND is_deprecated = 0 AND directory != '' $visibilityCondition",
      );
      debugPrint('Query result count: ${results.length}');

      if (results.isEmpty) {
        setState(() {
          _statusMessage = 'Keine Schemas gefunden';
          _isDownloading = false;
        });
        return;
      }

      final directories = results.map((row) => row['directory'] as String).toSet().toList();
      setState(() {
        _totalDirectories = directories.length;
        _statusMessage = 'Lade ${directories.length} Schema-Verzeichnisse...';
      });

      int successCount = 0;
      int failCount = 0;
      int totalFilesDownloaded = 0;

      for (int i = 0; i < directories.length; i++) {
        final directory = directories[i];
        setState(() {
          _currentDirectory = i + 1;
          _progress = (i + 1) / directories.length;
          _statusMessage = 'Lade Schema ${i + 1}/${directories.length}: $directory';
        });

        final result = await downloadValidationFiles(directory, force: force);

        if (result['success']) {
          successCount++;
          totalFilesDownloaded += (result['downloadedCount'] as int?) ?? 0;
        } else {
          failCount++;
        }
      }

      if (mounted) {
        setState(() {
          _isDownloading = false;
          _statusMessage =
              'Abgeschlossen: $successCount erfolgreich, $failCount fehlgeschlagen. $totalFilesDownloaded Dateien heruntergeladen.';
        });

        // Show completion dialog
        /*showDialog(
          context: context,
          builder:
              (context) => AlertDialog(
                title: const Text('Download abgeschlossen'),
                content: Text(
                  'Erfolgreich: $successCount\nFehlgeschlagen: $failCount\nDateien: $totalFilesDownloaded',
                ),
                actions: [
                  TextButton(onPressed: () => Navigator.of(context).pop(), child: const Text('OK')),
                ],
              ),
        );*/
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _isDownloading = false;
          _statusMessage = 'Fehler: $e';
        });

        showDialog(
          context: context,
          builder: (context) => AlertDialog(
            title: const Text('Fehler'),
            content: Text('Fehler beim Download: $e'),
            actions: [
              TextButton(onPressed: () => Navigator.of(context).pop(), child: const Text('OK')),
            ],
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(16.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          if (_isDownloading) ...[
            LinearProgressIndicator(value: _progress),
            const SizedBox(height: 8),
            Text(_statusMessage, style: const TextStyle(fontSize: 12), textAlign: TextAlign.center),
            const SizedBox(height: 16),
          ],
          if (!_isDownloading && _statusMessage.isNotEmpty) ...[
            Text(_statusMessage, style: const TextStyle(fontSize: 12), textAlign: TextAlign.center),
            const SizedBox(height: 16),
          ],
          Row(
            children: [
              Expanded(
                child: ElevatedButton.icon(
                  onPressed: _isDownloading ? null : () => _downloadSchemas(force: false),
                  icon: const Icon(Icons.download),
                  label: const Text('Fehlende laden'),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: ElevatedButton.icon(
                  onPressed: _isDownloading ? null : () => _downloadSchemas(force: true),
                  icon: const Icon(Icons.sync),
                  label: const Text('Alle neu laden'),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
