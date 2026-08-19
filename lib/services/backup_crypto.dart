import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:cryptography/cryptography.dart';

/// Envelope encryption for the support database backup.
///
/// The backup ZIP holds the complete local database — Trupp members, plot
/// coordinates, unsynced records — and leaves the device through the user's
/// Downloads folder and, as a rule, an e-mail attachment. Sealing it means
/// only support can read it on the way.
///
/// This buys CONFIDENTIALITY, not authenticity. The recipient key is public,
/// so anyone holding the app can seal a file of their own choosing: a sealed
/// backup proves nothing about what the device actually contained. Treat a
/// restored backup as untrusted input and let the server's audit trail decide
/// what is authoritative.
///
/// Scheme (age-style, deliberately boring):
///
///     ephemeral X25519 key pair, fresh per backup
///     shared  = X25519(ephemeral_sk, recipient_pk)
///     key     = HKDF-SHA256(ikm: shared, salt: eph_pk || recipient_pk,
///                           info: 'tfm-backup-v1', length: 32)
///     payload = AES-256-GCM over 1 MiB chunks, STREAM-style nonces
///
/// The chunk counter and a final-chunk flag live in the nonce, so a truncated
/// or reordered file fails to decrypt instead of silently yielding a short
/// database. The 44-byte header is authenticated as AAD in every chunk.
///
/// Pure Dart on purpose: [sealFile] runs inside the backup's background
/// isolate, where platform channels — and with them any native crypto
/// plugin — are unavailable.

/// File extension of a sealed backup. Plain (unsealed) backups stay `.zip`.
const String sealedBackupExtension = 'tfmbak';

const List<int> _magic = [0x54, 0x46, 0x4D, 0x42, 0x41, 0x4B]; // 'TFMBAK'
const int _formatVersion = 1;
const int _suiteX25519AesGcm = 1;
const int _headerLength = 44; // magic(6) + version(1) + suite(1) + eph_pk(32) + chunkSize(4)
const int _chunkSize = 1024 * 1024;
const int _tagLength = 16;
const String _hkdfInfo = 'tfm-backup-v1';

/// Decodes the base64 X25519 recipient public key from configuration.
///
/// Returns null when unset or malformed — the caller then writes a plain ZIP
/// rather than failing the backup. A backup nobody can read is worse than an
/// unsealed one: this button exists to rescue data.
Uint8List? parseBackupRecipientKey(String? configured) {
  final raw = configured?.trim();
  if (raw == null || raw.isEmpty) return null;
  try {
    final bytes = base64.decode(base64.normalize(raw));
    return bytes.length == 32 ? Uint8List.fromList(bytes) : null;
  } on FormatException {
    return null;
  }
}

/// Seals [sourcePath] to [targetPath] for the holder of [recipientPublicKey]
/// and returns the size of the sealed file in bytes.
///
/// Streams in 1 MiB chunks: the ZIP can be hundreds of megabytes and must
/// never be materialised in memory.
Future<int> sealFile({
  required String sourcePath,
  required String targetPath,
  required Uint8List recipientPublicKey,
}) async {
  if (recipientPublicKey.length != 32) {
    throw ArgumentError('X25519 recipient key must be 32 bytes, got ${recipientPublicKey.length}');
  }

  final x25519 = X25519();
  final ephemeral = await x25519.newKeyPair();
  final ephemeralPublic = (await ephemeral.extractPublicKey()).bytes;
  final shared = await x25519.sharedSecretKey(
    keyPair: ephemeral,
    remotePublicKey: SimplePublicKey(recipientPublicKey, type: KeyPairType.x25519),
  );
  final key = await Hkdf(hmac: Hmac.sha256(), outputLength: 32).deriveKey(
    secretKey: shared,
    nonce: Uint8List.fromList([...ephemeralPublic, ...recipientPublicKey]),
    info: utf8.encode(_hkdfInfo),
  );

  final header = Uint8List(_headerLength);
  header.setRange(0, 6, _magic);
  header[6] = _formatVersion;
  header[7] = _suiteX25519AesGcm;
  header.setRange(8, 40, ephemeralPublic);
  ByteData.view(header.buffer).setUint32(40, _chunkSize, Endian.big);

  final aes = AesGcm.with256bits();
  final source = File(sourcePath).openSync();
  final sink = File(targetPath).openWrite();
  try {
    sink.add(header);
    final total = source.lengthSync();
    var written = 0;
    var counter = 0;
    // do/while so a zero-byte source still produces one final chunk —
    // otherwise an empty payload would be indistinguishable from truncation.
    do {
      final plain = source.readSync(_chunkSize);
      written += plain.length;
      final box = await aes.encrypt(
        plain,
        secretKey: key,
        nonce: _chunkNonce(counter, isFinal: written >= total),
        aad: header,
      );
      final frame = Uint8List(4)
        ..buffer.asByteData().setUint32(0, box.cipherText.length + _tagLength, Endian.big);
      sink
        ..add(frame)
        ..add(box.cipherText)
        ..add(box.mac.bytes);
      counter++;
    } while (written < total);
    await sink.flush();
  } finally {
    await sink.close();
    source.closeSync();
  }
  return File(targetPath).lengthSync();
}

/// 12-byte GCM nonce: 8-byte big-endian chunk counter, 3 zero bytes, then a
/// final-chunk flag. Written as two 32-bit halves because `setUint64` is
/// unavailable on the web build.
Uint8List _chunkNonce(int counter, {required bool isFinal}) {
  final nonce = Uint8List(12);
  ByteData.view(nonce.buffer).setUint32(4, counter, Endian.big);
  nonce[11] = isFinal ? 1 : 0;
  return nonce;
}
