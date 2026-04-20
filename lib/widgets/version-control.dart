import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:package_info_plus/package_info_plus.dart';
import 'package:url_launcher/url_launcher.dart';

import 'package:terrestrial_forest_monitor/widgets/version_control_logic.dart';

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
  String _releaseUrl = allReleasesUrl;
  bool _isChecking = false;
  bool _hasChecked = false;

  @override
  void initState() {
    super.initState();
    _checkForUpdates();
  }

  Future<void> _checkForUpdates() async {
    if (_hasChecked || _isChecking) return;

    if (!mounted) return;

    setState(() {
      _isChecking = true;
    });

    try {
      // Get current app version
      final packageInfo = await PackageInfo.fromPlatform();
      final currentVersion = 'v${packageInfo.version}+${packageInfo.buildNumber}';

      if (mounted) {
        setState(() {
          _currentVersion = currentVersion;
        });
      }

      // Fetch the latest stable release from GitHub.
      final response = await http
          .get(
            Uri.parse(
              'https://api.github.com/repos/Thuenen-Forest-Ecosystems/TFM-client-app/releases/latest',
            ),
            headers: {
              'Accept': 'application/vnd.github+json',
              'X-GitHub-Api-Version': '2022-11-28',
              'User-Agent': 'TFM-client-app-version-check',
            },
          )
          .timeout(const Duration(seconds: 10));

      if (response.statusCode == 200) {
        final latestRelease = parseLatestReleaseResponse(response.body);
        final latestTag = latestRelease?.tagName;
        final htmlUrl = latestRelease?.htmlUrl;

        if (mounted &&
            latestTag != null &&
            htmlUrl != null &&
            isNewerVersion(latestTag, currentVersion)) {
          setState(() {
            _latestVersion = latestTag;
            _releaseUrl = htmlUrl;
          });
        }
      }
    } catch (e) {
      // Silently fail - no internet connection or API error
      debugPrint('Failed to check for updates: $e');
    } finally {
      if (mounted) {
        setState(() {
          _isChecking = false;
          _hasChecked = true;
        });
      }
    }
  }

  Future<void> _openReleaseUrl() async {
    final uri = Uri.parse(_releaseUrl);
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
        onTap: _openReleaseUrl,
        borderRadius: BorderRadius.circular(0),
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
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
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

              //Icon(Icons.open_in_new, color: textColor, size: 20),
              const Spacer(),
              IconButton(
                icon: Icon(Icons.launch, color: textColor, size: 20),
                onPressed: _openReleaseUrl,
                tooltip: hasUpdate ? 'Release der neuen Version öffnen' : 'Alle Releases öffnen',
              ),
              IconButton(
                icon: _isChecking
                    ? SizedBox(
                        width: 20,
                        height: 20,
                        child: CircularProgressIndicator(strokeWidth: 2, color: textColor),
                      )
                    : Icon(Icons.refresh, color: textColor, size: 20),
                onPressed: _isChecking
                    ? null
                    : () {
                        setState(() {
                          _hasChecked = false;
                          _latestVersion = null;
                          _releaseUrl = allReleasesUrl;
                        });
                        _checkForUpdates();
                      },
                tooltip: 'Nach Updates suchen',
              ),
            ],
          ),
        ),
      ),
    );
  }
}
