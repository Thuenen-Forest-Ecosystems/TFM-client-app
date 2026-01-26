import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:package_info_plus/package_info_plus.dart';
import 'package:url_launcher/url_launcher.dart';

/// Widget that checks for new app versions on GitHub releases
/// Shows nothing if on latest version, displays update notification if newer version available
class VersionControl extends StatefulWidget {
  const VersionControl({super.key});

  @override
  State<VersionControl> createState() => _VersionControlState();
}

class _VersionControlState extends State<VersionControl> {
  String? _currentVersion;
  String? _latestVersion;
  String? _releaseUrl;
  bool _isChecking = false;
  bool _hasChecked = false;

  @override
  void initState() {
    super.initState();
    _checkForUpdates();
  }

  Future<void> _checkForUpdates() async {
    if (_hasChecked || _isChecking) return;

    setState(() {
      _isChecking = true;
    });

    try {
      // Get current app version
      final packageInfo = await PackageInfo.fromPlatform();
      final currentVersion = 'v${packageInfo.version}+${packageInfo.buildNumber}';

      setState(() {
        _currentVersion = currentVersion;
      });

      // Fetch latest release from GitHub
      final response = await http
          .get(
            Uri.parse(
              'https://api.github.com/repos/Thuenen-Forest-Ecosystems/TFM-client-app/releases',
            ),
            headers: {
              'Accept': 'application/vnd.github+json',
              'X-GitHub-Api-Version': '2022-11-28',
            },
          )
          .timeout(const Duration(seconds: 10));

      if (response.statusCode == 200) {
        final List<dynamic> releases = json.decode(response.body);

        // Find the latest non-prerelease version
        final latestRelease = releases.firstWhere(
          (release) => release['prerelease'] == false && release['draft'] == false,
          orElse: () => null,
        );

        if (latestRelease != null) {
          final latestTag = latestRelease['tag_name'] as String;
          final htmlUrl = latestRelease['html_url'] as String;

          // Compare versions
          if (_isNewerVersion(latestTag, currentVersion)) {
            setState(() {
              _latestVersion = latestTag;
              _releaseUrl = htmlUrl;
            });
          }
        }
      }
    } catch (e) {
      // Silently fail - no internet connection or API error
      debugPrint('Failed to check for updates: $e');
    } finally {
      setState(() {
        _isChecking = false;
        _hasChecked = true;
      });
    }
  }

  /// Compare version strings in format v1.0.0+50
  /// Returns true if latestVersion is newer than currentVersion
  bool _isNewerVersion(String latestVersion, String currentVersion) {
    try {
      // Remove 'v' prefix if present
      final latest = latestVersion.startsWith('v') ? latestVersion.substring(1) : latestVersion;
      final current = currentVersion.startsWith('v') ? currentVersion.substring(1) : currentVersion;

      // Split by '+' to separate version from build number
      final latestParts = latest.split('+');
      final currentParts = current.split('+');

      // Compare semantic version (1.0.0)
      final latestSemVer = latestParts[0].split('.').map(int.parse).toList();
      final currentSemVer = currentParts[0].split('.').map(int.parse).toList();

      for (int i = 0; i < 3; i++) {
        if (latestSemVer[i] > currentSemVer[i]) return true;
        if (latestSemVer[i] < currentSemVer[i]) return false;
      }

      // If semantic versions are equal, compare build numbers
      if (latestParts.length > 1 && currentParts.length > 1) {
        final latestBuild = int.parse(latestParts[1]);
        final currentBuild = int.parse(currentParts[1]);
        return latestBuild > currentBuild;
      }

      return false;
    } catch (e) {
      debugPrint('Error comparing versions: $e');
      return false;
    }
  }

  Future<void> _openReleaseUrl() async {
    if (_releaseUrl == null) return;

    final uri = Uri.parse(_releaseUrl!);
    if (await canLaunchUrl(uri)) {
      await launchUrl(uri, mode: LaunchMode.externalApplication);
    }
  }

  @override
  Widget build(BuildContext context) {
    // Show nothing if we're still checking or haven't checked yet
    if (!_hasChecked || _currentVersion == null) {
      return const SizedBox.shrink();
    }

    final hasUpdate = _latestVersion != null;
    final cardColor = hasUpdate
        ? Theme.of(context).colorScheme.primaryContainer
        : Theme.of(context).colorScheme.surfaceContainerHighest;
    final textColor = hasUpdate
        ? Theme.of(context).colorScheme.onPrimaryContainer
        : Theme.of(context).colorScheme.onSurface;

    return Card(
      color: cardColor,
      child: InkWell(
        onTap: hasUpdate ? _openReleaseUrl : null,
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Row(
            children: [
              Icon(
                hasUpdate ? Icons.system_update : Icons.check_circle,
                color: textColor,
                size: 32,
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      hasUpdate ? 'Neue Version verfügbar' : 'Aktuelle Version',
                      style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: textColor),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      hasUpdate
                          ? 'Version $_latestVersion ist verfügbar (Aktuell: $_currentVersion)'
                          : 'Version $_currentVersion',
                      style: TextStyle(fontSize: 14, color: textColor.withOpacity(0.8)),
                    ),
                  ],
                ),
              ),
              if (hasUpdate) Icon(Icons.open_in_new, color: textColor, size: 20),
            ],
          ),
        ),
      ),
    );
  }
}
