import 'dart:io';
import 'dart:math';
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:terrestrial_forest_monitor/services/backup_crypto.dart';

/// Round-trips a sealed backup through the support-side decryptor.
///
/// The point of these tests is INTEROP: the container is written by Dart
/// (`sealFile`) and opened by Node (`tools/tfm-backup.mjs`). A nonce, framing
/// or HKDF mismatch between the two would otherwise only surface the day
/// support tries to open a real backup — by which time the device is long
/// gone. They are skipped where `node` is unavailable.
void main() {
  final tool = File('tools/tfm-backup.mjs');
  final hasNode = _hasNode() && tool.existsSync();

  late Directory tmp;
  late String privateKeyPath;
  late Uint8List recipientKey;

  setUpAll(() {
    if (!hasNode) return;
    tmp = Directory.systemTemp.createTempSync('tfm-backup-test');
    final keygen = Process.runSync('node', [tool.path, 'keygen', '--out', tmp.path]);
    expect(keygen.exitCode, 0, reason: keygen.stderr.toString());
    final line = (keygen.stdout as String)
        .split('\n')
        .firstWhere((l) => l.startsWith('BACKUP_RECIPIENT_KEY='));
    privateKeyPath = '${tmp.path}/tfm-backup-private.pem';
    recipientKey = parseBackupRecipientKey(line.split('=').sublist(1).join('='))!;
  });

  tearDownAll(() {
    if (hasNode) tmp.deleteSync(recursive: true);
  });

  ProcessResult decrypt(String sealed, String out) =>
      Process.runSync('node', [tool.path, 'decrypt', sealed, out, '--key', privateKeyPath]);

  /// Deterministic filler — a real backup is a compressed ZIP, so the payload
  /// must not be a run of identical bytes that would hide framing bugs.
  File sample(String name, int length) {
    final random = Random(42);
    final bytes = Uint8List.fromList(List.generate(length, (_) => random.nextInt(256)));
    return File('${tmp.path}/$name')..writeAsBytesSync(bytes);
  }

  test('multi-chunk payload survives the round trip', () async {
    final source = sample('multi.zip', 2 * 1024 * 1024 + 12345); // 3 chunks, last one short
    final sealed = '${tmp.path}/multi.tfmbak';
    await sealFile(
      sourcePath: source.path,
      targetPath: sealed,
      recipientPublicKey: recipientKey,
    );

    final result = decrypt(sealed, '${tmp.path}/multi.out');
    expect(result.exitCode, 0, reason: result.stderr.toString());
    expect(File('${tmp.path}/multi.out').readAsBytesSync(), source.readAsBytesSync());
  }, skip: hasNode ? false : 'node not available');

  test('empty payload still produces one authenticated final chunk', () async {
    final source = sample('empty.zip', 0);
    final sealed = '${tmp.path}/empty.tfmbak';
    await sealFile(
      sourcePath: source.path,
      targetPath: sealed,
      recipientPublicKey: recipientKey,
    );

    final result = decrypt(sealed, '${tmp.path}/empty.out');
    expect(result.exitCode, 0, reason: result.stderr.toString());
    expect(File('${tmp.path}/empty.out').lengthSync(), 0);
  }, skip: hasNode ? false : 'node not available');

  test('a truncated container is rejected, not silently shortened', () async {
    final source = sample('cut.zip', 2 * 1024 * 1024 + 500);
    final sealed = '${tmp.path}/cut.tfmbak';
    await sealFile(
      sourcePath: source.path,
      targetPath: sealed,
      recipientPublicKey: recipientKey,
    );

    // Drop the trailing chunk: what a half-finished mail attachment looks like.
    final bytes = File(sealed).readAsBytesSync();
    final truncated = '${tmp.path}/cut-truncated.tfmbak';
    File(truncated).writeAsBytesSync(bytes.sublist(0, 44 + 4 + 1024 * 1024 + 16));

    final result = decrypt(truncated, '${tmp.path}/cut.out');
    expect(result.exitCode, isNot(0));
  }, skip: hasNode ? false : 'node not available');

  test('a wrong recipient key yields no readable backup', () async {
    final source = sample('wrong.zip', 4096);
    final sealed = '${tmp.path}/wrong.tfmbak';
    final otherKey = Uint8List.fromList(List.generate(32, (i) => i + 1));
    await sealFile(
      sourcePath: source.path,
      targetPath: sealed,
      recipientPublicKey: otherKey,
    );

    final result = decrypt(sealed, '${tmp.path}/wrong.out');
    expect(result.exitCode, isNot(0));
  }, skip: hasNode ? false : 'node not available');

  test('recipient key parsing rejects anything that is not 32 bytes', () {
    expect(parseBackupRecipientKey(null), isNull);
    expect(parseBackupRecipientKey('   '), isNull);
    expect(parseBackupRecipientKey('not base64 at all!!'), isNull);
    expect(parseBackupRecipientKey('c2hvcnQ='), isNull); // valid base64, wrong length
    expect(parseBackupRecipientKey('9VpJwe58mu2BVKFNiCh/i2iQhsZ2TSP/QJN79z7rxRM='), hasLength(32));
  });
}

bool _hasNode() {
  try {
    return Process.runSync('node', ['--version']).exitCode == 0;
  } catch (_) {
    return false;
  }
}
