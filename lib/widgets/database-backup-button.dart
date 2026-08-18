import 'dart:io';

import 'package:archive/archive_io.dart';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'package:terrestrial_forest_monitor/services/powersync.dart';

/// Copies every non-active TFM database file (incl. -wal/-shm journals) into
/// [workDirPath], writes a manifest, and zips the directory to [zipPath].
///
/// Runs in a background isolate via [compute]: deflate is CPU-heavy pure-Dart
/// work that would otherwise block the UI thread long enough for an ANR kill.
/// Only plain dart:io is used here — no platform channels (they are
/// unavailable in background isolates), which is why all paths are resolved
/// by the caller and passed in as strings.
///
/// MUST stay a top-level function taking one sendable record: a closure
/// created inside the widget's method would capture the enclosing context
/// (including the State object via setState) and fail to cross the isolate
/// boundary with "object is unsendable".
Future<int> _stageAndZip(
  ({
    String supportDirPath,
    String workDirPath,
    String base,
    String activeName,
    String zipPath,
    String timestampIso,
  })
  job,
) async {
  final supportDirPath = job.supportDirPath;
  final workDirPath = job.workDirPath;
  final base = job.base;
  final activeName = job.activeName;
  final zipPath = job.zipPath;
  final timestampIso = job.timestampIso;
  final workDir = Directory(workDirPath);

  // Every other TFM database file, as-is including -wal/-shm.
  // (The active file's trio is covered by the VACUUM INTO snapshot.)
  for (final entry in Directory(supportDirPath).listSync().whereType<File>()) {
    final name = p.basename(entry.path);
    if (!name.startsWith(base) || !name.contains('.db')) continue;
    if (name.startsWith(activeName)) continue;
    try {
      entry.copySync(p.join(workDirPath, name));
    } catch (_) {
      // Unreadable file — skip rather than failing the whole backup.
    }
  }

  // Manifest so support can see what this backup contains.
  final files = workDir.listSync().whereType<File>().toList()
    ..sort((a, b) => a.path.compareTo(b.path));
  final manifest = StringBuffer()
    ..writeln('TFM Datenbank-Backup')
    ..writeln('Erstellt: $timestampIso')
    ..writeln('Aktive Datenbank: $activeName (Snapshot via VACUUM INTO)')
    ..writeln('Dateien:');
  for (final f in files) {
    manifest.writeln('  ${p.basename(f.path)} (${f.lengthSync()} Bytes)');
  }
  File(p.join(workDirPath, 'manifest.txt')).writeAsStringSync(manifest.toString());

  final encoder = ZipFileEncoder();
  encoder.create(zipPath);
  await encoder.addDirectory(workDir, includeDirName: false);
  encoder.close();

  return File(zipPath).lengthSync();
}

/// Bottom-bar button that packs ALL local TFM database files into a ZIP and
/// lets the user save it (support/forensics backup).
///
/// The ACTIVE database is open and being written, so a plain file copy could
/// be torn mid-write — it is snapshotted with `VACUUM INTO` instead, which
/// produces a consistent single-file copy. Inactive files (legacy shared db,
/// other users' files) are copied as-is together with their -wal/-shm
/// journals, so un-checkpointed changes are not lost.
class DatabaseBackupButton extends StatefulWidget {
  const DatabaseBackupButton({super.key});

  @override
  State<DatabaseBackupButton> createState() => _DatabaseBackupButtonState();
}

class _DatabaseBackupButtonState extends State<DatabaseBackupButton> {
  bool _busy = false;

