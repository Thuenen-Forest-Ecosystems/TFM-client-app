# Terresrial Forst Monitor CLIENT

## Pre-requisites

Get and install [Flutter](https://flutter.dev/docs/get-started/install).

## Getting Started

Clone the repository and navigate to the project directory.

```bash
cd TFM-client-app
cp .env.example .env
flutter pub get
flutter run
```

## Release (Developers)

### Creating a New Release

1. **Update version** in `pubspec.yaml` (e.g., `1.0.0+48`)
2. **Commit and push** changes
3. **Create release** using GitHub CLI:
   ```bash
   gh release create v1.0.48 --title "Version 1.0.48" --notes-file .github/RELEASE_TEMPLATE.md
   ```
4. **GitHub Actions** will automatically build and upload Windows artifacts
5. **Edit release notes** on GitHub to describe changes

### Updating an Existing Release

Manually trigger the workflow:

1. Go to Actions → "Build Windows Release" → "Run workflow"
2. Enter the release tag (e.g., `v1.0.48`)
3. Artifacts will be rebuilt and uploaded to that release

## Installation

### Android

**Installation**

1. Gehe zu [Releases](../../releases/latest)
2. Lade `app-release.apk` herunter
3. Öffne die heruntergeladene APK-Datei

**Bei erster Installation:**

- Android zeigt eine Sicherheitswarnung
- Tippe auf **"Einstellungen"** oder **"Trotzdem installieren"**
- Aktiviere **"Apps aus dieser Quelle zulassen"** (nur für Browser/Dateimanager)
- Gehe zurück und installiere die App

### Windows

**Installation**

1. Gehe zu [Releases](../../releases/latest)
2. Lade `TFM-Setup.exe` herunter
3. **Doppelklick** auf die heruntergeladene Datei

**Windows SmartScreen Warnung (normal):**

Windows zeigt eine Sicherheitswarnung, da die App nicht im Microsoft Store ist:

**Windows 11:**

1. Warnung: "Windows hat den Start dieser unbekannten App verhindert"
2. Klicke auf **"Weitere Informationen"**
3. Klicke auf **"Trotzdem ausführen"**
4. Bei UAC-Abfrage auf **"Ja"** klicken (für Installation)

**Windows 10:**

1. Warnung: "Der Computer wurde durch Windows geschützt"
2. Klicke auf **"Weitere Informationen"**
3. Klicke auf **"Trotzdem ausführen"**
4. Bei UAC-Abfrage auf **"Ja"** klicken (für Installation)

💡 **Warum diese Warnung?**

- Die App ist nicht mit einem Microsoft-Zertifikat signiert
- Dies ist normal für Open-Source-Software
- Die App ist sicher - der Quellcode ist öffentlich einsehbar

**Alternative:** Wenn Ihre IT-Abteilung die Installation blockiert, kontaktieren Sie Ihren Administrator.

### Updating

Um die App zu aktualisieren:

1. Lade die neueste Version von `TFM-Setup.exe` herunter
2. Führe den Installer aus - er aktualisiert die bestehende Installation automatisch
