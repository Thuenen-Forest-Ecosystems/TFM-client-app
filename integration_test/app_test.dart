import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:patrol/patrol.dart';
import 'package:terrestrial_forest_monitor/main.dart' as app;

/// End-to-end tests that drive the REAL app on an emulator/device.
///
/// Run the whole file:
///   patrol test -t integration_test/app_test.dart
///
/// The authenticated flows need credentials. They are read from the app's
/// `.env` file (git-ignored, already bundled as an asset):
///   TFM_TEST_EMAIL=you@thuenen.de
///   TFM_TEST_PASSWORD=your-password
/// A `--dart-define` of the same names overrides `.env` (handy for CI, which
/// has no `.env`). If neither is set, the authenticated flows skip themselves.
const _emailDefine = String.fromEnvironment('TFM_TEST_EMAIL');
const _passwordDefine = String.fromEnvironment('TFM_TEST_PASSWORD');

/// Resolves credentials, preferring a `--dart-define` over `.env`. Assumes
/// `dotenv.load()` has already run (done in [_bootAndLogin]).
(String email, String password) _resolveCreds() => (
  _emailDefine.isNotEmpty ? _emailDefine : (dotenv.env['TFM_TEST_EMAIL'] ?? ''),
  _passwordDefine.isNotEmpty
      ? _passwordDefine
      : (dotenv.env['TFM_TEST_PASSWORD'] ?? ''),
);

// NOTE ON BOOTING THE APP
// These tests call the app's real `main()`. That runs the full startup
// (Supabase, PowerSync, FMTC, dotenv), so the device needs the same runtime
// environment as a normal launch: a bundled `.env` and network reachability to
// the backend. This app does NOT override `FlutterError.onError` or use
// `runZonedGuarded`, so `main()` is safe to call from a Patrol test. For even
// stricter isolation Patrol suggests extracting a `createTfmApp()` seam from
// `main()` (build the root widget without `runApp`/`ensureInitialized`) and
// pumping that instead — see integration_test/README.md.

