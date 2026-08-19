import 'dart:io';

import 'package:archive/archive_io.dart';
import 'package:convert/convert.dart';
import 'package:crypto/crypto.dart';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'package:terrestrial_forest_monitor/services/backup_crypto.dart';
import 'package:terrestrial_forest_monitor/services/powersync.dart';

/// Name of the `.env` key holding the base64 X25519 public key of whoever is
/// allowed to open backups. Unset (the default) means backups stay plain ZIPs.
const String _recipientKeyEnvName = 'BACKUP_RECIPIENT_KEY';

/// Copies every non-active TFM database file (incl. -wal/-shm journals) into
/// [workDirPath], writes a manifest, zips the directory to [zipPath] and — if
/// a recipient key is configured — seals the ZIP to [sealedPath].
///
/// Runs in a background isolate via [compute]: deflate and AES are CPU-heavy
/// pure-Dart work that would otherwise block the UI thread long enough for an
/// ANR kill. Only plain dart:io is used here — no platform channels (they are
/// unavailable in background isolates), which is why all paths, the app
/// version, the integrity-check result and the recipient key are resolved by
/// the caller and passed in.
///
/// MUST stay a top-level function taking one sendable record: a closure
/// created inside the widget's method would capture the enclosing context
/// (including the State object via setState) and fail to cross the isolate
/// boundary with "object is unsendable".
Future<({String path, int size, bool sealed})> _stageAndZip(
  ({
    String supportDirPath,
    String workDirPath,
    String base,
    String activeName,
    String zipPath,
    String sealedPath,
    String timestampIso,
    String appVersion,
    String integrityCheck,
    Uint8List? recipientKey,
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
  //
  // The per-file SHA-256 is not a tamper control — whoever can edit a database
  // can recompute the hash, and the ZIP's own CRC32 already catches transit
  // damage. It is an identity: it lets support say "this is the same file you
  // sent in August", match a re-packed copy against the original, and spot a
  // backup that was accidentally exported twice from different devices. What
  // answers "was the database already broken on the device?" is the
  // integrity-check line, which the caller obtained from SQLite itself.
  final files = workDir.listSync().whereType<File>().toList()
    ..sort((a, b) => a.path.compareTo(b.path));
  final manifest = StringBuffer()
    ..writeln('TFM Datenbank-Backup')
    ..writeln('Erstellt: $timestampIso')
    ..writeln('App-Version: ${job.appVersion}')
    ..writeln('Aktive Datenbank: $activeName (Snapshot via VACUUM INTO)')
    ..writeln('PRAGMA quick_check: ${job.integrityCheck}')
    ..writeln('Dateien:');
  for (final f in files) {
    manifest.writeln(
      '  ${p.basename(f.path)} (${f.lengthSync()} Bytes)\n'
      '    sha256: ${_sha256OfFile(f)}',
    );
  }
  File(p.join(workDirPath, 'manifest.txt')).writeAsStringSync(manifest.toString());

  final encoder = ZipFileEncoder();
  encoder.create(zipPath);
  await encoder.addDirectory(workDir, includeDirName: false);
  encoder.close();

  final recipientKey = job.recipientKey;
  if (recipientKey == null) {
    return (path: zipPath, size: File(zipPath).lengthSync(), sealed: false);
  }

  final sealedSize = await sealFile(
    sourcePath: zipPath,
    targetPath: job.sealedPath,
    recipientPublicKey: recipientKey,
  );
  // Drop the cleartext ZIP immediately — leaving it in the temp directory
  // would defeat the point of sealing the copy the user gets to keep.
  try {
    File(zipPath).deleteSync();
  } catch (_) {}
  return (path: job.sealedPath, size: sealedSize, sealed: true);
}

/// SHA-256 of a file, read in 1 MiB chunks — a database snapshot can be
/// hundreds of megabytes and must not be materialised in memory.
String _sha256OfFile(File file) {
  final output = AccumulatorSink<Digest>();
  final input = sha256.startChunkedConversion(output);
  final handle = file.openSync();
  try {
    while (true) {
      final chunk = handle.readSync(1 << 20);
      if (chunk.isEmpty) break;
      input.add(chunk);
    }
  } finally {
    handle.closeSync();
  }
  input.close();
  final digest = output.events.single;
  output.close();
  return digest.toString();
}

/// Bottom-bar button that packs ALL local TFM database files into a ZIP and
/// lets the user save it (support/forensics backup).
///
/// The ACTIVE database is open and being written, so a plain file copy could
/// be torn mid-write — it is snapshotted with `VACUUM INTO` instead, which
/// produces a consistent single-file copy. Inactive files (legacy shared db,
/// other users' files) are copied as-is together with their -wal/-shm
/// journals, so un-checkpointed changes are not lost.
///
/// With [_recipientKeyEnvName] configured the ZIP is sealed to that recipient
/// (`.tfmbak`, see [sealFile]) because the archive carries personal data —
/// Trupp members, plot coordinates — across the user's Downloads folder and an
/// e-mail attachment. Without it the backup stays a plain ZIP: an unreadable
/// backup would be worse than an unsealed one.
class DatabaseBackupButton extends StatefulWidget {
  const DatabaseBackupButton({super.key});

  @override
  State<DatabaseBackupButton> createState() => _DatabaseBackupButtonState();
}

class _DatabaseBackupButtonState extends State<DatabaseBackupButton> {
  bool _busy = false;

  /// Whether a recipient key is configured. Decides both the container the
  /// backup lands in and what the button may promise the user — a label
  /// saying ZIP while the file is sealed sends people to support with an
  /// archive they cannot open and no idea why.
  late final bool _seals = parseBackupRecipientKey(_configuredRecipientKey()) != null;

  Future<void> _backup() async {
    setState(() => _busy = true);
    Directory? workDir;
    File? outputFile;
    try {
      // Resolve everything that needs platform channels on the main isolate.
      final tempDir = await getTemporaryDirectory();
      final supportDir = await getApplicationSupportDirectory();
      final base = await getDatabaseBaseName();
      final activePath = await getActiveDatabasePath();
      final activeName = p.basename(activePath);
      final packageInfo = await PackageInfo.fromPlatform();
      final recipientKey = parseBackupRecipientKey(_configuredRecipientKey());

      final now = DateTime.now();
      final stamp =
          '${now.year}${now.month.toString().padLeft(2, '0')}${now.day.toString().padLeft(2, '0')}'
          '-${now.hour.toString().padLeft(2, '0')}${now.minute.toString().padLeft(2, '0')}${now.second.toString().padLeft(2, '0')}';
      workDir = await Directory(
        p.join(tempDir.path, 'tfm-db-backup-$stamp'),
      ).create(recursive: true);
      final zipPath = p.join(tempDir.path, 'tfm-datenbank-backup-$stamp.zip');
      final sealedPath = p.join(
        tempDir.path,
        'tfm-datenbank-backup-$stamp.$sealedBackupExtension',
      );

      // Ask SQLite whether the live database is sound BEFORE snapshotting it.
      // This is the one line that separates "the file was damaged in transit"
      // from "the database on the device was already broken" — the question
      // support has to answer first in a data-loss case.
      final integrityCheck = await _quickCheck();

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

      // Stage the remaining files, zip and seal — in a background isolate, so
      // the CPU-heavy deflate cannot freeze the UI (previously caused an ANR).
      // compute() with a top-level function + record message keeps the
      // isolate payload free of unsendable captures (see _stageAndZip doc).
      final result = await compute(_stageAndZip, (
        supportDirPath: supportDir.path,
        workDirPath: workDir.path,
        base: base,
        activeName: activeName,
        zipPath: zipPath,
        sealedPath: sealedPath,
        timestampIso: now.toIso8601String(),
        appVersion: '${packageInfo.version}+${packageInfo.buildNumber}',
        integrityCheck: integrityCheck,
        recipientKey: recipientKey,
      ));
      outputFile = File(result.path);

      // file_picker needs the bytes only on Android/iOS (it writes the file
      // itself there). Desktop ignores them — don't load the archive into RAM.
      final needsBytes = !kIsWeb && (Platform.isAndroid || Platform.isIOS);
      final savedPath = await FilePicker.saveFile(
        dialogTitle: 'Datenbank-Backup speichern',
        fileName: p.basename(result.path),
        type: FileType.custom,
        allowedExtensions: [result.sealed ? sealedBackupExtension : 'zip'],
        bytes: needsBytes ? await outputFile.readAsBytes() : null,
      );
      if (savedPath == null) return; // user cancelled

      // On Android/iOS file_picker has already written the bytes via SAF and
      // returns a content identifier (e.g. '/document/901'), not a real file
      // path — dart:io must not touch it. Only on desktop, where the dialog
      // merely returns the chosen path, do we write the file ourselves.
      if (!needsBytes) {
        await outputFile.copy(savedPath);
      }
      final sizeMb = result.size / (1024 * 1024);
      final kind = result.sealed ? 'Backup verschlüsselt gespeichert' : 'Backup gespeichert';
      _showSnack(
        needsBytes
            ? '$kind (${sizeMb.toStringAsFixed(1)} MB)'
            : '$kind (${sizeMb.toStringAsFixed(1)} MB): $savedPath',
      );
    } catch (e) {
      _showSnack('Backup fehlgeschlagen: $e');
    } finally {
      try {
        workDir?.deleteSync(recursive: true);
      } catch (_) {}
      try {
        outputFile?.deleteSync();
      } catch (_) {}
      if (mounted) setState(() => _busy = false);
    }
  }

  /// The configured recipient key, or null when `.env` was never loaded
  /// (flutter_dotenv throws instead of returning an empty map in that case).
  String? _configuredRecipientKey() {
    try {
      return dotenv.env[_recipientKeyEnvName];
    } catch (_) {
      return null;
    }
  }

  /// `PRAGMA quick_check` on the live database, rendered as one manifest line.
  /// Never fails the backup: a database too broken to answer is exactly the
  /// case the backup needs to survive.
  Future<String> _quickCheck() async {
    try {
      final rows = await db.getAll('PRAGMA quick_check');
      final results = rows.map((row) => row.values.first?.toString() ?? '?').toList();
      return results.isEmpty ? 'keine Ausgabe' : results.join('; ');
    } catch (e) {
      return 'nicht ausführbar ($e)';
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
          label: Text(
            _busy
                ? 'Backup wird erstellt …'
                : _seals
                ? 'Backup aller Datenbanken (verschlüsselt)'
                : 'Backup aller Datenbanken (ZIP)',
          ),
        ),
      ),
    );
  }
}
