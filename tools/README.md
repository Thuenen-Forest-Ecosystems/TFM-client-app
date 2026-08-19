# `tfm-backup.mjs` — support backups

The app's **Backup aller Datenbanken** button (Profil → Sicherungen) packs every
local TFM database file into a ZIP for support. Where a recipient key is
configured, that ZIP is sealed to it and saved as `.tfmbak` instead — the
archive contains the complete local database (Trupp members, plot coordinates,
unsynced records) and travels through the user's Downloads folder and, as a
rule, an e-mail attachment.

This script is the other end of that: it creates the key pair, and it opens the
sealed backups.

## Requirements

Node 18 or newer. **No `npm install`** — the script uses only `node:crypto` and
`node:fs`, so it still runs years from now on whatever machine support happens
to have.

## Opening a backup

```bash
node tools/tfm-backup.mjs decrypt .backups/tfm-datenbank-backup-20260819-111003.tfmbak .backups/backup.zip \
  --key ~/.tfm/tfm-backup-private.pem
```

```
ok — 42 chunk(s) authenticated, wrote backup.zip
```

Every chunk is authenticated on the way out, so that line also means the file
arrived intact. Read the manifest first:

```bash
unzip -p .backups/backup.zip manifest.txt
```

```
TFM Datenbank-Backup
Erstellt: 2026-08-19T10:15:00.123456
App-Version: 1.1.16+131
Aktive Datenbank: tfm_<userId>.db (Snapshot via VACUUM INTO)
PRAGMA quick_check: ok
Dateien:
  tfm_<userId>.db (48210944 Bytes)
    sha256: 9f2c…
```

`PRAGMA quick_check` is the line to read first in a data-loss case: it was run
against the **live** database on the device, before the snapshot was taken, so
anything other than `ok` means the database was already damaged on the device
rather than in transit. The per-file SHA-256 is an identity, not a tamper
control — it lets you match a re-packed copy against the original, or spot the
same backup submitted twice. The ZIP's own CRC32 already covers transit damage.

Then unpack and open the databases with any SQLite client:

```bash
unzip .backups/backup.zip -d .backups/backup/
sqlite3 .backups/backup/tfm_<userId>.db '.tables'
```

File names follow `<base>_<userId>.db`, where the base comes from the server
config and is usually `tfm` (older or differently configured deployments use
`postgres`); the manifest names the active one explicitly.