void main() {
  patrolTest('app boots and lands on the login screen', ($) async {
    await app.main();
    await $.pumpAndSettle(timeout: const Duration(seconds: 60));

    // Unauthenticated users are redirected to /login by the BeamGuard. The
    // email/password fields render in both online and offline login states.
    expect($(#loginEmailField), findsOneWidget);
    expect($(#loginPasswordField), findsOneWidget);
  });

  patrolTest('login -> home walkthrough', ($) async {
    if (!await _bootAndLogin($)) return;

    // We're on the home (Schema) screen; its settings gear is present.
    expect($(#homeSettingsButton), findsOneWidget);
  });

  patrolTest('settings: open page, switch language and theme', ($) async {
    if (!await _bootAndLogin($)) return;

    // The home gear beams to the Profile/settings page.
    await $(#homeSettingsButton).tap();

    // Settings page is open when its language + theme options are in the tree.
    // scrollTo() waits for the option and brings it into view.
    await $(#langOption_de).scrollTo();
    expect($(#langOption_en), findsOneWidget);
    expect($(#themeOption_light), findsOneWidget);

    // Switch language and assert the selected-option indicator (a check_circle
    // shown only on the active option) follows the tap — proving the setting
    // actually took effect, independent of localized label text.
    await $(#langOption_en).scrollTo().tap();
    expect($(#langOption_en).$(Icons.check_circle), findsOneWidget);

    await $(#langOption_de).scrollTo().tap();
    expect($(#langOption_de).$(Icons.check_circle), findsOneWidget);

    // Same for the theme setting. Leaves the app on light/German (sane defaults).
    await $(#themeOption_dark).scrollTo().tap();
    expect($(#themeOption_dark).$(Icons.check_circle), findsOneWidget);

    await $(#themeOption_light).scrollTo().tap();
    expect($(#themeOption_light).$(Icons.check_circle), findsOneWidget);
  });

  patrolTest('offline login with cached credentials', ($) async {
    // Self-contained: log in ONLINE first so offline credentials are guaranteed
    // to be cached (the app's logout() deliberately keeps them), then log out
    // and sign back in with the network switched off.
    if (!await _bootAndLogin($)) return;
    final (email, password) = _resolveCreds();

    // Log out via the account menu -> back to the login screen. Offline
    // credentials are intentionally preserved by logout().
    await $(#homeAccountMenuButton).tap();
    await $(#logoutMenuItem).tap();
    await $(#loginEmailField).waitUntilVisible();

    // Force the device offline so the app switches to the offline login path.
    // The device has both Wi-Fi and cellular, so disable both.
    await $.platform.mobile.disableWifi();
    await $.platform.mobile.disableCellular();

    try {
      // The app's connectivity listener flips to offline and reveals the
      // offline login button (which requires the cached previous login).
      var offline = false;
      for (var i = 0; i < 20; i++) {
        offline = $(#loginOfflineSubmitButton).exists;
        if (offline) break;
        await $.pump(const Duration(seconds: 1));
      }
      expect(
        offline,
        isTrue,
        reason:
            'Offline login button never appeared after disabling the network — '
            'connectivity did not flip offline, or no previous login is cached.',
      );

      // Sign in offline with the cached credentials.
      await $(#loginEmailField).enterText(email);
      await $(#loginPasswordField).enterText(password);
      await $(#loginOfflineSubmitButton).tap();

      // Success = offline auth navigated us to the home (Schema) screen.
      await $(#homeSettingsButton).waitUntilVisible();
    } finally {
      // ALWAYS restore connectivity, even if an assertion above failed, so the
      // device isn't left offline for the next test / the user.
      await $.platform.mobile.enableWifi();
      await $.platform.mobile.enableCellular();
    }
  });
}

/// Boots the app, grants the location permission, and signs in.
///
/// Credentials come from `.env` (loaded here before booting so we can skip
/// cleanly without a pointless full startup); a `--dart-define` overrides them
/// for CI. Returns `false` when no credentials are configured (the caller
/// should `return` to skip). On success the app is on the home (Schema) screen.
Future<bool> _bootAndLogin(PatrolIntegrationTester $) async {
  await dotenv.load(fileName: '.env');
  final (email, password) = _resolveCreds();
  if (email.isEmpty || password.isEmpty) {
    // ignore: avoid_print
    print(
      '⏭  Skipping authenticated flow: set TFM_TEST_EMAIL and '
      'TFM_TEST_PASSWORD in TFM-app/.env (or pass --dart-define).',
    );
    return false;
  }

  await app.main();
  await $.pumpAndSettle(timeout: const Duration(seconds: 60));

  // The app requests location (GPS) / nearby-devices (Bluetooth) permission via
  // native OS dialogs. Tapping these is the whole reason for Patrol — plain
  // integration_test cannot reach outside the Flutter view.
  if (await $.platform.mobile.isPermissionDialogVisible(
    timeout: const Duration(seconds: 5),
  )) {
    await $.platform.mobile.grantPermissionWhenInUse();
  }

  // A restored session may have skipped login entirely — if so, skip sign-in.
  if ($(#loginEmailField).exists) {
    // Login fields are keyed in lib/screens/login.dart, so these finders are
    // stable regardless of German/English labels or widget order.
    await $(#loginEmailField).enterText(email);
    await $(#loginPasswordField).enterText(password);

    // Which submit button is shown depends on the app's connectivity check,
    // which resolves asynchronously (and can briefly report offline in the
    // instrumentation environment). Poll for whichever button appears and tap
    // it: online -> Supabase sign-in, offline -> cached-credential sign-in.
    var online = false;
    var offline = false;
    for (var i = 0; i < 15; i++) {
      online = $(#loginSubmitButton).exists;
      offline = $(#loginOfflineSubmitButton).exists;
      if (online || offline) break;
      await $.pump(const Duration(seconds: 1));
    }
    if (online) {
      await $(#loginSubmitButton).tap();
    } else if (offline) {
      await $(#loginOfflineSubmitButton).tap();
    } else {
      fail(
        'No login button appeared within 15s — neither the online nor the '
        'offline branch rendered. Check connectivity / cached-login state.',
      );
    }
  }

  // Success = we left the login screen. The home screen may host a live map/GPS
  // that never "settles", so poll for the login field to disappear instead of
  // pumpAndSettle.
  for (var i = 0; i < 60 && $(#loginEmailField).exists; i++) {
    await $.pump(const Duration(seconds: 1));
  }
  expect(
    $(#loginEmailField),
    findsNothing,
    reason: 'Still on the login screen after 60s — check credentials/network.',
  );

  // Wait until the home (Schema) screen has actually rendered its app-bar gear,
  // so callers can assert/act immediately without racing the route transition.
  await $(#homeSettingsButton).waitUntilVisible();
  return true;
}