  Future<void> _backup() async {
    setState(() => _busy = true);
    Directory? workDir;
    File? zipFile;
    try {
      // Resolve everything that needs platform channels on the main isolate.
      final tempDir = await getTemporaryDirectory();
      final supportDir = await getApplicationSupportDirectory();
      final base = await getDatabaseBaseName();
      final activePath = await getActiveDatabasePath();
      final activeName = p.basename(activePath);

      final now = DateTime.now();
      final stamp =
          '${now.year}${now.month.toString().padLeft(2, '0')}${now.day.toString().padLeft(2, '0')}'
          '-${now.hour.toString().padLeft(2, '0')}${now.minute.toString().padLeft(2, '0')}${now.second.toString().padLeft(2, '0')}';
      workDir = await Directory(
        p.join(tempDir.path, 'tfm-db-backup-$stamp'),
      ).create(recursive: true);
      final zipPath = p.join(tempDir.path, 'tfm-datenbank-backup-$stamp.zip');

      // Consistent snapshot of the active (open, live-written) database.
      // Runs on the database's own worker, does not block the UI thread.
      final snapshotPath = p.join(workDir.path, activeName);
      try {
        await db.execute("VACUUM INTO '${snapshotPath.replaceAll("'", "''")}'");
      } catch (_) {
        // VACUUM INTO unavailable/failed — fall back to a raw copy including
        // the journals. Possibly mid-write, but better than no backup at all.
        for (final suffix in ['', '-wal', '-shm']) {
          final f = File('$activePath$suffix');
          if (await f.exists()) {
            await f.copy(p.join(workDir.path, '$activeName$suffix'));
          }
        }
      }

      // Stage the remaining files and zip — in a background isolate, so the
      // CPU-heavy deflate cannot freeze the UI (previously caused an ANR).
      // compute() with a top-level function + record message keeps the
      // isolate payload free of unsendable captures (see _stageAndZip doc).
      final zipSize = await compute(_stageAndZip, (
        supportDirPath: supportDir.path,
        workDirPath: workDir.path,
        base: base,
        activeName: activeName,
        zipPath: zipPath,
        timestampIso: now.toIso8601String(),
      ));
      zipFile = File(zipPath);

      // file_picker needs the bytes only on Android/iOS (it writes the file
      // itself there). Desktop ignores them — don't load the ZIP into RAM.
      final needsBytes = !kIsWeb && (Platform.isAndroid || Platform.isIOS);
      final savedPath = await FilePicker.saveFile(
        dialogTitle: 'Datenbank-Backup speichern',
        fileName: p.basename(zipPath),
        type: FileType.custom,
        allowedExtensions: ['zip'],
        bytes: needsBytes ? await zipFile.readAsBytes() : null,
      );
      if (savedPath == null) return; // user cancelled

      // On Android/iOS file_picker has already written the bytes via SAF and
      // returns a content identifier (e.g. '/document/901'), not a real file
      // path — dart:io must not touch it. Only on desktop, where the dialog
      // merely returns the chosen path, do we write the file ourselves.
      if (!needsBytes) {
        await zipFile.copy(savedPath);
      }
      final sizeMb = zipSize / (1024 * 1024);
      _showSnack(
        needsBytes
            ? 'Backup gespeichert (${sizeMb.toStringAsFixed(1)} MB)'
            : 'Backup gespeichert (${sizeMb.toStringAsFixed(1)} MB): $savedPath',
      );
    } catch (e) {
      _showSnack('Backup fehlgeschlagen: $e');
    } finally {
      try {
        workDir?.deleteSync(recursive: true);
      } catch (_) {}
      try {
        zipFile?.deleteSync();
      } catch (_) {}
      if (mounted) setState(() => _busy = false);
    }
  }

  void _showSnack(String message) {
    if (!mounted) return;
    // Fixed (not floating) — see upload-failures.dart: floating snackbars
    // assert when they outlive this page and land on a Scaffold whose bottom
    // widgets are too tall.
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(message)));
  }

  @override
  Widget build(BuildContext context) {
    if (kIsWeb) return const SizedBox.shrink();

    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(12, 8, 12, 12),
        child: OutlinedButton.icon(
          onPressed: _busy ? null : _backup,
          icon: _busy
              ? const SizedBox(
                  width: 18,
                  height: 18,
                  child: CircularProgressIndicator(strokeWidth: 2),
                )
              : const Icon(Icons.archive_outlined, size: 18),
          label: Text(_busy ? 'Backup wird erstellt …' : 'Backup aller Datenbanken (ZIP)'),
        ),
      ),
    );
  }
}
