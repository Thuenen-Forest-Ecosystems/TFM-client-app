import 'package:flutter_test/flutter_test.dart';
import 'package:terrestrial_forest_monitor/widgets/version_control_logic.dart';

void main() {
  group('version control logic', () {
    test('detects a newer build with the same semantic version', () {
      expect(isNewerVersion('v1.0.21+89', 'v1.0.21+88'), isTrue);
    });

    test('detects a newer semantic version even without a build number', () {
      expect(isNewerVersion('v1.1.0', 'v1.0.21+89'), isTrue);
    });

    test('does not report an update for an older release', () {
      expect(isNewerVersion('v1.0.20+88', 'v1.0.21+89'), isFalse);
    });

    test('returns null for invalid versions', () {
      expect(parseVersion('main'), isNull);
    });

    test('parses the latest release API response', () {
      const responseBody = '{"tag_name":"v1.0.21+89","html_url":"https://example.invalid/release"}';

      final release = parseLatestReleaseResponse(responseBody);

      expect(release, isNotNull);
      expect(release!.tagName, 'v1.0.21+89');
      expect(release.htmlUrl, 'https://example.invalid/release');
    });

    test('exposes the all releases fallback URL', () {
      expect(
        allReleasesUrl,
        'https://github.com/Thuenen-Forest-Ecosystems/TFM-client-app/releases',
      );
    });
  });
}
