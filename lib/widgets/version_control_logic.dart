import 'dart:convert';

import 'package:flutter/foundation.dart';

const String allReleasesUrl =
    'https://github.com/Thuenen-Forest-Ecosystems/TFM-client-app/releases';

@immutable
class ParsedVersion {
  const ParsedVersion({required this.semanticParts, required this.buildNumber});

  final List<int> semanticParts;
  final int buildNumber;
}

@immutable
class ReleaseInfo {
  const ReleaseInfo({required this.tagName, required this.htmlUrl});

  final String tagName;
  final String htmlUrl;
}

ParsedVersion? parseVersion(String version) {
  try {
    final normalized = version.startsWith('v') ? version.substring(1) : version;
    final parts = normalized.split('+');
    final semanticParts = parts.first
        .split('.')
        .where((part) => part.isNotEmpty)
        .map(int.parse)
        .toList(growable: false);

    if (semanticParts.isEmpty) {
      return null;
    }

    final buildNumber = parts.length > 1 ? int.tryParse(parts[1]) ?? 0 : 0;

    return ParsedVersion(semanticParts: semanticParts, buildNumber: buildNumber);
  } catch (error) {
    debugPrint('Error parsing version "$version": $error');
    return null;
  }
}

bool isNewerVersion(String latestVersion, String currentVersion) {
  final latest = parseVersion(latestVersion);
  final current = parseVersion(currentVersion);

  if (latest == null || current == null) {
    debugPrint('Error comparing versions: latest=$latestVersion current=$currentVersion');
    return false;
  }

  final maxLength = latest.semanticParts.length > current.semanticParts.length
      ? latest.semanticParts.length
      : current.semanticParts.length;

  for (int index = 0; index < maxLength; index++) {
    final latestPart = index < latest.semanticParts.length ? latest.semanticParts[index] : 0;
    final currentPart = index < current.semanticParts.length ? current.semanticParts[index] : 0;

    if (latestPart > currentPart) return true;
    if (latestPart < currentPart) return false;
  }

  return latest.buildNumber > current.buildNumber;
}

ReleaseInfo? parseLatestReleaseResponse(String responseBody) {
  try {
    final latestRelease = json.decode(responseBody) as Map<String, dynamic>;
    final latestTag = latestRelease['tag_name'] as String?;
    final htmlUrl = latestRelease['html_url'] as String?;

    if (latestTag == null || htmlUrl == null) {
      return null;
    }

    return ReleaseInfo(tagName: latestTag, htmlUrl: htmlUrl);
  } catch (error) {
    debugPrint('Error parsing latest release response: $error');
    return null;
  }
}
