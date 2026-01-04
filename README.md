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

### Publishing to Microsoft Store (Recommended for End Users)

The Microsoft Store eliminates certificate issues and provides automatic updates.

**Setup (One-time):**
1. Create a [Microsoft Partner Center](https://partner.microsoft.com/dashboard) account
2. Reserve app name: "Terrestrial Forest Monitor"
3. Create app submission
4. Add GitHub secrets:
   - `MS_TENANT_ID` - Your Azure tenant ID
   - `MS_SELLER_ID` - Your seller ID from Partner Center
   - `MS_CLIENT_ID` - Azure AD app client ID
   - `MS_CLIENT_SECRET` - Azure AD app client secret
   - `MS_PRODUCT_ID` - Product ID from Partner Center

**Publishing:**
1. Uncomment the Microsoft Store CLI steps in `.github/workflows/build-release-windows.yml`
2. Create a release - Store MSIX will be automatically submitted
3. Microsoft reviews and publishes (usually 24-48 hours)

**Benefits:**
- No certificate installation needed
- Users trust Microsoft Store
- Automatic updates
- Better discoverability

Read the [GitHub CLI documentation](https://docs.github.com/en/repositories/releasing-projects-on-github/managing-releases-in-a-repository) for more information.

## Installation (End Users)

### Windows

**Option 1: Single-Click Installer (Easiest - Recommended)**
1. Go to [Releases](../../releases/latest)
2. Download **both files**:
   - `terrestrial_forest_monitor_sideload.msix`
   - `install.bat`
3. Put both files in the same folder
4. **Double-click** `install.bat`
5. Click "Yes" when asked for administrator access
6. Wait for installation to complete
7. Done! ✅

**Option 2: Microsoft Store (Coming Soon - No certificate needed)**
- Search "Terrestrial Forest Monitor" in Microsoft Store
- Click Install
- Automatic updates included

**Option 3: Portable (No installation)**
1. Go to [Releases](../../releases/latest)
2. Download `TFM-windows-portable.zip`
3. Extract and run `terrestrial_forest_monitor.exe`
4. Manual updates required

### Updating

**MSIX users**: The app checks for updates on startup and shows a notification when a new version is available. Click "Update" to download and install the latest MSIX.

**Portable users**: Download the latest ZIP from releases and replace your existing files.