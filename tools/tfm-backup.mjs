#!/usr/bin/env node
// Support-side counterpart to lib/services/backup_crypto.dart.
//
//   node tools/tfm-backup.mjs keygen [--out <dir>]
//   node tools/tfm-backup.mjs decrypt <backup.tfmbak> <out.zip> --key <private.pem>
//
// Dependency-free on purpose: this has to run years from now on whatever
// machine support happens to have, without a working npm install.
//
// Container format (see backup_crypto.dart for the rationale):
//   header 44 bytes: 'TFMBAK' | version | suite | ephemeral X25519 pk (32) | chunk size (uint32 BE)
//   then chunks:     length (uint32 BE, ciphertext+tag) | ciphertext | GCM tag (16)
//   key  = HKDF-SHA256(X25519(eph_sk, recipient_pk), salt: eph_pk||recipient_pk, info: 'tfm-backup-v1')
//   nonce = uint32BE(0) | uint32BE(counter) | 0 0 0 | finalFlag, header as AAD

import crypto from 'node:crypto';
import fs from 'node:fs';
import path from 'node:path';

const MAGIC = Buffer.from('TFMBAK', 'ascii');
const FORMAT_VERSION = 1;
const SUITE_X25519_AES_GCM = 1;
const HEADER_LENGTH = 44;
const TAG_LENGTH = 16;
const HKDF_INFO = Buffer.from('tfm-backup-v1', 'ascii');
// DER prefix for an X25519 SubjectPublicKeyInfo — Node has no raw-key import.
const SPKI_PREFIX = Buffer.from('302a300506032b656e032100', 'hex');

const rawPublicKey = (key) => key.export({ type: 'spki', format: 'der' }).subarray(-32);

function keygen(outDir) {
  const { publicKey, privateKey } = crypto.generateKeyPairSync('x25519');
  const pub = rawPublicKey(publicKey).toString('base64');
  const privPath = path.join(outDir, 'tfm-backup-private.pem');
  fs.writeFileSync(privPath, privateKey.export({ type: 'pkcs8', format: 'pem' }), { mode: 0o600 });
  console.log(`private key : ${privPath}  (KEEP OFFLINE, ESCROW IT — losing it makes every backup unreadable)`);
  console.log(`public key  : add to the app's .env as`);
  console.log(`\nBACKUP_RECIPIENT_KEY=${pub}\n`);
}

function decrypt(inPath, outPath, keyPath) {
  const privateKey = crypto.createPrivateKey(fs.readFileSync(keyPath));
  const recipientRaw = rawPublicKey(crypto.createPublicKey(privateKey));

  const fd = fs.openSync(inPath, 'r');
  const size = fs.fstatSync(fd).size;
  const out = fs.openSync(outPath, 'w');
  try {
    const header = readExactly(fd, 0, HEADER_LENGTH);
    if (!header.subarray(0, 6).equals(MAGIC)) throw new Error('not a TFM backup container');
    if (header[6] !== FORMAT_VERSION) throw new Error(`unsupported format version ${header[6]}`);
    if (header[7] !== SUITE_X25519_AES_GCM) throw new Error(`unsupported suite ${header[7]}`);
    const ephemeralRaw = header.subarray(8, 40);

    const shared = crypto.diffieHellman({
      privateKey,
      publicKey: crypto.createPublicKey({
        key: Buffer.concat([SPKI_PREFIX, ephemeralRaw]),
        format: 'der',
        type: 'spki',
      }),
    });
    const key = Buffer.from(
      crypto.hkdfSync('sha256', shared, Buffer.concat([ephemeralRaw, recipientRaw]), HKDF_INFO, 32),
    );

    let offset = HEADER_LENGTH;
    let counter = 0;
    while (offset < size) {
      const frame = readExactly(fd, offset, 4);
      const length = frame.readUInt32BE(0);
      if (length < TAG_LENGTH) throw new Error(`chunk ${counter}: implausible length ${length}`);
      const body = readExactly(fd, offset + 4, length);
      offset += 4 + length;
      // A chunk is final iff nothing follows it; a truncated file therefore
      // fails its authentication tag instead of yielding a short database.
      const isFinal = offset >= size;
      const decipher = crypto.createDecipheriv('aes-256-gcm', key, nonce(counter, isFinal));
      decipher.setAAD(header);
      decipher.setAuthTag(body.subarray(length - TAG_LENGTH));
      const plain = Buffer.concat([decipher.update(body.subarray(0, length - TAG_LENGTH)), decipher.final()]);
      fs.writeSync(out, plain);
      counter++;
    }
    if (counter === 0) throw new Error('container has no chunks');
    console.log(`ok — ${counter} chunk(s) authenticated, wrote ${outPath}`);
  } finally {
    fs.closeSync(fd);
    fs.closeSync(out);
  }
}

function nonce(counter, isFinal) {
  const buf = Buffer.alloc(12);
  buf.writeUInt32BE(counter, 4);
  buf[11] = isFinal ? 1 : 0;
  return buf;
}

function readExactly(fd, position, length) {
  const buf = Buffer.alloc(length);
  const read = fs.readSync(fd, buf, 0, length, position);
  if (read !== length) throw new Error(`unexpected end of file at ${position} (wanted ${length}, got ${read})`);
  return buf;
}

const [command, ...rest] = process.argv.slice(2);
const flag = (name) => {
  const i = rest.indexOf(name);
  return i === -1 ? undefined : rest[i + 1];
};
const positional = rest.filter((a, i) => !a.startsWith('--') && !(i > 0 && rest[i - 1].startsWith('--')));

if (command === 'keygen') {
  keygen(flag('--out') ?? process.cwd());
} else if (command === 'decrypt') {
  const keyPath = flag('--key');
  if (positional.length < 2 || !keyPath) {
    console.error('usage: node tools/tfm-backup.mjs decrypt <backup.tfmbak> <out.zip> --key <private.pem>');
    process.exit(2);
  }
  decrypt(positional[0], positional[1], keyPath);
} else {
  console.error('usage: node tools/tfm-backup.mjs keygen [--out <dir>]');
  console.error('       node tools/tfm-backup.mjs decrypt <backup.tfmbak> <out.zip> --key <private.pem>');
  process.exit(2);
}