The active database is a `VACUUM INTO` snapshot — a single consistent file.
Inactive ones (a legacy shared db, other users' files on the same device) are
copied as-is and may be accompanied by their `-wal`/`-shm` journals; keep those
next to their `.db` so SQLite can replay un-checkpointed changes.

## Creating the key pair

Once, for the whole deployment:

```bash
node tools/tfm-backup.mjs keygen --out ~/.tfm
```

```
private key : ~/.tfm/tfm-backup-private.pem  (KEEP OFFLINE, ESCROW IT …)
public key  : add to the app's .env as

BACKUP_RECIPIENT_KEY=9VpJwe58mu2BVKFNiCh/i2iQhsZ2TSP/QJN79z7rxRM=
```

The private key is written `0600` and is **the only way any sealed backup will
ever be readable again**. Escrow it before relying on the feature: a lost key
does not degrade the backups, it destroys them. Note that this is the failure
mode the backup button exists to prevent, so it deserves more care than the
usual "store it somewhere safe".

Rotating the key only affects backups made after the change — keep the old
private key for as long as you might still receive a backup from a device
running an older build.

## Wiring the public key into the app

Add it to `.env` (gitignored, bundled as a Flutter asset and read once at
startup — a full restart is needed, hot reload will not pick it up):

```
BACKUP_RECIPIENT_KEY=<base64 public key>
```

Release builds reconstruct `.env` from GitHub secrets, so the same value has to
exist there too, alongside `DMZ_KEY`, in the workflows that write `.env`
(`publish_android.yml`, `build-release-windows.yml`, `build-release-ios.yml`,
`deploy-desktop.yml`).
**Until it does, release builds keep exporting plain readable ZIPs.**

With the key unset the app deliberately falls back to an unsealed `.zip` and
the button label drops the _(verschlüsselt)_ suffix. That is on purpose: a
backup nobody can open would be worse than an unsealed one, and this button
exists to rescue data.

## What sealing does and does not do

It buys **confidentiality**: personal data in the archive is unreadable to
anyone but the key holder, in Downloads, in a mailbox, on a mail relay.

It does **not** make a backup tamper-proof. The recipient key is public and
ships in the app, so anyone holding the app can seal a file of their own
choosing — a sealed backup proves nothing about what a device actually
contained. Treat a restored backup as untrusted input; the server's audit trail
stays the authority on what is real.

## When it fails

Failures print one line to stderr and exit `1` (usage errors exit `2`). No
partial output is ever left behind — a half-written `.zip` would look like a
backup.

| Message                                                                                   | What happened                                                                                                        |
| ----------------------------------------------------------------------------------------- | -------------------------------------------------------------------------------------------------------------------- |
| `chunk N failed authentication — wrong private key, or the file was altered or truncated` | Usually the wrong key. Node reports every AES-GCM failure identically, so a modified or clipped file lands here too. |
| `truncated container: wanted N bytes at offset M, got K`                                  | The file is short — an interrupted download or a mail gateway that clipped the attachment. Ask for it again.         |
| `… is already a plain ZIP — that build had no recipient key configured, just unzip it`    | Nothing to decrypt; the device ran a build without `BACKUP_RECIPIENT_KEY`.                                           |
| `… is not a TFM backup container`                                                         | Not a backup at all, or damaged beyond its first 44 bytes.                                                           |
| `unsupported format version N` / `unsupported suite N`                                    | The backup was written by a newer app than this script. Update `tfm-backup.mjs`.                                     |

## Container format

Documented so the format outlives the script. The reference implementation is
[`lib/services/backup_crypto.dart`](../lib/services/backup_crypto.dart); the
scheme is age-style and deliberately boring.

Header, 44 bytes, in clear and authenticated as AAD on every chunk:

| Offset | Bytes | Content                                          |
| ------ | ----- | ------------------------------------------------ |
| 0      | 6     | `TFMBAK`                                         |
| 6      | 1     | Format version (`1`)                             |
| 7      | 1     | Suite (`1` = X25519 + HKDF-SHA256 + AES-256-GCM) |
| 8      | 32    | Ephemeral X25519 public key, fresh per backup    |
| 40     | 4     | Chunk plaintext size, uint32 big-endian (1 MiB)  |

Then chunks to the end of the file, each a uint32 big-endian length (ciphertext
plus tag), the ciphertext, and the 16-byte GCM tag.

```
shared = X25519(ephemeral_sk, recipient_pk)
key    = HKDF-SHA256(ikm: shared, salt: eph_pk || recipient_pk,
                     info: "tfm-backup-v1", length: 32)
nonce  = uint32BE(0) | uint32BE(chunk counter) | 0x00 0x00 0x00 | final flag
```

The counter and final-chunk flag live in the nonce, so a reordered or truncated
file fails authentication rather than yielding a plausible-looking short
database. Chunking keeps memory flat: neither side ever holds more than 1 MiB
of the archive, which matters when a database snapshot runs to hundreds of
megabytes.

## Related

- [`lib/services/backup_crypto.dart`](../lib/services/backup_crypto.dart) — the sealing side
- [`lib/widgets/database-backup-button.dart`](../lib/widgets/database-backup-button.dart) — staging, manifest, ZIP
- [`test/backup_crypto_test.dart`](../test/backup_crypto_test.dart) — seals with Dart, opens with this script, compares bytes. Run with `flutter test test/backup_crypto_test.dart`; it skips itself where `node` is unavailable.
